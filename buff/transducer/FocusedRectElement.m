classdef FocusedRectElement < Element
    properties(SetAccess = public)
        width;
        height;
        Rfocus;
    end
    
    methods
        function self = FocusedRectElement(number, width, height, center, nx, ny, Rfocus)                        
            self = self@Element();
            self.number = number;
            self.center = center;
            self.width = width;
            self.height = height;
            self.Rfocus = Rfocus;
            
            % ME centers
            [me_cy, me_cx] = ndgrid(1:ny, 1:nx);
            me_cy = me_cy .* height/ny;
            me_cx = me_cx .* width/nx;
            me_cy = me_cy - mean(me_cy, 'all');
            me_cx = me_cx - mean(me_cx, 'all');
            me_centers = [me_cx(:), me_cy(:), 0.*me_cx(:)];
            
            % ME corners clockwise from scatterer perspective
            me_corners = [   ...
                me_centers + [-width/nx/2,  height/ny/2, 0]; ...
                me_centers + [ width/nx/2,  height/ny/2, 0]; ...
                me_centers + [ width/nx/2, -height/ny/2, 0]; ...
                me_centers + [-width/nx/2, -height/ny/2, 0] ...
            ];
            
            % add curvature
            me_corners(:, 3) = Rfocus - sqrt(Rfocus^2 - me_corners(:, 2).^2);
            me_corners(:, 3) = me_corners(:, 3) - min(me_corners(:, 3));
            me_centers = squeeze(mean(reshape(me_corners, [], 4, 3), 2));

            me_corners = reshape(me_corners, [], 12);
            
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
            for mei = 1:(nx*ny)
                self.math_elements(mei).corners = reshape(me_corners(mei, :), [], 3) + self.center;
            end
            self.math_elements = reshape(self.math_elements, [ny, nx]);
        end             
    end
end