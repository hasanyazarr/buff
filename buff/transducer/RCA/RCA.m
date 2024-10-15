classdef RCA < BaseTransducer 
    
    properties (Access = public)
        row_aperture;
        col_aperture;
    end
    
    methods
        function self = RCA()
            self.name = "RCA Transducer";
            self.description = "128+128 element medium frequency Row Column Array transducer";
            self.row_aperture = GridAperture( ...
                [1, 128],       ...
                2.56e-2,   ... %  Width
                175e-6,   ... %  Height
                [25e-6, 25e-6],    ... %  Kerf
                128,            ... %  nx
                1               ... %  ny
            );
            self.row_aperture.build();            
            self.row_aperture.apply_waveforms();
            self.row_aperture.apply_delays();
            self.row_aperture.apply_apodization();
            
            self.col_aperture = GridAperture( ...
                [128, 1],       ...
                175e-6,   ... %  Width
                2.56e-2,   ... %  Height
                [25e-6, 25e-6],    ... %  Kerf
                1,         ... %  nx
                128        ... %  ny
            );
            self.col_aperture.build();
            self.col_aperture.apply_waveforms();
            self.col_aperture.apply_delays();
            self.col_aperture.apply_apodization();
            
            self.tx_aperture = self.row_aperture;
            self.rx_aperture = self.col_aperture;
            
            %Arb response from spectrum
            f = load('rca_imp_resp.mat', 'f').f;
            a = load('rca_imp_resp.mat', 'a').a;
            
            a(f<1.0e6) = 0.00001;
            a(f>14.0e6) = 0.00001;
            
            self.tx_aperture.impulse_response = ArbFImpulseResponse(f, a, 256);
            self.rx_aperture.impulse_response = ArbFImpulseResponse(f, a, 256);
            
        end

        function sel_col(self)
            self.tx_aperture = self.col_aperture;
            self.rx_aperture = self.row_aperture;
        end
        
        function sel_row(self)
            self.tx_aperture = self.row_aperture;
            self.rx_aperture = self.col_aperture;
        end
    end
end