n_rows = 3;
n_cols = 3;
H = 100;
W = 100;

figure();

for i = 1:n_rows
    for j = 1:n_cols
        subplot(n_rows, n_cols, sub2ind([n_rows, n_cols], i, j));
        imagesc(perlin_noise(H, W));
    end
end
