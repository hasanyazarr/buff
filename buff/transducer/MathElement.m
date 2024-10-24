classdef MathElement < handle
    
    properties (SetAccess = public)
        corners = zeros(3,3);
        delay  = 0;
        apodization = 1;
    end
    
    properties (Dependent, GetAccess = public, SetAccess = private)
        center;
    end
    
    methods
        function self = MathElement(corners, apodization, delay)
            if nargin >=1
                self.corners = corners;
            end
            if nargin >=2
                self.apodization = apodization;
            end
            if nargin >=3
                self.delay = delay;
            end
        end
        
        function center = get.center(self)
            center = mean(self.corners, 1);
        end
        
        function plot(varargin)
            if nargin == 1
                self = varargin{1};
                x = self.corners(:, 1);
                y = self.corners(:, 2);
                z = self.corners(:, 3);
                patch(x, y, z, self.apodization);
            elseif nargin == 2
                ax = varargin{1};
                self = varargin{2};
                x = self.corners(:, 1);
                y = self.corners(:, 2);
                z = self.corners(:, 3);
                patch(ax, x, y, z, self.apodization);
            elseif nargin > 2
                ax = varargin{1};
                self = varargin{2};
                x = self.corners(:, 1);
                y = self.corners(:, 2);
                z = self.corners(:, 3);
                patch(ax, x, y, z, self.apodization, varargin{3:end});
            end
             xlabel('X');
             ylabel('Y');
             zlabel('Z');
             view(3);
        end
    end
end