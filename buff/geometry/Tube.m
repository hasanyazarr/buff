classdef Tube < BaseGeometry
    % Cylinder Class that implements a Tube
    %   This class implements a cylinder using two points and a radius.
    %   Dependent properties are defined for area, volume, diameter, length
    %   and base vector calculations
    
    properties (Dependent)
        area;                       % Total area of the tube [m^2]
        volume;                     % Volume of the tube [m^3]
    end
    
    methods
        function self = Tube(center, size, rotation)
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
            % Ramanujan approximation to the ellipse perimeter
            a = self.size(1)/2;
            b = self.size(2)/2;
            h = self.size(3);
            f = ((a-b)/(a+b))^2;
            p = pi * (a+b) * (1 + 3*f/ (10 + sqrt(4-3*f)));
            area =  p * h;
        end
        
        function set.area(self, new_area)
            factor = sqrt(new_area/self.area);
            self.size = self.size .* factor;
        end

        function volume = get.volume(self)
            a = self.size(1)/2;
            b = self.size(2)/2;
            h = self.size(3);
            volume = pi * a * b * h;
        end
        
        function set.volume(self, new_volume)
            factor = nthroot(new_volume / self.volume, 3);
            self.size = self.size .* factor;
        end
        
        function out = is_inside(self, pos)
            
            size_pos = size(pos);
            if size_pos(end) ~= 3
                error("Last dimension of pos should have size 3. Points must be 3Dimensional");
            end
            pos = reshape(pos, [], 3);
            pos = self.wpos2opos(pos);
            pos = pos ./ (self.size/2);
            
            in_z = (-1 <= pos(:,3)) & (pos(:,3) <= 1);
            in_r = (pos(:,1).^2 + pos(:,2).^2) < 1; 
            
            out = in_z & in_r;
            out = reshape(out, [size_pos(1:end-1), 1]);
        end

        function points = ordered_top_end_points(self, npoints)
            if length(npoints) == 2
                n_ang = npoints(1);
                n_length = npoints(2);
            elseif length(npoints) == 1
                n_ang = npoints;
                n_length = npoints;
            else
                error("npoints should be either 1 or 2 dimension");
            end
            
            [A, L] = ndgrid( ...
                        linspace(0, 2*pi, n_ang), ...
                        linspace(1, 1, n_length) ...
            );
        
            points = [cos(A(:)) , sin(A(:)) , L(:) ] .* self.size/2;
            points = self.opos2wpos(points);
        end
        
        function points = ordered_bot_end_points(self, npoints)
            if length(npoints) == 2
                n_ang = npoints(1);
                n_length = npoints(2);
            elseif length(npoints) == 1
                n_ang = npoints;
                n_length = npoints;
            else
                error("npoints should be either 1 or 2 dimension");
            end
            
            [A, L] = ndgrid( ...
                        linspace(0, 2*pi, n_ang), ...
                        linspace(-1, -1, n_length) ...
            );
        
            points = [cos(A(:)) , sin(A(:)) , L(:) ] .* self.size/2;
            points = self.opos2wpos(points);
        end
        
        function points = ordered_surface_points(self, npoints)
            if length(npoints) == 2
                n_ang = npoints(1);
                n_length = npoints(2);
            elseif length(npoints) == 1
                n_ang = npoints;
                n_length = npoints;
            else
                error("npoints should be either 1 or 2 dimension");
            end
            
            [A, L] = ndgrid( ...
                        linspace(0, 2*pi, n_ang), ...
                        linspace(-1, 1, n_length) ...
            );
        
            points = [cos(A(:)) , sin(A(:)) , L(:) ] .* self.size/2;
            points = self.opos2wpos(points);
        end
        
        function points = ordered_volume_points(self, npoints)
            if length(npoints) == 3
                n_ang = npoints(1);
                n_rad = npoints(2);
                n_length = npoints(3);
            elseif length(npoints) == 1
                n_ang = npoints;
                n_rad = npoints;
                n_length = npoints;
            else
                error("npoints should be either 1 or 3 dimension");
            end
            [A, R, L] = ndgrid( ...
                        linspace(0, 2*pi, n_ang), ...
                        linspace(0, 1, n_rad), ...
                        linspace(-1, 1, n_length) ...
            );
            points = [ R(:) .* cos(A(:)) , R(:) .* sin(A(:)) , L(:) ] .* self.size/2;
            points = self.opos2wpos(points);
        end
        
        function points = random_top_end_points(self, npoints)
            if length(npoints) ~= 1
                error("npoints should be either 1 dimension");
            end
            
            L = ones(npoints, 1);
            A = rand(npoints, 1) * 2 * pi;
            R = rand(npoints, 1);
            points = [ R.*cos(A(:)) , R.*sin(A(:)) , L(:) ] .* self.size/2;
            points = self.opos2wpos(points);
        end
        
        function points = random_bot_end_points(self, npoints)
            if length(npoints) ~= 1
                error("npoints should be either 1 dimension");
            end
            
            L = -ones(npoints, 1);
            A = rand(npoints, 1) * 2 * pi;
            R = rand(npoints, 1);
            points = [ R.*cos(A(:)) , R.*sin(A(:)) , L(:) ] .* self.size/2;
            points = self.opos2wpos(points);
        end
        
        function points = random_surface_points(self, npoints)
            if length(npoints) ~= 1
                error("npoints should be either 1 dimension");
            end
            
            L = 2 * rand(npoints, 1) - 1;
            A = rand(npoints, 1) * 2 * pi;
            points = [ cos(A(:)) , sin(A(:)) , L(:) ] .* self.size/2;
            points = self.opos2wpos(points);
        end
        
        function points = random_volume_points(self, npoints)
            if length(npoints) ~= 1
                error("npoints should be either 1 dimension");
            end
            
            L = 2 * rand(npoints, 1) - 1;
            A = rand(npoints, 1) * 2 * pi;
            R = rand(npoints, 1);
            points = [ R(:) .* cos(A(:))  ,  R(:) .* sin(A(:)), L(:) ] .* self.size/2;
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