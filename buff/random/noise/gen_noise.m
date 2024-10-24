% Generate Noise
clearvars; clc; close all;

% Define Image Size
nx = 200; 
nz = 400; 
nt = 150;

% Generate Base White Noise
white_noise = abs(rand(nz,nx,nt));
white_noise = imgaussfilt(white_noise,1,'FilterSize',[5 5])*0.1;
[~, Zg] = meshgrid( ones(nx,1), (0:nz-1)/nz);

% Generate Cloud Noise
cloud = zeros(nz, nx, nt);
for i = 1:nt
    if mod(i,15) ==0 || i == 1
        new_noise = noiseonf(nz, nx, 1.7);
    end
    cloud(:,:,i) = 400*abs(new_noise);
end
cloud = movmean(cloud,21,3);


% Generate Blob Noise
blobs = zeros(nz,nx,nt);
for i = 1:nt
    num_of_blobs = round(rand*5); 
    for j = 1:num_of_blobs
        bx = round(nx*rand);
        bz = round(rand*nx*0.2);
        x_pos = round(rand*(nx-1-bx)); 
        z_pos = round(rand*(nz-1-bz));
        if x_pos <= 0 
            x_pos = 1;
        end
        if z_pos <= 0
            z_pos = 1;
        end
        try
            new_blob = noiseonf(bz, bx, 1.7);
            blobs(z_pos:z_pos+bz-1,x_pos:x_pos+bx-1,i) = 100*new_blob;
        end
    end
    blobs(:,:,i) = imgaussfilt(blobs(:,:,i), 5);
end
blobs = movmean(blobs,51,3);

% Sum All Sources Of Noise
noise = white_noise + cloud + blobs; 

% Add TGC To Noise
noise = noise.*Zg; 

% Filter Noise
NoiseLowFreq = 1;      % The lower stopband of the noise in MHz
NoiseHighFreq = 15;     % The higher stopband of the noise in MHz
% Filter the noise to have a bandwidth relevant to the probe
Hd             = fir1(30,[NoiseLowFreq, NoiseHighFreq]/(100/2));    % Normalised Frequency 100 MHz sampling frequency
noise_filtered = filter(Hd,1,noise);
noise_filtered = abs(noise_filtered);                               % abs() only applies to image data, delete when adding to rf-data
            
% Play Video
for i = 1:nt
    imagesc(noise_filtered(:,:,i)); title(i); axis image; caxis([0 1]); colormap('gray'); caxis([0 0.1])
    drawnow
end