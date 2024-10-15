classdef  TriMathElement < MathElement  
    methods
        function self = TriMathElement(p1, p2, p3)
            self.corners = [p1(:)'; p2(:)'; p3(:)'];
        end
    end
end