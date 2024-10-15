function [delay, chanel] = beamform_delays(transducer, focus_coords, ang_az, ang_el)   
    delay = zeros(size(focus_coords,1), transducer.rx_aperture.n_elements);
    
    ax_rot = roty(ang_az) * rotx(ang_el);
    tx_dist = focus_coords * ax_rot(3,:)';

    ang_delays = transducer.tx_aperture.calc_delays(ang_az);
    mean_delay = mean(ang_delays);
    
    for ii = 1:transducer.rx_aperture.n_elements
%     for ii = 1:size(focus_coords, 1)
        
        % Calculate distance from each element to each focus position
%         For Focus
%         rx_diff = transducer.rx_aperture.elem_centers - focus_coords(ii,:);

%         For Elements
        rx_diff = focus_coords * [0,0,1];

        rx_dist = vecnorm(rx_diff, 2, 2);
        
%         For Focus
%         dist = tx_dist(ii) + rx_dist;

%         For Elements
        dist = tx_dist + rx_dist;

        
        % transform distance to  in time
        delays = dist./transducer.c;
        
        % substract the mean delay of the transducer
        delays = delays + mean_delay;
        
%         For Focus
%         delay(ii,:) = delays;

%         For Elements
        delay(:, ii) = delays;
    end
    % Compensate pulse width
	delay = delay + max(transducer.tx_aperture.excitation.t)/2;
    delay = delay + transducer.tx_aperture.impulse_response.delay;
    delay = delay + transducer.rx_aperture.impulse_response.delay;

    % element domain indices
    chanel = repmat(1:transducer.tx_aperture.n_elements, [size(focus_coords,1), 1]);
end
