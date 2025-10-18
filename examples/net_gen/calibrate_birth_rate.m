function adj = calibrate_birth_rate(net, flow, fps, targetActivePerFrame, initMeanBirths, opts)
%CALIBRATE_BIRTH_RATE Estimate mean_births_per_frame to hit target active bubbles.
%   adj = calibrate_birth_rate(net, flow, fps, targetActivePerFrame, initMeanBirths)
%   Optional opts.trialFrames (default 80), opts.maxIter (default 3), opts.verbose (true)
%   Uses short trial simulations to scale the birth rate toward the desired
%   average number of simultaneously active bubbles per frame.
%
% Strategy: run small trial -> measure mean active count -> scale births by ratio.
% Repeats up to maxIter times, clamping to reasonable bounds.

if nargin < 6 || isempty(opts), opts = struct; end
trialFrames = getOpt(opts,'trialFrames',80);
maxIter     = getOpt(opts,'maxIter',3);
verbose     = getOpt(opts,'verbose',true);

adj = max(1, round(initMeanBirths));
targetActivePerFrame = max(1, targetActivePerFrame);

for it = 1:maxIter
    simOpts = struct('mean_births_per_frame', adj, 'seed', 1000+it);
    [~, diag] = generate_bubble_tracks(net, flow, trialFrames, fps, simOpts);
    if ~isfield(diag,'active_counts') || isempty(diag.active_counts)
        warning('calibrate_birth_rate:NoActiveCounts','Diagnostic lacked active_counts; aborting calibration.');
        return;
    end
    measured = mean(diag.active_counts);
    if measured <= 0
        measured = eps; % avoid /0
    end
    scale = targetActivePerFrame / measured;
    newAdj = max(1, round(adj * scale));
    if verbose
        fprintf('[calibrate_birth_rate] Iter %d: births=%d | measured=%.1f | target=%d | scale=%.3f -> new=%d\n', ...
            it, adj, measured, targetActivePerFrame, scale, newAdj);
    end
    % convergence check (within 5%)
    if abs(measured - targetActivePerFrame) / targetActivePerFrame < 0.05
        adj = newAdj; break; end
    % update for next iter (limit explosive changes)
    adj = max(1, min(round(newAdj), 10*initMeanBirths));
end

end

function v = getOpt(S,f,d)
if isfield(S,f) && ~isempty(S.(f)), v = S.(f); else, v = d; end
end
