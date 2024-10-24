classdef ImpulseResponse < BaseImpulseResponse
    properties
       f0 = 1e6;
       bw = 1e6;
    end

    methods
        function self = ImpulseResponse(f0, bw)
            if nargin >= 1
                self.f0 = f0;
            end
            
            if nargin >= 2
                self.bw = bw;
            end
        end

        function [signal, t] = get_sig_t(self)
            hann_size = round(2 * self.fs/self.bw);
            t = (0:1:hann_size-1)/self.fs;
            signal = cos(2*pi*self.f0*t) .* hanning(hann_size)'; 
        end
    end
end
