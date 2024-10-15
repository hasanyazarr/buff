classdef (Abstract) UniqueIDSequential < handle
    properties
        uid
    end
    methods
        function self = UniqueIDSequential()
        	self.uid = UniqueIDSequential.count();
        end
	end
	methods(Static, Hidden, Access=private)
        function c = count()
            persistent cc;
            if isempty(cc)
                cc = 0;
            end
            cc = cc +1;
            c = cc;
        end
    end
end