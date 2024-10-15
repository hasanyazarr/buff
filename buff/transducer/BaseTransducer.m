classdef (Abstract) BaseTransducer < Oriented3D & GlobalConfig
    
    properties (GetAccess = public, SetAccess = protected)
        name = "Transducer";
        description = "Transducer";
    end
    
    properties (Access = public)
        tx_aperture;
        rx_aperture;
    end

    methods
        function self = BaseTransducer()
        end
       
        function out = tx_pressure(self, pos)
            % pos from the transducer perspective
            pos = self.wpos2opos(pos);
            out = self.tx_aperture.TX(pos);
        end

        function out = tx_spatial_response(self, pos)
            % pos from the transducer perspective
            pos = self.wpos2opos(pos);
            out = self.tx_aperture.TX_resp(pos);
        end
        
        function out = rx_voltage(self, pos, sig)
            % pos from the transducer perspective
            pos = self.wpos2opos(pos);
            out = self.rx_aperture.RX(pos, sig);
        end
        
        function out = rx_spatial_response(self, pos)
            % pos from the transducer perspective
            pos = self.wpos2opos(pos);
            out = self.rx_aperture.TX_resp(pos);
        end
        
        function set_MI(self, MI, pos)
        % SET_MI  Set Mechanical Index
        %   SET_MI(MI, POS) sets mechanical index MI at POS 
            current_MI = self.get_MI(pos);
            
            self.tx_aperture.excitation.amplitude = ...
                self.tx_aperture.excitation.amplitude * MI / current_MI; 
            self.tx_aperture.apply_waveforms();
        end
        
        function MI = get_MI(self, pos)
            tx_p = self.tx_pressure(pos);
            
            % Maximum negative pressure peak
            peak_p = max(-tx_p.signals, [], 'all');

            peak_p_MPa = peak_p / MPa;
            f0_MHz = self.tx_aperture.excitation.f0 / MHz;           
            MI = peak_p_MPa / sqrt(f0_MHz);
            
        end

        function out = tx_rx_angles(self, scat, angles)
            out = arrayfun(@(x) RFSignals([], 0, self.fs), 1:numel(angles));
            for i_ang = 1:numel(angles)
                % calc and apply delays
                delays = self.tx_aperture.calc_delays(angles(i_ang));
                for ee = 1:self.tx_aperture.n_elements
                    self.tx_aperture.elements(ee).delay = delays(ee);
                end
                self.tx_aperture.apply_delays();
                % transmit
                out(i_ang) = self.tx_rx(scat);
            end
        end
        
        function out = pulse_inversion(self, scat, angles)
            if nargin == 2
                angles = 0;
            end
            out1 = self.tx_rx_angles(scat, angles);            
            % set inverse excitation
            self.tx_aperture.excitation.amplitude = -self.tx_aperture.excitation.amplitude;            
            out2 = self.tx_rx_angles(scat, angles);
            % restore excitation
            self.tx_aperture.excitation.amplitude = -self.tx_aperture.excitation.amplitude;
            
        end
        
        function out = tx_rx(self, scat)
            if isa(scat, 'LinearScatterers')
                out = self.tx_rx_linear(scat.pos, scat.amp);
            elseif isa(scat, 'BubbleScatterers')
                out = self.tx_rx_bubble(scat);
            elseif isa(scat, 'CoupledBubbleScatterers')
                out = self.tx_rx_coupled(scat);
            end
        end
        
        function out = tx_rx_linear(self, pos, amp)
            pos = self.wpos2opos(pos);           
            [sig, t] = calc_scat_multi(     ...
                self.tx_aperture.fII_id,    ...
                self.rx_aperture.fII_id,    ...
                pos,                        ...
                amp                         ...
            );
            out = RFSignals(sig', t, self.fs);
        end
        
        function out = tx_rx_bubble(self, bubbles)            
            tmp = arrayfun(@(x) RFSignals([], 0, self.fs), 1:bubbles.count);
            for ii = 1:bubbles.count
                tx_p = self.tx_pressure(bubbles.pos(ii,:));
                [bub_sig, br, t] = bubbles.bub(ii).response(tx_p.signals);
                bub_sig =  RFSignals(bub_sig', tx_p.start_t, self.fs);
                tmp(ii) = self.rx_voltage(bubbles.pos(ii,:), bub_sig);
            end
            
            out = tmp(1);
            for ii = 2:bubbles.count
                out = out + tmp(ii);
            end
        end

        function out = tx_bub_radius(self, bubbles)            
            out = arrayfun(@(x) RFSignals([], 0, self.fs), 1:bubbles.count);
            for ii = 1:bubbles.count
                tx_p = self.tx_pressure(bubbles.pos(ii,:));
                [bub_sig, br, t] = bubbles.bub(ii).response(tx_p.signals);
                bub_rad =  RFSignals(br', tx_p.start_t, self.fs);
                %bub_rad =  RFSignals(br(:,1)', tx_p.start_t, self.fs);
                out(ii) = bub_rad;
            end
        end
        
        function out = tx_bub_scat_sig(self, bubbles)            
            out = arrayfun(@(x) RFSignals([], 0, self.fs), 1:bubbles.count);
            for ii = 1:bubbles.count
                tx_p = self.tx_pressure(bubbles.pos(ii,:));
                [bub_sig, br, t] = bubbles.bub(ii).response(tx_p.signals);
                bub_sig =  RFSignals(bub_sig', tx_p.start_t, self.fs);
                out(ii) = bub_sig;
            end
        end
        
        function out = tx_rx_coupled(self, coupled_bubs)            
            tmp = arrayfun(@(x) RFSignals([], 0, self.fs), 1:coupled_bubs.count);
            for ii = 1:coupled_bubs.count
                tx_p1 = self.tx_pressure(coupled_bubs.bubs(ii).pos{1});
                tx_p2 = self.tx_pressure(coupled_bubs.bubs(ii).pos{2});

                [bub_sig, ~, ~] = coupled_bubs.bubs(ii).response(...
                                                        tx_p1.signals, ...
                                                        tx_p2.signals ...
                );
            
                bub_sig1 =  RFSignals(bub_sig{1}', tx_p1.start_t, self.fs);
                bub_sig2 =  RFSignals(bub_sig{2}', tx_p2.start_t, self.fs);
                rx = self.rx_voltage(coupled_bubs.bubs(ii).pos{1}, bub_sig1) ...
                     + self.rx_voltage(coupled_bubs.bubs(ii).pos{2}, bub_sig2);
                tmp(ii) = rx;
            end
            
            out = tmp(1);
            for ii = 2:coupled_bubs.count
                out = out + tmp(ii);
            end
        end
        
        function out = scat_resp(self, scat)
            if isa(scat, 'LinearScatterers')
                out = self.tx_rx_linear(scat.pos, scat.amp);
            elseif isa(scat, 'BubbleScatterers')
                out = self.tx_rx_bubble(scat);
            elseif isa(scat, 'CoupledBubbles')
                out = self.tx_rx_coupled(scat);
            end
        end
        
        function out = scat_resp_linear(self, pos, amp)
            pos = self.wpos2opos(pos);
            tx_p = self.tx_pressure(pos);
            out = tx_p*amp;
        end
        
        function [out_scat, out_r] = scat_resp_bubble(self, bubbles)            
            tmp = arrayfun(@(x) RFSignals([], 0, self.fs), 1:bubbles.count);
            tmp2 = arrayfun(@(x) RFSignals([], 0, self.fs), 1:bubbles.count);
            for ii = 1:bubbles.count
                tx_p = self.tx_pressure(bubbles.pos(ii,:));
                [bub_sig, bub_rad, ~] = bubbles.bub(ii).response(tx_p.signals);
                tmp(ii) =  RFSignals(bub_sig', tx_p.start_t, self.fs);
                tmp2(ii) =  RFSignals(bub_rad', tx_p.start_t, self.fs);
            end
            
            out = tmp(1);
            for ii = 2:bubbles.count
                out = out + tmp(ii);
            end
        end
    end
end