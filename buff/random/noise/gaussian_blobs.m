function [blobs] = gaussian_blobs(nx, nz, nt, nblob_lims,height_frac, width_frac)

    blobs = zeros(nx, nz, nt);
    for i = 1:nt
        num_of_blobs = randi(nblob_lims);
        for j = 1:num_of_blobs
            max_bx = round(nx * width_frac/2);
            bx = randi([3, max_bx]);
            
            max_bz = round(nz * height_frac/2);
            bz = randi([3, max_bz]);

            x_pos = randi([1, nx]);
            z_pos = randi([1, nz]);
            
            x_start = max(1, x_pos - bx);
            z_start = max(1, z_pos - bz);

            x_end = min(nx, x_pos + bx);
            z_end = min(nz, z_pos + bz);

            blobs(x_start:x_end, z_start:z_end, i) = ...
                100 * noiseonf(x_end-x_start+1, z_end-z_start+1, 1.7);

        end
        blobs(:,:,i) = imgaussfilt(blobs(:,:,i), 5);
    end
    %blobs = imgaussfilt3(blobs, 5);
    blobs = movmean(blobs, 51, 3);
    blobs = rescale(blobs);
end