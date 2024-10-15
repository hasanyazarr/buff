classdef Element < GlobalConfig & handle
    properties(SetAccess = public)
        impulse_response;
        excitation;
        delay = 0;
        enabled = true;     
        apodization = 1;    % Apodization of the whole element
        number = 1;         % Number of Element inside an aperture
        math_elements;      % Array of mathematical elements
        center = [0, 0, 0];
    end
     
    properties (Dependent, GetAccess = public, SetAccess = protected)
        fII_melem_rect_info;    % Rectangle information of the math elements 
                                % to be used when calling xdc_rectangles
        fII_melem_tri_info;     % Triangle information of the math elements 
                                % to be used when calling xdc_triangles                                
        fII_elem_waveform;      % Waveform of the whole element
        
        fII_elem_apodization;   % Apodization for the whole element
        fII_melem_apodization;  % Apodization for the math elements
        
        fII_elem_delay;        % delay for the whole elements
        fII_melem_delay;       % delays for the math elements
    end
    
    methods
        function self = Element()
            self.impulse_response = ImpulseResponse();
            self.impulse_response.is_ideal = true;
            self.excitation = Excitation();
            self.excitation.is_ideal = true;
            self.math_elements = [MathElement()];
        end      

        function fII_melem_rect_info = get.fII_melem_rect_info(self)
            n_rects = numel(self.math_elements);
            fII_melem_rect_info = zeros(n_rects, 19);
            for ri = 1:n_rects
                corners = self.math_elements(ri).corners;
                corners = corners';
                corners = corners(:)';
                
                row = [ ...
                    self.number, ...
                    corners, ...
                    self.math_elements(ri).apodization, ...
                    self.math_elements(ri).width, ...
                    self.math_elements(ri).height, ...
                    self.math_elements(ri).center ...
                ];
        
                fII_melem_rect_info(ri,:) = row;
            end
        end
        
        function fII_melem_tri_info = get.fII_melem_tri_info(self)
            n_rects = numel(self.math_elements);
            fII_melem_tri_info = zeros(n_rects, 19);
            for ri = 1:n_rects
                corners = self.math_elements(ri).corners;
                corners = corners';
                corners = corners(:)';
                
                row = [ ...
                    self.number, ...
                    corners, ...
                    self.math_elements(ri).apodization, ...
                    self.math_elements(ri).width, ...
                    self.math_elements(ri).height, ...
                    self.math_elements(ri).center ...
                ];
        
                fII_melem_rect_info(ri,:) = row;
            end
        end
        
        function fII_elem_waveform = get.fII_elem_waveform(self)
            fII_elem_waveform = conv(...
                self.impulse_response.signal, ...
                self.excitation.signal ...
            );
        end
        
        function fII_elem_apodization = get.fII_elem_apodization(self)
            fII_elem_apodization = self.apodization * self.enabled;
        end
        
        function fII_melem_apodization = get.fII_melem_apodization(self)
            fII_melem_apodization = cell2mat({self.math_elements.apodization}')';
        end
        
        function fII_elem_delay = get.fII_elem_delay(self)
            fII_elem_delay = self.delay;
        end
        
        function fII_melem_delay = get.fII_melem_delay(self)
            fII_melem_delay = cell2mat({self.math_elements.delay}')';
        end
        
        function plot_element(self, ha)
            if nargin == 1
                ha = axes();
                hold(ha, 'on');
            end
            n_melem = numel(self.math_elements);
            for ri = 1:n_melem
                self.math_elements(ri).plot(ha)
            end
        end
        
    end
end