classdef SonovueScattererSource < BubbleScattererSource
   
    methods
        function self = SonovueScattererSource(geometry, avg_rate)
            self = self@BubbleScattererSource(geometry, avg_rate);
            
            data = load('sonovue_radius.mat');            

            self.kappa_gen = ConstantGenerator(1.07);
            self.kappa_s_gen = ConstantGenerator(5E-9);
            self.chi_gen = ConstantGenerator(0.4);
            self.R_0_gen = ArbitraryGenerator(data.rad, data.pdf);
            self.lin_scat_gen = ConstantGenerator(0);
            
        end
        function bub = random_bubble(self)
            if ~isempty(self.R_0_gen)
                R_0 = self.R_0_gen.draw(1);
                bub = SonovueBubble(R_0);
            end
            
            if ~isempty(self.kappa_gen)
                bub.kappa     = self.kappa_gen.draw(1);
            end
            
            if ~isempty(self.kappa_s_gen)
                bub.kappa_s     = self.kappa_s_gen.draw(1);
            end
            
            if ~isempty(self.chi_gen)
                bub.chi     = self.chi_gen.draw(1);
            end

            if ~isempty(self.r_buckle_gen)
                bub.r_buckle     = self.r_buckle_gen.draw(1);
            end

            if ~isempty(self.r_break_gen)
                bub.r_break     = self.r_break_gen.draw(1);
            end
        end
    end

end