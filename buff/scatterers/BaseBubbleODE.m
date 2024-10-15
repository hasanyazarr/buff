classdef (Abstract) BaseBubbleODE < BaseBubble
    properties
        ode_solver = @ode45;
        ode_ic {mustBeNumeric};
        ode_opts= odeset();
    end
    
    properties (Dependent, GetAccess = public, SetAccess = protected)
    end
    
    methods
        function self = BaseBubbleODE()
        end
        
        function [b_scat, b_R, t] = response(self, p_in)
            
            
            
            % Upsample to fs_bub
            upsample_factor = ceil(self.fs_bub/self.fs);
            p_in = interp(p_in, upsample_factor);
            t_p_in = (1:length(p_in)) / self.fs_bub;
            
            % Solve
            sol = self.ode_solver(...
                @(t, y) self.f(t, y, t_p_in, p_in), ...
                [min(t_p_in) max(t_p_in)], ...
                self.ode_ic, ...
                self.ode_opts ...
            );
            
            [y, yp] = deval(sol, t_p_in);
            
            % append ddR
            b_R = [y', yp(2,:)'];
            
            b_scat = self.calc_bscat(b_R, t_p_in);
            
            b_scat = downsample(b_scat, upsample_factor);
            b_R    = downsample(b_R, upsample_factor);
            t      = downsample(t_p_in, upsample_factor);
        end
    end
    methods (Abstract)
    	dydt = f(self, t, y, t_pin, pin);
        b_scat = calc_bscat(self, b_R, t);
    end
end