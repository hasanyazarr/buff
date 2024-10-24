out_sz = [1024, 1024];
out = zeros(out_sz);
x = linspace(0, 1, out_sz(1));
y = linspace(0, 1, out_sz(2));

for ii = 1:6
    sz = out_sz ./ 2^ii;
    a = rand(sz);
    aa = interp2(a, x, y', 'bicubic');
    out = out + 1/2^ii .*  aa;
end

a = rand(10,10);
a = rand(10,10);
a = rand(10,10);
a = rand(10,10);