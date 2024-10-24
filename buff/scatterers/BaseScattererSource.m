classdef (Abstract) BaseScattererSource < handle & GlobalConfig
    properties(GetAccess = public, SetAccess = public)
        geometry;
        avg_rate;            % Average number of objects created per second [1/s]
    end
    
    methods
        function self = BaseScattererSource(geometry, avg_rate)
            if nargin >= 1
                self.geometry = geometry;
            end
            if nargin >= 2
                self.avg_rate = avg_rate;
            end
        end
        
        function [objs, n_obj] = step(self, dt)
            n_obj = poissrnd(self.avg_rate * dt);
            pos = self.geometry.random_volume_points(n_obj);
            objs = self.generate(n_obj, pos);
        end
    end
    
    methods (Abstract)
        objs = generate(self, n_obj, pos);
    end
end