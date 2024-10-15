classdef (Abstract) BaseRandomGenerator < handle
        
    methods
        function self = BaseRandomGenerator()
        end

        function out = draw(self, varargin)
            out = self.draw_(cell2mat(varargin));
        end       
    end
    
    methods(Abstract, Hidden)
        nums = draw_(self, count);
        out = eq(self, other);
    end
end