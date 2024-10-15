function noise = filtered_noise(noise, sz, order, bw_x, bw_z, bw_t)
    [nx, nz, nt] = size(noise);

    X_sz = sz(1);
    Z_sz = sz(2);
    T_sz = sz(3);

    %% X domain filter
    fs_x = nx / X_sz;
    fnyq_x = fs_x/2;
%     bw_x = [2, 10]/X_sz;
    fir_x = fir1(order, bw_x/fnyq_x);
    
    % apply filter 
%     noise = filter(fir_x, 1, noise, [], 1);
    noise = convn(noise, reshape(fir_x, [],1,1) , 'same');
    
    %% Z domain filter
    fs_z = nz / Z_sz;
    fnyq_z = fs_z/2;
%     bw_z = [2, 10]/Z_sz;
    fir_z = fir1(order, bw_z/fnyq_z);
    
    % apply filter 
%     noise = filter(fir_z, 1, noise, [], 2);
    noise = convn(noise, reshape(fir_z, 1,[],1) , 'same');
    
    %% Time domain filter
    fs_t = nt / T_sz;
    fnyq = fs_t/2;
%     bw_t = [2, 10]/ T_sz;
    fir_t = fir1(order, bw_t/fnyq);
    
    % apply filter 
    %noise = filter(fir_t, 1, noise, [], 3);
    noise = convn(noise, reshape(fir_t, 1,1,[]) , 'same');
end