function imshow_log(img_in, i_lim, j_lim, db_lim, t, ha)
    if numel(size(img_in)) ~= 2
        error("Input image should be 2D");
    end
    
    im_log = 20*log10(img_in./max(img_in(:)));    
    
    if nargin < 6
        ha = axes();
    end
    
    if nargin < 3
        imagesc(ha, im_log);
    end
    
    if nargin == 3
        imagesc(ha, j_lim, i_lim, im_log);
    end
    
    if nargin > 3
        imagesc(ha, j_lim, i_lim, im_log, db_lim);
    end
    
    axis(ha, 'equal');
    axis(ha, 'tight');
    
    if nargin >= 5
        title(ha, t);
    end
end