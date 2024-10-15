%% Cleanup
%clear all;
close all;
clc;

addpath(genpath('../../buff'));
addpath("../../third_party/Field_II_ver_3_30_linux");
field_init(0);
set_sampling(GlobalConfig().fs);


%% Setup

transducer = L11_4V();
angles = linspace(-5, 5, 3);

space = Box( ...
        [0, 0, 60*mm], ...          % Center
        [50*mm, 10*mm, 60*mm], ...  % Size
        [0, 0, 0] ...               % Rotation
);

cyst_6mm =  Ellipsoid( ...
        [10*mm, 0*mm, 40*mm], ...   % Center
        [6*mm, 6*mm, 6*mm], ...     % Size
        [0, 0, 0] ...               % Rotation
);

cyst_5mm =  Ellipsoid( ...
        [10*mm, 0*mm, 50*mm], ...   % Center
        [5*mm, 5*mm, 5*mm], ...     % Size
        [0, 0, 0] ...               % Rotation
);

cyst_4mm =  Ellipsoid( ...
        [10*mm, 0*mm, 60*mm], ...   % Center
        [4*mm, 4*mm, 4*mm], ...     % Size
        [0, 0, 0] ...               % Rotation
);

cyst_3mm =  Ellipsoid( ...
        [10*mm, 0*mm, 70*mm], ...   % Center
        [3*mm, 3*mm, 3*mm], ...     % Size
        [0, 0, 0] ...               % Rotation
);

cyst_2mm =  Ellipsoid( ...
        [10*mm, 0*mm, 80*mm], ...   % Center
        [2*mm, 2*mm, 2*mm], ...     % Size
        [0, 0, 0] ...               % Rotation
);

high_6mm =  Ellipsoid( ...
        [-5*mm, 0*mm, 40*mm], ...   % Center
        [6*mm, 6*mm, 6*mm], ...     % Size
        [0, 0, 0] ...               % Rotation
);

high_5mm =  Ellipsoid( ...
        [-5*mm, 0*mm, 50*mm], ...   % Center
        [5*mm, 5*mm, 5*mm], ...     % Size
        [0, 0, 0] ...               % Rotation
);

high_4mm =  Ellipsoid( ...
        [-5*mm, 0*mm, 60*mm], ...   % Center
        [4*mm, 4*mm, 4*mm], ...     % Size
        [0, 0, 0] ...               % Rotation
);

high_3mm =  Ellipsoid( ...
        [-5*mm, 0*mm, 70*mm], ...   % Center
        [3*mm, 3*mm, 3*mm], ...     % Size
        [0, 0, 0] ...               % Rotation
);

high_2mm =  Ellipsoid( ...
        [-5*mm, 0*mm, 80*mm], ...   % Center
        [2*mm, 2*mm, 2*mm], ...     % Size
        [0, 0, 0] ...               % Rotation
);


%% Scatterers
nscat = 200000;

% generate random scatterers
scats = LinearScatterers(space.random_volume_points(nscat), randn(nscat,1));

% make the amplitudes inside the cyst to zero 
scats.amp( cyst_2mm.is_inside(scats.pos) ) = 0;
scats.amp( cyst_3mm.is_inside(scats.pos) ) = 0;
scats.amp( cyst_4mm.is_inside(scats.pos) ) = 0;
scats.amp( cyst_5mm.is_inside(scats.pos) ) = 0;
scats.amp( cyst_6mm.is_inside(scats.pos) ) = 0;

% make the amplitudes inside the high scattering regions
scats.amp( high_2mm.is_inside(scats.pos) ) = 10 * scats.amp( high_2mm.is_inside(scats.pos) );
scats.amp( high_3mm.is_inside(scats.pos) ) = 10 * scats.amp( high_3mm.is_inside(scats.pos) );
scats.amp( high_4mm.is_inside(scats.pos) ) = 10 * scats.amp( high_4mm.is_inside(scats.pos) );
scats.amp( high_5mm.is_inside(scats.pos) ) = 10 * scats.amp( high_5mm.is_inside(scats.pos) );
scats.amp( high_6mm.is_inside(scats.pos) ) = 10 * scats.amp( high_6mm.is_inside(scats.pos) );


% add point scatterers to the phantom
point_scats = LinearScatterers(...
    [ ...
    high_2mm.center - [10*mm 0 0]; ...
    high_3mm.center - [10*mm 0 0]; ...
    high_4mm.center - [10*mm 0 0]; ...
    high_5mm.center - [10*mm 0 0]; ...
    high_6mm.center - [10*mm 0 0]  ...
    ], ...
    20 * ones(5,1) ...
);


%% Display Scene

hf = figure();
ha = axes();
cyst_2mm.plot(ha);
cyst_3mm.plot(ha);
cyst_4mm.plot(ha);
cyst_5mm.plot(ha);
cyst_6mm.plot(ha);

high_2mm.plot(ha);
high_3mm.plot(ha);
high_4mm.plot(ha);
high_5mm.plot(ha);
high_6mm.plot(ha);

space.plot_skeleton(ha);

point_scats.plot(ha);
transducer.tx_aperture.plot_aperture(ha);

%% Simulate
total_scats = scats + point_scats;
scat_rf = transducer.tx_rx_angles(total_scats, angles);

%% Create Beamform Indices and Delays
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
                            [N_x, N_z], ...
                            delay{i_ang}, ...
                            chanel{i_ang} ...
    );
end

%% Create image

scat_img = mean(scat_bf, 3);
scat_img = abs(scat_img);
scat_img = scat_img./max(scat_img(:));
scat_img = clip_dynamic_range(scat_img, 45);
scat_img = log10(scat_img);
scat_img = rescale(scat_img);

%% Display

hf = figure();
ha = axes();
imshow(scat_img');

