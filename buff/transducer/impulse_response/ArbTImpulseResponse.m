classdef ArbTImpulseResponse < BaseImpulseResponse
    properties(GetAccess = public, SetAccess = public)
        tresp_t
        tresp_s
    end

    methods
        function self = ArbTImpulseResponse(t, a)
            if nargin < 2
                error("ArbTImpulseResponse: Arguments time, and amp must be provided");
            end
            
            t = t(:);
            a = a(:);
            
            self.check(t, a);
            self.build(t, a);        
        end
        
        function [imp_resp, t] = get_sig_t(self)
            imp_resp = self.tresp_s;
            t = self.tresp_t;
        end
        
        function check(self, t, a)
            if nargin < 2
                error("ArbTImpulseResponse: Both vectors (time and amp) must be provided");
            end
            
            if size(a) ~= size(t)
                error("ArbTImpulseResponse: Both vectors (time and amp) must have the same size");
            end
        end
        
        function build(self, t, a)

            % compensate non uniform sampling
            a = interp1(t, a, linspace(min(t), max(t), length(t)), 'linear', 0);
            
            % remove offset
            t = t - min(t);
            a = a - mean(a);
            
            % resample to our fs            
            old_fs = 1/mean(diff(t));
            new_fs = self.fs;
            
            if new_fs < old_fs
                f = fir1(50, new_fs/old_fs);
                a = filtfilt(f, 1, a);
            end
            
            new_t = min(t) : 1/new_fs : max(t);
            self.tresp_s = interp1(t, a, new_t);
            self.tresp_t = new_t;
            [h, ~] = freqz(self.tresp_s);
            self.tresp_s = self.tresp_s./max(abs(h));
            
            % calc delay as time of max envelope
            env = abs(hilbert(self.tresp_s));
            [~, I] = max(env);
            self.delay = (I-1)/new_fs;
        end
    end
end
