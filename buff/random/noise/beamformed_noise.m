function beamformed_noise()
%% Cleanup
clear all;
close all;
clc;

addpath(genpath('/mnt/media/imperial/repos/sim/src/'));
addpath("/home/marcelo/programs/Field_II_ver_3_24_linux");
field_init(0);
set_sampling(GlobalConfig().fs);

%% World
space = Box( ...
        [ 0*mm, 0, 77*mm], ...  % center
        [40*mm, 0, 80*mm], ... % size
        [0, 0, 0] ...
);
N_x = 512;
N_z = 512;


%% Transducer
transducer = GEM5ScD_1D();
transducer.center = [0, 0, 0];

% apodization
apo = tukeywin(transducer.tx_aperture.n_elements, 0.25);
transducer.tx_aperture.elem_apodization = apo;
transducer.tx_aperture.apply_apodization();

transducer.rx_aperture.elem_apodization = apo;
transducer.rx_aperture.apply_apodization();
transducer.set_MI(0.1, space.center);

angles = linspace(-10, 10, 3);
N_angles = numel(angles);


%% Create noise RF
nframes = 512;

rf_start_t = vecnorm((space.center- space.size/2) - [0,0,0]) / GlobalConfig().c;
max_t   = 2.5*vecnorm((space.center+ space.size/2) - [0,0,0]) / GlobalConfig().c;
rf_sz = ceil((max_t-rf_start_t) * GlobalConfig().fs);

for ff = 1:nframes
    noise_rf(ff, :) = arrayfun( ...
                    @(x) RFSignals( ...
                            rand(transducer.tx_aperture.n_elements, rf_sz), ...
                            rf_start_t ...
                    ), ...
                    1:N_angles ...
    );

    for i_ang = 1:N_angles
        noise_rf(ff, i_ang) = ...
            noise_rf(ff, i_ang).conv(transducer.rx_aperture.impulse_response.signal, 'same');
    end
end
%% Create Beamform indices
image_coords = space.ordered_volume_points([N_x, 1, N_z]);
delay = cell(N_angles, 1);
chanel = cell(N_angles, 1);
for i_ang = 1:N_angles
    [delay{i_ang}, chanel{i_ang}] = beamform_delays(transducer, image_coords, -angles(i_ang), 0);
end


%% Beamform
noise_bf = zeros(nframes, N_z, N_x, N_angles);

for ff = 1:nframes
    disp(["frame: ", num2str(ff)])
    drawnow;
    for i_ang = 1:N_angles
        noise_bf(ff, :, :, i_ang) = beamform( ...
                                noise_rf(ff, i_ang).hilbert(), ...
                                N_x, N_z, ...
                                delay{i_ang}, ...
                                chanel{i_ang} ...
        );
    end
end

%% Make Video
%vid = sum(noise_bf, 4);
%vid = abs(vid);
%vid = permute(vid, [3,2,1]);
%vid = vid./max(vid(:));
%vid2 = clip_dynamic_range(vid, 10);
%vid2 = 10*log10(vid2);
%vid2 = rescale(vid2);

%subplot(121);
%imagesc(squeeze(vid)); axis image;
%subplot(122);
%imagesc(squeeze(vid2)); axis image;

save( ...
[ work_folder, 'noise_bf.mat'], ...
'noise_bf', ...
'-v7.3', ...
);

end

