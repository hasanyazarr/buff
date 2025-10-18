function [gt, diag] = generate_bubble_tracks(net, flow, nFrames, frameRateHz, opts)
%GENERATE_BUBBLE_TRACKS Generate bubble trajectories along a flow graph.
%   gt = generate_bubble_tracks(net, flow, nFrames, frameRateHz)
%   gt = [frame, id, x, y, z] (meters) one row per bubble observation.
%   [gt, diag] additionally returns diagnostics (spawn counts, etc.).
%
% Inputs
%   net  : struct with fields nodes [N x 3], edges [M x 2], lengths [M x 1], radii [M x 1]
%   flow : struct with fields Q_m3ps [M x 1], v_mps [M x 1], dir_unit [M x 3] (optional)
%   nFrames (scalar) number of frames
%   frameRateHz      frame rate
%   opts (optional)  parameters:
%     .mean_births_per_frame (550) Poisson mean births per frame
%     .max_bubbles_cap       (15000) hard cap of simultaneously alive bubbles
%     .rho_model             ('uniform_area') or 'centerline' or numeric scalar in [0,1)
%     .spawn_weight          ('flux_length') one of 'flux','flux_length','length'
%     .life_max_frames       (2*nFrames) maximum age (frames) before forced death
%     .dt_substeps           (1) sub-stepping per frame (increase for large velocities)
%     .fov_margin_m          (0) extra margin beyond node bbox for culling
%     .seed                  (42) RNG seed
%
% Output
%   gt   : [K x 5] double matrix [frame, id, x, y, z]
%   diag : struct diagnostics
%
% Notes
%   - Bubble motion along an edge uses mean speed v_mean and Poiseuille profile
%     with u_max = 2*v_mean and u(rho) = u_max*(1 - rho^2), where rho fixed per bubble.
%   - Direction of motion determined by sign of Q_m3ps per edge.
%   - At nodes, next edge chosen among outgoing (by flow direction) weighted by |Q|.
%   - Fallback Poisson sampler included if poissrnd unavailable.
%
% Author: Step 4 integration (2025)

if nargin < 5 || isempty(opts), opts = struct; end
% Safe option fetch (avoids referencing missing dynamic field)
function val = getOptLocal(name, defaultVal)
    if isfield(opts, name) && ~isempty(opts.(name))
        val = opts.(name);
    else
        val = defaultVal;
    end
end

mean_births_per_frame = getOptLocal('mean_births_per_frame', 550);
max_bubbles_cap       = getOptLocal('max_bubbles_cap',       15000);
rho_model             = getOptLocal('rho_model',             'uniform_area');
spawn_weight          = getOptLocal('spawn_weight',          'flux_length');
life_max_frames       = getOptLocal('life_max_frames',       2*max(1,nFrames));
dt_substeps           = max(1, round(getOptLocal('dt_substeps', 1)));
fov_margin_m          = getOptLocal('fov_margin_m',          0);
seed                  = getOptLocal('seed',                  42);
csv_path              = getOptLocal('csv_path',              '');  % optional: write CSV
csv_header            = getOptLocal('csv_header',            true);

rng(seed);

% ---- unpack ----
nodes = double(net.nodes);
edges = double(net.edges); M = size(edges,1);
L = double(net.lengths(:));
R = double(net.radii(:)); %#ok<NASGU>
Q = double(flow.Q_m3ps(:));
v_mean = double(flow.v_mps(:));
if any([numel(L), numel(Q), numel(v_mean)] ~= M)
    error('generate_bubble_tracks:SizeMismatch','Input edge arrays inconsistent size.');
end
if isfield(flow,'dir_unit') && ~isempty(flow.dir_unit)
    du = double(flow.dir_unit);
else
    vec = nodes(edges(:,2),:) - nodes(edges(:,1),:);
    du = vec ./ vecnorm(vec,2,2);
end
du(~isfinite(du)) = 0;

% ---- oriented direction & adjacency (physical flow direction) ----
from = zeros(M,1); to = zeros(M,1); du_dir = du;
for e=1:M
    if Q(e) >= 0
        from(e) = edges(e,1); to(e) = edges(e,2);
    else
        from(e) = edges(e,2); to(e) = edges(e,1); du_dir(e,:) = -du(e,:);
    end
end
Nnodes = size(nodes,1);
outEdges = cell(Nnodes,1);
for e=1:M
    if isfinite(Q(e)) && Q(e) ~= 0
        outEdges{from(e)}(end+1) = e; %#ok<AGROW>
    end
end

% ---- spawn weights ----
switch lower(spawn_weight)
    case 'flux'
        w = abs(Q);
    case 'flux_length'
        w = abs(Q) .* max(L, eps);
    case 'length'
        w = max(L, eps);
    otherwise
        error('generate_bubble_tracks:BadSpawnWeight','Unknown spawn_weight %s', spawn_weight);
end
w(~isfinite(w)) = 0;
if all(w==0), w(:)=1; end
cdf_w = cumsum(w/sum(w));

% ---- FoV bounds (node box) ----
xMin = min(nodes(:,1))-fov_margin_m; xMax = max(nodes(:,1))+fov_margin_m;
yMin = min(nodes(:,2))-fov_margin_m; yMax = max(nodes(:,2))+fov_margin_m;
zMin = min(nodes(:,3))-fov_margin_m; zMax = max(nodes(:,3))+fov_margin_m;
inFov = @(p) p(1)>=xMin && p(1)<=xMax && p(2)>=yMin && p(2)<=yMax && p(3)>=zMin && p(3)<=zMax; %#ok<NASGU>

% ---- helpers ----
sample_edge = @() find(cdf_w >= rand(), 1, 'first');
sample_rho = @() local_sample_rho(rho_model);
choose_next = @(node) local_choose_next(node, outEdges, Q);
poisson = @(lam) local_poisson(lam);

% ---- containers ----
dt = 1 / max(1, frameRateHz);
dt_sub = dt / dt_substeps;

active.id = zeros(0,1,'uint32');
active.e  = zeros(0,1);
active.s  = zeros(0,1);   % arclength along edge (flow direction)
active.rho= zeros(0,1);
active.age= zeros(0,1);
next_id = uint32(1);

gt = zeros(0,5); % [frame,id,x,y,z]
spawn_counts = zeros(nFrames,1);
death_counts = zeros(nFrames,1);
active_counts = zeros(nFrames,1);

% Prepare CSV streaming if requested (write header now, append per frame)
csv_stream = false;
if ~isempty(csv_path)
    try
        fid_csv = fopen(csv_path,'w');
        if fid_csv==-1
            warning('generate_bubble_tracks:CSVOpenFail','Could not open %s for writing. Skipping CSV export.', csv_path);
        else
            csv_stream = true;
            if csv_header
                fprintf(fid_csv,'frame,id,x,y,z\n');
            end
        end
    catch ME
        warning(ME.identifier,'CSV init failed (%s). Skipping CSV export.', ME.message);
        csv_stream = false;
    end
end

% ---- main frames loop ----
for f = 1:nFrames
    % births
    nBirth = poisson(max(mean_births_per_frame,0));
    spawn_counts(f) = nBirth;
    if nBirth > 0
        nBirth = min(nBirth, max(0, max_bubbles_cap - numel(active.id)));
    end
    if nBirth > 0
        new_ids = next_id + uint32(0:nBirth-1);
        next_id = next_id + uint32(nBirth);
        new_e = zeros(nBirth,1); new_s = zeros(nBirth,1); new_rho = zeros(nBirth,1);
        for k=1:nBirth
            e = sample_edge();
            new_e(k) = e;
            L_e = L(e); if L_e <= 0, L_e = eps; end
            new_s(k) = rand() * L_e;
            new_rho(k) = sample_rho();
        end
        active.id  = [active.id; new_ids(:)]; %#ok<AGROW>
        active.e   = [active.e;  new_e]; %#ok<AGROW>
        active.s   = [active.s;  new_s]; %#ok<AGROW>
        active.rho = [active.rho; new_rho]; %#ok<AGROW>
        active.age = [active.age; zeros(nBirth,1)]; %#ok<AGROW>
    end

    % movement (substeps)
    for ss = 1:dt_substeps
        if isempty(active.id), break; end
        eidx = active.e;
        u_max = 2 * v_mean(eidx);
        u = max(0, u_max .* (1 - active.rho.^2));
        ds = u * dt_sub;
        active.s = active.s + ds;
        L_now = L(eidx);

        cross = find(active.s > L_now);
        % iterative routing while there are crossers
        guard = 0; to_kill = false(numel(active.id),1);
        while ~isempty(cross)
            guard = guard + 1; if guard > 1000, warning('Routing guard break'); break; end
            for ii = 1:numel(cross)
                b = cross(ii); e = active.e(b); L_e = L(e);
                over = active.s(b) - L_e; if over < 0, over = 0; end
                node_to = to(e);
                enext = choose_next(node_to);
                if enext == 0
                    % dead end => mark kill
                    active.s(b) = L_e;
                    to_kill(b) = true;
                else
                    active.e(b) = enext;
                    active.s(b) = over; % residual distance along new edge
                end
            end
            % remove killed
            if any(to_kill)
                keep = ~to_kill;
                active.id  = active.id(keep);
                active.e   = active.e(keep);
                active.s   = active.s(keep);
                active.rho = active.rho(keep);
                active.age = active.age(keep);
                to_kill = to_kill(keep);
            end
            % recompute
            if isempty(active.id), break; end
            eidx = active.e; L_now = L(eidx); cross = find(active.s > L_now);
        end
        death_counts(f) = death_counts(f) + sum(to_kill);
    end

    % record positions this frame
    if ~isempty(active.id)
        eidx = active.e; s = active.s;
        p0 = nodes(from(eidx),:);
        dir = du_dir(eidx,:);
        pos = p0 + dir .* s;
        rows = [repmat(f,numel(active.id),1), double(active.id), pos];
        gt = [gt; rows]; %#ok<AGROW>
        if csv_stream
            % Stream append (vectorized fprintf)
            try
                fprintf(fid_csv, '%d,%d,%.9g,%.9g,%.9g\n', rows.');
            catch ME
                warning(ME.identifier,'CSV write failed mid-run (%s). Closing stream.', ME.message);
                fclose(fid_csv); csv_stream = false;
            end
        end
    end

    % aging & lifespan removal
    if ~isempty(active.id)
        active.age = active.age + 1;
        if life_max_frames > 0
            keep = active.age <= life_max_frames;
            if any(~keep)
                death_counts(f) = death_counts(f) + sum(~keep);
                active.id  = active.id(keep);
                active.e   = active.e(keep);
                active.s   = active.s(keep);
                active.rho = active.rho(keep);
                active.age = active.age(keep);
            end
        end
    end

    % record active count AFTER deaths this frame
    active_counts(f) = numel(active.id);
end

% ---- diagnostics ----
if nargout > 1
    diag.spawn_counts = spawn_counts;
    diag.death_counts = death_counts;
    diag.active_counts = active_counts;
    diag.total_rows   = size(gt,1);
    diag.unique_ids   = numel(unique(gt(:,2)));
    diag.frames       = nFrames;
    diag.mean_per_frame = size(gt,1)/max(1,nFrames);
    diag.params = struct('mean_births_per_frame',mean_births_per_frame,'max_bubbles_cap',max_bubbles_cap, ...
        'rho_model',rho_model,'spawn_weight',spawn_weight,'life_max_frames',life_max_frames,'dt_substeps',dt_substeps,'seed',seed);
    if ~isempty(csv_path)
        diag.csv_path = csv_path;
        diag.csv_streamed = csv_stream;
    end
end

% Close CSV file if opened
if exist('fid_csv','var') && fid_csv>0
    fclose(fid_csv);
end

end

% ---------------- local helpers ----------------
function rho = local_sample_rho(rho_model)
    if ischar(rho_model) || isstring(rho_model)
        switch lower(string(rho_model))
            case "centerline"
                rho = 0;
            case "uniform_area"
                rho = sqrt(rand()); % rho^2 ~ U(0,1)
            otherwise
                error('generate_bubble_tracks:BadRhoModel','Unknown rho_model %s', rho_model);
        end
    else
        rho = max(0, min(0.9999, double(rho_model)));
    end
end

function enext = local_choose_next(node, outEdges, Q)
    if node < 1 || node > numel(outEdges)
        enext = 0; return; end
    cand = outEdges{node};
    if isempty(cand), enext = 0; return; end
    w = abs(Q(cand)); w(~isfinite(w)) = 0;
    if all(w==0), enext = 0; return; end
    cdf = cumsum(w/sum(w));
    enext = cand(find(cdf >= rand(),1,'first'));
    if isempty(enext), enext = cand(end); end
end

function k = local_poisson(lambda)
    % Fallback Poisson sampler if poissrnd missing.
    if exist('poissrnd','file') == 2 %#ok<EXIST>
        k = poissrnd(lambda);
        return;
    end
    % Knuth algorithm (good for moderate lambdas)
    L = exp(-lambda); k = 0; p = 1;
    while p > L
        k = k + 1; p = p * rand();
    end
    k = k - 1;
end
