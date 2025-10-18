function hw = fieldii_setup(SimSet)
%FIELDII_SETUP  Create Field II TX/RX apertures and HF waveforms (robust).
%   hw = fieldii_setup(SimSet)
%   hw = fieldii_setup() uses default values if SimSet omitted.
%   Attempts to auto-add third_party/FieldII; provides fallbacks for
%   gauspuls / tukeywin / hann if missing. Returns reproducible waveform data.
%
% hw fields (key):
%   tx, rx              Field II aperture handles
%   fc_Hz, fs_Hz        center & sampling frequency
%   nelem, pitch, kerf, width, height, sub_x, sub_y geometry
%   excitation_t, excitation, impulse_t, impulse
%   apodization         element apodization vector
%   cleanup()           function handle to call field_end
%   meta.*              metadata (tx_scale, assumed_MI, tool_fallbacks)

if nargin < 1 || isempty(SimSet)
    SimSet.fc_Hz = 7.24e6;
    SimSet.fs_Hz = 80e6;
end

% Helper for options
function v = getOpt(S,f,def)
    if isfield(S,f) && ~isempty(S.(f)), v = S.(f); else, v = def; end
end

req = {'fc_Hz','fs_Hz'}; assert(all(isfield(SimSet,req)), 'SimSet needs fc_Hz & fs_Hz');

persistent fieldii_initialized fieldii_root_cached 
if isempty(fieldii_initialized)
    if exist('field_init','file') ~= 2
        here = fileparts(mfilename('fullpath'));
        cand_root = fullfile(here,'..','..','third_party','FieldII');
        cand_m = fullfile(cand_root,'m_files');
        if exist(cand_m,'dir'), addpath(genpath(cand_m)); end
        if exist(cand_root,'dir'), addpath(genpath(cand_root)); end
        if exist('field_init','file') == 2
            fieldii_root_cached = cand_root; %#ok<NASGU>
        end
    end
    fieldii_initialized = true;
end

if exist('field_init','file') ~= 2
    error('fieldii_setup:FieldIIMissing','Field II functions not found (field_init.m). Add FieldII to path.');
end

% ---------------- Acoustic & array parameters ----------------
c_sound = getOpt(SimSet,'c_sound_mps',1540);
field_init(0);               % quiet
set_field('c',  c_sound);
% Prefer explicit set_sampling (avoids Field II warning about pulses & fs)
if exist('set_sampling','file')==2
    set_sampling(SimSet.fs_Hz);
else
    set_field('fs', SimSet.fs_Hz);
end
set_field('use_rectangles', 1);

hw.nelem  = getOpt(SimSet,'nelem',128);
hw.pitch  = getOpt(SimSet,'pitch_m',0.3e-3);
hw.kerf   = getOpt(SimSet,'kerf_m', 0.03e-3);
hw.width  = hw.pitch - hw.kerf; assert(hw.width>0,'fieldii_setup:BadWidth','Computed element width <= 0');
hw.height = getOpt(SimSet,'height_m',5.0e-3);
hw.sub_x  = getOpt(SimSet,'sub_div_x',1);
hw.sub_y  = getOpt(SimSet,'sub_div_y',15);

% Allow optional element selection mask (for sparse aperture studies)
elem_mask = getOpt(SimSet,'element_mask',true(1,hw.nelem));
if numel(elem_mask) ~= hw.nelem
    warning('fieldii_setup:MaskSize','element_mask length mismatch; ignoring.'); elem_mask = true(1,hw.nelem); end

% ---------------- Aperture creation ----------------
hw.tx = xdc_linear_array(hw.nelem, hw.width, hw.height, hw.kerf, hw.sub_x, hw.sub_y, [0 0 0]);
hw.rx = xdc_linear_array(hw.nelem, hw.width, hw.height, hw.kerf, hw.sub_x, hw.sub_y, [0 0 0]);

% ---------------- Waveform design ----------------
fc = SimSet.fc_Hz; fs = SimSet.fs_Hz;
ncycles_exc = getOpt(SimSet,'excitation_cycles',2.5);
imp_cycles  = getOpt(SimSet,'impulse_cycles',3.0); % span for impulse approximation
frac_bw     = getOpt(SimSet,'impulse_frac_bw',0.6); % relative bandwidth for gauspuls

tc = 1/fc;
t_ir = (0:round(imp_cycles/fc*fs)) / fs;

% Impulse response (fallback if gauspuls missing)
if exist('gauspuls','file') == 2
    imp = gauspuls(t_ir - mean(t_ir), fc, frac_bw);
    imp_meta = 'gauspuls';
else
    % Approx Gaussian-modulated sinusoid fallback
    sigma = (imp_cycles/(2*fc));
    env = exp(-0.5*((t_ir - mean(t_ir))/sigma).^2);
    imp = env .* sin(2*pi*fc*(t_ir - mean(t_ir)));
    imp_meta = 'fallback_gaussian_sin';
end

exc_t = (0:round(ncycles_exc*tc*fs)) / fs;
exc_base = sin(2*pi*fc*exc_t);

% Window (prefer Tukey -> Hann -> Rect fallback)
if exist('tukeywin','file') == 2
    win_exc = tukeywin(numel(exc_t),0.25)'; win_meta='tukey';
elseif exist('hann','file') == 2
    win_exc = hann(numel(exc_t))'; win_meta='hann';
else
    win_exc = ones(1,numel(exc_t)); win_meta='rect';
end
exc = exc_base .* win_exc;

% MI scaling (document only; actual MI computation external)
tx_scale = getOpt(SimSet,'tx_scale', 50);
exc = tx_scale * exc;

% Assign to apertures
xdc_impulse(hw.tx, imp);  xdc_excitation(hw.tx, exc);
xdc_impulse(hw.rx, imp);

% ---------------- Apodization ----------------
% Prefer Tukey(0.25); fallback to Hanning/Hann or rectangular.
if exist('tukeywin','file') == 2
    apo = tukeywin(hw.nelem,0.25)'; apo_meta='tukey';
elseif exist('hanning','file') == 2
    apo = hanning(hw.nelem)'; apo_meta='hanning';
elseif exist('hann','file') == 2
    apo = hann(hw.nelem)'; apo_meta='hann';
else
    apo = ones(1,hw.nelem); apo_meta='rect';
end

% Apply element mask (zero-out deactivated elements)
apo(~elem_mask) = 0;
xdc_apodization(hw.tx, 0, apo);
xdc_apodization(hw.rx, 0, apo);

% ---------------- Populate output struct ----------------
hw.fc_Hz           = fc;
hw.fs_Hz           = fs;
hw.simset          = SimSet;
hw.excitation_t    = exc_t;
hw.excitation      = exc;
hw.impulse_t       = t_ir;
hw.impulse         = imp;
hw.apodization     = apo;
hw.meta.tx_scale   = tx_scale;
hw.meta.apo_method = apo_meta;
hw.meta.win_method = win_meta;
hw.meta.impulse_method = imp_meta;
hw.meta.tool_fallbacks = struct('gauspuls', exist('gauspuls','file')==2, ...
                                'tukeywin', exist('tukeywin','file')==2, ...
                                'hann', exist('hann','file')==2, ...
                                'hanning', exist('hanning','file')==2, ...
                                'set_sampling', exist('set_sampling','file')==2);
if exist('cand_root','var'); hw.fieldii_root = cand_root; end %#ok<NASGU>

% Cleanup handle (optional use by caller)
hw.cleanup = @() safe_field_end();

end

% ---------------- Helpers ----------------
function safe_field_end()
try
    if exist('field_end','file')==2, field_end(); end
catch ME
    warning(ME.identifier,'field_end failed: %s', ME.message);
end
end
