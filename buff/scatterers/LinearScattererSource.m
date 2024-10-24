classdef LinearScattererSource < handle & BaseScattererSource & GlobalConfig
    properties(GetAccess = public, SetAccess = public)
        amp_gen;
    end
    
    methods
        function self = LinearScattererSource(geometry, avgrate, amp_gen)
            self = self@BaseScattererSource(geometry, avgrate);
            if nargin >= 3
                self.amp_gen = amp_gen;
            end
        end
    end
    
    methods
        % change pos to self.geometry.random_pos(n_obj)
        function objs = generate(self, n_obj, pos)
            objs = LinearScatterers(pos, self.amp_gen.draw([n_obj,1]));
        end
    end
end