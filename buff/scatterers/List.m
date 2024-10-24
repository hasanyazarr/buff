classdef List < handle
    properties(GetAccess = public, SetAccess = public)
        objs;
    end
    
    properties (Dependent)
        count;
        type;
    end
    
    methods
        function self = List(objs)
            if nargin >= 1
                self.objs = objs;
            end
        end
        
        function set.count(self, ~)
            error(strcat(class(self), ":Error"), ...
                    "count can't be set.");
        end

        function type = get.type(self)
            type = class(self(1).objs(1));
        end
       
        function set.type(self, ~)
            error(strcat(class(self), ":Error"), ...
                    "type can't be set.");
        end
        
        function append(self, other)
            if isa(other, self.type)
                self.objs = [self.objs ; other];
            elseif isa(other, 'List')
                if isa(other.objs, self.type)
                    self.objs = [self.objs ; other.objs];
                end
            else
                error(strcat(class(self), ":TypeError"),...
                        '%s is not a supported type for append', class(other));
            end
        end
        

       
        function new_self = plus(self, other)
            if isa(other, self.type)
                new_self = List([self.objs ; other]);
            elseif isa(other, 'List')
                if isa(other.objs, self.type)
                    new_self = List( ...
                        [self.objs ; other.objs] ...
                    );
                end
            else
                error(strcat(class(self), ":TypeError"),...
                        '%s is not a supported tipe for addition', class(other));
            end
        end

        function out = set_props(self, arr_ind, list_ind, prop, val)
            
            if isempty(arr_ind) || strcmp(arr_ind, ':')
                sz_arr = size(self);
            else
                sz_arr = size(arr_ind);
            end
            
            if isempty(list_ind) || strcmp(list_ind, ':')
                sz_lst = size(self(1).objs);
            else
                sz_lst = size(list_ind);
            end
            
            if isempty(prop_ind) || strcmp(prop_ind, ':')
                sz_prp = size(self(1).objs(1).(prop));
            else
                sz_prp = size(prop_ind);
            end
            
            % Remove singleton dimensions
            if prod(sz_arr) ==1
                sz_arr = 1;
            else
                sz_arr = sz_arr(sz_arr~=1);
            end
            
            if prod(sz_lst) ==1
                sz_lst = 1;
            else
                sz_lst = sz_lst(sz_lst~=1);
            end
            
            if prod(sz_prp) ==1
                sz_prp = 1;
            else
                sz_prp = sz_prp(sz_prp~=1);
            end
            
            out = cell([sz_arr, sz_lst, sz_prp]);
            
            for ai = 1:prod(sz_arr)
                for li = 1:prod(sz_lst)
                    for pi = 1:prod(sz_prp)
                        ind = sub2ind(size(out), ai, li, pi);
                        out{ind} = self(ai).objs(li).(prop);
                    end
                end
            end
            out = cell2mat(squeeze(out));
        end
        
        function out = get_props(self, arr_ind, list_ind, prop, prop_ind)
            if isempty(arr_ind) || strcmp(arr_ind, ':')
                out = cell(size(self));
                for ai = 1:numel(self)
                    out{ai} = self.get_props(ai, list_ind, prop, prop_ind);
                end
                return;
            elseif numel(arr_ind) > 1
                out = cell(size(arr_ind));
                for ai = 1:numel(arr_ind)
                    out{ai} = self.get_props(arr_ind(ai), list_ind, prop, prop_ind);
                end
                return;
            end
            
            if isempty(list_ind) || strcmp(list_ind, ':')
                n_list = self.count;
                out = cell(n_list, 1);
                for li = 1:n_list
                    out{li} = self.get_props(arr_ind, li, prop, prop_ind);
                end
                return;
            elseif numel(list_ind) > 1
                out = cell(size(list_ind));
                for li = 1:numel(list_ind)
                    out{li} = self.get_props(arr_ind, list_ind(li), prop, prop_ind);
                end
                return;
            end
            
            if isempty(prop)
                out = self(arr_ind).objs(list_ind);
                return;
            end
            
            if isempty(prop_ind) || strcmp(prop_ind, ':')
                out = self(arr_ind).objs(list_ind).(prop);
                return;
            elseif numel(prop_ind) > 1
                out = cell(size(prop_ind));
                for pi = 1:numel(prop_ind)
                    out{pi} = self.get_props(arr_ind, list_ind, prop, prop_ind(pi));
                end
                return;
            end

            out = self(arr_ind).objs(list_ind).(prop)(prop_ind);            
        end
    end
end