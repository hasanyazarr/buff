function im = TGC(im, tg)
    [nx, nz, ~] = size(im);
    tg = interp1(tg, linspace(1, length(tg), nz));
    tg = rescale(tg);
    Zg = repmat(tg(:)', nx, 1); 
    im = im .* Zg';
end