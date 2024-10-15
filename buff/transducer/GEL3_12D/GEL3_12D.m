classdef GEL3_12D < BaseTransducer 
    
    properties (Access = public)
        aperture1;
        aperture2;
    end
    
    methods
        function self = GEL3_12D()
            self.name = "GE L-3-12-D Transducer";
            self.description = " 256-element high frequency linear array transducer";
            self.aperture1 = FocusedLinearAperture( ...
                256,    ...
                180*um, ... %  Width
                5*mm,   ... %  Height
                20*um,  ... %  Kerf
                1,      ... %  nx
                10,     ... %  ny
                22*mm   ... %  elevation focus
            );
            self.aperture1.build();            
            self.aperture1.apply_waveforms();
            self.aperture1.apply_delays();
            self.aperture1.apply_apodization();
            
            self.aperture2 = FocusedLinearAperture( ...
                256,    ...
                180*um, ... %  Width
                5*mm,   ... %  Height
                20*um,  ... %  Kerf
                1,      ... %  nx
                10,     ... %  ny
                22*mm   ... %  elevation focus
            );
            self.aperture2.build();
            self.aperture2.apply_waveforms();
            self.aperture2.apply_delays();
            self.aperture2.apply_apodization();
            
            self.tx_aperture = self.aperture1;
            self.rx_aperture = self.aperture2;
            

            % Arb response from time
            t = load('GEL3_12D_1elem.mat', 'X').X;
            a = load('GEL3_12D_1elem.mat', 'Y').Y;
            
            self.tx_aperture.impulse_response = ArbTImpulseResponse(t, a);
            self.rx_aperture.impulse_response = ArbTImpulseResponse(t, a);

            self.tx_aperture.f0 = 6.5*MHz;
            self.tx_aperture.bw = self.tx_aperture.f0 * 0.85;
            
            self.rx_aperture.f0 = 6.5*MHz;
            self.rx_aperture.bw = self.rx_aperture.f0 * 0.85;
            
        end        
    end
end