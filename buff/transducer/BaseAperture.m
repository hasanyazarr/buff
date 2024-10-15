classdef (Abstract) BaseAperture < GlobalConfig
    
    properties
        elements;           % Array of mathematical elements
        fII_id;             % fII_handle
        impulse_response;   
        excitation;
    end
    
    properties (Dependent, SetAccess = public, GetAccess = public)
        f0;
        bw;
        elem_apodization;
    end
    
    properties (Dependent, GetAccess = public, SetAccess = protected)
        n_elements;
        elem_centers;
    end

    properties (Abstract, Dependent)
    end
    
    methods
        function self = BaseAperture()
            self.elements = [Element()];
            self.impulse_response = ImpulseResponse();
            self.impulse_response.is_ideal = false;
            self.excitation = Excitation();
            self.excitation.is_ideal = false;
        end
        
        function delete(self)
            if ~isempty(self.fII_id)
                xdc_free(self.fII_id);
            end
        end
        
        function n_elements = get.n_elements(self)
            n_elements = numel(self.elements);
        end
        
        function elem_centers = get.elem_centers(self)
            elem_centers = cell2mat({self.elements.center}');
        end
        
        function elem_apodization = get.elem_apodization(self)
            elem_apodization = cell2mat({self.elements.apodization}');
        end

        function set.elem_apodization(self, elem_apodization)
            if numel(elem_apodization) ~= self.n_elements
                error("BaseAperture:Error", "Wrong number of apodization values");
            end
            for ei = 1:self.n_elements
                self.elements(ei).apodization = elem_apodization(ei);
            end
        end
        
        function set.f0(self, new_f0)
            self.excitation.f0 = new_f0;
            for ei = 1:self.n_elements
                self.elements(ei).excitation.f0 = new_f0;
            end
            self.apply_waveforms();
        end
        
        function f0 = get.f0(self)
            f0 = self.excitation.f0;
        end

        function set.bw(self, new_bw)
            %self.impulse_response.bw = new_bw;
            for ei = 1:self.n_elements
                %self.elements(ei).impulse_response.bw = new_bw;
            end
            self.apply_waveforms();
        end
        
        function bw = get.bw(self)
            bw = self.impulse_response.bw;
        end
        
        function fII_rect_info = get_fII_rect_info(self)
            fII_rect_info = ...
                cell2mat( ...
                    arrayfun( ...
                        @(ei)self.elements(ei).fII_melem_rect_info, ...
                        1:self.n_elements, ...
                        'UniformOutput', ...
                        false...
                    )' ...
                );
        end
        
        function fII_tri_info = get_fII_tri_info(self)
            fII_tri_info = ...
                cell2mat( ...
                    arrayfun( ...
                        @(ei)self.elements(ei).fII_melem_tri_info, ...
                        1:self.n_elements, ...
                        'UniformOutput', ...
                        false...
                    )' ...
                );
        end
        
        function build(self)
            % remove previous aperture
            if ~isempty(self.fII_id)
                xdc_free(self.fII_id);
            end
            self.fII_id = xdc_rectangles(self.get_fII_rect_info(), self.elem_centers, [0, 0, 1]);
        end

        function apply_waveforms(self)
            if isempty(self.fII_id)
                error("BaseAperture:Error", "Transducer needs to be built");
            end
            % elem wise waveform
            arrayfun( ...
                @(ei) ele_waveform(self.fII_id, ei, self.elements(ei).fII_elem_waveform), ...
                1:self.n_elements ...
            )
            % aperture wise waveform
            xdc_impulse(self.fII_id, self.impulse_response.signal);
            xdc_excitation(self.fII_id, self.excitation.signal);
        end
        
        function apply_delays(self)
            if isempty(self.fII_id)
                error("BaseAperture:Error", "Transducer needs to be built");
            end
            % math elem wise delays
            for ei = 1:self.n_elements
                ele_delay (self.fII_id, ei, self.elements(ei).fII_melem_delay);
            end
            % elem wise delays
            elem_delays = cell2mat({self.elements.fII_elem_delay}')';
            xdc_focus_times(self.fII_id, 0, elem_delays);
        end
        
        function apply_apodization(self)
            if isempty(self.fII_id)
                error("BaseAperture:Error", "Transducer needs to be built");
            end
            % math elem wise apodization
            for ei = 1:self.n_elements
                ele_apodization (self.fII_id, ei, self.elements(ei).fII_melem_apodization);
            end
            % elem wise apodization
            elem_apodization = cell2mat({self.elements.fII_elem_apodization}')';
            xdc_apodization(self.fII_id, 0, elem_apodization);
        end
        
        function plot_aperture(self, ha)

            if nargin == 1
                ha = axes();
            end
            if isempty(self.fII_id)
                error("BaseAperture:Error", "Transducer needs to be built");
            end
            data = xdc_get(self.fII_id, 'rect');
            x = data([11, 20, 17, 14], :);
            y = data([12, 21, 18, 15], :);
            z = data([13, 22, 19, 16], :);
            c = data([5, 5, 5, 5], :);

            patch(ha, x, y, z, c);
            view(ha, 3)
            xlabel(ha, 'X');
            ylabel(ha, 'Y');
            zlabel(ha, 'Z');
        end

        function out = TX(self, pos)
            [sig, t] = calc_hp(self.fII_id, pos);
            out = RFSignals(sig', t);
        end
        
        function out = TX_resp(self, pos)
            [sig, t] = calc_h(self.fII_id, pos);
            out = RFSignals(sig', t);
        end
        
        function make_ideal(self)
            xdc_impulse(self.fII_id, [1 0]);
            xdc_excitation(self.fII_id, [1 0]);
        end
        
        function out = RX(self, pos, sig)           
            out = self.RX_resp(pos);
            out = out .* self.elem_apodization;
            if nargin >= 2
                 out = out.conv(sig);
            end
            out = out.conv(self.impulse_response.signal);
        end

        function out = RX_resp(self, pos)
            % RX_resp  Receive spatial response.
            %   obj.RX_resp(pos) calculates the receive spatial response
            %   from position 'pos' to each of the elements of the
            %   aperture
            %
            %   See also RX, TX, TX_resp.            
            xdc_excitation(self.fII_id, [1 0]);
            xdc_impulse(self.fII_id, [1 0]);
            
            out = arrayfun(@(x) RFSignals([], 0, self.fs), 1:self.n_elements);
            for ii = 1:self.n_elements                        
                % use apodization to select one element at a time
                xdc_apodization(self.fII_id, 0, onehot(ii, self.n_elements));
                % response element->pos  is equivalent to  pos->element
                out(ii) = self.TX(pos);
            end
            out = vertcat(out);
            
            % restore apodization
            self.apply_apodization();
            self.apply_waveforms();
        end
        
    end
    
    methods (Abstract)
        delays = calc_delays(self, angles);
    end
end
