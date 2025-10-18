function [I8, rf_cube, meta] = simulate_bmode_fieldii(gt, PxSet, ImSet, SimSet, opts)
%SIMULATE_BMODE_FIELDII  Plane-wave (multi-angle) Field II B-mode simulation.
%   [I8, rf_cube, meta] = simulate_bmode_fieldii(gt, PxSet, ImSet, SimSet, opts)
%
% Inputs:
%   gt      [K x 5] bubble ground truth rows: [frame,id,x,y,z] (meters)
%   PxSet   struct with mapX, mapZ
%   ImSet   struct with nFrames, log_dynamic_range_dB
%   SimSet  struct (passed to fieldii_setup)
%   opts    (optional) struct fields:
%       n_lines          (256)  lateral receive lines
%       z_focus_m        (mid)  nominal focus depth used for TX placeholder
%       angles_deg       ([-10 0 10]) steering angles for plane-wave compounding (deg)
%       noise_level      (0.06) envelope noise amplitude (post-compounding)
%       noise_mode       ('post') 'post' | 'per_angle' | 'none'
%       seed             ([]) RNG seed for reproducibility (noise only)
%       tgc_fun          ([]) custom gain function handle: gain = f(Ns,t0,fs,PxSet)
%       rf_pad_samples   (512) extra trailing RF samples margin
%       keep_fieldii     (false) keep Field II session open (do not field_end)
%       reuse_hw         ([]) pass in existing hw struct from fieldii_setup (skip re-init)
%       envelope_norm    ('frame') 'frame' | 'p99' | 'none'
%       log_eps          (1e-6) floor added before log10
%       display_progress (false)
%       scatter_gain      (1)    scalar multiplier applied to every bubble amplitude
%       auto_gain         (true) if true, automatically rescales rf_compound when peak is extremely small
%       auto_gain_threshold (1e-12) peak |rf| below which auto gain triggers
%       auto_gain_target  (1e-3) target peak |rf| after auto scaling
%       diag_verbose      (true) extra per-line diagnostics (first frame)
%       synthetic_if_empty (false) inject synthetic impulses if RF remains ~0 (debug aid)
%       synthetic_gain    (1e-2) amplitude of injected synthetic impulses
%       safe_mode         (false) skip all focusing / steering calls (reduces crash risk)
%       debug_force_synthetic (false) bypass Field II entirely and render synthetic bubbles
%
% Outputs:
%   I8{f}     8-bit log-compressed B-mode frames
%   rf_cube{f} RF data (compounded) Ns x n_lines (single)
%   meta       struct with simulation metadata (angles, gain, timing, etc.)
%
% Notes:
%   - Noise is applied AFTER coherent angular compounding by default for stable SNR.
%   - Per-angle noise mode scales variance by 1/sqrt(Nangles) to keep global variance.
%   - No fractional delay interpolation currently (nearest sample placement).
%   - For performance the focusing foci depths reused across lines.
%

if nargin < 5 || isempty(opts), opts = struct; end

% ---- robust option getter ----
    function v = getOpt(name, def)
        if isfield(opts,name) && ~isempty(opts.(name))
            v = opts.(name); else, v = def; end
    end

reuse_hw       = getOpt('reuse_hw', []);
keep_fieldii   = logical(getOpt('keep_fieldii', false));
noise_mode     = lower(string(getOpt('noise_mode','post')));
angles_deg     = getOpt('angles_deg', [-10 0 10]);
if isempty(angles_deg); warning('simulate_bmode_fieldii:NoAngles','angles_deg empty -> using 0'); angles_deg = 0; end
n_lines        = max(1, round(getOpt('n_lines', 256)));
z_focus_m      = getOpt('z_focus_m', mean(double([PxSet.mapZ(1) PxSet.mapZ(end)])) );
noise_level    = getOpt('noise_level', 0.06);
rf_pad_samples = max(0, round(getOpt('rf_pad_samples', 512)));
seed           = getOpt('seed', []);
envelope_norm  = lower(string(getOpt('envelope_norm','frame')));
log_eps        = getOpt('log_eps', 1e-6);
display_progress = logical(getOpt('display_progress', false));
tgc_fun        = []; if isfield(opts,'tgc_fun'), tgc_fun = opts.tgc_fun; end
scatter_gain   = getOpt('scatter_gain', 1);
auto_gain      = logical(getOpt('auto_gain', true));
auto_gain_threshold = getOpt('auto_gain_threshold', 1e-12);
auto_gain_target    = getOpt('auto_gain_target', 1e-3);
diag_verbose        = logical(getOpt('diag_verbose', true));
synthetic_if_empty  = logical(getOpt('synthetic_if_empty', false));
synthetic_gain      = getOpt('synthetic_gain', 1e-2);
tx_mode             = lower(string(getOpt('tx_mode','hybrid'))); % 'hybrid' | 'plane' | 'focused'
% Backward compatibility for 'txmode' (without underscore)
if isfield(opts,'txmode') && (~isfield(opts,'tx_mode') || isempty(opts.tx_mode))
    try
        tx_mode = lower(string(opts.txmode));
    catch
    end
end
synthetic_trigger_peak = getOpt('synthetic_trigger_peak', 1e-14); % if max |rf| below this, treat as empty for synthetic injection
fallback_synthetic = logical(getOpt('fallback_synthetic', false));
safe_mode = logical(getOpt('safe_mode', false));
debug_force_synthetic = logical(getOpt('debug_force_synthetic', false));
fieldii_runtime_failed = false; crash_msg = '';

restore_rng = false; prev_rng = [];
if ~isempty(seed)
    prev_rng = rng; rng(seed); restore_rng = true;
end

% ---- Field II hardware ----
if ~isempty(reuse_hw)
    hw = reuse_hw;
else
    if exist('field_init','file') ~= 2
        try, fieldii_setup(SimSet); catch ME, error('simulate_bmode_fieldii:FieldIIMissing','Field II not available (%s).', ME.message); end
    end
    hw = fieldii_setup(SimSet);
end
tx = hw.tx; rx = hw.rx;
% Sanity: ensure excitation & impulse non-empty (prevent later zero-sample calc_scat crash)
try
    exc_dat = xdc_get(tx,'excitation'); imp_dat = xdc_get(tx,'impulse');
    if isempty(exc_dat) || numel(exc_dat)<2 || isempty(imp_dat) || numel(imp_dat)<2
        warning('simulate_bmode_fieldii:EmptyPulse','Excitation/impulse length very small (%d / %d). Forcing synthetic fallback.',numel(exc_dat),numel(imp_dat));
        fieldii_runtime_failed = true;
    end
catch MEp
    warning(MEp.identifier,'Pulse fetch failed (%s); enabling synthetic fallback.', MEp.message);
    fieldii_runtime_failed = true;
end

% ---- Precompute focusing depths ----
nfoci = 8; z_foci = linspace(PxSet.mapZ(1), PxSet.mapZ(end), nfoci); c = 1540;
t_foci = 2*z_foci/c;

% ---- Time/depth sampling ----
Nx = numel(PxSet.mapX); x_lines = linspace(PxSet.mapX(1), PxSet.mapX(end), n_lines);
t0 = 2*PxSet.mapZ(1)/c; t1 = 2*PxSet.mapZ(end)/c; fs = SimSet.fs_Hz;
Ns = ceil((t1 - t0)*fs) + rf_pad_samples;

% col2line mapping (rescale fallback)
if exist('rescale','file') == 2
    col2line = round(rescale(1:Nx, 1, n_lines));
else
    col2line = round( 1 + (0:(Nx-1)) * (n_lines-1)/(Nx-1) );
end
col2line = max(1,min(n_lines,col2line));

% ---- Steering delays per angle ----
elem_pos = xdc_get(tx,'rect');
nelem = hw.nelem;
ex = zeros(nelem,1);
for e=1:nelem
    idx = (elem_pos(:,end)==e);
    ex(e) = mean(elem_pos(idx,1));
end

nAngles = numel(angles_deg);
angle_rad = deg2rad(angles_deg(:));

% ---- Allocate outputs ----
I8 = cell(ImSet.nFrames,1); rf_cube = cell(ImSet.nFrames,1);
meta = struct();
meta.angles_deg = angles_deg; meta.n_lines = n_lines; meta.seed = seed; meta.noise_mode = char(noise_mode);
meta.envelope_norm = char(envelope_norm); meta.rf_pad_samples = rf_pad_samples;
meta.col2line = col2line; meta.z_foci = z_foci; meta.t_foci = t_foci; meta.c = c;
meta.log_eps = log_eps; meta.noise_level = noise_level;
meta.scatter_gain = scatter_gain; meta.auto_gain = auto_gain;
meta.tx_mode = char(tx_mode); meta.safe_mode = safe_mode; meta.debug_force_synthetic = debug_force_synthetic;
meta.auto_gain_threshold = auto_gain_threshold; meta.auto_gain_target = auto_gain_target;
meta.auto_gain_scales = zeros(ImSet.nFrames,1,'double');
meta.diag = struct();
meta.fallback_synthetic = fallback_synthetic;
meta.fieldii_runtime_failed = false;
meta.crash_msg = '';

% Initialize gain variable (will be overwritten in loop, but needs to exist for meta assignment)
gain = [];

% ---- Frame loop ----
for f = 1:ImSet.nFrames
    if display_progress && (mod(f, max(1,ceil(ImSet.nFrames/10)))==0 || f==1)
        fprintf('[simulate_bmode_fieldii] Frame %d/%d\n', f, ImSet.nFrames); end

    mask = gt(:,1)==f; pos = [gt(mask,3), gt(mask,4), gt(mask,5)];
    amp = scatter_gain * ones(sum(mask),1,'single');
    rf_compound = zeros(Ns, n_lines, 'single');

    % ---- Debug: check scatterers inside FOV ----
    xL = PxSet.mapX(1); xR = PxSet.mapX(end);
    zL = PxSet.mapZ(1); zR = PxSet.mapZ(end);

    fprintf('[F%3d] bubbles total=%d\n', f, size(pos,1));
    if ~isempty(pos)
        inFOV = pos(:,1)>=xL & pos(:,1)<=xR & pos(:,3)>=zL & pos(:,3)<=zR;
        fprintf('       in FOV (x,z)=%d | out=%d\n', nnz(inFOV), nnz(~inFOV));
        fprintf('       x[%g,%g] z[%g,%g] (m)\n', ...
            min(pos(:,1)), max(pos(:,1)), min(pos(:,3)), max(pos(:,3)));
    end

    line_energy = zeros(n_lines,1);
    k0_vals = zeros(n_lines,1); k1_vals = zeros(n_lines,1);

    % Debug bypass: purely synthetic image (no Field II) ------------------
    if debug_force_synthetic
        if ~isempty(pos)
            env_img = zeros(numel(PxSet.mapZ), numel(PxSet.mapX), 'single');
            [xg,zg] = meshgrid(PxSet.mapX, PxSet.mapZ);
            sx = (PxSet.mapX(end)-PxSet.mapX(1))/400; sz = (PxSet.mapZ(end)-PxSet.mapZ(1))/400;
            for bp=1:size(pos,1)
                g = exp(-((xg-pos(bp,1)).^2/(2*sx^2) + (zg-pos(bp,3)).^2/(2*sz^2)));
                env_img = max(env_img, g);
            end
            env_img = env_img / max(env_img(:)+eps);
        else
            env_img = zeros(numel(PxSet.mapZ), numel(PxSet.mapX), 'single');
        end
        scl = max(env_img(:)); if scl==0, scl = 1; end
        env_img = env_img / scl;
        Idb = 20*log10(env_img + log_eps); DR = ImSet.log_dynamic_range_dB; Idb = max(Idb,-DR); Inrm = (Idb+DR)/DR;
        I8{f} = uint8(255*Inrm); rf_cube{f} = [];
        if display_progress
            fprintf('   [debug_force_synthetic] frame %d synthetic bubbles rendered (count=%d)\n', f, size(pos,1));
        end
        if f==ImSet.nFrames, continue; else, continue; end
    end

    if ~isempty(pos) && ~fieldii_runtime_failed
        for ai = 1:nAngles
            th = angle_rad(ai);
            % Steering delays: plane wave arrival times at each element
            t_delays = (ex(:) * sin(th))/c; %#ok<NASGU>
            % Field II uses xdc_times_focus for per-element time offsets
            if ~safe_mode && (tx_mode=="plane" || tx_mode=="hybrid")
                try
                    xdc_times_focus(tx, 0, t_delays');
                catch MEtd
                    warning(MEtd.identifier,'xdc_times_focus failed (%s) -> synthetic fallback', MEtd.message);
                    fieldii_runtime_failed = true; crash_msg = MEtd.message; break;
                end
            end

            % Per-angle accumulator if adding noise per angle
            rf_angle = zeros(Ns, n_lines, 'single');
            for li = 1:n_lines
                x_line = x_lines(li);
                if ~safe_mode
                    try, xdc_center_focus(tx, [0 0 0]); catch, end
                    try, xdc_center_focus(rx, [x_line 0 0]); catch, end
                end
                % Transmit focusing / plane steering logic
                if ~safe_mode
                    if tx_mode=="plane"
                        % no tx focus
                    elseif tx_mode=="focused" || tx_mode=="hybrid"
                        try, xdc_focus(tx, 0, [0 0 z_focus_m]); catch, end
                    end
                end
                if ~safe_mode
                    try, xdc_focus(rx, t_foci(:), [x_line*ones(nfoci,1) zeros(nfoci,1) z_foci(:)]); catch, end
                end
                try
                    [rf_line, tstart] = calc_scat(tx, rx, pos, amp);
                catch MEcs
                    fieldii_runtime_failed = true; crash_msg = MEcs.message;
                    warning('simulate_bmode_fieldii:CalcScatFail','calc_scat failed (%s). Switching to synthetic fallback.', MEcs.message);
                    break; % exit line loop
                end
                k0 = floor((tstart - t0)*fs) + 1; % MATLAB 1-based
                k1 = k0 + numel(rf_line) - 1;
                if k1 < 1 || k0 > Ns, continue; end
                dst0 = max(1,k0); dst1 = min(Ns,k1);
                src0 = 1 + (dst0 - k0); src1 = src0 + (dst1-dst0);
                rf_angle(dst0:dst1, li) = rf_angle(dst0:dst1, li) + single(rf_line(src0:src1));
                if ai==1 % record stats only once per line
                    if dst1>=dst0
                        line_energy(li) = line_energy(li) + sum(abs(single(rf_line(src0:src1))));
                        k0_vals(li) = k0; k1_vals(li) = k1;
                    end
                end
            end

            % Noise per angle (optional)
            if strcmp(noise_mode,'per_angle') && noise_level>0
                % Generate band-limited noise (simple Gaussian -> lowpass smoothing)
                n = randn(size(rf_angle), 'single');
                if exist('imgaussfilt','file')==2
                    n = single(imgaussfilt(double(n), 1));
                end
                % scale variance so compounded net variance ~ noise_level^2
                n = (noise_level/sqrt(nAngles)) * n;
                rf_angle = rf_angle + n;
            end
            rf_compound = rf_compound + rf_angle; % coherent sum
            if fieldii_runtime_failed, break; end
        end
        if fieldii_runtime_failed
            meta.fieldii_runtime_failed = true; meta.crash_msg = crash_msg;
        end
        % Normalize compound amplitude by number of angles
        if ~fieldii_runtime_failed
            rf_compound = rf_compound / max(1,nAngles);
        end
    end

    if f==1 && diag_verbose && display_progress
        % Apodization diagnostics
        if isfield(hw,'apodization')
            apo = hw.apodization; nz = nnz(apo>0);
            fprintf('   [diag] active TX elements: %d/%d (apo sum=%.3g)\n', nz, numel(apo), sum(double(apo)));
        end
        nz_lines = nnz(line_energy>0);
        fprintf('   [diag] lines with energy: %d/%d\n', nz_lines, n_lines);
        if nz_lines>0
            fprintf('   [diag] k0 range: [%d %d] | k1 range: [%d %d] (Ns=%d)\n', min(k0_vals(k0_vals~=0)), max(k0_vals), min(k1_vals(k1_vals~=0)), max(k1_vals), Ns);
        end
    end

    % Optional synthetic fallback if no RF energy registered
    if (fieldii_runtime_failed && fallback_synthetic) && ~isempty(pos)
        % Force synthetic injection if Field II failed mid-run
        peak_now = 0;
        if display_progress
            fprintf('   [synthetic-fallback] Field II failed (%s). Injecting synthetic impulses.\n', crash_msg);
        end
        for p=1:size(pos,1)
            depth = pos(p,3); twoWay = 2*depth/c; k = round((twoWay - t0)*fs)+1;
            if k>=1 && k<=Ns
                [~,li] = min(abs(x_lines - pos(p,1)));
                rf_compound(k, li) = rf_compound(k, li) + synthetic_gain;
            end
        end
    elseif synthetic_if_empty && ~isempty(pos)
        peak_now = max(abs(rf_compound(:)));
        if (~any(rf_compound(:))) || peak_now < synthetic_trigger_peak
            if display_progress
                fprintf('   [synthetic] Injecting impulses (gain=%.3g) peak_rf=%.3g < %.3g.\n', synthetic_gain, peak_now, synthetic_trigger_peak);
            end
            for p=1:size(pos,1)
                depth = pos(p,3); twoWay = 2*depth/c; k = round((twoWay - t0)*fs)+1;
                if k>=1 && k<=Ns
                    [~,li] = min(abs(x_lines - pos(p,1)));
                    rf_compound(k, li) = rf_compound(k, li) + synthetic_gain;
                end
            end
            % Ensure synthetic peaks exceed log floor: floor_amp = 10^(-DR/20)
            DRloc = ImSet.log_dynamic_range_dB; floor_amp = 10^(-DRloc/20);
            peak_after = max(abs(rf_compound(:)));
            if peak_after < 2*floor_amp
                boost = (2*floor_amp)/max(peak_after,eps);
                rf_compound = rf_compound * boost;
                if display_progress
                    fprintf('   [synthetic] Boosting synthetic RF by %.2g to exceed floor (new peak=%.3g)\n', boost, max(abs(rf_compound(:))));
                end
            end
        end
    end

    % Adaptive auto gain (before noise addition / or after? choose after compounding before envelope)
    if auto_gain && ~fieldii_runtime_failed
        peak_rf = max(abs(rf_compound(:)));
        if peak_rf > 0 && peak_rf < auto_gain_threshold
            scale_fac = auto_gain_target / max(peak_rf, eps);
            rf_compound = rf_compound * scale_fac;
            meta.auto_gain_scales(f) = scale_fac;
            if display_progress
                fprintf('   [auto_gain] peak_rf %.3g < %.3g -> scaled by %.3g (new peak ~%.3g)\n', ...
                    peak_rf, auto_gain_threshold, scale_fac, max(abs(rf_compound(:))));
            end
        end
    end

    % Post-compounding noise (preferred)
    if strcmp(noise_mode,'post') && noise_level>0
        n = randn(size(rf_compound),'single');
        if exist('imgaussfilt','file')==2
            n = single(imgaussfilt(double(n),1));
        end
        n = noise_level * n;
        rf_compound = rf_compound + n;
    end

    % Envelope detection
    env = abs(hilbert(rf_compound));

    % TGC
    tt = (0:Ns-1)/fs + t0; z_depth = c*tt/2;
    if isempty(tgc_fun)
        gain = 0.6 + 1.2*((z_depth - PxSet.mapZ(1))/max(PxSet.mapZ(end)-PxSet.mapZ(1),eps)).^1.2;
    else
        gain = tgc_fun(Ns, t0, fs, PxSet);
    end
    env = env .* gain(:);

    % Scan conversion (improved lateral interpolation)
    env_img = local_scan_convert(env, PxSet, x_lines, fs, t0);

    % Envelope normalization modes
    switch envelope_norm
        case 'frame'
            scl = max(env_img(:));
        case 'p99'
            v = env_img(:); v = sort(v(v>0));
            if isempty(v)
                scl = 1;
            else
                scl = v( max(1, round(0.99*numel(v))) );
            end
        case 'none'
            scl = 1;
        otherwise
            warning('simulate_bmode_fieldii:NormMode','Unknown envelope_norm=%s; using frame.', envelope_norm);
            scl = max(env_img(:));
    end
    % Fallback: if scale is denormal / too tiny, revert to frame max
    if ~(isfinite(scl)) || scl < 1e-30
        if display_progress
            fprintf('   [norm-fallback] scl=%.3g invalid/tiny -> using frame max\n', scl);
        end
        scl = max(env_img(:));
    end
    env_img = env_img / max(scl, eps);

    if display_progress
        fprintf('   env_img max=%.3g (scl=%.3g) nonzeros=%d\n', ...
            max(env_img(:)), scl, nnz(env_img));
    end

    % Log compression
    Idb = 20*log10(env_img + log_eps);
    DR = ImSet.log_dynamic_range_dB;
    Idb = max(Idb, -DR);
    Inrm = (Idb + DR)/DR;
    I8{f} = uint8(255 * Inrm);
    rf_cube{f} = rf_compound;

    if f==1 || display_progress
        mx_line = 0;
    end
    mx_line = max(mx_line, max(abs(rf_compound(:))));
    if display_progress
        fprintf('   RF max abs after compounding (frame %d) = %.3g\n', f, mx_line);
    end
end

meta.gain_curve = gain; %#ok<NASGU>

% Cleanup
if restore_rng, rng(prev_rng); end
if ~keep_fieldii && isempty(reuse_hw) && ~fieldii_runtime_failed
    field_end;
end
end

function img = local_scan_convert(env, PxSet, x_lines, fs_Hz, t0)
%LOCAL_SCAN_CONVERT Depth accumulation + lateral interpolation.
% Converts RF envelope (time x lines) into an image (Nz x Nx) where Nx is
% the number of display lateral pixels, using linear interpolation between
% beam line centers instead of full-width replication (reduces horizontal banding).

Nz = numel(PxSet.mapZ); Nx = numel(PxSet.mapX);
Ns = size(env,1); c = 1540;
t = (0:Ns-1)/fs_Hz + t0; z = c*t/2; dz = PxSet.mapZ(2)-PxSet.mapZ(1);
iz = 1 + round((z - PxSet.mapZ(1))/dz); iz = max(1,min(Nz,iz));

n_lines = size(env,2);
env_depth = zeros(Nz, n_lines, 'single');
for li = 1:n_lines
    line_env = env(:,li);
    acc = accumarray(iz(:), single(line_env), [Nz 1], @max, single(0));
    env_depth(:,li) = acc;
end

% Lateral interpolation to pixel grid
xl = single(x_lines(:));
xp = single(PxSet.mapX(:));
% Ensure xl is strictly increasing for interp1 (guard against degenerate cases)
if any(diff(xl)==0)
    xl = xl + (0:numel(xl)-1)'*1e-9*max(abs(xl)+eps);
end
% Perform lateral interpolation. env_depth' is (n_lines x Nz) so interp1 returns (Nx x Nz)
tmp = interp1(double(xl), double(env_depth'), double(xp), 'linear', 'extrap');  % Nx x Nz
img = single(tmp'); % -> Nz x Nx
% Replace any NaNs (can occur if xl has duplicate values) with 0
if any(~isfinite(img(:)))
    img(~isfinite(img)) = 0;
end

% Clamp negatives (could appear due to extrapolation edge cases)
img(img<0) = 0;
end

% (No additional helpers)
