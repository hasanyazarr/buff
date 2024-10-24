classdef ArbitraryGenerator < BaseRandomGenerator
    properties
        values = 0;
        pdf = 0;
    end
        
    methods
        function self = ArbitraryGenerator(values, pdf)
            self.values = values;
            self.pdf = pdf;
        end
    end
    
    methods (Hidden)        
        %% TODO: 
        %        create set/get for x and pdf and add cdf property so it is
        %        not calculated every time draw is calling
        function nums = draw_(self, count)
        % Generate random numbers with arbitrary probability density function
        % using Inverse transform sampling
        % Inputs:
        %     count - size of the output
        %     x     - pdf values
        %     pdf   - pdf densities at each value
        %
        % Outputs:
        %     out   - array of size: count, filled with random values drawn 
        %             from input pdf distribution

            % Upsample pdf
            x_hd = interp1(1:length(self.values), self.values, linspace(1, length(self.values), 100), 'linear');
            pdf_hd = interp1(self.values, self.pdf, x_hd, 'linear');

            % Normalize pdf (area of 1)
            pdf_hd = pdf_hd./sum(pdf_hd(1:end-1) .* diff(x_hd));

            % Calculate Cumulative distribution function
            cdf = cumsum(pdf_hd(1:end-1) .* diff(x_hd));
            cdf = [0, cdf];

            % clip
            cdf = round(cdf, 5);
            [~, u_ind] = unique(cdf);

            x_hd = x_hd(u_ind);
            cdf  = cdf(u_ind);

            % draw from uniform distribution. u = UNIF(0,1)
            u = rand(count);

            % apply the inverse cdf. out = inv_cdf(u)
            nums = interp1(cdf, x_hd, u);
        end
        
        function out = eq(self, other)
            out = false;
            if isa(other, 'ArbitraryGenerator') ...
               && other.values == self.values ...
               && other.pdf == self.pdf
               out = true;
            end
        end
    end
end

