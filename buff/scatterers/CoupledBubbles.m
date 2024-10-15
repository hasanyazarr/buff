classdef CoupledBubbles < GlobalConfig
    properties
        bubbles (1,:) Bubble
        n_bubbles {mustBeNumeric}
        pos
        distance {mustBeNumeric}
        coupling {mustBeNumeric}
    end
    methods
        function self = CoupledBubbles(b1, pos1, b2, pos2)
            self.bubbles = [b1, b2];
            self.pos = {pos1, pos2};
            self.distance = max(0, vecnorm(pos1 - pos2) - b1.R_0 - b2.R_0);
            self.coupling = 1;
        end
        
        function [b_scat, b_R, t] = response(self, p_in1, p_in2)

            upsample_factor = ceil(self.fs_bub/self.fs);
            p_in1 = interp(p_in1, upsample_factor);
            p_in2 = interp(p_in2, upsample_factor);
            p_sz = max(length(p_in1), length(p_in2));
            p_in1 = padarray(p_in1, [p_sz - size(p_in1, 1), 0], 'post');
            p_in2 = padarray(p_in2, [p_sz - size(p_in2, 1), 0], 'post');
            
            b1 = self.bubbles(1);
            b2 = self.bubbles(2);
            
            dt = 1/self.fs_bub;

            delay = self.distance/1540;
            delay_samps = round(delay/dt);

            nt = p_sz;
            t =  zeros(nt, 1);
            
            b1_R = zeros(nt, 3);
            b1_R(1) = b1.R_0;
            b1_scat = zeros(nt, 1);

            b2_R = zeros(nt, 3);
            b2_R(1) = b2.R_0;
            b2_scat = zeros(nt, 1);

            for n=1:nt-1

                %% Coupling delay and amplitude
                delay_index = n-delay_samps;
                delay_amp = 1/self.distance;
                if delay_index > 0
                    b1_scat_at_b2 = self.coupling * b1_scat(delay_index) * delay_amp;
                    b2_scat_at_b1 = self.coupling * b2_scat(delay_index) * delay_amp;
                else
                    b1_scat_at_b2 = 0;
                    b2_scat_at_b1 = 0;
                end
                

                b1_incoming = p_in1(n) + b2_scat_at_b1;
                b2_incoming = p_in2(n) + b1_scat_at_b2;

                %% Bubble 1
                [t(n+1), b1_R(n+1,:)] = b1.step(t(n), b1_R(n,:), b1_incoming);

                %% Bubble 2
                [t(n+1), b2_R(n+1,:)] = b2.step(t(n), b2_R(n,:), b2_incoming);

                %% Scat calc
                b1_scat(n+1) = b1.rho_l * b1_R(n,1) * (2 * b1_R(n,2).^2 + b1_R(n,1) * b1_R(n,3)) + b1.lin_scat * b1_incoming;
                b2_scat(n+1) = b2.rho_l * b2_R(n,1) * (2 * b2_R(n,2).^2 + b2_R(n,1) * b2_R(n,3)) + b2.lin_scat * b2_incoming;

            end

            b1_scat = downsample(b1_scat, upsample_factor);
            b2_scat = downsample(b2_scat, upsample_factor);
            b1_R    = downsample(b1_R, upsample_factor);
            b2_R    = downsample(b2_R, upsample_factor);
            t       = downsample(t, upsample_factor);
            
            b_scat = {b1_scat, b2_scat};
            b_R = {b1_R, b2_R};
        end
    end
end