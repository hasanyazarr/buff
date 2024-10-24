classdef Ellipsoid < BaseGeometry
    properties (Dependent)
        area;
        volume;
    end
    
    methods
        function self = Ellipsoid(center, size, rotation)
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
            area = 4*pi * (mean(prod(self.size( nchoosek(1:3,2) ), 2).^(1.6)))^(1/1.6);
        end
        
        function set.area(self, new_area)
            factor = sqrt(new_area/self.area);
            self.size = self.size * factor;
        end

        function volume = get.volume(self)
            volume = 4/3 * pi * prod(self.size);
        end
        
        function set.volume(self, new_volume)
            factor = new_volume/self.volume;
            self.size = self.size * factor;
        end
        
        function out = is_inside(self, pos)
            pos = self.wpos2opos(pos);
            pos = pos ./ (self.size/2);
            out = vecnorm(pos, 2, 2) <= 1;
        end
                
        function points = ordered_surface_points(self, npoints)
            if length(npoints) == 2
                n_ele = npoints(1);
                n_azi = npoints(2);
            elseif length(npoints) == 1
                n_ele = npoints;
                n_azi = npoints;
            else
                error("npoints should be either 1 or 2 dimension");
            end
            [E, A] = ndgrid( ...
                        linspace(0, pi, n_ele), ...
                        linspace(0, 2*pi, n_azi) ...
            );
            points = [sin(E(:)) .* cos(A(:)) , sin(E(:)) .* sin(A(:)) , cos(E(:))];
            points  = points .* self.size./2;
            points = self.opos2wpos(points);
        end
        
        function points = ordered_volume_points(self, npoints)
            if length(npoints) == 3
                n_ele = npoints(1);
                n_azi = npoints(2);
                n_rad = npoints(3);
            elseif length(npoints) == 1
                n_ele = npoints;
                n_azi = npoints;
                n_rad = npoints;
            else
                error("npoints should be either 1 or 3 dimension");
            end
            [E, A, R] = ndgrid( ...
                        linspace(0, pi, n_ele), ...
                        linspace(0, 2*pi, n_azi), ...
                        linspace(0, 1, n_rad) ...
            );
            points = [ ...
                R(:) .* sin(E(:)) .* cos(A(:)) , ...
            	R(:) .* sin(E(:)) .* sin(A(:)) , ...
            	R(:) .* cos(E(:)) ...
            ];
            points  = points .* self.size./2;
            points = self.opos2wpos(points);
        end
        
        function points = random_surface_points(self, npoints)
            if length(npoints) ~= 1
                error("npoints should be either 1 dimension");
            end
            
            E = rand(npoints, 1) * pi;
            A = rand(npoints, 1) * 2 * pi;
            points = [sin(E(:)) .* cos(A(:)) , sin(E(:)) .* sin(A(:)) , cos(E(:))];
            points  = points .* self.size./2;
            points = self.opos2wpos(points);
        end
        
        function points = random_volume_points(self, npoints)
            if length(npoints) ~= 1
                error("npoints should be either 1 dimension");
            end
            
            E = rand(npoints, 1) * pi;
            A = rand(npoints, 1) * 2 * pi;
            R = rand(npoints, 1);
            points = [ ...
                R(:) .* sin(E(:)) .* cos(A(:)) , ...
            	R(:) .* sin(E(:)) .* sin(A(:)) , ...
            	R(:) .* cos(E(:)) ...
            ];
            points  = points .* self.size./2;
            points = self.opos2wpos(points);
        end
        
        function plot_skeleton(self, ha)
            if nargin == 1
                ha = axes();
            end
            % TODO: implement
        end
    end
end