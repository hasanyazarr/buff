classdef Excitation < GlobalConfig & handle

    properties
       f0 = 1e6;
       n_cycles = 3;
       amplitude = 1;
       is_ideal = true;
    end
    
    properties (Dependent, GetAccess = public, SetAccess = protected)
       signal;
       t;
    end

    methods
        function self = Excitation(f0, n_cycles, amplitude)
            if nargin >= 1
                self.f0 = f0;
            end
            
            if nargin >= 2
                self.n_cycles = n_cycles;
            end
            
            if nargin >= 3
                self.amplitude = amplitude;
            end
        end
        
        function signal = get.signal(self)
            if self.is_ideal
                [signal, ~] = Excitation.ideal(self.fs);
            else
                [signal, ~] = Excitation.create(self.f0, self.n_cycles, self.amplitude, self.fs);
            end
        end
        
        function t = get.t(self)
            if self.is_ideal
                [~, t] = Excitation.ideal(self.fs);
            else
                [~, t] = Excitation.create(self.f0, self.n_cycles, self.amplitude, self.fs);
            end
        end
        
        function plot(self)
            plot( ...
                self.t, ...
                self.signal ...
            );
        end
    end
    
    methods (Static)
        function [excitation, t] = create(f0, n_cycles, amplitude, fs)
            t = 0 : 1/fs : n_cycles/f0;
            excitation = amplitude * sin(2 * pi * f0 * t);
        end

        function [excitation, t] = ideal(fs)
            t = 1:5;
            excitation = [1, 0, 0, 0, 0];
            if nargin == 1
                t = t./fs;
            end
        end
    end
end
