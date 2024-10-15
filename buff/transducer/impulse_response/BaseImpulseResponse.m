classdef BaseImpulseResponse < GlobalConfig & handle
    properties
       is_ideal = false;
       delay = 0;
    end

    properties (Dependent, GetAccess = public, SetAccess = protected)
       signal;
       t;
    end

    methods
        function self = BaseImpulseResponse()
        end

        function signal = get.signal(self)
            if self.is_ideal
                [signal, ~] = self.ideal();
            else
                [signal, ~] = self.get_sig_t();
            end
        end
        
        function t = get.t(self)
            if self.is_ideal
                [~, t] = self.ideal();
            else
                [~, t] = self.get_sig_t();
            end
        end
        
        function freqz(self, varargin)
            [h, w] = freqz(self.signal, 1, 1024);
            f = w./2/pi * self.fs;
            subplot(2,1,1)
            plot(f/MHz, db(h))            
            ylabel('Magnitude (dB)')
            grid on;
            subplot(2,1,2)
            plot(f/MHz, rad2deg(unwrap(angle(h))))
            ylabel('Phase [degrees]')
            xlabel('Frequency [MHz]')
            grid on;
            
        end
        
        function plot(self, varargin)
            if nargin>1 && isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ha = varargin{1};
                o_args = varargin{2:end};
            else
                ha = gca;
                o_args = varargin;
            end
            
            plot( ...
                ha, ...
                self.t, ...
                self.signal, ...
                o_args{:} ...
            );
        end
        
        function [signal, t] = ideal(self)
            t = (1:5)./self.fs;
            signal = [1, 0, 0, 0, 0];
        end

    end
    
    methods (Abstract)
        [signal, t] = get_sig_t(self);
    end
end
