function fSigDataGen(settings)
% FSIGDATAGEN Generate ideal GPS C/A code signals for antenna array
%
%   FSIGDATAGEN(SETTINGS) generates clean GPS L1 signals with C/A code
%   modulation for multiple antenna elements, simulating ideal conditions
%   without noise or interference.
%
%   Input Parameters:
%       settings - Receiver configuration structure containing:
%           directory        : Output directory path
%           sigFileName       : Base output filename
%           numberOfElements : Number of antenna elements
%           samplingFreq     : Sampling frequency [Hz]
%           codeFreqBasis    : C/A code chipping rate [Hz]
%           PRN              : Satellite PRN number
%           sigCarrierFreq   : RF carrier frequency [Hz]
%           sigIfFreq       : Intermediate frequency [Hz]
%           cnr              : Carrier-to-noise ratio [dB-Hz]
%           noisePsd         : Noise power spectral density [dBm/Hz]
%
%   Output:
%       Creates '_real.dat' and '_imag.dat' files for each antenna element

%% Initialize file handles ==============================================
fileNameBase = settings.sigFileName; % Base output filename

% Preallocate file handle arrays
realHandles = zeros(1, settings.numberOfElements);
imagHandles = zeros(1, settings.numberOfElements);

for elementIdx = 1:settings.numberOfElements
    % Create real component file
    realFile = fullfile(settings.directory, ...
                       [fileNameBase num2str(elementIdx) '_real.dat']);
    realHandles(elementIdx) = fopen(realFile, 'w', 'ieee-be');
    if realHandles(elementIdx) < 0
        error('Failed to open real component file: %s', realFile);
    end
    
    % Create imaginary component file
    imagFile = fullfile(settings.directory, ...
                       [fileNameBase num2str(elementIdx) '_imag.dat']);
    imagHandles(elementIdx) = fopen(imagFile, 'w', 'ieee-be');
    if imagHandles(elementIdx) < 0
        fclose(realHandles(elementIdx));
        error('Failed to open imaginary component file: %s', imagFile);
    end
end

%% Signal generation parameters =========================================
fs = settings.samplingFreq;        % Sampling frequency [Hz]
ts = 1 / fs;                        % Sampling period [s]
tc = 1 / settings.codeFreqBasis;    % Chip duration [s]
prn = settings.PRN;                 % Satellite PRN number
codeLength = 1023;                  % C/A code length [chips]

% Calculate signal power
signalPower = db2real(settings.cnr + settings.noisePsd); % Linear power

% Generate C/A code sequence
caCode = generateCaCode(prn);       % Generate PRN sequence

%% Main signal generation loop ==========================================
for timeBlock = 1:settings.msToProcess
    % Add controlled oscillator drift
    freqDrift = 3 * (rand - 0.5); % ¡À3 Hz maximum drift
    effectiveCodeFreq = settings.codeFreqBasis + freqDrift;
    
    % Calculate block size (1 ms of samples)
    samplesPerMs = ceil(1e-3 * fs);
    
    %% Carrier generation ================================================
    % Generate carrier phase vector
    phaseVector = (0:samplesPerMs-1) * 2 * pi * settings.sigIfFreq / fs;
    ifCarrier = exp(1i * phaseVector); % Complex IF carrier
    
    %% Code generation ===================================================
    % Calculate code phase indices
    codePhaseStep = ts / tc;             % Code phase increment per sample
    codePhaseIndices = mod(floor((0:samplesPerMs-1) * codePhaseStep), codeLength) + 1;
    sampledCaCode = caCode(codePhaseIndices); % Sampled C/A code sequence
    
    %% Process in frequency blocks ======================================
    fftSize = 1024;                      % FFT processing block size
    numBlocks = samplesPerMs / fftSize;   % Number of blocks per ms
    
    for blockIdx = 1:numBlocks
        % Extract current code block
        startIdx = (blockIdx-1)*fftSize + 1;
        endIdx = blockIdx*fftSize;
        codeBlock = sampledCaCode(startIdx:endIdx);
        
        % Process each antenna element
        for elementIdx = 1:settings.numberOfElements
            %% Apply antenna-specific processing =========================
            % In ideal case, no delay between elements
            elementDelay = 0; 
            
            % Apply delay in frequency domain
            freqVector = linspace(-fs/2, fs/2, fftSize);
            delayOperator = exp(-1i * 2 * pi * freqVector * elementDelay);
            delayedCode = ifft(fft(codeBlock) .* delayOperator);
            
            %% Modulate carrier and scale power ==========================
            % Extract carrier segment for current block
            carrierSegment = ifCarrier(startIdx:endIdx);
            
            % Create complex baseband signal
            basebandSignal = sqrt(2 * signalPower) * delayedCode .* carrierSegment;
            
            %% Write output data =========================================
            fwrite(realHandles(elementIdx), real(basebandSignal), settings.dataType);
            fwrite(imagHandles(elementIdx), imag(basebandSignal), settings.dataType);
        end
    end
end

%% Cleanup operations ===================================================
% Close all file handles
fclose('all');
end

%% Helper function =======================================================
function caCode = generateCaCode(prn)
% GENERATECACODE Generate C/A code for given PRN
%   caCode = GENERATECACODE(PRN) generates 1023-chip C/A code sequence
    % Implementation of C/A code generation would go here
    % For actual implementation, refer to fB3CCodeGen functionality
    caCode = zeros(1, 1023); % Placeholder for actual code
end