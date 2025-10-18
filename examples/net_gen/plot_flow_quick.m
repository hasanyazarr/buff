function plot_flow_quick(net, flow)
%PLOT_FLOW_QUICK Quick 2D visualization of edge mean speeds (log color).
%   plot_flow_quick(net, flow)
% Colors edges by log10(mean speed) and sets line width proportional to
% radius. Axes: x (lateral) vs z (axial). Y inverted (ultrasound convention).

nodes = net.nodes; E = size(net.edges,1);
if E==0
    warning('plot_flow_quick:Empty','Network has no edges; nothing to plot.');
    return;
end
v = flow.v_mps; r = net.radii;
cm = parula(256);
vplot = max(v, 1e-5);  % avoid log(0)
vmin = min(vplot); vmax = max(vplot);
if vmax <= vmin, vmax = vmin*1.001; end
vlog = (log10(vplot) - log10(vmin)) / (log10(vmax) - log10(vmin));

figure('Name','Flow (mean speeds)','Color','w'); hold on; axis image;
for e=1:E
    i = net.edges(e,1); j = net.edges(e,2);
    p1 = nodes(i,[1 3]); p2 = nodes(j,[1 3]);
    cidx = 1 + round(255 * vlog(e)); cidx = max(1,min(256,cidx));
    lw = max(0.4, 6 * (r(e)/max(r)));
    plot([p1(1) p2(1)]*1e3, [p1(2) p2(2)]*1e3, '-', 'Color', cm(cidx,:), 'LineWidth', lw);
end
set(gca,'YDir','reverse'); xlabel('x [mm]'); ylabel('z [mm]');
cb = colorbar; colormap(cm); ylabel(cb,'Mean speed (log scale)');
title('Edge mean speed (m/s)');
end
