classdef ScatterersFromFile < handle & GlobalConfig
    properties(GetAccess = public, SetAccess = public)
        raw_data;
        nframes;
        nscats;
        ampmap_x;
        ampmap_z;
        ampmap;
        bubs;
    end
    
    methods
        function self = ScatterersFromFile(filename)
            %% Load Scatterer Positions Data
            self.raw_data = readmatrix(filename);
            self.nframes = max(self.raw_data(:,1)) + 1;
            self.nscats = max(self.raw_data(:,2)) + 1;
            
            % clip number of bubbles
            self.nscats = min(self.nscats, 1000);
            
            % Create Bubble list
            data = load('sonovue_radius.mat');
            gen = SonovueScattererSource(Box(), 1);
            
%             gen.kappa_gen = ConstantGenerator(1.07);
%             gen.kappa_s_gen = ConstantGenerator(5E-9);
%             gen.chi_gen = ConstantGenerator(0.4);
%             gen.R_0_gen = ArbitraryGenerator(data.rad, data.pdf);
%             gen.lin_scat_gen = ConstantGenerator(0);
            
            bub_list = gen.generate(self.nscats, zeros(self.nscats,3));
            self.bubs = bub_list.bub;
        end
    end
    
    methods
        function scats = get_frame(self, f)
            frame_data = self.raw_data(self.raw_data(:,1)==f, :);
            pos = [frame_data(:,3), frame_data(:,4), frame_data(:,5)];
            pos(:,2) = pos(:,2) .* 0.2;
            scats = BubbleScatterers(pos, self.bubs( mod(frame_data(:,2), 1000)+1));
        end
    end
end