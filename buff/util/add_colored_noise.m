function imgN = add_colored_noise(img, level)
%ADD_COLORED_NOISE Add light colored multiplicative + additive noise.
%   imgN = add_colored_noise(img, level)
% level ~ 0.05-0.1 typical.
if nargin < 2, level = 0.06; end
img = single(img);
sz = size(img);
% Low-frequency multiplicative component
lf = imgaussfilt(randn(sz,'single'), 8);  %#ok<*IMGFILT>
lf = (lf - min(lf(:))) / max(eps, (max(lf(:))-min(lf(:))));
lf = 0.9 + 0.2*lf; % 0.9..1.1

% Additive white-esque component
aw = randn(sz,'single');
aw = imgaussfilt(aw, 1.2);
aw = aw / max(1e-6, std(aw(:)));

imgN = img .* lf .* (1 + level*0.5*randn()) + level*0.4*aw;
imgN = max(0, imgN);
end
