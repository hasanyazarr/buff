classdef F0BWImpulseResponse < BaseImpulseResponse
    properties(GetAccess = private, SetAccess = private)
        tresp_t
        tresp_s
    end

    methods
        function self = F0BWImpulseResponse(varargin)
            if nargin == 1 % (bw)
                bw = varargin{1};
                n = 128;
                if length(bw) ~= 2
                    error("F0BWImpulseResponse: when using only one argument, low and high cutoff frequencies must be provided");
                end
            elseif nargin == 2 % (bw, f0) or (bw, n)
                bw = varargin{1};
                if length(bw) == 1 % (bw, f0)
                    f0 = varargin{2};
                    n = 128;
                elseif length(bw) == 2 % (bw, n)
                    n = varargin{2};
                end
            elseif nargin == 3
                bw = varargin{1};
                f0 = varargin{2};
                n = varargin{3};
            end
            
            if length(bw) == 1
                lims = [-bw/2, bw/2] + f0;
            elseif length(bw) == 2
                lims = bw;
            end
            if any(lims<0) || any(lims>self.fs/2)
                error("F0BWImpulseResponse: frequency lims out of bounds");
            end
            if n>1024
                warning("F0BWImpulseResponse: filter order > 1024");
            end
            self.build(lims, n);        
        end
        
        function [imp_resp, t] = get_sig_t(self)
            imp_resp = self.tresp_s;
            t = self.tresp_t;
        end
        
        function build(self, lims, n)
            fnyq = self.fs/2;
            self.tresp_s = fir1(n, lims/fnyq);
            self.tresp_t = (1:length(self.tresp_s))/self.fs;
            
            % Symmetric FIR -> delay = t/2
            self.delay = max(self.tresp_t)/2;
        end
    end
end
