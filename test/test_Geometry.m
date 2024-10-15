%% CleanUP
close all;
clear all;
clc;

%% Define Geometries

% Box
box = Box();
box.size = [2, 2, 2];
box.center = [5, 0, 0];
box.rotation = [0, 0, 0];

% Ellipsoid
ellip = Ellipsoid();
ellip.size = [2, 2, 2];
ellip.center = [0, 0, 0];
ellip.rotation = [0, 0, 0];

% Tube
tube = Tube();
tube.size = [2, 2, 2];
tube.center = [-5, 0, 0];
tube.rotation = [0, 0, 0];

%% Plot
hf_box = figure();
ha_box = subplot(3,1,1);
title(ha_box, 'Box');
box.plot(ha_box);
xlim(ha_box, [-6,6]);
ylim(ha_box, [-6,6]);
zlim(ha_box, [-6,6]);

ha_ellip = subplot(3,1,2);
title(ha_ellip, 'Ellipsoid');
ellip.plot(ha_ellip);
xlim(ha_ellip, [-6,6]);
ylim(ha_ellip, [-6,6]);
zlim(ha_ellip, [-6,6]);

ha_tube = subplot(3,1,3);
title(ha_tube, 'Tube');
tube.plot(ha_tube);
xlim(ha_tube, [-6,6]);
ylim(ha_tube, [-6,6]);
zlim(ha_tube, [-6,6]);

linkprop([ha_box, ha_ellip, ha_tube], {'CameraPosition','CameraUpVector'});

%% Build MultiGeometries
m1 = MultiGeometry(box, ellip,tube);
hf_m1 = figure();
ha_m1 = axes();
title(ha_m1, 'Multi 1');
m1.plot(ha_m1);

m2 = tube + box + ellip;
hf_m2 = figure();
ha_m2 = axes();
title(ha_m2, 'Multi 2');
m2.plot(ha_m2);


if (m1 == m2)
    disp("OK");
else
    disp("WRONG!");
end


