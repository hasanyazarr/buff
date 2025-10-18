function [I8, rf_cube] = simulate_bmode_fieldii(gt, PxSet, ImSet, SimSet, opts)
%SIMULATE_BMODE_FIELDII  Line-by-line Field II B-mode from bubble GT.
% Inputs: gt [Kx5], PxSet, ImSet, SimSet, opts (struct, optional)
% opts fields: n_lines (256), z_focus_m (mid-depth), prf_Hz (unused placeholder),
%              tgc_fun (function handle), noise_level (0.06)
% Returns: cell arrays I8{frame}, rf_cube{frame}

if nargin < 5 || isempty(opts), opts = struct; end

    function v = getOpt(name, default)
        if isfield(opts, name) && ~isempty(opts.(name))
            v = opts.(name);
        else
            v = default;
        end
    end

if exist('field_init','file') ~= 2
    % Attempt auto-add via fieldii_setup
    try, fieldii_setup(SimSet); catch ME, error('simulate_bmode_fieldii:FieldIIMissing','Field II not available (%s).', ME.message); end
end

hw = fieldii_setup(SimSet);

n_lines   = max(1, round(getOpt('n_lines', 256)));
z_focus_m = getOpt('z_focus_m', mean(double([PxSet.mapZ(1) PxSet.mapZ(end)])) );
noise_level = getOpt('noise_level', 0.06);
tgc_fun = []; if isfield(opts,'tgc_fun'), tgc_fun = opts.tgc_fun; end

Nx = numel(PxSet.mapX);
x_lines = linspace(PxSet.mapX(1), PxSet.mapX(end), n_lines);

c = 1540;
t0 = 2*PxSet.mapZ(1)/c; t1 = 2*PxSet.mapZ(end)/c;
Ns = ceil((t1 - t0)*SimSet.fs_Hz) + 512;
col2line = round(rescale(1:Nx, 1, n_lines));
col2line = max(1,min(n_lines,col2line));

I8 = cell(ImSet.nFrames,1); rf_cube = cell(ImSet.nFrames,1);

tx = hw.tx; rx = hw.rx; % handles

for f = 1:ImSet.nFrames
    mask = gt(:,1)==f;
    pos = [gt(mask,3), gt(mask,4), gt(mask,5)];
    amp = ones(sum(mask),1);
    rf_lines = zeros(Ns, n_lines, 'single');

    if ~isempty(pos)
        for li = 1:n_lines
            x_line = x_lines(li);
            xdc_center_focus(tx, [x_line 0 0]);
            xdc_center_focus(rx, [x_line 0 0]);
            xdc_focus(tx, 0, [x_line 0 z_focus_m]);
            z_foci = linspace(PxSet.mapZ(1), PxSet.mapZ(end), 8);
            t_foci = 2*z_foci/c;
            xdc_focus(rx, t_foci(:), [x_line*ones(numel(z_foci),1) zeros(numel(z_foci),1) z_foci(:)]);
            [rf, tstart] = calc_scat(tx, rx, pos, amp); %#ok<ASGLU>
            k0 = max(1, floor((tstart - t0)*SimSet.fs_Hz));
            k1 = min(Ns, k0 + numel(rf) - 1);
            dst = k0:k1; src = 1:(k1-k0+1);
            if ~isempty(dst)
                rf_lines(dst, li) = rf(src);
            end
        end
    end

    env = abs(hilbert(rf_lines));
    if isempty(tgc_fun)
        tt = (0:Ns-1)/SimSet.fs_Hz + t0;
        z_depth = c*tt/2;
        gain = 0.6 + 1.2*((z_depth - PxSet.mapZ(1))/max(PxSet.mapZ(end)-PxSet.mapZ(1),eps)).^1.2;
    else
        gain = tgc_fun(Ns, t0, SimSet.fs_Hz, PxSet);
    end
    env = env .* gain(:);

    env_img = local_scan_convert(env, PxSet, col2line, SimSet.fs_Hz, t0);
    if exist('add_colored_noise','file') ~= 2
        env_img = local_add_colored_noise(env_img, noise_level);
    else
        env_img = add_colored_noise(env_img, noise_level);
    end
    env_img = env_img / (max(env_img(:))+eps);
    Idb = 20*log10(env_img + 1e-6); Idb = max(Idb, -ImSet.log_dynamic_range_dB);
    Inrm = (Idb + ImSet.log_dynamic_range_dB)/ImSet.log_dynamic_range_dB;
    I8{f} = uint8(255 * Inrm);
    rf_cube{f} = rf_lines;
end

field_end;
end

function img = local_scan_convert(env, PxSet, col2line, fs_Hz, t0)
Nz = numel(PxSet.mapZ);
Ns = size(env,1); c = 1540;
t = (0:Ns-1)/fs_Hz + t0; z = c*t/2;
dz = PxSet.mapZ(2)-PxSet.mapZ(1);
iz = 1 + round((z - PxSet.mapZ(1))/dz); iz = max(1,min(Nz,iz));
img = zeros(Nz, numel(PxSet.mapX), 'single');
for col = 1:numel(PxSet.mapX)
    li = col2line(col);
    line = env(:,li);
    acc = accumarray(iz(:), single(line), [Nz 1], @max, single(0));
    img(:,col) = acc;
end
end

function imgN = local_add_colored_noise(img, level)
if nargin < 2, level = 0.06; end
img = single(img);
sz = size(img);
lf = imgaussfilt(randn(sz,'single'), 8);
lf = (lf - min(lf(:))) / max(eps, (max(lf(:))-min(lf(:))));
lf = 0.9 + 0.2*lf;
aw = randn(sz,'single');
aw = imgaussfilt(aw, 1.2);
aw = aw / max(1e-6, std(aw(:)));
imgN = img .* lf .* (1 + level*0.5*randn()) + level*0.4*aw;
imgN = max(0, imgN);
end
