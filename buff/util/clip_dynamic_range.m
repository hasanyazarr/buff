function out = clip_dynamic_range(in, dynamic_range)
    out = in;    
    minlevel = 10^(-dynamic_range/20) * max(out(:));          
    out(out<minlevel) = minlevel;
end