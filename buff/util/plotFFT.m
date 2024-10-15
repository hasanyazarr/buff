function plotFFT(sig, fs)
    L = length(sig);   
    Y = fftshift(fft(sig));
    f = (-L/2:L/2-1)*(fs/L); % zero-centered frequency range
    
    subplot(2,1,1);
    mag_Y = 20*log10(abs(Y));
    plot(f/1e6, mag_Y-max(mag_Y));
    title('Amplitude Spectrum of sig(t)')
    xlabel('f (MHz)')
    ylabel('|SIG(f)|')
    grid on;
    
    subplot(2,1,2);
    plot(f/1e6, unwrap(angle(Y)));
    title('Phase Spectrum of sig(t)')
    xlabel('f (MHz)')
    ylabel('< SIG(f)')
    grid on;
end