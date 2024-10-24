classdef LinearScatterers < BaseScattererList
    properties(GetAccess = public, SetAccess = public)
    end
    
    properties (Dependent)
        amp;
    end
    
    methods
        function self = LinearScatterers(pos, amp)
            if nargin >= 2
                if size(pos, 2) ~= 3
                    error("LinearScatterers:incorrectSize", "LinearScatterers: expected 3 columns for pos (x,y,z), got: %d", size(pos, 2));
                end
                if size(pos, 1) ~= size(amp, 1)
                    error("LinearScatterers:incorrectSize", "LinearScatterers: pos and amp should have the same number of rows");
                end
                self.pos = pos;
                self.amp = amp;
            end
        end
        
        function amp = get.amp(self)
            amp = self.scat;
        end

        function set.amp(self, new_amp)
            self.scat = new_amp;
        end

        function new_self = plus(self, other)
            if isa(other, 'double')
                new_self = LinearScatterers(self.pos, self.amp + other);
            elseif isa(other, 'LinearScatterers')
                [~, is, ~] = intersect(self.pos, other.pos, 'rows');
                [~, xs, xo] = setxor(self.pos, other.pos, 'rows');

                new_self = LinearScatterers( ...
                                cat(1, ...
                                    self.pos(xs, :), ...
                                    self.pos(is,: ), ...
                                    other.pos(xo, :) ...
                                ), ...
                                    cat(1, ...
                                    self.amp(xs), ...
                                    self.amp(is), ...
                                    other.amp(xo)...
                                )  ...
                );
            else
                error('LinearScatterers:TypeError',...
                        'LinearScatterers: %s is not a supported type for addition', class(other));
            end
        end
        
        function new_self = minus(self, other)
            if isa(other, 'double')
                new_self = LinearScatterers(self.pos, self.amp - other);
            elseif isa(other, 'BaseGeometry')
                i_out = other.is_outside(self.pos);
                new_self = LinearScatterers( ...
                                self.pos(i_out, :), ...
                                self.amp(i_out)...
                );
            elseif isa(other, 'LinearScatterers')
                [~, i_out, ~] = setxor(self.pos, other.pos, 'rows');
                new_self = LinearScatterers( ...
                                self.pos(i_out, :), ...
                                self.amp(i_out)...
                );
            else
                error('LinearScatterers:TypeError',...
                        'LinearScatterers: %s is not a supported type for substraction', class(other));
            end
        end
        
        function new_self = mtimes(self, other)
            new_self = self.times(other);
        end
        
        function new_self = times(self, other)
            if isa(other, 'double')
                new_self = LinearScatterers(self.pos, self.amp .* other);
            elseif isa(other, 'BaseGeometry')
                i_out = other.is_inside(self.pos);
                new_self = LinearScatterers( ...
                                self.pos(i_out, :), ...
                                self.amp(i_out)...
                );
            elseif isa(other, 'LinearScatterers')
                [~, is, io] = intersect(self.pos, other.pos, 'rows');
                new_self = LinearScatterers( ...
                                self.pos(is, :), ...
                                self.amp(is) .* other.amp(io)...
                );
            else
                error('LinearScatterers:TypeError',...
                        'LinearScatterers: %s is not a supported type for product', class(other));
            end
        end

        function new_self = mrdivide(self, other)
            new_self = self.rdivide(other);
        end
        
        function new_self = rdivide(self, other)
            if isa(other, 'double')
                new_self = LinearScatterers(self.pos, self.amp ./ other);
            elseif isa(other, 'BaseGeometry')
                warning("nothing done. no rdivide function for input BaseGeometry");
            elseif isa(other, 'LinearScatterers')
                [~, is, io] = intersect(self.pos, other.pos, 'rows');
                new_self = LinearScatterers( ...
                                self.pos(is, :), ...
                                self.amp(is) ./ other.amp(io)...
                );
            else
                error('LinearScatterers:TypeError',...
                        'LinearScatterers: %s is not a supported type for division', class(other));
            end
        end

%         function sref = subsref(self, s)
%             switch s(1).type
%                 case '.'
%                     sref = builtin('subsref', self, s);
%                 case '()'
%                     if length(s.subs) < 2 % obj at indices: lin_scat([1,2,3,5])
%                         sref = LinearScatterers( ...
%                             self.pos(s.subs{1}(:), :), ...
%                             self.amp(s.subs{1}(:)) ...
%                         );
%                     else % array of obj: lin_scat(1,2,3)
%                         sref = builtin('subsref', self, s);
%                     end
%                 case '{}'
%                     error( ...
%                         'LinearScatterers:subsref',...
%                         'Not a supported subscripted reference' ...
%                     );
%             end
%         end

        function self = subsasgn(self, s, val)
            if isempty(s) && isa(val,'LinearScatterers')
                self = LinearScatterers();
                self.pos = val.pos;
                self.amp = val.amp;
            end
           
            switch s(1).type
                case '.'
                    self = builtin('subsasgn', self, s, val);
                case '()'
                    if length(s) < 2
                        if isa(val,'double')
                            self.amp(s.subs{1}(:)) = val;
                        elseif isa(val,'LinearScatterers')
                            self.pos(s.subs{1}(:), :) = val.pos;
                            self.amp(s.subs{1}(:)) = val.amp;
                        else
                            error('LinearScatterers:subsasgn',...
                                    'LinearScatterers: Object must be scalar')
                        end
                    else % array of obj: lin_scat(1,2,3) = something
                        builtin('subsasgn', self, s, val);
                    end
                case '{}'
                    error('LinearScatterers:subsasgn',...
                        'LinearScatterers: Not a supported subscripted assignment')
            end
        end
    end
end