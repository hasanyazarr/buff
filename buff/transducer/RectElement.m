classdef RectElement < Element
    properties(SetAccess = public)
        width;
        height;
    end
    
    methods
        function self = RectElement(number, width, height, center, nx, ny)                        
            self = self@Element();
            self.number = number;
            self.center = center;
            self.width = width;
            self.height = height;
            
            [me_cy, me_cx] = ndgrid(1:ny, 1:nx);
            me_cy = me_cy .* height/ny;
            me_cx = me_cx .* width/nx;
            me_cy = me_cy - mean(me_cy, 'all');
            me_cx = me_cx - mean(me_cx, 'all');
            me_centers = [me_cx(:), me_cy(:), 0*me_cx(:)];
            
            self.math_elements = arrayfun(...
                @(mei) RectMathElement( ...
                    self.width/nx, ...
                    self.height/ny, ...
                    me_centers(mei, :) + self.center, ...
                    1, ...
                    0  ...
                ), ...
                1:(nx*ny) ...
            );
            self.math_elements = reshape(self.math_elements, [ny, nx]);
        end             
    end
end