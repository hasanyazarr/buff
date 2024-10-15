
nx = 512;
nz = 512;
nt = 128;


%% Uniform Noise

noise_unif = rand(nx, nz, nt);


%% Gaussian Noise

noise_gauss = randn(nx, nz, nt);


%% 1/F Noise
% noise_pink = reshape( ...
%                 cell2mat(arrayfun(@(x) noiseonf(nx, nz, 1), 1:200, 'UniformOutput', false)), ...
%                 nx, nz, []...
%             );
noise_pink = noiseonf3(nx, nz, nt, 1.4, 2);

%% Salt/pepper Noise
noise_snp = imnoise(noise_unif, 'salt & pepper', 0.01);

%% Speckle
noise_speck = imnoise(noise_unif, 'speckle');

%% Perlin
% noise_perlin = reshape( ...
%                 cell2mat(arrayfun(@(x) perlin_noise(nx, nz), 1:200, 'UniformOutput', false)), ...
%                 nx, nz, []...
%             );

%% Gaussian Blobs

blobs_gauss = gaussian_blobs(nx, nz, nt, [0, 5], 0.2, 1);

%% Marching Squares

blobs_ms = marching_sq3(nx, nz, nt, 96, 96, 64, 2.5, 1.2, 1.5);

%% output

noise_out =   rescale(clip_dynamic_range(noise_unif,   90)) * 0.25 ...
            + rescale(clip_dynamic_range(noise_gauss,  10)) * 0.25 ...
            + rescale(clip_dynamic_range(noise_pink,   10)) * 1.00 ...
            + rescale(clip_dynamic_range(noise_snp,    10)) * 0.25 ...
            + rescale(clip_dynamic_range(noise_speck,  10)) * 0.25 ...
            + rescale(clip_dynamic_range(blobs_gauss,  10)) * 1.20 ...
            + rescale(clip_dynamic_range(blobs_ms,     10)) * 1.20;

noise_out = TGC(noise_out, 1:512);
noise_out = rescale(noise_out);
implay(permute(noise_out,[2,1,3]));