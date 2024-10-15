classdef UniformGenerator < BaseRandomGenerator
    properties
        low = 0;
        high = 0;
    end
        
    methods
        function self = UniformGenerator(low, high)
            self.low = min(low, high);
            self.high = max(low, high);
        end
    end

    methods (Hidden)
        function nums = draw_(self, count)
            nums = rand(count) * (self.high - self.low) + self.low;
        end
        
        function out = eq(self, other)
            out = false;
            if isa(other, 'UniformGenerator') ...
               && other.low == self.low ...
               && other.high == self.high
               out = true;
            end
        end
    end
end