function sigs = noiseonf1(nc, nt, factor)
% Generate an image of random Gaussian noise, mean 0, std dev 1
sigs = randn(nt, nc);  

imfft = fft(sigs);                  % Take fft
mag = abs(imfft);                   % Get magnitude
phase = imfft./mag;                 % and phase

f = linspace(-nt/2, nt/2, nt)';

filter = ifftshift(1./(abs(f) + 1)) .^ factor; % Construct the filter.

% Reconstruct fft of noise image, but now with the specified amplitude spectrum
newfft =  imfft .* phase; %mag .* phase(:); 
sigs = real(ifft(newfft)); % Invert to obtain final noise image
sigs = rescale(sigs)';

