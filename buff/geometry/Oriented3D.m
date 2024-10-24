classdef (Abstract) Oriented3D < handle
	properties
        e1;                         % First base unit vector (x,y,z) [m, m, m]
        e2;                         % Second base unit vector (x,y,z) [m, m, m]
        e3;                         % Third base unit vector (x,y,z) [m, m, m]
        center = [0, 0, 0];         % Center of the object (x,y,z) [m, m, m]
        rotation = [0, 0, 0];       % Rotation of the object (x,y,z) [deg, deg, deg]
	end
    
    methods
        function self = Oriented3D()
        end
        
        function center = get.center(self)
            center = self.center;
        end
        
        function set.center(self, new_center)
            self.center = new_center;
        end

        function rotation = get.rotation(self)
            rotation = self.rotation;
        end
        
        function set.rotation(self, new_rotation)
            self.rotation = new_rotation;
        end
        
        function e1 = get.e1(self)
            total_rot =   rotx(self.rotation(1)) ...
                        * roty(self.rotation(2)) ...
                        * rotz(self.rotation(3));
            e1 = total_rot(:, 1)';
        end
        
        function e2 = get.e2(self)
            total_rot =   rotx(self.rotation(1)) ...
                        * roty(self.rotation(2)) ...
                        * rotz(self.rotation(3));
            e2 = total_rot(:, 2)';
        end
        
        function e3 = get.e3(self)
            total_rot =   rotx(self.rotation(1)) ...
                        * roty(self.rotation(2)) ...
                        * rotz(self.rotation(3));
            e3 = total_rot(:, 3)';
        end
        
        function opoints = wpos2opos(self, wpos)
            wpos_sz = size(wpos);
            wpos = reshape(wpos, [], 3);
            W2G = [self.e1(:) , self.e2(:) , self.e3(:)];
            opoints = (wpos - self.center) * W2G;
            opoints = reshape(opoints, wpos_sz);
        end
        
        function wpoints = opos2wpos(self, opos)
            opos_sz = size(opos);
            opos = reshape(opos, [], 3);
            W2G = [self.e1(:) , self.e2(:) , self.e3(:)];
            wpoints = opos/W2G + self.center; % opos * inv(W2G) + self.center
            wpoints = reshape(wpoints, opos_sz);
        end
        
        function out = eq(self, other)
            out = false;
            if isa(other, class(self)) ...
               && all(other.center == self.center) ...
               && all(other.rotation == self.rotation)
               out = true;
            end
        end
        
        function plot_axis(self, ha, sz)
            if nargin == 1
                ha = axes();
                sz = [1,1,1];
            elseif nargin == 2
                sz = [1,1,1];
            end

            M = repmat(self.center, 3,1);
            E = [self.e1; self.e2; self.e3];
            quiver3(ha , M(:,1), M(:,2), M(:,3), E(:,1), E(:,2), E(:,3));
        end
        
    end
    methods (Abstract)
    end
end