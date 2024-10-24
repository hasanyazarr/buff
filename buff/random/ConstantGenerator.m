classdef ConstantGenerator < BaseRandomGenerator
    properties
        val = 0;
    end
        
    methods
        function self = ConstantGenerator(val)
            if nargin >= 1
                self.val = val;
            end
        end
    end
    
    methods (Hidden)
        function nums = draw_(self, count)
            nums = ones(count) * self.val;
        end
        
        function out = eq(self, other)
            out = false;
            if isa(other, 'ConstantGenerator') ...
               && other.low == self.low ...
               && other.high == self.high
               out = true;
            end
        end
    end
end