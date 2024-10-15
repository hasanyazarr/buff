classdef BubbleScatterers < BaseScattererList & GlobalConfig
    properties(GetAccess = public, SetAccess = public)
    end
    
    properties (Dependent)
        bub;
    end
    
    methods        
        function self = BubbleScatterers(pos, bub)
            if nargin >= 2 && isa(bub, 'BaseBubble')
                self.pos = pos;
                self.bub = bub;
            end
        end
        
        function bub = get.bub(self)
            bub = self.scat;
        end
        
        function set.bub(self, new_bub)
            self.scat = new_bub;
        end
       
        function new_self = plus(self, other)
            if isa(other, 'BubbleScatterers')
                new_self = BubbleScatterers( ...
                    [self.pos ; other.pos],  ...
                    [self.bub ; other.bub]   ...
                );
            else
                plus@BaseScattererList(self, other);
            end
        end
    end
end