classdef RFSignals < GlobalConfig & handle
    % RFSignals   Multi-channel RF signals as FieldII outputs
    %
    % The signals returned by FieldII have two components:
    % start_t: time until first non-zero sample
    % signals: Nchan x Nsamp matrix
    %
    % This class provides a better implementation, with overloaded methods 
    % for basic operations, and more complex functions like Hilbert / IQ
    
    properties
        start_t = 0;            % Time until first non-zero sample [s]
        signals = [];           % Nchan x Nsamp matrix
    end
    methods
        function self = RFSignals(signals, start_t, fs)
            if nargin >= 1
                self.signals = signals;
            end
            if nargin >= 2
                self.start_t = start_t;
            end
            if nargin >= 3
                self.fs = fs;
            end
        end
        
        function n = n_chan(self)
            if isscalar(self)
                n = size(self.signals, 1);
            else
                n = size(self(1).signals, 1);
            end
        end
        
        function n = n_samp(self)
            n = size(self.signals, 2);
        end
        
        function t = time_vector(self)
            t = ( 1:size(self.signals,2) )/self.fs + self.start_t;
        end
        
        function resample(self, new_fs)
            end_t = self.start_t + (self.n_samp() - 1) * 1/self.fs;
            
            t = repmat( ...
                    self.start_t : 1/self.fs : end_t, ...
                    [self.n_chan(), 1] ...
            );
        
            c = repmat(...
                    (1:self.n_chan())', ...
                    [1, self.n_samp()] ...
            );
        
            new_t = repmat( ...
                    self.start_t : 1/new_fs : end_t, ..., ...
                    [self.n_chan(), 1] ...
            );
            
            new_c = repmat(...
                    (1:self.n_chan())', ...
                    [1, size(new_t, 2)] ...
            );
        
            if self.n_chan() == 1
                self.signals = interpn(t, self.signals, new_t, 'linear', 0);
            else
                self.signals = interpn(c, t, self.signals, new_c, new_t, 'linear', 0);
            end
            self.fs = new_fs;
        end
        
        function out = plus(self, other)
            if isa(other, 'double')
                out = RFSignals(self.signals + other, self.start_t, self.fs);
            elseif isa(other, 'RFSignals')
                if self.n_chan() ~= other.n_chan()
                    error("RFSignals must have same number of channels");
                end

                if self.fs ~= other.fs
                    other.resample(self.fs);
                end

                [sigs, t] = equalize_signals( ...
                    {self.signals, other.signals}, ...
                    [self.start_t, other.start_t], ...
                    self.fs ...
                );

                out = RFSignals(sigs{1} + sigs{2}, t, self.fs);
            end
        end

        function out = minus(self, other)
            if isa(other, 'double')
                out = RFSignals(self.signals - other, self.start_t, self.fs);
            elseif isa(other, 'RFSignals')
                if self.n_chan() ~= other.n_chan()
                    error("RFSignals must have same number of channels");
                end

                if self.fs ~= other.fs
                    other.resample(self.fs);
                end

                [sigs, t] = equalize_signals( ...
                    {self.signals, other.signals}, ...
                    [self.start_t, other.start_t], ...
                    self.fs ...
                );

                out = RFSignals(sigs{1} - sigs{2}, t, self.fs);
            end
        end
        
        function out = horzcat(self, other)
            if isa(other, 'RFSignals')
                if self.n_chan() ~= other.n_chan()
                    error("RFSignals must have same number of channels");
                end

                if self.fs ~= other.fs
                    other.resample(self.fs);
                end

                out = RFSignals([self.signals , other.signals], self.start_t, self.fs);
            end
        end

        function out = vertcat(self, other)
            % if self is an RFSignals array, concatenate them
            if nargin <=2
                fs = self.fs;
                [sigs, t] = equalize_signals( ...
                    {self.signals}, ...
                    [self.start_t], ...
                    fs ...
                );
                out = RFSignals(cell2mat(sigs'), t, fs);
                return;
            end
            
            if isa(other, 'RFSignals')
                if self.fs ~= other.fs
                    other.resample(self.fs);
                end
                [sigs, t] = equalize_signals( ...
                    {self.signals, other.signals}, ...
                    [self.start_t, other.start_t], ...
                    self.fs ...
                );

                out = RFSignals([sigs{1} ; sigs{2}], t, self.fs);
            end
        end

        
        function out = rdivide(self, other)
            if isa(self, 'RFSignals') && isa(other, 'double')
                out = RFSignals(self.signals ./ other, self.start_t, self.fs);
            elseif isa(self, 'double') && isa(other, 'RFSignals')
                out = RFSignals(other.signals ./ self, other.start_t, other.fs);
            elseif isa(self, 'RFSignals') && isa(other, 'RFSignals')
                if self.n_chan() ~= other.n_chan()
                    error("RFSignals must have same number of channels");
                end
                if self.fs ~= other.fs
                    other.resample(self.fs);
                end
                [sigs, t] = equalize_signals( ...
                    {self.signals, other.signals}, ...
                    [self.start_t, other.start_t], ...
                    self.fs ...
                );
                out = RFSignals(sigs{1} ./ sigs{2}, t, self.fs);
            end
        end
        
        function out = mrdivide(self, other)
            out = self ./ other;
        end
        
        function out = times(self, other)
            if isa(self, 'RFSignals') && isa(other, 'double')
                out = RFSignals(self.signals .* other, self.start_t, self.fs);
            elseif isa(self, 'double') && isa(other, 'RFSignals')
                out = RFSignals(other.signals .* self, other.start_t, other.fs);
            elseif isa(self, 'RFSignals') && isa(other, 'RFSignals')
                if self.n_chan() ~= other.n_chan()
                    error("RFSignals must have same number of channels");
                end
                if self.fs ~= other.fs
                    other.resample(self.fs);
                end
                [sigs, t] = equalize_signals( ...
                    {self.signals, other.signals}, ...
                    [self.start_t, other.start_t], ...
                    self.fs ...
                );
                out = RFSignals(sigs{1} .* sigs{2}, t, self.fs);
            end
        end
        
        function out = mtimes(self, other)
            out = self .* other;
        end
        
        function out = filtfilt(self, b, a)
            out = RFSignals(self.signals, self.start_t, self.fs);
            out.signals = ...
                cell2mat( ...
                    cellfun( ...
                        @(x) filtfilt(b, a, x), ...
                        mat2cell(out.signals, ones(1, size(out.signals,1))), ...
                        'UniformOutput', ...
                        false ...
                    ) ...
                ); 
        end
        
        function out = conv(self, other, shape)
            if nargin <3
                shape = 'full';
            end
            out = RFSignals(self.signals, self.start_t, self.fs);
            
            if isa(other, 'double')
                out.signals = ...
                    cell2mat( ...
                        cellfun( ...
                            @(x) conv(x, other, shape), ...
                            mat2cell(out.signals, ones(1, size(out.signals,1))), ...
                            'UniformOutput', ...
                            false ...
                        ) ...
                    );
            elseif isa(other, 'RFSignals')
                if self.fs ~= other.fs
                    other.resample(self.fs);
                end
                if other.n_chan() == 1
                    out.signals = ...
                        cell2mat( ...
                            cellfun( ...
                                @(x) conv(x, other.signals, shape), ...
                                mat2cell(out.signals, ones(1, size(out.signals,1))), ...
                                'UniformOutput', ...
                                false ...
                            ) ...
                        );
                elseif self.n_chan() == other.n_chan()
                    out.signals = ...
                        cell2mat( ...
                            cellfun( ...
                                @(x, y) conv(x, y, shape), ...
                                mat2cell(out.signals, ones(1, size(out.signals,1))), ...
                                mat2cell(other.signals, ones(1, size(other.signals,1))), ...
                                'UniformOutput', ...
                                false ...
                            ) ...
                        );
                else
                    error(strcat(class(self), ":TypeError"), ...
                        'not a supported size for convolution'); 
                end
                out.start_t = out.start_t + other.start_t;
            else
                error(strcat(class(self), ":TypeError"), ...
                        '%s is not a supported type for convolution', class(other));
            end
        end
        
        function out = hilbert(self)
            out = RFSignals(...
                    hilbert(self.signals')', ...
                    self.start_t, ...
                    self.fs ...
            );
        end
        
        function out = IQ(self, f0, BW, order)
            if nargin < 4
                order = 100;
            elseif nargin < 3
                BW = f0;
            end
            % complex exponential
            sig = self.signals;            
            sig = sig .* exp(1j * 2*pi*f0 * self.time_vector);            
                        
            % apply low pass filter
            if numel(BW) == 1
                lp_filt_b = fir1(order, BW/2/(self.fs/2));
            elseif numel(BW) == 2
                lp_filt_b = fir1(order, BW./(self.fs/2));
            end
            
            sig = filtfilt(lp_filt_b, 1, sig')';
            
            out = RFSignals(...
                    sig, ...
                    self.start_t, ...
                    self.fs ...
            );
        end
        
    end
end

function [sigs,t] = equalize_signals(sigs, times, fs)
    n_signals = length(sigs);
    % Equalize lengths
    start_times = times;
    %end_times = times + cellfun(@(a) size(a,2), sigs)/fs;
    end_times = times + cellfun(@(a) size(a,2)-1, sigs)/fs;
    min_t = min(times);
    max_t = max(end_times);

    for sig_ix = 1:n_signals
        zeros_left = round((start_times(sig_ix) - min_t) *fs);
        zeros_right = round((max_t - end_times(sig_ix)) *fs);
        sigs{sig_ix} = padarray(padarray(sigs{sig_ix}, [0, zeros_left], 'pre'), [0, zeros_right], 'post');
%         sigs{sig_ix} = interpn(...
%             (1:size(sigs{sig_ix},1))', start_times(sig_ix):1/fs:end_times(sig_ix), ...
%             sigs{sig_ix}, ...
%             (1:size(sigs{sig_ix},1))', min_t:1/fs:max_t, 'linear', 0 );
    end
    max_length = max(cellfun(@(a) size(a,2), sigs));
    sigs = cellfun(@(a) padarray(a,[0,max_length-length(a)],'post'), sigs,'UniformOutput',0); 

    % Merge
    t = min_t;
end