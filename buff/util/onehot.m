function out = onehot(pos, size)
    out = zeros(1, size);
    out(pos) = 1;
end