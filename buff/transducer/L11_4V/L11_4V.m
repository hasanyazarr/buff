classdef L11_4V < BaseTransducer 
    
    properties (Access = public)
        aperture1;
        aperture2;
    end
    
    methods
        function self = L11_4V()
            self.name = "L11-4V Transducer";
            self.description = "128-element high frequency linear array transducer";
            self.aperture1 = FocusedLinearAperture( ...
                128,    ...
                270*um, ... %  Width
                5*mm,   ... %  Height
                30*um,  ... %  Kerf
                1,      ... %  nx
                10,     ... %  ny
                25*mm   ... %  elevation focus
            );
            self.aperture1.build();            
            self.aperture1.apply_waveforms();
            self.aperture1.apply_delays();
            self.aperture1.apply_apodization();
            
            self.aperture2 = FocusedLinearAperture( ...
                128,    ...
                270*um, ... %  Width
                5*mm,   ... %  Height
                30*um,  ... %  Kerf
                1,      ... %  nx
                10,     ... %  ny
                25*mm   ... %  elevation focus
            );
            self.aperture2.build();
            self.aperture2.apply_waveforms();
            self.aperture2.apply_delays();
            self.aperture2.apply_apodization();
            
            self.tx_aperture = self.aperture1;
            self.rx_aperture = self.aperture2;
            
            % Arb response from spectrum
%             f = load('L11_4V_imp_resp.mat', 'f').f;
%             a = load('L11_4V_imp_resp.mat', 'a').a;
%             
%             a(f<2.38*MHz) = 0.00001;
%             a(f>14.17*MHz) = 0.00001;
%             
%             self.tx_aperture.impulse_response = ARBImpulseResponse(f, a, 256);
%             self.rx_aperture.impulse_response = ARBImpulseResponse(f, a, 256);
            
%             % Arb response from time
%             t = load('L11_5V_timp_resp.mat', 't').t;
%             a = load('L11_5V_timp_resp.mat', 'a').a;
%             
%             self.tx_aperture.impulse_response = ARBImpulseResponseT(t, a, 256);
%             self.rx_aperture.impulse_response = ARBImpulseResponseT(t, a, 256);

%             % F0 BW response that better fits actual spectrum
            self.tx_aperture.impulse_response = F0BWImpulseResponse(5*MHz, 7.24*MHz, 40);
            self.rx_aperture.impulse_response = F0BWImpulseResponse(5*MHz, 7.24*MHz, 40);

            self.tx_aperture.f0 = 7.24*MHz;
            self.tx_aperture.bw = 5*MHz;
            
            self.rx_aperture.f0 = 7.24*MHz;
            self.rx_aperture.bw = 5*MHz;
            
        end        
    end
end