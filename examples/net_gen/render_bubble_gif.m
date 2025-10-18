function render_bubble_gif(net, gt, outPath, opts)
%RENDER_BUBBLE_GIF Create an animated GIF of bubble tracks over network.
%   render_bubble_gif(net, gt, outPath)
%   render_bubble_gif(net, gt, outPath, opts)
%
% Inputs
%   net.nodes [N x 3], net.edges [M x 2]
%   gt        [K x 5] = [frame id x y z]
%   outPath   output GIF path (default 'bubbles.gif')
%   opts fields (all optional):
%     .fps            (15) playback FPS (controls GIF delay)
%     .frame_range    ([minFrame maxFrame] or []) subset of frames
%     .marker_size    (6) bubble marker size
%     .color          ([1 0 0]) bubble color
%     .tail_frames    (0) show last T frames as faded tail
%     .tail_decay     (0.7) multiplicative brightness per tail step
%     .show_network   (true) draw vessel skeleton background
%     .network_color  ([0 0 1]) network line color
%     .network_lw     (0.5) line width
%     .invert_z       (true) ultrasound style (depth increasing downward)
%     .progress_every (50) print progress interval
%     .figure_visible ('off') figure visibility ('off'/'on')
%     .axis_padding_mm (0.5) extra margin around network extents
%     .sample_step    (1) use >1 to subsample frames (performance)
%     .show_eta       (true) print per-frame timing & ETA with progress
%
% Notes
%   - Projects to x-z plane currently (ignores y variations).
%   - For large datasets (>500 frames, >10k bubbles/frame) expect several seconds.
%   - Tail rendering duplicates scatter calls; keep tail_frames modest (<=10).
%
% Author: Visualization utility (2025)

if nargin < 4 || isempty(opts), opts = struct; end
outPath = arg(outPath,'bubbles.gif');
fps            = arg(opts,'fps',15);
frRange        = arg(opts,'frame_range',[]);
msz            = arg(opts,'marker_size',6);
col            = arg(opts,'color',[1 0 0]);
tailFrames     = max(0, round(arg(opts,'tail_frames',0)));
tailDecay      = arg(opts,'tail_decay',0.7);
showNet        = arg(opts,'show_network',true);
netCol         = arg(opts,'network_color',[0 0 1]);
netLW          = arg(opts,'network_lw',0.5);
invertZ        = arg(opts,'invert_z',true);
progEvery      = arg(opts,'progress_every',50);
figVisible     = arg(opts,'figure_visible','off');
pad_mm         = arg(opts,'axis_padding_mm',0.5);
sample_step    = max(1, round(arg(opts,'sample_step',1)));
showETA        = arg(opts,'show_eta',true);

if isempty(gt)
    warning('render_bubble_gif:EmptyGT','Ground truth is empty; nothing to render.');
    return;
end

frames = gt(:,1);
fMin = min(frames); fMax = max(frames);
if isempty(frRange)
    fStart = fMin; fEnd = fMax;
else
    fStart = max(fMin, frRange(1));
    fEnd   = min(fMax, frRange(2));
end
frameList = fStart:sample_step:fEnd;
numF = numel(frameList);

% Pre-split indices per frame for efficiency
idxCell = accumarray(frames - fMin + 1, (1:numel(frames))', [fMax-fMin+1 1], @(v){v}, {});

% Axes limits
X = net.nodes(:,1); Z = net.nodes(:,3);
minX = min(X); maxX = max(X); minZ = min(Z); maxZ = max(Z);
pad = pad_mm/1e3;
minX = minX - pad; maxX = maxX + pad; minZ = minZ - pad; maxZ = maxZ + pad;

% Figure
fh = figure('Name','Bubble Tracks GIF','Color','w','Visible',figVisible);
ax = axes('Parent',fh); hold(ax,'on'); axis(ax,'image');
if showNet && ~isempty(net.edges)
    for e=1:size(net.edges,1)
        i = net.edges(e,1); j = net.edges(e,2);
        p1 = net.nodes(i,[1 3]); p2 = net.nodes(j,[1 3]);
        plot(ax, p1(1)*1e3, p1(2)*1e3,'LineStyle','none'); % ensure axis scale before lines
        plot(ax,[p1(1) p2(1)]*1e3,[p1(2) p2(2)]*1e3,'-','Color',netCol,'LineWidth',netLW);
    end
end
xlim(ax,[minX maxX]*1e3); ylim(ax,[minZ maxZ]*1e3);
if invertZ, set(ax,'YDir','reverse'); end
xlabel(ax,'x [mm]'); ylabel(ax,'z [mm]');
title(ax,sprintf('Bubbles (frames %d-%d)', fStart, fEnd));

delay = 1/max(fps,1);

% For tails, maintain a FIFO of past frame scatter handles
tailBuffer = cell(0,1);

gifFirst = true;
ticGlobal = tic;  % global timer start
% lastPrintTime = tic; % Removed unused variable
timeHist = zeros(numF,1);
for idxF = 1:numF
    tFrameStart = tic;
    f = frameList(idxF);
    % Clear previous current frame scatter (tails persist via buffer)
    % Remove scatter handle for frame older than tailFrames
    if tailFrames == 0
        delete(findobj(ax,'Tag','currentBubbles'));
    end

    % Add current frame bubbles
    idxGlobalCell = idxCell{f - fMin + 1};
    if ~isempty(idxGlobalCell)
        rows = gt(idxGlobalCell, :);
        xb = rows(:,3); zb = rows(:,5);
        h = scatter(ax, xb*1e3, zb*1e3, msz, col, 'filled', 'Tag','currentBubbles');
        if tailFrames > 0
            tailBuffer{end+1} = h; %#ok<AGROW>
            % Apply fading to existing tails
            for tb = 1:numel(tailBuffer)
                age = numel(tailBuffer) - tb; % 0 newest
                if age > 0
                    fade = tailDecay^age;
                    hc = tailBuffer{tb};
                    if isvalid(hc)
                        hc.CData = col * fade;
                    end
                end
            end
            % Prune old beyond tailFrames
            while numel(tailBuffer) > tailFrames
                hdel = tailBuffer{1};
                if isvalid(hdel), delete(hdel); end
                tailBuffer(1) = [];
            end
        end
    end

    % Update title with progress
    if mod(idxF,10)==0 || idxF==1
        title(ax,sprintf('Bubbles frame %d / %d', f, fEnd));
    end

    drawnow limitrate;
    frame = getframe(fh);
    [A,map] = rgb2ind(frame2im(frame),256,'nodither');
    if gifFirst
        imwrite(A,map,outPath,'gif','LoopCount',inf,'DelayTime',delay);
        gifFirst = false;
    else
        imwrite(A,map,outPath,'gif','WriteMode','append','DelayTime',delay);
    end

    if progEvery>0 && (mod(idxF,progEvery)==0 || idxF==1 || idxF==numF)
        if showETA
            elapsed = toc(ticGlobal);
            meanPer = elapsed/idxF;
            remaining = meanPer*(numF-idxF);
            fprintf('[render_bubble_gif] Frame %d/%d (origFrame=%d) | elapsed %.2fs | mean %.3fs | ETA %.2fs\n', ...
                idxF, numF, f, elapsed, meanPer, remaining);
        else
            fprintf('[render_bubble_gif] Frame %d / %d written\n', idxF, numF);
        end
    end
    timeHist(idxF) = toc(tFrameStart);
end

if strcmpi(figVisible,'off')
    close(fh);
end
totalT = toc(ticGlobal);
if showETA
    valid = timeHist(timeHist>0); meanPer = mean(valid); medPer = median(valid);
    fprintf('[render_bubble_gif] GIF complete: %s (%d frames) | total %.2fs | mean %.3fs s/frame | median %.3fs s/frame\n', ...
        outPath, numF, totalT, meanPer, medPer);
else
    fprintf('[render_bubble_gif] GIF complete: %s (%d frames)\n', outPath, numF);
end

end

function v = arg(A, B, C)
% Flexible optional argument helper.
% Forms:
%   v = arg(value, default)                -> if value empty, use default
%   v = arg(struct, fieldName, default)    -> fetch struct.fieldName or default
if nargin == 2
    if ~isempty(A)
        v = A;
    else
        v = B;
    end
elseif nargin == 3
    S = A; f = B; d = C;
    if isstruct(S) && isfield(S,f) && ~isempty(S.(f))
        v = S.(f);
    else
        v = d;
    end
else
    error('arg:InvalidUsage','arg expects 2 or 3 inputs.');
end
end
