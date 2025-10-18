function [img, PxSet_out, info] = load_dataset_frame_and_gt(dataset_dir)
%LOAD_DATASET_FRAME_AND_GT  Get first HF frame + axes + GT from dataset.
%   [img, PxSet_out, info] = load_dataset_frame_and_gt(dataset_dir)
%   Looks for: metadata.mat (PxSet/ImSet), net_*.avi (first frame),
%              gt_scat_inside.txt (optional)
img = [];
info = struct('GT',[]);

if nargin<1 || isempty(dataset_dir) || ~exist(dataset_dir,'dir')
    warning('Dataset dir not found.'); PxSet_out = default_axes(); return;
end

% 1) metadata (preferred)
meta = fullfile(dataset_dir,'metadata.mat');
if exist(meta,'file')
    S = load(meta);
    if isfield(S,'PxSet'), PxSet_out = S.PxSet; else, PxSet_out = default_axes(); end
else
    PxSet_out = default_axes();
end

% 2) AVI (take the first net_*.avi found)
aviList = dir(fullfile(dataset_dir,'net_*.avi'));
if isempty(aviList)
    warning('No net_*.avi in %s', dataset_dir); return;
end
aviPath = fullfile(aviList(1).folder, aviList(1).name);
V = VideoReader(aviPath);
raw = read(V,1);                         % first frame
if size(raw,3)==3, raw = rgb2gray(raw); end
img = double(raw)/255;                   % already 8-bit log

% 3) GT (optional)
gtPath = fullfile(dataset_dir,'gt_scat_inside.txt');
if exist(gtPath,'file')
    try
        info.GT = readmatrix(gtPath);    % [frame id x y z]
    catch
        warning('Failed to read GT at %s', gtPath);
    end
end
end

function Px = default_axes()
Px.mapX = linspace(-10e-3, 10e-3, 512);
Px.mapZ = linspace( 10e-3, 30e-3, 512);
Px.mapX = single(Px.mapX); Px.mapZ = single(Px.mapZ);
end
