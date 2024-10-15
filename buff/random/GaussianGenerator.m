classdef GaussianGenerator < BaseRandomGenerator
    properties
        mean = 0;
        sigma = 0;
    end
        
    methods
        function self = GaussianGenerator(mean, sigma)
            self.mean = mean;
            self.sigma = sigma;
        end
    end

    methods (Hidden)
        function nums = draw_(self, count)
            nums = self.sigma .* randn(count) + self.mean;
        end
        
        function out = eq(self, other)
            out = false;
            if isa(other, 'GaussianGenerator') ...
               && other.mean == self.mean ...
               && other.sigma == self.sigma
               out = true;
            end
        end
    end
end