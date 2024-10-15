classdef GridAperture < BaseAperture
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
        function self = GridAperture(count, width, height, kerf, nx, ny)
            if numel(count) == 1
                warning("count should be 2D for grid arrays, asuming same count for y dimension");
                count = [count, count];
            elseif numel(count) > 2
                warning("count should be 2D for grid arrays, using only first 2 counts");
                count = count([1,2]);
            else
                count = count(:)';
            end
            if numel(kerf) == 1
                warning("count should be 2D for grid arrays, asuming same kerf count for y dimension");
                kerf = [kerf, kerf];
            elseif numel(kerf) > 2
                warning("count should be 2D for grid arrays, using only first 2 kerfs");
                kerf = kerf([1,2]);
            else
                kerf = kerf(:)';
            end
            
            self.count = count;
            self.width = width;
            self.height = height;
            self.kerf = kerf;            
            
            [e_cy, e_cx] = ndgrid(1:count(2), 1:count(1));
            e_cx = e_cx .* self.pitch(1);
            e_cy = e_cy .* self.pitch(2);
            e_cx = e_cx - mean(e_cx, 'all');
            e_cy = e_cy - mean(e_cy, 'all');   
            e_centers = [e_cx(:), e_cy(:), 0*e_cx(:)];

            self.elements = arrayfun(...
                @(ei) RectElement( ...
                    ei, ...
                    self.width, ...
                    self.height, ...
                    e_centers(ei, :), ...
                    nx, ...
                    ny  ...
                ), ...
                1:prod(count) ...
            );
            self.elements = reshape(self.elements, [count(2), count(1)]);
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
        	pitch = [self.width, self.height] + self.kerf;
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

        %% This only works for RCA. set off-axis pitch to 0
        function delays = calc_delays(self, angles)
            angles = angles(:);
            delays = sind(angles) * max(self.pitch)./self.c;
            delays = cumsum(repmat(delays, [self.n_elements, 1]), 1);
            delays = delays - min(delays);
        end


    end
end

