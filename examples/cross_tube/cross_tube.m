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
        [0, 0, 25*mm], ...              % Center
        [40*mm, 5*mm, 40*mm], ...       % Size
        [0, 0, 0] ...                   % Rotation
);

tube1 = Tube( ...
        [0, 0.2*mm, 25*mm], ...         % Center
        [0.21*mm, 0.21*mm, 100*mm], ... % Size
        [0, 105, 0] ...                 % Rotation
);

tube2 = Tube( ...
        [0, -0.2*mm, 25*mm], ...        % Center
        [0.21*mm, 0.21*mm, 100*mm], ...	% Size
        [0, 75, 0] ...                  % Rotation
);

transducer = L11_4V();
angles = linspace(-6, 6, 3);

%% Sources
t1_src_g = Tube( ...
        tube1.center - 50*mm * tube1.e3, ...
        [0.21*mm, 0.21*mm, 1*mm], ...   % Size
        [0, 105, 0] ...                 % Rotation
);

t2_src_g = Tube( ...
        tube2.center - 50*mm * tube2.e3, ...
        [0.21*mm, 0.21*mm, 1*mm], ...	% Size
        [0, 75, 0] ...                  % Rotation
);


t1_bub_src = SonovueScattererSource(t1_src_g, 25);

t2_bub_src = SonovueScattererSource(t2_src_g, 25);

%% Tube Linear Scatterers
nscats = 50000;
% create scatterers
lin_scats = LinearScatterers(tube1.random_surface_points(nscats), randn(nscats,1)) ...
            + LinearScatterers(tube2.random_surface_points(nscats), randn(nscats,1));

line_scat_rf = transducer.tx_rx_angles(lin_scats, angles);

save('line_scat_rf.mat', 'line_scat_rf', '-v7.3')
clear line_scat_rf;

%% Pre-Sim
dt = 0.01;
nframes = 500;

t1_bubs = t1_bub_src.generate(1, tube1.center);
t2_bubs = t2_bub_src.generate(1, tube2.center);

for fn = 1:1000
    
    t1_bubs = t1_bubs + t1_bub_src.step(dt);
    t2_bubs = t2_bubs + t2_bub_src.step(dt);

    % update bubbles
    if (t1_bubs.count > 0)
        % calc velocity
        t1_bubs.pos = t1_bubs.pos + 30*mm/s .* velocity_in_tube(tube1, t1_bubs.pos).* dt;
        % delete bubbles
        idx_out = tube1.is_outside(t1_bubs.pos);
        t1_bubs.delete(idx_out);
    end
    
    if (t2_bubs.count > 0)
        % calc velocity
        t2_bubs.pos = t2_bubs.pos + 30*mm/s .* velocity_in_tube(tube2, t2_bubs.pos).* dt;
        % delete bubbles
        idx_out = tube2.is_outside(t2_bubs.pos);
        t2_bubs.delete(idx_out);
    end
end
    


%% Simulate

for fn = 1:nframes
    disp([num2str(fn) ' of ' num2str(nframes)]);
    drawnow;
    t1_bubs = t1_bubs + t1_bub_src.step(dt);
    t2_bubs = t2_bubs + t2_bub_src.step(dt);

    % update bubbles
    if (t1_bubs.count > 0)
        % calc velocity
        t1_bubs.pos = t1_bubs.pos + 30*mm/s .* velocity_in_tube(tube1, t1_bubs.pos).* dt;
        % delete bubbles
        idx_out = tube1.is_outside(t1_bubs.pos);
        t1_bubs.delete(idx_out);
    end
    
    if (t2_bubs.count > 0)
        % calc velocity
        t2_bubs.pos = t2_bubs.pos + 30*mm/s .* velocity_in_tube(tube2, t2_bubs.pos).* dt;
        % delete bubbles
        idx_out = tube2.is_outside(t2_bubs.pos);
        t2_bubs.delete(idx_out);
    end
    tot_bub = t1_bubs+t2_bubs;
    
    if tot_bub.count > 0
        scat_rf(fn,:) = transducer.tx_rx_angles(tot_bub, angles);
    else
        %generate empty rf signals
        scat_rf(fn,:) = transducer.tx_rx_angles(LinearScatterers(space.center,0), angles);
    end
end

save('bub_rf.mat', 'scat_rf', '-v7.3')

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

save('bub_bf.mat', 'scat_bf', '-v7.3')

%% bf linear scat
line_scat_bf = zeros(N_x, N_z, N_angles);
for i_ang = 1:N_angles
    line_scat_bf(:, :, i_ang) =  beamform( ...
                            line_scat_rf(i_ang).hilbert(), ...
                            N_x, N_z, ...
                            delay{i_ang}, ...
                            chanel{i_ang} ...
    );
end

save('line_scat_bf.mat', 'line_scat_bf', '-v7.3')


%% Make video

vid = sum(scat_bf + 1.5e8 * reshape(line_scat_bf,1,512,512,3), 4);
vid = abs(vid);
vid = permute(vid, [3,2,1]);
vid = vid./max(vid(:));
vid2 = clip_dynamic_range(vid, 60);
vid2 = 10*log10(vid2);
vid2 = rescale(vid2);

%% Helper Functions
function vel = velocity_in_tube(tube, pos)
    % assumes all points are inside the tube
    pos = tube.wpos2opos(pos);
    a = pos(:,1);
    A = tube.size(1);
    b = pos(:,2);
    B = tube.size(2);
    vel = (1 - a/A .* b/B);
    vel = vel .* tube.e3;
end
