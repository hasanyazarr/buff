%% Cleanup
clear all;
close all;
clc;

addpath(genpath('/mnt/media/imperial/repos/sim/src'));
addpath("/home/marcelo/programs/Field_II_ver_3_24_linux");
field_init(0);
set_sampling(GlobalConfig().fs);

%% Setup
space = Box( ...
        [0, 0, 50*mm], ...          % Center
        [50*mm, 0.1*mm, 50*mm], ... % Size
        [0, 0, 0] ...               % Rotation
);

transducer = L11_4V();
angles = linspace(-6, 6, 3);

%% Source
src_box =   Box( ...
        [0, 0, 25*mm], ...  	    % Center
        [50*mm, 0, 5*mm], ...       % Size
        [0, 0, 0] ...               % Rotation
);

bub_source = LinearScattererSource(src_box, 20);
bub_source.amp_gen = GaussianGenerator(0, 1);

%% Simulate
dt = 0.5;
nframes = 100;

scats = LinearScatterers(space.random_volume_points(50), randn(50,1));

for fn = 1:nframes    
    scats = scats + bub_source.step(dt);
    
    % update bubbles
    if (scats.count > 0)
        scat_vel = [1,0,0] .* abs(scats.pos - space.center)./space.size * 30*mm/s;
        scat_vel = fliplr(scat_vel);
        % vel_z = f(x)
        scats.pos = scats.pos + scat_vel .* dt;
        % delete bubbles
        idx_out = space.is_outside(scats.pos);
        scats.delete(idx_out);
    end
    
    scat_rf(fn,:) = transducer.tx_rx_angles(scats, angles);
end

%% Create Beamform Indices
N_angles = numel(angles);
N_x = 512;
N_z = 512;
image_coords = space.ordered_volume_points([N_x, 1, N_z]);

delay = cell(N_angles, 1);
chanel = cell(N_angles, 1);
for i_ang = 1:N_angles
    [delay{i_ang}, chanel{i_ang}] = beamform_delays(transducer, image_coords, -angles(i_ang), 0);
end

%% Beamform
scat_bf = zeros(nframes, N_x, N_z, N_angles);
for fn = 1:nframes
    for i_ang = 1:N_angles
        scat_bf(fn, :, :, i_ang) =  beamform( ...
                                scat_rf(fn, i_ang).hilbert(), ...
                                N_x, N_z, ...
                                delay{i_ang}, ...
                                chanel{i_ang} ...
        );
    end
end


%% Make video

vid = sum(scat_bf, 4);
vid = abs(vid);
vid = permute(vid, [3,2,1]);
vid = vid./max(vid(:));
vid2 = clip_dynamic_range(vid, 60);
vid2 = 10*log10(vid2);
vid2 = rescale(vid2);
