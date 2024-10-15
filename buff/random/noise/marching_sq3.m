function im = marching_sq3(nx, nz, nt, ox, oz, ot, dr, factor, factor_t)

    a = noiseonf3(ox, oz, nt, factor, factor_t);
    aa = interp3(double(a), linspace(1,ox,nx), linspace(1,oz,nz)', linspace(1,ot,nt));
    
    im = imgaussfilt3(aa,4);
    im = clip_dynamic_range(im, dr);    
    im = rescale(im);
end