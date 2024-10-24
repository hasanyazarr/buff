classdef Flow < handle & GlobalConfig
    properties(GetAccess = public, SetAccess = public)
        U;  % Velocity field interpolant for x-dimension
        V;  % Velocity field interpolant for y-dimension
        W;  % Velocity field interpolant for z-dimension
        geometry;
    end
    
    methods
        function self = Flow(pos, vel, geom)
            if nargin >= 2
                self.build(pos, vel)
            end
            if nargin >= 3
                self.geometry = geom;
            end
        end
        
        function build(self, pos, vel)
            pos = reshape(pos, [], 3);
            x = pos(:, 1);
            y = pos(:, 2);
            z = pos(:, 3);
            
            vel = reshape(vel, [], 3);
            vx = vel(:, 1);
            vy = vel(:, 2);
            vz = vel(:, 3);
            
            self.U = scatteredInterpolant(x, y, z, vx, 'natural', 'linear');
            self.V = scatteredInterpolant(x, y, z, vy, 'natural', 'linear');
            self.W = scatteredInterpolant(x, y, z, vz, 'natural', 'linear');
        end
        
        function vel = velocity_at(self, pos)
            vel = [self.U(pos) , self.V(pos) , self.W(pos)];
            % Anything outside the geometry should have 0 velocity
            vel = vel .* self.geometry.is_inside(pos);
        end
        
        function new_pos = apply_to(self, pos, dt)
            vel = self.velocity_at(pos);
            new_pos = pos + vel .* dt;
            % TODO: Check if outside geometry and put back inside
        end
        
        function plot(self, varargin)
            % self, ha
            % self, scale
            % self, ha, scale
            % self, ha, scale, count
            
            scale = 1;
            count = 10;
            
            if nargin >= 2
                if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                    ha = varargin{1};
                else
                    ha = axes();
                    scale = varargin{1};
                end
            else
                ha = axes();
            end
            
            if nargin >= 3
                if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                   scale = varargin{2};
                else
                   count = varargin{3};
                end
            end
            
            pos = self.geometry.ordered_volume_points(count);
            vel = self.velocity_at(pos);
            quiver3(ha, pos(:,1), pos(:,2), pos(:,3), vel(:,1), vel(:,2), vel(:,3), scale);
        end
    end
end