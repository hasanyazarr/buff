classdef BubbleMMT < BaseBubbleODE
    properties
        kappa {mustBeNumeric} = 1.095;              % [ ]       the polytropic gas exponent
        kappa_s {mustBeNumeric} = 15E-9;            % [N]       the surface dilatational viscosity from the monolayer
        chi {mustBeNumeric} = 1;                    % [N/m]     the elastic compression modulus of the monolayer
        R_0 {mustBeNumeric} = 3.5e-6;               % [m]       the equilibrium radius of the bubble
        sigma_break{mustBeNumeric} = 1;             % [N/m]     the break surface tension of the lipid layer
        r_buckle {mustBeNumeric} = 3.5e-6;          % [m]       the lower radius limit of the elastic state
        ruptured{mustBeNumericOrLogical} = false;   % [ ]       wether or not the bubble is in ruptured state
    end
    properties (Dependent, GetAccess = public, SetAccess = protected)
        r_rupture{mustBeNumeric};                   % [m]       the rupture upper radius limit of the elastic state
        r_break {mustBeNumeric};                    % [m]       the upper radius limit of the elastic state
    end
    
    methods
        function self = BubbleMMT()
            self.ode_solver = @ode45;
            self.ode_ic = [self.R_0 0];
            self.ode_opts = odeset();
        end

        function r_rupture = get.r_rupture(self)
            r_rupture = self.r_buckle * sqrt(1 + self.sigma_l/self.chi);
        end
        
        function r_break = get.r_break(self)
            r_break = self.r_buckle * sqrt(1 + self.sigma_break/self.chi);
        end
        
        function sgm = sigma(self, r)
            if (r <= self.r_rupture)
                self.ruptured = false;
            end
            
            if (r >= self.r_break)
                self.ruptured = true;
            end
                        
            if (self.ruptured == false)
                if (r <= self.r_buckle)
                    sgm = 0;                
                elseif (r <= self.r_break)
                    sgm = self.chi*((r/self.r_buckle)^2 - 1.0);
                end
            else
                sgm = self.sigma_l;
            end
        end
        
    	function dydt = f(self, t, y, t_pin, pin)            
            p_ac = interp1(t_pin, pin, t, 'linear', 0);
            
            R = y(1);
            dR = y(2);
            
            dR = dR;
            ddR = 1/R * 1/self.rho_l * (                            ... 
                    (self.P_0 + 2*self.sigma(self.R_0)/self.R_0)    ...
                        * (R/self.R_0)^(-3*self.kappa)              ...
                        * (1- 3*self.kappa/self.c * dR)             ...
                    - self.P_0                                      ...
                    - 2 * self.sigma(R) / R                         ...
                    - 4 * self.mu_l * dR / R                        ...
                    - 4 * self.kappa_s * dR / (R)^2                 ...
                    - p_ac                                          ...
                ) - 3/2 *  dR^2 / R;
 
            dydt = [dR ; ddR];
        end
        
        function b_scat = calc_bscat(self, b_R, t)            
            b_scat = self.rho_l .* ( 2 .* b_R(:,1) .* b_R(:,2).^2  + b_R(:,1).^2 .* b_R(:,3) );            
        end
        
        function w0 = w0_(self)
            %% Resonant angular frequency of the bubble
            % $\omega_0 = 2\pi f_0 = \frac{1}{R_0} \sqrt{\frac{1}{\rho_l}\(3
            % \kappa P_0 + (3\kappa -1)\frac{2\sigma(R_0)}{R_0} + \frac{4\chi}{R_0} \) }$ 
            w0 = 1/self.R_0 * sqrt( ...
                1/self.rho_l * ( ...
                    3*self.kappa*self.P_0 + ...
                    (3*self.kappa-1) * 2*self.sigma(self.R_0)/self.R_0 + ...
                    4 * self.chi/self.R_0 ...
                ) ...
            );
        end
	end
end