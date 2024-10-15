classdef BubbleScattererSource < handle & BaseScattererSource & GlobalConfig
    properties(GetAccess = public, SetAccess = public)
        kappa_gen;      % [ ]       the polytropic gas exponent.
        kappa_s_gen;    % [N]       the surface dilatational viscosity from the monolayer
        chi_gen;        % [N/m]     the elastic compression modulus of the monolayer
        R_0_gen;        % [m]       the equilibrium radius of the bubble
        r_buckle_gen;   % [m]       the lower radius limit of the elastic state
        r_break_gen;    % [m]       the upper radius limit of the elastic state
        lin_scat_gen;   % [ ]       linear scattering factor
    end
    
    methods
        function self = BubbleScattererSource(geometry, avg_rate)
            self = self@BaseScattererSource(geometry, avg_rate);
        end
    end
    
    methods
        function bub = random_bubble(self)
            bub           = BubbleMMT();
            if ~isempty(self.kappa_gen)
                bub.kappa     = self.kappa_gen.draw(1);
            end
            
            if ~isempty(self.kappa_s_gen)
                bub.kappa_s     = self.kappa_s_gen.draw(1);
            end
            
            if ~isempty(self.chi_gen)
                bub.chi     = self.chi_gen.draw(1);
            end
            
            if ~isempty(self.R_0_gen)
                bub.R_0     = self.R_0_gen.draw(1);
            end

            if ~isempty(self.r_buckle_gen)
                bub.r_buckle     = self.r_buckle_gen.draw(1);
            end

            if ~isempty(self.r_break_gen)
                bub.r_break     = self.r_break_gen.draw(1);
            end
            
            if ~isempty(self.lin_scat_gen)
                bub.lin_scat     = self.lin_scat_gen.draw(1);
            end
        end
        
        function objs = generate(self, n_obj, pos)
            bubs = arrayfun(@(x)self.random_bubble(), 1:n_obj)';
            objs = BubbleScatterers(pos, bubs);
        end
    end
end