classdef MultiGeometry < BaseGeometry
    
    properties (SetAccess = public)
        geometries = {};
    end
    
    properties (Dependent)
        area;
        volume;
    end
    
    %% TODO:
    %       When we set center, size and rotation for a multigeometry,
    %       It should modify it's sub-geometries, but in Matlab modifying  
    %       setters and getters in a subclass are not possible!
    methods 
        function self = MultiGeometry(varargin)
            if nargin > 0
                for ii = 1:nargin
                    if isa(varargin{ii}, 'BaseGeometry')
                        for kk = 1:numel(varargin{ii})
                            self.geometries{end+1} = varargin{ii}(kk);
                        end
                    else
                        warning('MultiGeometry:incorrectType', ...
                            'Inputs must be of a class derived from BaseGeometry, not a %s', class(varargin{ii}));
                    end
                end
            end
        end
        
        function area = get.area(self)
            area = 0;
            if ~isempty(self.geometries)
                for g = self.geometries
                    area = area + g{1}.area;
                end
            end
        end
        
        function set.area(self, new_area)
            factor = new_area / self.area;
            if ~isempty(self.geometries)
                for g = self.geometries
                    g{1}.area = g{1}.area.*factor;
                end
            end
        end
        
        function volume = get.volume(self)
            volume = 0;
            if ~isempty(self.geometries)
                for g = self.geometries
                    volume = volume + g{1}.volume;
                end
            end
        end
        
        function set.volume(self, new_volume)
            factor = new_volume / self.volume;
            if ~isempty(self.geometries)
                for g = self.geometries
                    g{1}.volume = g{1}.volume.*factor;
                end
            end
        end
        
        function out = is_inside(self, pos)
            out = 0 .* pos;
            if ~isempty(self.geometries)
                for g = self.geometries
                    out = out | g{1}.is_inside(pos);
                end
            end
            
        end
        
        function points = ordered_surface_points(self, npoints)
            points = [];
            if ~isempty(self.geometries)
                for g = self.geometries
                    points = [points ; g{1}.ordered_surface_points(npoints)];
                end
            end
        end
        
        function points = ordered_volume_points(self, npoints)
            points = [];
            if ~isempty(self.geometries)
                for g = self.geometries
                    points = [points ; g{1}.ordered_volume_points(npoints)];
                end
            end
        end
        
        function points = random_surface_points(self, npoints)
            points = [];
            if ~isempty(self.geometries)
                for g = self.geometries
                    points = [points ; g{1}.random_surface_points(npoints)];
                end
            end
        end
        
        function points = random_volume_points(self, npoints)
            points = [];
            if ~isempty(self.geometries)
                for g = self.geometries
                    points = [points ; g{1}.random_volume_points(npoints)];
                end
            end
        end
        
        function plot(self, ha)
            if nargin == 1
                ha = axes();
            end
            if ~isempty(self.geometries)
                for g = self.geometries
                    plot(g{1}, ha);
                end
            end
        end
        
        function plot_skeleton(self, ha)
            if nargin == 1
                ha = axes();
            end
            % TODO: implement
        end

        function out = eq(self, other)
            out = false;
            
            if eq@BaseGeometry(self, other)
                
                if isempty(self.geometries) && isempty(other.geometries)
                    out = true;
                else
                    if length(self.geometries) == length(other.geometries)
                        s_g = zeros(length(self.geometries), 1);
                        o_g = zeros(length(other.geometries), 1);
                        
                        for ii = 1:length(self.geometries)
                            for jj = 1:length(other.geometries)
                                if o_g(jj) == 0
                                    if self.geometries{ii} == other.geometries{jj}
                                        s_g(ii) = 1;
                                        o_g(jj) = 1;
                                    end
                                end
                            end
                        end
                        
                        if sum(s_g) == length(self.geometries) ...
                                && sum(o_g) == length(other.geometries)
                            out = true;
                        end
                    end
                end
            end
        end
    end
end