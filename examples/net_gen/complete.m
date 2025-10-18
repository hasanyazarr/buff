%% complete.m
% High-Frequency ULM Dataset Generation (Progressive Build Script)
% This script will gradually incorporate all pipeline stages. Currently it
% includes:
%   - Init & parameter definitions (Step 0 / 1 from outline)
%   - Imaging grid validation & styled visualization
%   - Vessel network generation (Step 2)
%   - Flow solution (Step 3)
%   - Bubble track generation (ground truth) (Step 4)

%% 0) Init -----------------------------------------------------------------
clear; clc; close all;
fprintf('--- complete.m | Starting partial pipeline (Steps 0-5) ---\n');

% Add path to BUFF framework (robust to case)
if exist('buff','dir'); addpath('buff'); end
if exist('BUFF','dir'); addpath('BUFF'); end

% Add Field II to path
scriptDir = fileparts(mfilename('fullpath'));
fieldiiPath = fullfile(scriptDir, '..', '..', 'third_party', 'FieldII', 'm_files');
if exist(fieldiiPath, 'dir')
	addpath(fieldiiPath);
	fprintf('Added Field II to path: %s\n', fieldiiPath);
else
	warning('Field II path not found: %s', fieldiiPath);
end

rng(1); % reproducibility

%% Unified output folder (redirected under examples/network_generation/outputs) ---------
% We keep the previous folder structure (figures/, gt/, fieldii/) but root it inside:
% examples/network_generation/outputs/run_output_<timestamp>
% This makes it easier to locate results alongside the example scripts.
ts = datestr(now,'YYYYmmdd_HHMMSS');
[scriptDir,~,~] = fileparts(mfilename('fullpath'));
outParent = fullfile(scriptDir,'outputs');
if ~exist(outParent,'dir'), mkdir(outParent); end
baseOut = fullfile(outParent, ['run_output_' ts]);
if ~exist(baseOut,'dir'), mkdir(baseOut); end
figOutDir    = fullfile(baseOut,'figures');    if ~exist(figOutDir,'dir'), mkdir(figOutDir); end
gtOutDir     = fullfile(baseOut,'gt');         if ~exist(gtOutDir,'dir'), mkdir(gtOutDir); end
fieldOutDir  = fullfile(baseOut,'fieldii');    if ~exist(fieldOutDir,'dir'), mkdir(fieldOutDir); end
fprintf('Output root (example-local): %s\n', baseOut);

%% 1) Define image & metadata ----------------------------------------------
PxSet.mapX = linspace(-10e-3, 10e-3, 512);   % lateral (m)
PxSet.mapZ = linspace( 10e-3, 30e-3, 512);   % axial (m)

% --- Enrich grid/metadata -------------------------------------------------
ImSet.size_px = [numel(PxSet.mapZ), numel(PxSet.mapX)];  % [Nz Nx]
PxSet.dx = single(mean(diff(PxSet.mapX)));              % pitch (m)
PxSet.dz = single(mean(diff(PxSet.mapZ)));
PxSet.spanX = single(PxSet.mapX(end) - PxSet.mapX(1));
PxSet.spanZ = single(PxSet.mapZ(end) - PxSet.mapZ(1));

% Promote grids to single precision (memory efficiency downstream)
PxSet.mapX = single(PxSet.mapX);
PxSet.mapZ = single(PxSet.mapZ);

% Extra sanity checks
assert(all(diff(double(PxSet.mapX)) > 0) && all(diff(double(PxSet.mapZ)) > 0), 'Grid must be strictly increasing.');
assert(ImSet.size_px(1) == 512 && ImSet.size_px(2) == 512, 'Expect 512x512 grid.');

% Convenience converters (do NOT round unless explicitly needed)
pix2x = @(ix) PxSet.mapX( max(1, min(ImSet.size_px(2), round(ix))) ); %#ok<NASGU>
pix2z = @(iz) PxSet.mapZ( max(1, min(ImSet.size_px(1), round(iz))) ); %#ok<NASGU>
x2pix = @(x) 1 + (double(x) - double(PxSet.mapX(1))) / double(PxSet.dx); %#ok<NASGU>
z2pix = @(z) 1 + (double(z) - double(PxSet.mapZ(1))) / double(PxSet.dz); %#ok<NASGU>

ImSet.frame_rate_Hz = 50;          % target frame rate (50 frames -> 1 second)
ImSet.log_dynamic_range_dB = 60;   % log compression dynamic range (raised from 40 to lower log floor)
% Limit run length for quick test / debug
ImSet.nFrames = 500;                % 1 second of data at 50 Hz

SimSet.transducer = 'L11-4v';      % ID (verify naming matches folder later)
SimSet.fc_Hz = 7.24e6;             % center frequency
SimSet.fs_Hz = 80e6;               % sampling frequency
SimSet.frames = ImSet.nFrames;     % redundant but convenient
SimSet.tx_scale = 50;              % increased transmit excitation scale (was implicit 1)

% Grid diagnostics
Nx = ImSet.size_px(2); Nz = ImSet.size_px(1);
fprintf('Imaging grid: Nz x Nx = %d x %d\n', Nz, Nx);
fprintf('Span X: %.2f mm | Span Z: %.2f mm\n', double(PxSet.spanX)*1e3, double(PxSet.spanZ)*1e3);
fprintf('dX: %.2f µm | dZ: %.2f µm | dZ/dX=%.3f\n', double(PxSet.dx)*1e6, double(PxSet.dz)*1e6, double(PxSet.dz)/double(PxSet.dx));

% Simple assertions (tolerances allow floating error)
expectedSpan = 20e-3; % 20 mm
expectedPitch = expectedSpan / (512-1);
assert(abs(double(PxSet.spanX)-expectedSpan)<1e-9,'Span X mismatch');
assert(abs(double(PxSet.spanZ)-expectedSpan)<1e-9,'Span Z mismatch');
assert(abs(double(PxSet.dx)-expectedPitch)<1e-9,'dX mismatch');
assert(abs(double(PxSet.dz)-expectedPitch)<1e-9,'dZ mismatch');
fprintf('Grid assertions passed.\n');

%% Visualization controls ---------------------------------------------------
if ~exist('makeBasicFigure','var');  makeBasicFigure  = true;  end
if ~exist('makeStyledFigure','var'); makeStyledFigure = true;  end
% Default now true so all generated figures are persisted per run
if ~exist('saveFigures','var');      saveFigures      = true; end
outDir = figOutDir; %#ok<NASGU>
if saveFigures && ~exist(outDir,'dir'); mkdir(outDir); end

%% Basic grid canvas -------------------------------------------------------
if makeBasicFigure
	fig1 = figure('Name','Grid Canvas','Color','w');
	imagesc(PxSet.mapX*1e3, PxSet.mapZ*1e3, zeros(Nz,Nx));
	set(gca,'YDir','normal'); axis image tight; colormap(gray);
	xlabel('Lateral x (mm)'); ylabel('Axial z (mm)');
	title('Imaging Grid (empty)');
	hold on; plot([0 0],[PxSet.mapZ(1) PxSet.mapZ(end)]*1e3,'c--');
	if saveFigures, saveas(fig1, fullfile(outDir,'grid_basic.png')); end
end

%% Styled figure (synthetic bubbles) ---------------------------------------
if makeStyledFigure
	fprintf('Generating styled demonstration image...\n');
	% Synthetic background similar to example style
	rng(7);
	speckle = randn(Nz,Nx)*0.2; %#ok<RAND>
	try
		speckle = imgaussfilt(speckle,0.75); % Image Processing Toolbox
	catch
		% Fallback: simple 2D conv blur
		k = fspecial('gaussian',9,1.2); speckle = conv2(speckle,k,'same');
	end
	speckle = speckle - min(speckle(:)); speckle = speckle / max(speckle(:));
	% Add Gaussian bubble spots
	nDemo = 250;
	bx = PxSet.mapX(1) + (PxSet.mapX(end)-PxSet.mapX(1))*rand(nDemo,1);
	bz = PxSet.mapZ(1) + (PxSet.mapZ(end)-PxSet.mapZ(1))*rand(nDemo,1);
	[xg, zg] = meshgrid(PxSet.mapX, PxSet.mapZ);
	sx = 0.15e-3; sz = 0.15e-3;
	for k = 1:nDemo
		amp = 0.6 + 0.4*rand; %#ok<RAND>
		g = amp*exp(-((xg-bx(k)).^2/(2*sx^2) + (zg-bz(k)).^2/(2*sz^2)));
		speckle = max(speckle, g);
	end
	% Log compression
	I = speckle / max(speckle(:));
	Idb = 20*log10(I + 1e-6);
	DR = ImSet.log_dynamic_range_dB; Idb = max(Idb, -DR);
	Inorm = (Idb + DR)/DR;
	fig2 = figure('Name','Styled Demo','Color','w');
	imagesc(double(PxSet.mapX)*1e3, double(PxSet.mapZ)*1e3, Inorm); set(gca,'YDir','normal');
	axis image tight; colormap(gray(256)); caxis([0 1]);
	xlabel('Width [mm]'); ylabel('Depth [mm]');
	title(sprintf('Network 001 - Frame rate %gHz', ImSet.frame_rate_Hz));
	hold on; plot(bx*1e3, bz*1e3, 'b+','MarkerSize',4,'LineWidth',0.5);
	set(gca,'FontSize',11,'LineWidth',0.75,'Box','off','Position',[0.07 0.07 0.9 0.88]);
	% Export also as 8-bit single frame (useful for later dataset consistency)
	I8 = uint8(255 * Inorm);
	if saveFigures
		saveas(fig2, fullfile(outDir,'grid_styled.png'));
		imwrite(I8, fullfile(outDir,'grid_styled_8bit.png'));
	end
end

%% 2) Vessel network generation -------------------------------------------
fprintf('Generating vessel network...\n');
net = generate_vessel_network(PxSet);  % unified generator (basic implementation merged)
fprintf('Network: %d nodes, %d segments (median radius=%.1f um)\n', ...
	size(net.nodes,1), size(net.edges,1), median(double(net.radii))*1e6);
% Save network figure if plotting enabled inside generator
if saveFigures
	saveFigByName('ULTRA-SR HF Vasculature (3D->XZ projection)', fullfile(figOutDir,'network_vessels.png'));
end

%% 3) Steady laminar flow solve (Poiseuille) -------------------------------
fprintf('Solving steady laminar flow...\n');
phys.mu_Pa_s       = 0.001;          % viscosity
phys.P_in_Pa       = 50*133.322;     % inlet (Pa)
phys.P_out_Pa      = 45*133.322;     % outlet (Pa)
phys.v_target_mps  = 0.05;           % target median speed (~5 cm/s)
phys.v_bounds_mps  = [2e-5, 0.14];   % mild diag bounds
flow = solve_flow_laminar(net, phys);
% Backward compatibility: older code expected flow.scaling.factor; new field is factor_global
if isfield(flow,'scaling') && isfield(flow.scaling,'factor_global') && ~isfield(flow.scaling,'factor')
	flow.scaling.factor = flow.scaling.factor_global; %#ok<STRNU>
end
scaleVal = NaN;
if isfield(flow,'scaling')
	if isfield(flow.scaling,'factor_global'); scaleVal = flow.scaling.factor_global; end
	if isnan(scaleVal) && isfield(flow.scaling,'factor'); scaleVal = flow.scaling.factor; end
end
if isnan(scaleVal); scaleVal = 1; end
fprintf('Flow median speed: %.3f m/s (min=%.4f, max=%.3f) | scale=%.2fx\n', ...
	flow.qc.v_mps_median, flow.qc.v_mps_minmax(1), flow.qc.v_mps_minmax(2), scaleVal);
try
	plot_flow_quick(net, flow);
catch ME
	warning(ME.identifier, 'Flow plot failed: %s', ME.message);
end
if saveFigures
	saveFigByName('Flow (mean speeds)', fullfile(figOutDir,'flow_speeds.png'));
end

%% 4) Bubble track generation (ground truth) ------------------------------
fprintf('Generating bubble tracks (Step 4)...\n');
gtOpts.dt_substeps = 1;               % increase if very high velocities
gtOpts.spawn_weight = 'flux_length';
% Automatic calibration to target active bubble density
targetActive = 550;                   % desired active bubbles per frame (~sparser than speckle regime)
initMeanBirths = 100;                  % starting guess for birth-rate calibration
fprintf('Calibrating birth rate toward ~%d active bubbles/frame...\n', targetActive);
gtOpts.mean_births_per_frame = calibrate_birth_rate(net, flow, ImSet.frame_rate_Hz, targetActive, initMeanBirths);
fprintf('Calibrated mean_births_per_frame = %d\n', gtOpts.mean_births_per_frame);
% CSV export
csvOutDir = gtOutDir; if ~exist(csvOutDir,'dir'), mkdir(csvOutDir); end
gtOpts.csv_path = fullfile(csvOutDir,'gt_tracks.csv');
[gt, gtDiag] = generate_bubble_tracks(net, flow, ImSet.nFrames, ImSet.frame_rate_Hz, gtOpts);
if isfield(gtDiag,'csv_path')
	fprintf('GT CSV written: %s (%d rows)\n', gtDiag.csv_path, gtDiag.total_rows);
end
if isfield(gtDiag,'active_counts')
	fprintf('Active bubbles/frame: mean=%.1f | min=%d | max=%d\n', mean(gtDiag.active_counts), min(gtDiag.active_counts), max(gtDiag.active_counts));
end

% Optionally render animated GIF of bubble motion
if ~exist('makeBubbleGif','var'); makeBubbleGif = true; end
if makeBubbleGif
	gifOpts.fps = 10; gifOpts.tail_frames = 5; gifOpts.tail_decay = 0.5; gifOpts.marker_size = 7; %#ok<NASGU>
	gifOpts.sample_step = 1;            % save every frame
	gifOpts.frame_range = [1 ImSet.nFrames];  % explicitly restrict to first N frames
	gifPath = fullfile(csvOutDir,'bubbles.gif');
	try
		render_bubble_gif(net, gt, gifPath, gifOpts);
	catch ME
		warning(ME.identifier,'Bubble GIF generation failed: %s', ME.message);
	end
end
fprintf('GT: %d rows | unique bubbles=%d | mean/frame=%.1f (spawn mean=%.1f)\n', ...
	gtDiag.total_rows, gtDiag.unique_ids, gtDiag.mean_per_frame, mean(gtDiag.spawn_counts));

% Quick visualization: frame 1 overlay
if ~isempty(gt)
	fr1 = gt(gt(:,1)==1,:);
	if ~isempty(fr1)
		figure('Name','GT Frame 1 Bubbles','Color','w'); hold on; axis image;
		% Plot network (x-z projection)
		for e=1:size(net.edges,1)
			i = net.edges(e,1); j = net.edges(e,2);
			p1 = net.nodes(i,[1 3]); p2 = net.nodes(j,[1 3]);
			plot([p1(1) p2(1)]*1e3, [p1(2) p2(2)]*1e3,'b-','LineWidth',0.5);
		end
		plot(fr1(:,3)*1e3, fr1(:,5)*1e3,'r.','MarkerSize',6);
		set(gca,'YDir','reverse'); xlabel('x [mm]'); ylabel('z [mm]');
		title('Ground Truth Bubbles (Frame 1)');
		if exist('saveFigures','var') && saveFigures
			saveas(gcf, fullfile(outDir,'gt_frame1.png'));
		end
	end
end

%% Placeholders for later stages ------------------------------------------
% Frame loop: RF simulation -> beamform -> envelope -> noise/compression    % (to implement)
% Output saving & overlay                                                   % (to implement)

%% 5) (Optional) Field II B-mode simulation --------------------------------
if ~exist('skipFieldII','var') || ~skipFieldII
	fprintf('Attempting Field II B-mode simulation\n');
	try
		% Optional fast path: define fastBModeFrames before running complete.m to limit frames
		if exist('fastBModeFrames','var') && ~isempty(fastBModeFrames)
			bmodeFrames = min(ImSet.nFrames, fastBModeFrames);
			fprintf('Using fastBModeFrames=%d (of %d total) for B-mode simulation.\n', bmodeFrames, ImSet.nFrames);
			gt_bmode = gt(gt(:,1)<=bmodeFrames,:);
			ImSet_bmode = ImSet; ImSet_bmode.nFrames = bmodeFrames;
		else
			bmodeFrames = ImSet.nFrames;
			gt_bmode = gt; ImSet_bmode = ImSet;
		end
		% Performance tuning knobs:
		%  - angles_deg: set to 0 for single angle (fastest)
		%  - n_lines: reduce to 32 or 48 for quicker test
		%  - enable display_progress for heartbeat printing
		%  - envelope_norm 'p99' stabilizes brightness across subsets
		bmodeOpts = struct( ...
			'n_lines',64, ...                % try 128 later for finer lateral sampling
			'angles_deg',0, ...              % single angle for debugging
			'noise_level',0, ...             % no noise until signal confirmed
			'envelope_norm','frame', ...     % frame normalization to visualize tiny signals
			'display_progress',true, ...
			'keep_fieldii',false, ...
			'scatter_gain',1e8, ...          % very high scatter gain (adjust down once visible)
			'auto_gain',true, ...
			'auto_gain_threshold',1e-10, ...
			'auto_gain_target',1e-2, ...
			'diag_verbose',true, ...
			'synthetic_if_empty',true, ...
			'fallback_synthetic',true, ...   % NEW: enable crash-guard synthetic fallback
			'synthetic_gain',1e-2, ...
			'synthetic_trigger_peak',1e-8, ... % force synthetic injection if peak RF < threshold
			'tx_mode','plane', ...             % correct field name (was txmode)
			'safe_mode',true, ...              % skip Field II focusing & steering to avoid crash
			'debug_force_synthetic',true ...   % start with synthetic to verify visualization path
			); %#ok<NASGU>
		fprintf('B-mode config: lines=%d | angles=%s | frames=%d\n', bmodeOpts.n_lines, mat2str(bmodeOpts.angles_deg), ImSet_bmode.nFrames);
		tic;
		[I8_bmode, rf_cube, bmodeMeta] = simulate_bmode_fieldii(gt_bmode, PxSet, ImSet_bmode, SimSet, bmodeOpts); %#ok<NASGU>
		% Sanity check: first frame should not be all zeros after synthetic fallback
		if ~isempty(I8_bmode) && ~isempty(I8_bmode{1})
			if ~any(I8_bmode{1}(:))
				warning('BModeFirstFrameZero:ZeroFrame','First B-mode frame is all zeros. Check RF path / synthetic settings.');
			else
				fprintf('First frame nonzero pixels: %d / %d\n', nnz(I8_bmode{1}), numel(I8_bmode{1}));
			end
		else
			warning('BModeEmpty:EmptyOutput','B-mode output cell array empty or first cell empty.');
		end
		tSim = toc;
		fprintf('Field II simulation done in %.1f s (frames=%d).\n', tSim, ImSet_bmode.nFrames);
		vidPath = fullfile(fieldOutDir,'HF_fieldII.avi');
		VW = VideoWriter(vidPath); VW.FrameRate = ImSet.frame_rate_Hz; open(VW);
		for f = 1:min(ImSet_bmode.nFrames, numel(I8_bmode))
			writeVideo(VW, repmat(I8_bmode{f}, [1 1 3]));
		end
		close(VW);
		if ~isempty(I8_bmode)
			imwrite(I8_bmode{1}, fullfile(fieldOutDir,'HF_fieldII_frame001.png'));
			if saveFigures
				% Also store a copy under figures directory for quick browsing
				imwrite(I8_bmode{1}, fullfile(figOutDir,'bmode_frame001.png'));
			end
		end
		% Save RF plus minimal metadata for later inspection
		save(fullfile(fieldOutDir,'HF_fieldII_rf.mat'),'rf_cube','PxSet','ImSet_bmode','SimSet','bmodeMeta','bmodeOpts','-v7.3');
	catch ME
		warning(ME.identifier,'Field II simulation skipped: %s', ME.message);
	end
end

fprintf('Pipeline partial run done (Steps 0-5 including optional Field II).\n');
fprintf('Outputs saved under: %s\n', baseOut);

%% Local helper -----------------------------------------------------------
function saveFigByName(nameStr, outPath)
% saveFigByName Locate a figure by its Name property and save as PNG.
if isempty(nameStr) || isempty(outPath), return; end
fh = findall(0,'Type','figure','Name',nameStr);
if isempty(fh) || ~ishandle(fh), return; end
try
	[outDir,~] = fileparts(outPath);
	if ~exist(outDir,'dir'); mkdir(outDir); end
	exportgraphics(fh, outPath, 'Resolution', 200);
catch
	try
		saveas(fh, outPath);
	catch ME
		warning(ME.identifier,'Failed to save figure %s -> %s (%s)', nameStr, outPath, ME.message);
	end
end
end

