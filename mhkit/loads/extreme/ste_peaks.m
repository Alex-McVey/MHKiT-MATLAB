classdef ste_peaks
    % Estimate the short-term extreme distribution from the peaks
    % distribution.
    % 
    % Parameters
    % ----------
    % peaks_distribution: peaks_distribution class object
    %     Probability distribution of the peaks.
    % npeaks : float
    %     Number of peaks in short term period.
    % 
    % Returns
    % -------
    % ste: 
    %     Short-term extreme distribution.
    % 
    properties
        peaks_obj
        npeaks
    end
    
    methods
        function obj = ste_peaks(peaks_distribution, npeaks)
            %STE_PEAKS Construct an instance of this class
            
            assert(isa(peaks_distribution,'peaks_distribution'), ...
                ['Individual Constructor Error:  peaks_distribution ' ...
                'object is of class %s, not a peaks_distribution ' ...
                'object.'], class(peaks_distribution));
            obj.peaks_obj = peaks_distribution;
            obj.npeaks = npeaks;
        end
        
        function out = ppf(obj,q)
            % Percent point function (inverse of cdf) at q of the given 
            % RV.
            % 
            % Parameters
            % ----------
            % q : array_like
            %     lower tail probability
            % 
            % Returns
            % -------
            % out : array_like
            %     quantile corresponding to the lower tail probability q.
            
            args = [];
            loc = 0;
            scale = 1;
            
            cond0 = scale > 0;
            cond1 = (0 < q) & (q < 1);
            cond = cond0 & cond1;

            if any(cond)                
                factor = 10;
                left = -10;
                right = inf;
                while (obj.cdf(left) - q) > 0
                    right = left;
                    left = left*factor;                    
                end

                if isinf(right)
                    right = max(factor, left);
                    while (obj.cdf(right) - q) < 0
                        left = right;
                        right = right * factor;
                    end
                end

                [out, ierr] = brentq(obj, left, right, q);   
                if ierr < 0
                    ME = MException('MATLAB:extreme:ste_peaks:ppf', ...
                        "Brent's method was not properly bracketed");
                    throw(ME);
                end
            end

            if isempty(out)
                out = [];
            end
        end

        function out =  pdf(obj, x)
            % Probability density function at x of the given RV.
            % 
            % Parameters
            % ----------
            % x : array_like
            %     quantiles
            % 
            % Returns
            % -------
            % pdf : array
            %     Probability density function evaluated at x
            args = [];
            loc = 0;
            scale = 1;            

            x = (x-loc)/scale;
            cond0 = scale > 0;
            cond1 = -inf <= x & x <= inf & scale > 0;
            cond = cond0 & cond1;
            out = zeros(size(cond));

            if any(cond)
                goodargs = x(cond);                
                % Find the nth derivative of a function at a point.
                % Given a function, use a central difference formula 
                % with spacing dx to compute the nth derivative at x0.
                order = 5;
                dx = 1e-5;
                weights = [1,-8,0,8,-1]/12.0;
                val = 0;
                ho = bitshift(order,-1);
                for k = 1:order
                    val = val + weights(k)*obj.cdf(x+(k-ho)*dx);
                end
                out = val./dx; 
            end              
        end

        function out = cdf(obj, x)
            % Cumulative distribution function of the given RV.
            % 
            % Parameters
            % ----------
            % x : array_like
            %     quantiles
            %
            % Returns
            %    -------
            % cdf : ndarray
            %       Cumulative distribution function evaluated at x
            
            peaks_cdf = obj.peaks_obj.cdf(x);
            peaks_cdf(isnan(peaks_cdf)) = 0.0;
            out = peaks_cdf.^obj.npeaks;
        end

        function out = expect(obj)
            % Calculate expected value of a function with respect to the 
            % distribution for discrete distribution by numerical summation

            % The expected value of a function ``f(x)`` with respect to a
            % distribution ``dist`` is defined as::
            % 
            %             ub
            %     E[f(x)] = Integral(f(x) * dist.pdf(x)),
            %             lb
            % 
            % where ub and lb are arguments and x has the dist.pdf(x)
            % distribution. If the bounds lb and ub correspond to the
            % support of the distribution, e.g. [-inf, inf] in the default
            % case, then the integral is the unrestricted expectation of 
            % f(x). Also, the function f(x) may be defined such that f(x) 
            % is 0 outside a finite interval in which case the expectation 
            % is  calculated within the finite range [lb, ub].

            loc = 0;
            scale = 1;
            
            % in MHKiT python this interval is -inf -> inf. This causes a
            % warning on the python side that it is divergent or slowly
            % convergent but in Matlab it is divergent and wont return a 
            % value thus we are forced to utilize the interval of -100->100
            if strcmp(obj.peaks_obj.method,'pot')
                a = -10;
                b = 10;
            else
                a = -100;
                b = 100;
            end
            lb = loc + a * scale;
            ub = loc + b * scale;

            out = obj.quad(lb,ub);
        end   

        function out = quad(obj, a, b)
            % Compute a definite integral.
            % 
            % Integrate func from `a` to `b` (possibly infinite interval) 
            % using a technique from the Fortran library QUADPACK.
            
            % check the limits of integration: \int_a^b, expect a < b
            flip = b < a;
            a = min(a, b);
            b = max(a, b);

            if (a==Inf && b==Inf) || (a==-Inf && b==-Inf)
                ME = MException('MATLAB:extreme:ste_block_maxima:quad', ...
                    "Infinity comparisons don't work with this method.");
                throw(ME);
            end
            
            fun = @(x) x .*obj.pdf(x);
            out = integral(fun,a,b);

            if flip
                out = -out;
            end            
        end

        function [out, ierr] = brentq(obj, a, b, args)
            % Find a root of a function in a bracketing interval using 
            % Brent's method.
            %
            % Uses the classic Brent's method to find a zero of the 
            % function f on the sign changing interval [a , b]. 
            % Generally considered the best of the rootfinding routines 
            % here. It is a safe version of the secant method that
            % uses inverse quadratic extrapolation. Brent's method 
            % combines root bracketing, interval bisection, and inverse 
            % quadratic interpolation. It is sometimes known as the 
            % van Wijngaarden-Dekker-Brent method. Brent (1973)
            % claims convergence is guaranteed for functions computable
            % within [a,b].
            % 
            % Notes
            % -----
            % f must be continuous. f(a) and f(b) must have opposite signs.
            %
            % Source:
            %   https://mathworld.wolfram.com/BrentsMethod.html
            % or
            % http://phys.uri.edu/nigh/NumRec/bookfpdf/f9-3.pdf for the
            % numerical recipes source

            maxiter = 100;
            xtol = 1e-12;
            ierr = 0;
            f = @(x) obj.cdf(x)-args;

            if f(a)*f(b) >= 0
                % Problem is not correctly bracketed 
                ierr = -1;
                return
            end

            %Swapping a and b Contents
            if abs(f(a)) < abs(f(b))
                L=a; a=b; b=L;
            end
            c = a;  
            flag = true;
            iter = 0;

            while abs(b-a) > xtol
                if f(a)~=f(c) && f(b)~=f(c)
                    %Inverse Quadratic Interpolation
                    s = (a*f(b)*f(c))/((f(a)-f(b))*(f(a)-f(c))) + ...
                        (b*f(a)*f(c))/((f(b)-f(a))*(f(b)-f(c))) + ...
                        (c*f(a)*f(b))/((f(c)-f(a))*(f(c)-f(b)));                    
                else
                    s = b-f(b)*(b-a)/(f(b)-f(a));  %Secant method
                end

                if ~((3*a + b)/4 < s && s < b)          ||...
                    (flag && abs(s-b) >= abs(b-c)/2)    ||...
                    (~flag && abs(s-b) >= abs(c-d)/2)   ||...
                    (flag && abs(b-c) < xtol)           ||...
                    (~flag && abs(c-d) < xtol)
                    % Bisection method
                    s = (a+b)/2;
                    flag = true;
                else
                    flag = false;
                end

                % calculate f(s)
                d = c; c = b;
                if f(a)*f(s) < 0
                    b = s;
                else
                    a = s;
                end

                if abs(f(a)) < abs(f(b))
                    L=a; a=b; b=L;
                end

                % break for max iterations
                iter = iter + 1;
                if iter > maxiter
                    break
                end
            end 
            out = s;
        end

    end
end

