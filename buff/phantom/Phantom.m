classdef Phantom < handle & GlobalConfig
    properties(GetAccess = public, SetAccess = public)
        flow;
        lin_scat;
        lin_sources;
        lin_sinks;
        bub_scat;
        bub_sources;
        bub_sinks;
    end
    
    methods
        function self = Phantom()
        end
        
        function update(self, dt)
            %% Update positions
            if ~isempty(self.lin_scat)
                self.lin_scat.pos = self.flow.apply_to(self.lin_scat.pos, dt);
            end
            if ~isempty(self.bub_scat)
                self.bub_scat.pos = self.flow.apply_to(self.bub_scat.pos, dt);
            end
            
            %% Generate on sources
            if ~isempty(self.lin_sources)                
                self.lin_scat = self.lin_scat + self.lin_sources.step(dt);
            end
            if ~isempty(self.bub_sources)
                self.bub_scat = self.bub_scat + self.bub_sources.step(dt);
            end
            
            %% Delete on sinks
            if ~isempty(self.lin_sinks)
                self.lin_scat = self.lin_scat - self.lin_sinks;
            end
            if ~isempty(self.bub_sinks)
                self.bub_scat = self.bub_scat - self.bub_sinks;                
            end                        
        end
        
        function plot(self, ha)
            if nargin == 1
                ha = axes();
            end
            hold(ha, 'on');
            if ~isempty(self.lin_scat)
                plot3(ha, self.lin_scat.pos(:,1), self.lin_scat.pos(:,2), self.lin_scat.pos(:,3), '*b');
            end
            if ~isempty(self.bub_scat)
                plot3(ha, self.bub_scat.pos(:,1), self.bub_scat.pos(:,2), self.bub_scat.pos(:,3), 'or');
            end
            self.flow.plot(ha);
            self.flow.geometry.plot_skeleton(ha);
            self.bub_sources.geometry.plot_skeleton(ha);
            self.bub_sinks.plot_skeleton(ha);
        end
    end
end