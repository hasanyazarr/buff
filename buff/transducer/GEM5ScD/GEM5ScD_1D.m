classdef GEM5ScD_1D < BaseTransducer 
    
    properties (Access = public)
        aperture1;
        aperture2;
    end
    
    methods
        function self = GEM5ScD_1D()
            self.name = "GEM5ScD GE probe";
            self.description = "1.5D transducer (turned into 1D)";
            self.aperture1 = FocusedLinearAperture( ...
                80,    ...
                230*um, ... %  Width
                13*mm,   ...%  Height
                40*um,  ... %  Kerf
                1,      ... %  nx
                10,     ... %  ny
                77*mm   ... %  elevation focus
            );
            self.aperture1.build();
            self.aperture1.apply_waveforms();
            self.aperture1.apply_delays();
            self.aperture1.apply_apodization();
            
            self.aperture2 = FocusedLinearAperture( ...
                80,    ...
                230*um, ... %  Width
                13*mm,   ...%  Height
                40*um,  ... %  Kerf
                1,      ... %  nx
                10,     ... %  ny
                77*mm   ... %  elevation focus
            );
            self.aperture2.build();
            self.aperture2.apply_waveforms();
            self.aperture2.apply_delays();
            self.aperture2.apply_apodization();
            
            self.tx_aperture = self.aperture1;
            self.rx_aperture = self.aperture2;
            
            %% Impulse response from measurement
            %load
            t = load('GEM5ScD_1elem.mat').X;
            a = load('GEM5ScD_1elem.mat').Y;
            self.tx_aperture.impulse_response = ArbTImpulseResponse(t, a);
            self.rx_aperture.impulse_response = ArbTImpulseResponse(t, a);
            self.tx_aperture.apply_waveforms();
            self.rx_aperture.apply_waveforms();
            
            self.tx_aperture.excitation.f0 = 2.841*MHz;
            self.tx_aperture.bw = 2.5*MHz; %[1.7 4.2]
            self.rx_aperture.excitation.f0 = 2.841*MHz;
            self.rx_aperture.bw = 2.5*MHz; %[1.7 4.2]            
        end        
    end
end