classdef ArbFImpulseResponse < BaseImpulseResponse
    properties(GetAccess = private, SetAccess = private)
        tresp_t
        tresp_s
    end

    methods
        function self = ArbFImpulseResponse(f, a, n)
            if nargin < 2
                error("ArbFImpulseResponse: Arguments freq, and amp must be provided");
            elseif nargin < 3
                n = 128;
            end
            
            f = f(:);
            a = a(:);
            
            self.check(f, a);
            self.build(f, a, n);        
        end
        
        function [imp_resp, t] = get_sig_t(self)
            imp_resp = self.tresp_s;
            t = self.tresp_t;
        end
        
        function check(self, f, a)
            if nargin < 2
                error("ArbFImpulseResponse: Both vectors (freq and amp) must be provided");
            end
            
            if size(a) ~= size(f)
                error("ArbFImpulseResponse: Both vectors (freq and amp) must have the same size");
            end
            
            if any(f>self.fs/2) || any(f<0)
                error("ArbFImpulseResponse: frequency values should be between 0 and Fs/2");
            end
        end
        
        function build(self, f, a, n)
            nf = 1024;
            f_nyq = self.fs/2;
            a = interp1(f, a, linspace(0, f_nyq, nf), 'linear', min(a));
            f = linspace(0, f_nyq, nf);
            f = f./f_nyq;

            d = fdesign.arbmag('N,F,A', n, f, a);
            Hd = design(d, 'freqsamp','SystemObject', true);
            self.tresp_s = Hd.Numerator;
            self.tresp_t = (1:length(self.tresp_s))/self.fs;
            
            % Symmetric FIR -> delay = t/2
            self.delay = max(self.tresp_t)/2;
        end
    end
end
