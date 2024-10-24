classdef (Abstract) BaseGeometry < Oriented3D
    properties
        size = [1, 1, 1];           % Size of the geomentry (x,y,z) [m, m, m]
    end
    
    properties (Abstract, Dependent)
        area;                       % Total area of the geometry [m^2]
        volume;                     % Volume of the geometry [m^3]
    end
    
    methods
        function self = BaseGeometry()
        end
        
        function size = get.size(self)
            size = self.size;
        end
        
        function set.size(self, new_size)
            self.size = new_size;
        end
        
        function out = is_outside(self, pos)
            out = ~self.is_inside(pos);
        end
        
        function plot(self, ha)
            if nargin == 1
                ha = axes();
            end
            surf_points = self.random_surface_points(1000);
            vol_points = self.random_volume_points(1000);
            
           
            plot3(ha, surf_points(:,1), surf_points(:,2), surf_points(:,3), '*');
            hold(ha, 'on');
            plot3(ha, vol_points(:,1), vol_points(:,2), vol_points(:,3), '*');
            plot3(ha, self.center(1), self.center(2), self.center(3), '*');

            quiver3(ha, self.center(1), self.center(2), self.center(3), self.e1(1), self.e1(2), self.e1(3), self.size(1)/2);

            quiver3(ha, self.center(1), self.center(2), self.center(3), self.e2(1), self.e2(2), self.e2(3), self.size(2)/2);

            quiver3(ha, self.center(1), self.center(2), self.center(3), self.e3(1), self.e3(2), self.e3(3), self.size(3)/2);
            
            self.plot_boundary(ha);
            xlabel(ha, "X");
            ylabel(ha, "Y");
            zlabel(ha, "Z");
            axis(ha, 'equal');
            grid(ha, 'on');
            
            legend(ha, 'surface', 'volume', 'center', 'e1', 'e2', 'e3');
        end
        
        function plot_boundary(self, ha)
            if nargin == 1
                ha = axes();
            end
            [X, Y, Z] = ndgrid(-1:2:1, -1:2:1, -1:2:1);
            pos = [X(:), Y(:), Z(:)];
            
            points = [ ...
                pos(1,:); ...
                pos(2,:); ...
                pos(6,:); ...
                pos(2,:); ...
                pos(4,:); ...
                pos(8,:); ...
                pos(4,:); ...
                pos(3,:); ...
                pos(7,:); ...
                pos(3,:); ...
                pos(1,:); ...
                pos(5,:); ...
                pos(6,:); ...
                pos(8,:); ...
                pos(7,:); ...
                pos(5,:); ...
            ];
            
            points = points .* self.size/2;
            points = self.opos2wpos(points);
            
            plot3(ha, points(:,1), points(:,2), points(:,3));
        end
        
        function out = eq(self, other)
            out = false;
            if isa(other, class(self)) ...
               && all(other.center == self.center) ...
               && all(other.size == self.size) ...
               && all(other.rotation == self.rotation)
               out = true;
            end
        end
        
        function out = plus(self, other)
            if ~isa(other, 'BaseGeometry')
                error("BaseGeometry:incorrectType", "A Geometry was expected, got: %s", class(other));
            end
            if isa(self, 'MultiGeometry')
                if isa(other, 'MultiGeometry')
                    out = MultiGeometry(self.geometries{:}, other.geometries{:});
                else
                    out = MultiGeometry(self.geometries{:}, other);
                end
            else
                if isa(other, 'MultiGeometry')
                    out = MultiGeometry(self, other.geometries{:});
                else
                    out = MultiGeometry(self, other);
                end
            end
       end
    end
    methods (Abstract)
        out = is_inside(self, pos);
        points = ordered_surface_points(self, npoints);
        points = ordered_volume_points(self, npoints);
        points = random_surface_points(self, npoints);
        points = random_volume_points(self, npoints);
        plot_skeleton(self, ha);
    end
end