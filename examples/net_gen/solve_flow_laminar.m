function flow = solve_flow_laminar(net, phys)
%SOLVE_FLOW_LAMINAR  Steady Poiseuille flow on a vessel graph (physics-preserving).
%
% Physics-preserving version (2025-10):
%   • Incidence matrix convention: B(i,e)=+1 (source), B(j,e)=-1 (sink)
%     => B^T P = P_i - P_j ; Q = g .* (B^T P)
%   • Dirichlet solve with fixed pressures at roots & leaves.
%   • Single global scale to match target median speed v_target_mps.
%   • Mass-balance diagnostics (L1/L2/Linf divergence at interior nodes).
%   • Optional display-only shaping (v_display) that does NOT alter physical Q/v.
%
% Inputs network: nodes [N x 3], edges [M x 2], radii, lengths, root_idx.
% phys optional fields:
%   mu_Pa_s, P_in_Pa, P_out_Pa, v_target_mps, v_bounds_mps.
%   display_shape.enable (false), .method ('percentile'|'none'),
%   .quantiles ([1 50 99]), .targets_mps ([2e-5 5e-2 1.4e-1]).

if nargin < 2, phys = struct; end

% ---- Physical parameters ----
mu        = getf(phys,'mu_Pa_s',       0.001);
mmHg2Pa   = 133.322;
P_out     = getf(phys,'P_out_Pa',      45*mmHg2Pa);
P_in_init = getf(phys,'P_in_Pa',       50*mmHg2Pa);
v_target  = getf(phys,'v_target_mps',  0.05);
v_bounds  = getf(phys,'v_bounds_mps',  [2e-5 0.14]);

% Display-only shaping opts
dsh_enable  = getfs(phys,'display_shape','enable',false);
dsh_method  = getfs(phys,'display_shape','method','percentile');
dsh_q       = getfs(phys,'display_shape','quantiles',[1 50 99]);
dsh_targets = getfs(phys,'display_shape','targets_mps',[2e-5 5e-2 1.4e-1]);

% ---- Unpack network ----
nodes  = net.nodes;
edgesE = double(net.edges);
r_edge = double(net.radii);
L_edge = double(net.lengths);
N = size(nodes,1); M = size(edgesE,1);

if any(L_edge<=0) || any(r_edge<=0)
    error('solve_flow_laminar:NonPositive','Lengths/radii must be > 0.');
end
if M==0 || N==0
    flow = struct('P_node_Pa',zeros(N,1),'Q_m3ps',zeros(M,1),'v_mps',zeros(M,1), ...
                  'dir_unit',zeros(M,3),'g_SI',zeros(M,1), ...
                  'boundary',struct,'scaling',struct,'qc',struct,'phys',phys);
    return;
end

% ---- Geometry / conductance ----
i_idx = edgesE(:,1); j_idx = edgesE(:,2);
vec = nodes(j_idx,:) - nodes(i_idx,:);
dir_unit = vec ./ vecnorm(vec,2,2);
g = (pi .* r_edge.^4) ./ (8*mu .* L_edge);   % conductance
A_edge = pi * r_edge.^2;                     % cross-sectional area

% ---- Incidence matrix (source +1, sink -1) ----
B = sparse([i_idx; j_idx], [ (1:M)'; (1:M)' ], [ +ones(M,1); -ones(M,1) ], N, M);

% ---- Boundary sets ----
deg = accumarray([i_idx; j_idx], 1, [N 1]);
roots = unique(net.root_idx(:)); roots = roots(roots>=1 & roots<=N);
isLeaf = (deg==1); isRoot = false(N,1); isRoot(roots) = true; leaves = find(isLeaf & ~isRoot);
if isempty(leaves)
    if ~isempty(roots)
        r0 = roots(1); dvec = nodes(:,3) - nodes(r0,3); [~,idxSort] = sort(dvec,'descend');
        leaves = idxSort(1:min(3,numel(idxSort)));
    else
        warning('solve_flow_laminar:NoLeaves','No leaves detected; flows will be zero.');
    end
end
fixed = unique([roots(:); leaves(:)]); free = setdiff((1:N)', fixed);

% ---- Dirichlet Poiseuille Solve ----
Lmat = B * spdiags(g,0,M,M) * B';
P_fixed = zeros(N,1); P_fixed(leaves) = P_out; P_fixed(roots) = P_in_init;
L_ff = Lmat(free, free); rhs = -Lmat(free,fixed) * P_fixed(fixed);
P = zeros(N,1);
if ~isempty(free)
    if rcond(full(L_ff)) < 1e-14
        P(free) = (L_ff + 1e-12*speye(size(L_ff))) \ rhs;
    else
        P(free) = L_ff \ rhs;
    end
end
P(fixed) = P_fixed(fixed);

% Physical flows & speeds
dP = (B.' * P);      % (P_i - P_j)
Q  = g .* dP;
v  = abs(Q) ./ A_edge;

% ---- Global scale for median speed ----
v_med = median(v(v>0)); s = 1;
if ~isempty(v_med) && v_med>0, s = v_target / v_med; end
s = max(0.1, min(20, s));
P = P * s; Q = Q * s; v = v * s;

% Pressure cosmetic shift (leaf mean -> P_out)
if ~isempty(leaves)
    P = P + (P_out - mean(P(leaves)));
end

% ---- QC: mass balance & velocity bounds ----
div_all = B * Q; div_free = div_all; div_free(fixed) = 0;
mb_L1 = sum(abs(div_free)); mb_L2 = norm(div_free); mb_Linf = max(abs(div_free));
v_viol_low  = nnz(v < v_bounds(1));
v_viol_high = nnz(v > v_bounds(2));

% ---- Display-only shaping (optional) ----
flow.display = struct();
if dsh_enable
    v_abs = v; v_abs(~isfinite(v_abs)) = 0;
    switch lower(charify(dsh_method))
        case 'none'
            v_tgt = v_abs;
        case 'percentile'
            vq = prctile_simple(v_abs, dsh_q);
            v_tgt = rankwise_piecewise_map(v_abs, vq, dsh_targets);
        otherwise
            warning('solve_flow_laminar:DisplayShapeMethod','Unknown display_shape.method=%s; using none.', dsh_method); v_tgt = v_abs;
    end
    Q_tgt = sign(Q) .* (v_tgt .* A_edge);
    flow.display.v_mps_tgt  = v_tgt;
    flow.display.Q_m3ps_tgt = Q_tgt;
    flow.display.delta_v_L2 = norm(v_tgt - v_abs);
    flow.display.delta_Q_L2 = norm(Q_tgt - Q);
end

% ---- Pack output ----
flow.P_node_Pa = P;
flow.Q_m3ps    = Q;
flow.v_mps     = v;
flow.g_SI      = g;
flow.dir_unit  = dir_unit;
flow.boundary.roots  = roots;
flow.boundary.leaves = leaves;
flow.boundary.free   = free;
flow.scaling.factor_global = s;
flow.phys = phys;
flow.qc.v_mps_median   = median(v(v>0));
flow.qc.v_mps_minmax   = [min(v) max(v)];
flow.qc.mass_balance_L1   = mb_L1;
flow.qc.mass_balance_L2   = mb_L2;
flow.qc.mass_balance_Linf = mb_Linf;
flow.qc.v_viol_low     = v_viol_low;
flow.qc.v_viol_high    = v_viol_high;
end

% ----------------- helpers -----------------
function v = getf(S,f,def)
if isstruct(S) && isfield(S,f) && ~isempty(S.(f)), v = S.(f); else, v = def; end
end
function v = getfs(S,sub,f,def)
v = def;
if ~isstruct(S) || ~isfield(S,sub) || ~isstruct(S.(sub)), return; end
if isfield(S.(sub),f) && ~isempty(S.(sub).(f)), v = S.(sub).(f); end
end
function s = charify(x)
if isstring(x), s = char(x); else, s = x; end
end
function vq = prctile_simple(x, qs)
x = x(:); x = x(isfinite(x));
if isempty(x), vq = zeros(size(qs)); return; end
x = sort(x,'ascend'); n = numel(x); vq = zeros(size(qs));
for k = 1:numel(qs)
    p = min(max(qs(k),0),100)/100; idx = 1 + p*(n-1); i0=floor(idx); i1=ceil(idx);
    if i0==i1, vq(k)=x(i0); else, t=idx-i0; vq(k)=(1-t)*x(i0)+t*x(i1); end
end
end
function y = rankwise_piecewise_map(x, xq, yq)
x = x(:); xq = xq(:); yq = yq(:);
for k=2:numel(xq)
    if xq(k) < xq(k-1), xq(k) = xq(k-1); end
    if yq(k) < yq(k-1), yq(k) = yq(k-1); end
end
y = zeros(size(x));
for k=1:numel(x)
    xi = x(k);
    if xi <= xq(1)
        if xq(1)>0, y(k) = (xi/xq(1))*yq(1); else, y(k)=yq(1); end
    elseif xi >= xq(end)
        if numel(xq)>1 && xq(end)>xq(end-1)
            t=(xi-xq(end-1))/max(xq(end)-xq(end-1),eps); y(k)=yq(end-1)+t*(yq(end)-yq(end-1));
        else
            y(k)=yq(end);
        end
    else
        j=find(xq>=xi,1,'first'); xL=xq(j-1); xR=xq(j); yL=yq(j-1); yR=yq(j); t=(xi-xL)/max(xR-xL,eps); y(k)=yL+t*(yR-yL);
    end
end
end
