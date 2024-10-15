function [f, a] = ui_create_response(impath, a_range, f_range)
    ha = axes();
    im = imread(impath);
    hi = imagesc(ha, im);
    
    pmin = images.roi.Point(ha);
    title(ha, 'input min point');
    draw(pmin);
    pmin = pmin.Position;
    
    pmax = images.roi.Point(ha);
    title(ha, 'input max point');
    draw(pmax);
    pmax = pmax.Position;
    
    pline = images.roi.Polyline(ha);
    title(ha, 'input points');
    draw(pline);
    pline = pline.Position;
    
    % transform points to freq, amp
    fa_min = [f_range(1) a_range(1)];
    fa_max = [f_range(2) a_range(2)];
    pline = (pline - pmin) ./ (pmax-pmin) .* (fa_max-fa_min) + fa_min;    
    
    f = pline(:, 1);
    a = pline(:, 2);
    
    % remove non monotonically increasing frequencies
    ind_keep = [diff(f) > 0; true];

    f = f(ind_keep);
    a = a(ind_keep);
    
    a = 10.^(a./20);
end
