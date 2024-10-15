classdef (Abstract) BaseBubble < GlobalConfig
    properties
    end
    properties (Dependent, GetAccess = public, SetAccess = protected)
        w0;
        f0;
    end
    methods
        function self = Bubble()
        end
        
        function f0 = get.f0(self)
            f0 = self.w0/2/pi;
        end
        
        function w0 = get.w0(self)
            w0 = self.w0_();
        end
    end
    methods (Abstract)
        [b_scat, b_R, t] = response(self, p_in);
        w0 = w0_();
    end
end
