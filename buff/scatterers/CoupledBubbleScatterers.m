classdef CoupledBubbleScatterers < BaseScattererList & GlobalConfig
    properties(GetAccess = public, SetAccess = public)
    end
    
    properties (Dependent)
        bubs;
    end
    
    methods        
        function self = CoupledBubbleScatterers(pos, bubs)
            if nargin >= 2 && isa(bubs, 'CoupledBubbles')
                self.pos = pos;
                self.bubs = bubs;
            end    
        end
        
        function bub = get.bubs(self)
            bub = self.scat;
        end
        
        function set.bubs(self, new_bubs)
            self.scat = new_bubs;
        end      
       
        function new_self = plus(self, other)
            if isa(other, 'CoupledBubbleScatterers')
                new_self = CoupledBubbleScatterers( ...
                    [self.pos ; other.pos],  ...
                    [self.bub ; other.bub]   ...
                );
            else
                plus@BaseScattererList(self, other);
            end
        end
    end
end