close all; clc;

% Root of a previously generated run (timestamped folder)
runDir = 'run_output_20250929_052004';  % adjust if using a newer run

% 1) Load first video frame (HF dataset)
vidPath = fullfile(runDir,'fieldii','HF_fieldII.avi');
vid = VideoReader(vidPath);            % HF = 7.24 MHz
frame01 = rgb2gray(read(vid,1));       % already log-compressed

% 2) Load RF / (and optionally metadata if saved separately)
rfMatPath = fullfile(runDir,'fieldii','HF_fieldII_rf.mat');
if exist(rfMatPath,'file')
	S = load(rfMatPath);               % may contain rf_cube only (depending on save)
	% If PxSet / ImSet / SimSet not present, warn.
	if ~exist('PxSet','var') && isfield(S,'PxSet'); PxSet = S.PxSet; end %#ok<NODEF>
	if ~exist('ImSet','var') && isfield(S,'ImSet'); ImSet = S.ImSet; end %#ok<NODEF>
	if ~exist('SimSet','var') && isfield(S,'SimSet'); SimSet = S.SimSet; end %#ok<NODEF>
end

% Fallback: if metadata not inside RF mat, attempt to infer grid from current frame size
if ~exist('PxSet','var')
	warning('visualize:NoMetadata','PxSet not found in MAT file; constructing dummy axes.');
	Nz = size(frame01,1); Nx = size(frame01,2);
	PxSet.mapX = linspace(-10,10,Nx)*1e-3; %#ok<STRNU>
	PxSet.mapZ = linspace( 10,30,Nz)*1e-3;
end
if ~exist('ImSet','var')
	ImSet.frame_rate_Hz = 10; ImSet.log_dynamic_range_dB = 40; %#ok<STRNU>
end

% 3) Load ground-truth tracks from CSV produced by complete.m
gtCsv = fullfile(runDir,'gt','gt_tracks.csv');
assert(exist(gtCsv,'file')==2,'Ground truth CSV not found: %s', gtCsv);
GT = readmatrix(gtCsv);   % [frame,id,x,y,z]
idx = (GT(:,1)==1);       % frame 1 only

% 3) Plot
figure('Color','w','Units','normalized','Position',[0.1 0.1 0.8 0.8]);
imagesc(PxSet.mapX*1e3, PxSet.mapZ*1e3, frame01); 
set(gca,'YDir','normal'); axis image; colormap(gray);
title(sprintf('Network 001 - Frame rate %gHz', ImSet.frame_rate_Hz));
xlabel('Width [mm]'); ylabel('Depth [mm]');

hold on;
plot(GT(idx,3)*1e3, GT(idx,5)*1e3, 'b*');   % overlay GT
