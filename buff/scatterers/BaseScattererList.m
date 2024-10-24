classdef BaseScattererList < handle
    properties(GetAccess = public, SetAccess = public)
        pos;
        scat;
    end
    
    properties (Dependent)
        count;
        type;
    end
    
    methods
        function self = BaseScattererList(pos, scat)
            if nargin>=2
                if size(scat, 1) == size(pos, 1) && size(scat, 2) == 1 && size(pos, 2) == 3
                    self.scat = scat;
                    self.pos = pos;
                else
                    error(strcat(class(self), ":SizeError"), ...
                            "Must supply same number of positions and scatterers.");
                end
            end            
        end
        
        function count = get.count(self)
            count = length(self.scat);
        end
        
        function set.count(self, ~)
            error(strcat(class(self), ":Error"), ...
                    "count can't be set.");
        end
        
        function type = get.type(self)
            type = class(self(1).scat(1));
        end
       
        function set.type(self, ~)
            error(strcat(class(self), ":Error"), ...
                    "type can't be set.");
        end
        
        function append(self, other)
            if isa(other, self.type)
                self.pos = [self.pos ; rand(numel(other), 3)];
                self.scat = [self.scat ; other(:)];
                warning("scatterers appended at random positions");
            elseif isa(other, 'BaseScattererList')
                if isa(other.scat, self.type)
                    self.pos = [self.pos ; other.pos];
                    self.scat = [self.scat ; other.scat];
                end
            else
                error(strcat(class(self), ":TypeError"),...
                        '%s is not a supported type for append', class(other));
            end
        end

        function new_self = plus(self, other)
            if isa(other, self.type)
                new_self = BaseScattererList( ...
                            [self.pos ; rand(numel(other), 3)], ...
                            [self.scat ; other(:)] ...
                );
                warning("scatterers appended at random positions");
            elseif isa(other, 'BaseScattererList')
                if isa(other.scat, self.type)
                    new_self = BaseScattererList( ...
                                    [self.pos ; other.pos],  ...        
                                    [self.scat ; other.scat] ...
                    );
                end
            else
                error(strcat(class(self), ":TypeError"),...
                        '%s is not a supported type for addition', class(other));
            end
        end
        
        function new_self = minus(self, other)
            if isa(other, 'BaseGeometry')
                i_out = other.is_outside(self.pos);
                new_self = BubbleScatterers( ...
                                self.pos(i_out,:), ...
                                self.scat(i_out) ...
                );
            else
                error(strcat(class(self), ":TypeError"),...
                        '%s is not a supported type for substraction', class(other));
            end
        end

        function new_self = mtimes(self, other)
            new_self = self.times(other);
        end

        function new_self = times(self, other)
            if isa(other, 'BaseGeometry')
                i_out = other.is_inside(self.pos);
                new_self = BubbleScatterers( ...
                                self.pos(i_out,:), ...
                                self.scat(i_out) ...
                );
            else
                error(strcat(class(self), ":TypeError"),...
                        '%s is not a supported type for product', class(other));
            end
        end
        
        function delete(self, ind)
            if numel(ind) == self.count
                self.pos = self.pos(~ind,:);
                self.scat = self.scat(~ind);
            end
        end
        
        function plot(varargin)
            if nargin == 1
                self = varargin{1};
                plot3(self.pos(:,1), self.pos(:,2), self.pos(:,3), 'o')
            elseif nargin == 2
                ax = varargin{2};
                self = varargin{1};
                plot3(ax, self.pos(:,1), self.pos(:,2), self.pos(:,3), 'o')
            elseif nargin > 2
                ax = varargin{2};
                self = varargin{1};
                plot3(ax, self.pos(:,1), self.pos(:,2), self.pos(:,3),varargin{3:end})
            end
            xlabel('X')
            ylabel('Y')
            zlabel('Z')
        end

    end
end