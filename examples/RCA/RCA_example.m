%% Cleanup
clear all;
close all;
clc;

addpath(genpath('../../buff'));
addpath("../../third_party/Field_II_ver_3_30_linux");
field_init(0);
set_sampling(GlobalConfig().fs);


%% Setup
space = Box( ...
        [0, 0, 5e-2], ...                % Center
        [2.5e-2, 2.5e-2, 2.5e-2], ...    % Size
        [0, 0, 0] ...                    % Rotation
);

transducer = RCA();
angles = linspace(-5, 5, 5);

transducer.col_aperture.excitation.f0 = 3e6;
transducer.col_aperture.excitation.n_cycles = 1;

transducer.row_aperture.excitation.f0 = 3e6;
transducer.row_aperture.excitation.n_cycles = 1;

transducer.sel_col()
transducer.set_MI(0.1, space.center);
transducer.sel_row()
transducer.set_MI(0.1, space.center);

%% Bubble Scatterers

% bub = SonovueBubble(3e-6);
% bubs = BubbleScatterers(space.center, [bub]);


bubs = LinearScatterers(space.center, 1);


transducer.sel_col()
scat_rf_c = transducer.tx_rx_angles(bubs, angles);

transducer.sel_row()
scat_rf_r = transducer.tx_rx_angles(bubs, angles);


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
scat_bf = zeros(N_x, N_z, N_angles);
for i_ang = 1:N_angles
    scat_bf(:, :, i_ang) =  beamform( ...
                            scat_rf(i_ang).hilbert(), ...
                            N_x, N_z, ...
                            delay{i_ang}, ...
                            chanel{i_ang} ...
    );
end
