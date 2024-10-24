classdef  RectMathElement < MathElement
    properties (SetAccess = public)
        width = 0;
        height  = 0;
    end
    methods
        function self = RectMathElement(width, height, center, apodization, delay)
            if nargin <3
                error("Must provide width, height, and center");
            end
            if nargin >=3
                self.width = width;
                self.height = height;
                corners = [ ...
                    -1,  1, 0 ; ...
                     1,  1, 0 ; ...
                     1, -1, 0 ; ...
                    -1, -1, 0 ; ...
                    ];
                corners = corners .* [width/2, height/2, 0];
                self.corners = corners + center;
            end
            if nargin >=4
                self.apodization = apodization;
            end
            if nargin >=5
                self.delay = delay;
            end
        end
        
        function corners = corners(self)

        end
        
        function plot(self, ha)
            if nargin == 1
                ha = axes();
            end
            x = self.corners(:, 1);
            y = self.corners(:, 2);
            z = self.corners(:, 3);
            patch(ha, x, y, z, self.apodization);
        end
    end
end