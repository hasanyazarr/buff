function net = generate_vessel_network(PxSet, opts)
%GENERATE_VESSEL_NETWORK ULTRA-SR HF aligned vascular network generator (3D).
%   Builds a 3D branching tree with:
%     - Fixed segment length (default 1 mm) for all edges (true 3D length)
%     - Depth / level dependent bifurcation probabilities
%     - Angle constraints:
%         XZ plane : +/-30 deg from axial (z) direction
%         YZ plane : 0 deg (single) and small symmetric tilt for bifurcations (default +/-3 deg)
%     - Simple stochastic radius decay per segment
%   Output fields: nodes [N x 3], edges [M x 2], radii [M x 1], lengths [M x 1],
%                  root_idx, opts (resolved parameters)
%
% Backward compatibility: accepts legacy 2.5D option names
%   single_angle_range_deg -> single_angle_xz_range_deg (if new absent)
%   split_angle_range_deg  -> split_angle_xz_range_deg (if new absent)
%   y_sigma_m retained (adds Gaussian jitter in y per segment)
%

if nargin < 2 || isempty(opts); opts = struct; end
if nargin < 1 || ~isstruct(PxSet) || ~all(isfield(PxSet,{'mapX','mapZ'}))
	error('generate_vessel_network:InvalidInput','PxSet with mapX/mapZ required.');
end

% ---- backward compatibility remapping ----
if ~isfield(opts,'single_angle_xz_range_deg') && isfield(opts,'single_angle_range_deg')
	opts.single_angle_xz_range_deg = opts.single_angle_range_deg;
end
if ~isfield(opts,'split_angle_xz_range_deg') && isfield(opts,'split_angle_range_deg')
	opts.split_angle_xz_range_deg = opts.split_angle_range_deg;
end

	function val = getOpt(name, defaultVal)
		if isfield(opts,name) && ~isempty(opts.(name))
			val = opts.(name);
		else
			val = defaultVal;
		end
	end

% ---------------- Parameters ----------------------
seed        = getOpt('seed',123);
n_roots     = max(1,round(getOpt('n_roots',3))); 
r_root      = getOpt('root_radius_m',140e-6);
r_min       = getOpt('min_radius_m',12e-6);
rdec_mu     = getOpt('r_decay_mean',0.82);
rdec_sd     = getOpt('r_decay_std',0.05);
p_levels    = getOpt('p_bifurcate_levels',[0.05 0.15 0.20 0.30 0.40]);
L_fixed     = getOpt('seg_len_m',1e-3);

ang_rng_xz_deg   = getOpt('single_angle_xz_range_deg',[-30 30]);
yz_single_deg    = getOpt('single_angle_yz_deg',0);
yz_split_range   = getOpt('split_angle_yz_range_deg',[-3 3]);
split_rng_xz_deg = getOpt('split_angle_xz_range_deg',[-30 30]);

max_depth   = round(getOpt('max_depth',22));
max_segs    = round(getOpt('max_segments',4000));
z_margin    = getOpt('z_margin_m',0.25e-3);
elev_half_width_m = getOpt('elev_half_width_m',0.75e-3);
y_sigma     = getOpt('y_sigma_m',0); % legacy small jitter per segment
doPlot      = logical(getOpt('plot',true));

deg2rad = @(d) d*pi/180;
ang_min_xz = deg2rad(ang_rng_xz_deg(1));
ang_max_xz = deg2rad(ang_rng_xz_deg(2));
split_abs_max_xz = deg2rad(max(abs(split_rng_xz_deg)));

rng(seed);

% Field-of-view bounds (XZ define imaging plane)
xMin = min(PxSet.mapX); xMax = max(PxSet.mapX);
zMin = min(PxSet.mapZ); zMax = max(PxSet.mapZ);

% Preallocate
nodes = zeros(2048,3,'single'); nN = 0;
edges = zeros(4096,2,'uint32'); nE = 0;
radii = zeros(4096,1,'single');

	function idx = add_node(x,y,z)
		if nN >= size(nodes,1)
			nodes = [nodes; zeros(size(nodes,1),3,'single')]; %#ok<AGROW>
		end
		nN = nN + 1;
		nodes(nN,:) = single([x,y,z]);
		idx = uint32(nN);
	end

	function add_edge(i,j,r)
		if nE >= size(edges,1)
			edges = [edges; zeros(size(edges,1),2,'uint32')]; %#ok<AGROW>
			radii = [radii; zeros(size(radii,1),1,'single')]; %#ok<AGROW>
		end
		nE = nE + 1;
		edges(nE,:) = uint32([i,j]);
		radii(nE)   = single(r);
	end

	function tf = inside_xz(x,z)
		tf = (x >= xMin) && (x <= xMax) && (z >= zMin) && (z <= zMax);
	end

	function r2 = decay(r1)
		r2 = r1 * (rdec_mu + rdec_sd*randn());
		r2 = max(min(r2, r1*0.95), r1*0.5);
	end

	function pb = bif_prob(depth)
		if depth <= numel(p_levels)
			pb = p_levels(depth);
		else
			extra = depth - numel(p_levels);
			pb = p_levels(end) * 0.5^extra;
		end
		pb = max(0,min(0.95,pb));
	end

	function th = clamp_xz(th)
		th = min(max(th, ang_min_xz), ang_max_xz);
	end

	% 3D recursive grow: theta_xz (about y-axis), theta_yz (about x-axis)
	function grow(parent_idx, theta_xz, theta_yz, r, depth)
		if depth > max_depth || r < r_min || nE >= max_segs
			return; end

		x0 = nodes(parent_idx,1); y0 = nodes(parent_idx,2); z0 = nodes(parent_idx,3);

		% Direction with fixed 3D segment length:
		% Base XZ direction (unit): dx0 = sin(theta_xz), dz0 = cos(theta_xz)
		% Elevational tilt: apply cos(theta_yz) shrink in XZ plane, dy = sin(theta_yz)
		c_yz = cos(theta_yz); s_yz = sin(theta_yz);
		dx = c_yz * sin(theta_xz);
		dz = c_yz * cos(theta_xz);
		dy = s_yz;
		% (dx,dy,dz) now unit-length (within numerical error).

		x1 = x0 + L_fixed * dx;
		y1 = y0 + L_fixed * dy + y_sigma*randn(); % optional jitter
		z1 = z0 + L_fixed * dz;

		if ~inside_xz(x1,z1); return; end
		if abs(y1) > elev_half_width_m
			y1 = sign(y1) * elev_half_width_m; % soft clamp
		end

		child_idx = add_node(x1,y1,z1);
		add_edge(parent_idx, child_idx, r);

		r_next = decay(r);
		if r_next < r_min; return; end

		pb = bif_prob(depth);
		if rand() < pb
			% Bifurcate symmetrically (XZ & YZ)
			mag_xz = split_abs_max_xz * (0.3 + 0.7*rand());
			dth_xz = mag_xz;
			ymin = yz_split_range(1); ymax = yz_split_range(2);
			if ymin > ymax; tmp = ymin; ymin = ymax; ymax = tmp; end
			dth_yz = deg2rad( ymin + (ymax - ymin) * rand() );

			left_xz  = clamp_xz(theta_xz + dth_xz);
			right_xz = clamp_xz(theta_xz - dth_xz);
			left_yz  =  dth_yz;
			right_yz = -dth_yz;
			grow(child_idx, left_xz,  left_yz,  r_next, depth+1);
			grow(child_idx, right_xz, right_yz, r_next, depth+1);
		else
			jitter_xz = deg2rad(5)*randn();
			theta_xz2 = clamp_xz(theta_xz + jitter_xz);
			theta_yz2 = deg2rad(yz_single_deg); % enforce desired single-segment tilt (default 0)
			grow(child_idx, theta_xz2, theta_yz2, r_next, depth+1);
		end
	end

% --------------------------- Root initialization -------------------------
roots_x = linspace(xMin+0.15*(xMax-xMin), xMax-0.15*(xMax-xMin), n_roots);
roots_x = roots_x + 0.15*(xMax-xMin)/max(1,n_roots) * (rand(1,n_roots)-0.5);
root_z  = zMin + z_margin;
root_idx = zeros(1,n_roots,'uint32');
for k=1:n_roots
	root_idx(k) = add_node(roots_x(k), 0, root_z); % start centered in y
end

theta0s_xz = ang_min_xz + (ang_max_xz-ang_min_xz) * rand(1,n_roots);
theta0s_yz = zeros(1,n_roots) + deg2rad(yz_single_deg);
for k=1:n_roots
	grow(root_idx(k), theta0s_xz(k), theta0s_yz(k), r_root, 1);
end

% -------------------------- Finalize & outputs ---------------------------
nodes = nodes(1:nN,:);
edges = edges(1:nE,:);
radii = radii(1:nE);
if ~isempty(edges)
	vec = nodes(edges(:,2),:) - nodes(edges(:,1),:);
	lengths = sqrt(sum(vec.^2,2));
else
	lengths = single([]);
end

net.nodes    = nodes;
net.edges    = edges;
net.radii    = radii;
net.lengths  = lengths;
net.root_idx = root_idx;
net.opts = struct( ...
	'seed',seed,'n_roots',n_roots,'root_radius_m',r_root,'min_radius_m',r_min, ...
	'r_decay_mean',rdec_mu,'r_decay_std',rdec_sd,'p_bifurcate_levels',p_levels, ...
	'seg_len_m',L_fixed, ...
	'single_angle_xz_range_deg',ang_rng_xz_deg, ...
	'single_angle_yz_deg',yz_single_deg, ...
	'split_angle_xz_range_deg',split_rng_xz_deg, ...
	'split_angle_yz_range_deg',yz_split_range, ...
	'max_depth',max_depth,'max_segments',max_segs,'z_margin_m',z_margin, ...
	'elev_half_width_m',elev_half_width_m,'y_sigma_m',y_sigma,'plot',logical(doPlot));

% ------------------------------ Visualization ----------------------------
if doPlot
	figure('Name','ULTRA-SR HF Vasculature (3D->XZ projection)','Color','w'); hold on; axis image;
	for e=1:size(edges,1)
		i = edges(e,1); j = edges(e,2);
		p1 = nodes(i,[1 3]); p2 = nodes(j,[1 3]); % XZ projection
		lw = max(0.4, 5 * (radii(e)/r_root));
		plot([p1(1) p2(1)]*1e3, [p1(2) p2(2)]*1e3,'b-','LineWidth',lw);
	end
	plot(nodes(root_idx,1)*1e3, nodes(root_idx,3)*1e3,'go','MarkerSize',5,'LineWidth',1.1);
	set(gca,'YDir','reverse'); xlabel('Lateral x [mm]'); ylabel('Axial z [mm]');
	title(sprintf('Vasculature 3D (segments=%d) | XZ projection', size(edges,1)));
	xlim([xMin xMax]*1e3); ylim([zMin zMax]*1e3); box off;
end
end