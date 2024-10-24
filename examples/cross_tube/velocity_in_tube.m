function vel = velocity_in_tube(tube, pos)
    % Calculates the velocity of positions inside a tube
    % assumes all points are inside the tube
    % It uses the geometry's reference system [e1, e2, e3]
    % in which e3 is a unit vector pointing in the direction of the tube
    % and e1 and e2 form an orthonormal base with e3
    
    % Obtain the positions from the tube point of reference
    pos = tube.wpos2opos(pos);
    
    rad1 = tube.size(1)/2;
    rad2 = tube.size(2)/2;
    
    a = pos(:,1) / rad1; % fraction of radius in direction 1
    b = pos(:,2) / rad2; % fraction of radius in direction 2
    
    vel = (1 - a .* b); % magnitude follows a "parabolic" profile
    vel = vel .* tube.e3; % Add direction to velocity
end
