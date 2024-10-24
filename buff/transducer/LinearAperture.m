classdef LinearAperture < BaseAperture
    properties (SetAccess = public, GetAccess = public)
        count   = 128;
        width   = 500e-6;
        height  = 5e-3;
        kerf    = 100e-6;
    end
    
    properties (Dependent, GetAccess = public, SetAccess = private)
        pitch;
    end
    
    methods
        function self = LinearAperture(count, width, height, kerf, nx, ny)
            if numel(count) > 1
                warning("count should be 1D for linear arrays, using only the first value");
                count = count(1);
            end
            if numel(kerf) > 1
                warning("kerf should be 1D for linear arrays, using only the first value");
                kerf = kerf(1);
            end
            
            self.count = count;
            self.width = width;
            self.height = height;
            self.kerf = kerf;
            self.elements = arrayfun(@(tvj) Element(), 1:self.count);
            
            e_centers = (1:self.count) .* (self.width + self.kerf);
            e_centers = e_centers - mean(e_centers);
            e_centers = e_centers' .* [1, 0, 0];
            
            self.elements = arrayfun(...
                @(ei) RectElement( ...
                    ei, ...
                    self.width, ...
                    self.height, ...
                    e_centers(ei, :), ...
                    nx, ...
                    ny  ...
                ), ...
                1:count ...
            );
        
            self.build();
        end
        
        
        function enable(self, new_enabled)
            if isa(new_enabled, 'double')
                for eni = 1:numel(new_enabled)
                    self.elements(new_enabled(eni)).enabled = true;
                end
            elseif isa(new_enabled, 'string') || isa(new_enabled, 'char')
                if strcmpi(new_enabled, 'full')
                    for ei = 1:numel(self.elements)
                        self.elements(ei).enabled = true;
                    end
                elseif strcmpi(new_enabled, 'even')
                    for ei = 1:numel(self.elements)
                        self.elements(ei).enabled = ...
                            mod(self.elements(ei).number, 2) == 0;
                    end
                elseif strcmpi(new_enabled, 'odd')
                    for ei = 1:numel(self.elements)
                        self.elements(ei).enabled = ...
                            mod(self.elements(ei).number, 2) == 1;
                    end
                end
            end      
        end

        function pitch = get.pitch(self)
        	pitch = self.width + self.kerf;
        end
                      
        function update_transducer(self)
            if isempty(self.element_count) ...
               || isempty(self.element_width) ...
               || isempty(self.element_height) ...
               || isempty(self.element_kerf) ...
               || isempty(self.element_pitch)
                error("LinearTransducer:PropertyNotSet", "Tried to update transducer with unset property");
            end
            
            % remove previous transducer
            if ~isempty(self.fII_id)
                xdc_free(self.fII_id);
            end
            
            % create a new transducer
            self.fII_id = xdc_linear_array( ...
                    self.element_count, ...
                    self.element_width, ...
                    self.element_height, ...
                    self.element_kerf, ...
                    10, 10, [0, 0, 0] ...
            );
        
            % update element center & index
            self.elem_ix = 0:self.element_count-1;
            elem_posx = self.elem_ix .* self.element_pitch;
            elem_posy = zeros(size(elem_posx));
            elem_posz = zeros(size(elem_posx));
            elem_pos = cat(2, elem_posx', elem_posy', elem_posz');
            self.element_center = elem_pos - mean(elem_pos);
        end

        
        function delays = calc_delays(self, angles)
            angles = angles(:);
            delays = sind(angles) * self.pitch./self.c;
            delays = cumsum(repmat(delays, [self.n_elements, 1]), 1);
            delays = delays - min(delays);
        end


    end
end

