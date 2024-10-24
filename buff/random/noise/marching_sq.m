function im = marching_sq(nx, nz, ox, oz, dr, factor)

    a = noiseonf(ox, oz, factor);
    aa = interp2(double(a), linspace(1,ox,nx), linspace(1,oz,nz)');
    
    im = clip_dynamic_range(aa, dr);
end