function im = noiseonf3(nx, nz, nt, factor, factor_t)
% Generate an image of random Gaussian noise, mean 0, std dev 1.    
   
im = randn(nx, nz, nt);  

imfft = fftn(im);                   % Take fft of volume.
imfft = fftshift(imfft);            % Shift 0 frequency to the middle.
mag = abs(imfft);                   % Get magnitude
phase = imfft./mag;                 % and phase

% Create two matrices, x and y. All elements of x have a value equal to its 
% x coordinate relative to the centre, elements of y have values equal to 
% their y coordinate relative to the centre.  From these two matrices produce
% a radius matrix that gives distances from the middle
[X, Z, T] = ndgrid(-nz/2 : (nz/2 - 1), -nx/2 : (nx/2 - 1), -nt/2 : (nt/2 - 1));

radius = sqrt(X.^2 + Z.^2);         % Matrix values contain radius from centre.
radius(round(nx/2+1),round(nz/2+1),:) = 1;      % .. avoid division by zero.

T_factor = abs(T)+1;

filter = 1./(radius.^factor)./T_factor.^factor_t;       % Construct the filter.

% Reconstruct fft of noise image, but now with the specified amplitude spectrum
newfft =  filter .* phase; 
im = real(ifftn(fftshift(newfft))); % Invert to obtain final noise image
im = rescale(im);
% caption = sprintf('noise with 1/(f^%2.1f) amplitude spectrum',factor);
% imagesc(im);
% axis('equal');
% axis('off');
% title(caption);
