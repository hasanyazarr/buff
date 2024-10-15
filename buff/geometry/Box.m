classdef Box < BaseGeometry
    
    properties (SetAccess = public)

    end
    
    properties (Dependent)
        area;                       % Area of the box [m^2]
        volume;                     % Volume of the box [m^3]
    end
    
    methods
        function self = Box(center, size, rotation)
            if nargin >=1
                self.center = center;
            end
            if nargin >=2
                self.size = size;
            end
            if nargin >=3
                self.rotation = rotation;
            end           
        end
                
        function area = get.area(self)
            area = 2 * sum( prod( self.size(nchoosek(1:3,2) ), 2 ) );
        end
        
        function set.area(self, new_area)
            factor = sqrt(new_area/self.area);
            self.size = self.size .* factor;
        end

        function volume = get.volume(self)
            volume = prod(self.size);
        end
        
        function set.volume(self, new_volume)
            factor = sqrt(new_volume/self.volume);
            self.size = self.size .* factor;
        end
        
        function out = is_inside(self, pos)
            % go to geometry coords
            pos = self.wpos2opos(pos);
            % test inside cube in each dimension
            in = (pos > -self.size/2) & (pos < self.size/2);
            % check if inside in all dimensions 
            out = all(in,2);
        end

        function points = ordered_surface_points(self, npoints)
            if length(npoints) == 2
                [A, B] = ndgrid( ...
                            linspace(-1, 1, npoints(1)), ...
                            linspace(-1, 1, npoints(2))  ...
                );
            elseif length(npoints) == 1
                [A, B] = ndgrid( ...
                            linspace(-1, 1, npoints), ...
                            linspace(-1, 1, npoints)  ...
                );     
            else
                error("npoints should be either 1 or 2 dimension");
            end
            
            points = [ ...
                [  A(:),   B(:), 0*A(:)] - [0, 0, 1]; ...
                [  A(:),   B(:), 0*A(:)] + [0, 0, 1]; ...
                [0*A(:),   A(:),   B(:)] - [1, 0, 0]; ...
                [0*A(:),   A(:),   B(:)] + [1, 0, 0]; ...
                [  A(:), 0*A(:),   B(:)] - [0, 1, 0]; ...
                [  A(:), 0*A(:),   B(:)] + [0, 1, 0]; ...
            ];
            points = points .* (self.size/2);
            points = self.opos2wpos(points);
        end
        
        function points = ordered_volume_points(self, npoints)
            if length(npoints) == 3
                [X, Y, Z] = ndgrid( ...
                            linspace(-1, 1, npoints(1)), ...
                            linspace(-1, 1, npoints(2)), ...
                            linspace(-1, 1, npoints(3)) ...
                );           
            elseif length(npoints) == 1
                [X, Y, Z] = ndgrid( ...
                            linspace(-1, 1, npoints), ...
                            linspace(-1, 1, npoints), ...
                            linspace(-1, 1, npoints) ...
                );      
            else
                error("npoints should be either 1 or 3 dimension");
            end
            points = [X(:) Y(:) Z(:)] .* (self.size/2);       
            points = self.opos2wpos(points);
        end

        function points = random_surface_points(self, npoints)
            if length(npoints) ~= 1
                error("npoints should be either 1 dimension");
            end
            
            dim = randi([1, 3], [npoints, 1]); % choose a random dimension
            sig = randi([0, 1], [npoints, 1]); % choose a random sign
            points = 2 * rand(npoints, 3) - 1;
            ind = sub2ind(size(points), (1:npoints)', dim);
            points(ind) = (-1).^sig;
            points = points .* self.size/2;
            points = self.opos2wpos(points);
        end
        
        function points = random_volume_points(self, npoints)
            if length(npoints) ~= 1
                error("npoints should be either 1 dimension");
            end
            
            points = 2*rand(npoints, 3) - 1;
            points = points .* self.size/2;
            points = self.opos2wpos(points);
        end
        
        function plot_skeleton(self, ha)
            if nargin == 1
                ha = axes();
            end
            self.plot_boundary(ha);
        end
    end
end