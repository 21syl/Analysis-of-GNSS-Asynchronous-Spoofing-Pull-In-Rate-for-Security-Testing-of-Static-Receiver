function fCWIgen(settings, jam, delay, delaycnt, power)
% FCWIGEN Generate GPS spoofing signals with configurable delays
%
%   FCWIGEN(SETTINGS, JAM, DELAY, DELAYCNT, POWER) generates GPS spoofing
%   signals with programmable code phase delays and power levels. The output
%   consists of complex baseband I/Q samples stored in separate files.
%
%   Input Parameters:
%       settings - Receiver configuration structure
%       jam      - Jammer configuration parameters
%       delay    - Code phase delay increment per millisecond [chips]
%       delaycnt - Number of milliseconds for dynamic delay application
%       power    - Spoofing signal power gain [dB]
%
%   Output:
%       Creates '_real.dat' and '_imag.dat' files containing I/Q samples

%% Initialize output files ================================================
fileName = 'CWI1_';  % Base output filename

% Create file handles for real/imaginary components
fidReal = zeros(1, settings.numberOfElements);
fidImag = zeros(1, settings.numberOfElements);

for nElements = 1:settings.numberOfElements
    realFile = fullfile(settings.directory, [fileName num2str(nElements) '_real.dat']);
    imagFile = fullfile(settings.directory, [fileName num2str(nElements) '_imag.dat']);
    
    fidReal(nElements) = fopen(realFile, 'w', 'ieee-be');
    if fidReal(nElements) < 0
        error('Cannot open real component file: %s', realFile);
    end
    
    fidImag(nElements) = fopen(imagFile, 'w', 'ieee-be');
    if fidImag(nElements) < 0
        fclose(fidReal(nElements));
        error('Cannot open imaginary component file: %s', imagFile);
    end
end

%% Signal generation parameters ==========================================
tc = 1/settings.codeFreqBasis;    % Chip duration [s]
resigDelay = 10e3 * (tc/977.5e-9); % Base resampling delay [s]
sigDelay = -4 * tc;               % Initial code phase delay [s]

%% Generate spoofing signal ==============================================
for loopCnt = 1:settings.msToProcess
    % Recurrent parameters (updated per ms)
    ts = 1/settings.samplingFreq;   % Sampling period [s]
    PRN = settings.PRN;              % Satellite PRN number
    codeLen = settings.codeLength;    % C/A code length (1023 chips)
    
    % Carrier parameters
    fi = settings.sigIfFreq;        % Intermediate frequency [Hz]
    fs = settings.samplingFreq;      % Sampling frequency [Hz]
    
    % Configure signal power
    noiseAmplitude = 3;              % Phase noise amplitude
    noise = (rand - 0.5) * noiseAmplitude; % Random phase noise
    effectiveCodeFreq = settings.codeFreqBasis + noise; % Noisy code frequency
    
    % Generate C/A code
    caCode = fB3CCodeGen(PRN);      % Generate PRN sequence
    
    % Calculate block size (1ms of samples)
    blksize = ceil(1e-3 * fs);      % Samples per millisecond
    
    % Initialize phase states
    remCarrPhase = 0;               % Residual carrier phase
    remCodePhase = 0;                % Residual code phase
    
    %% Apply dynamic delay ===============================================
    % Gradually increase delay during initial phase
    if loopCnt < delaycnt
        sigDelay = sigDelay + delay * tc; % Incremental delay
    end
    
    %% Generate carrier and code sequences ===============================
    % Carrier wave generation
    timeVector = (0:blksize-1) * ts; % Time vector for current block
    carrPhase = 2 * pi * fi * timeVector + remCarrPhase;
    ifCarr = exp(1i * carrPhase);    % Complex carrier wave
    remCarrPhase = mod(carrPhase(end) + 2*pi*fi*ts, 2*pi); % Update phase
    
    % Code sequence generation
    codePhaseStep = ts / tc;         % Code phase increment per sample
    codePhase = (0:blksize-1) * codePhaseStep + remCodePhase;
    codeIndex = mod(floor(codePhase), codeLen) + 1; % Circular indexing
    caCodeSampled = caCode(codeIndex); % Sampled C/A code sequence
    remCodePhase = mod(codePhase(end) + codePhaseStep, codeLen); % Update
    
    %% Apply frequency-domain delay ======================================
    Nfft = 1024;                    % FFT size
    numSegments = blksize / Nfft;   % Number of segments per block
    freqVector = linspace(-fs/2, fs/2, Nfft); % Frequency vector
    
    for segIdx = 1:numSegments
        % Extract current code segment
        startIdx = (segIdx-1)*Nfft + 1;
        endIdx = segIdx*Nfft;
        codeSegment = caCodeSampled(startIdx:endIdx);
        
        % Apply delay in frequency domain
        codeFFT = fft(codeSegment);
        delayPhase = exp(-1i * 2 * pi * freqVector * resigDelay);
        delayedCode = ifft(codeFFT .* delayPhase);
        
        % Modulate carrier and apply power scaling
        signalPower = db2real(power + settings.cnr + settings.noisePsd);
        ifSig = sqrt(2 * signalPower) * delayedCode .* ifCarr(startIdx:endIdx);
        
        % Write to output files
        for nElements = 1:settings.numberOfElements
            fwrite(fidReal(nElements), real(ifSig), settings.dataType);
            fwrite(fidImag(nElements), imag(ifSig), settings.dataType);
        end
    end
end

%% Cleanup ===============================================================
fclose(fidReal(1));
fclose(fidImag(1));
end