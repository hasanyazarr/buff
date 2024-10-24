classdef SonovueBubble < BubbleMMT
    methods
        function self = SonovueBubble(R_0)
            self = self@BubbleMMT();
            if (nargin >= 1)
                self.R_0 = R_0;
                self.ode_ic = [self.R_0 0];
            end
            
            self.r_buckle = self.R_0;
            self.sigma_break = 1;
            self.chi = 0.4;
            
            self.kappa = 1.07;
            self.kappa_s = 5E-9;            
            self.ode_opts.RelTol = 1e-7;
        end
    end
end