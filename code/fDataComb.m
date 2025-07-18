function fDataComb(settings, jam1, jam2, jam3)
% FDATACOMB Combine signals with interference and noise sources
%
%   FDATACOMB(SETTINGS, JAM1, JAM2, JAM3) synthesizes complex baseband
%   signals by combining:
%       - Authentic GNSS signals
%       - Configurable interference sources (jam1, jam2, jam3)
%       - Gaussian noise
%
%   Input Parameters:
%       settings - Receiver configuration structure
%       jam1     - Interference configuration for source 1
%       jam2     - Interference configuration for source 2 (spoofing)
%       jam3     - Interference configuration for source 3
%
%   Output:
%       Creates combined I/Q data files for each antenna element

%% Initialize parameters =================================================
fs = settings.samplingFreq;                    % Sampling frequency [Hz]
samplesPerMs = ceil(1e-3 * fs);                 % Samples per millisecond
receiverBw = settings.receiverBw;               % Receiver bandwidth [Hz]

% Calculate noise power (converts dBm/Hz to linear power)
noisePsd = settings.noisePsd;                  % Noise power spectral density
noisePower = db2real(10 + noisePsd);            % Total noise power [W]

%% File handling setup ===================================================
% Initialize output file handles
outputRealFiles = cell(1, settings.numberOfElements);
outputImagFiles = cell(1, settings.numberOfElements);

% Initialize signal input file handles
signalRealFiles = cell(1, settings.numberOfElements);
signalImagFiles = cell(1, settings.numberOfElements);

% Initialize interference file handles
interfRealFiles = struct('jam1', cell(1, settings.numberOfElements), ...
                         'jam2', cell(1, settings.numberOfElements), ...
                         'jam3', cell(1, settings.numberOfElements));
                     
interfImagFiles = struct('jam1', cell(1, settings.numberOfElements), ...
                        'jam2', cell(1, settings.numberOfElements), ...
                        'jam3', cell(1, settings.numberOfElements));

%% Create output files ===================================================
for elementIdx = 1:settings.numberOfElements
    % Output files (combined signal)
    outputRealFiles{elementIdx} = fopen(...
        fullfile(settings.directory, ...
                 [settings.combDataFileName num2str(elementIdx) '_real.dat']), ...
        'w', 'ieee-be');
    outputImagFiles{elementIdx} = fopen(...
        fullfile(settings.directory, ...
                 [settings.combDataFileName num2str(elementIdx) '_imag.dat']), ...
        'w', 'ieee-be');
    
    % Signal input files
    signalRealFiles{elementIdx} = fopen(...
        fullfile(settings.directory, ...
                 [settings.sigFileName num2str(elementIdx) '_real.dat']), ...
        'r', 'ieee-be');
    signalImagFiles{elementIdx} = fopen(...
        fullfile(settings.directory, ...
                 [settings.sigFileName num2str(elementIdx) '_imag.dat']), ...
        'r', 'ieee-be');
    
    % Interference source 1 files
    if jam1.turnOn
        interfRealFiles(elementIdx).jam1 = fopen(...
            fullfile(settings.directory, ...
                     ['WGN1_' num2str(elementIdx) '_real.dat']), ...
            'r', 'ieee-be');
        interfImagFiles(elementIdx).jam1 = fopen(...
            fullfile(settings.directory, ...
                     ['WGN1_' num2str(elementIdx) '_imag.dat']), ...
            'r', 'ieee-be');
    end
    
    % Interference source 2 files (spoofing signal)
    if jam2.turnOn
        interfRealFiles(elementIdx).jam2 = fopen(...
            fullfile(settings.directory, ...
                     ['CWI1_' num2str(elementIdx) '_real.dat']), ...
            'r', 'ieee-be');
        interfImagFiles(elementIdx).jam2 = fopen(...
            fullfile(settings.directory, ...
                     ['CWI1_' num2str(elementIdx) '_imag.dat']), ...
            'r', 'ieee-be');
    end
    
    % Interference source 3 files
    if jam3.turnOn
        interfRealFiles(elementIdx).jam3 = fopen(...
            fullfile(settings.directory, ...
                     ['WGN3_' num2str(elementIdx) '_real.dat']), ...
            'r', 'ieee-be');
        interfImagFiles(elementIdx).jam3 = fopen(...
            fullfile(settings.directory, ...
                     ['WGN3_' num2str(elementIdx) '_imag.dat']), ...
            'r', 'ieee-be');
    end
end

%% Data combination processing ===========================================
% Preallocate data arrays
signalData = complex(zeros(samplesPerMs, settings.numberOfElements));
interferenceData = struct(...
    'jam1', complex(zeros(samplesPerMs, settings.numberOfElements)), ...
    'jam2', complex(zeros(samplesPerMs, settings.numberOfElements)), ...
    'jam3', complex(zeros(samplesPerMs, settings.numberOfElements)));
noiseData = complex(zeros(samplesPerMs, settings.numberOfElements));

% Timing parameters
jam1StartTime = 2220; % Jammer 1 activation time [ms]
jam2StartTime = 2000; % Spoofer activation time [ms]
jam3StartTime = 2220; % Jammer 3 activation time [ms]

fprintf('Starting data combination processing...\n');
startTime = tic;

for timeBlock = 1:settings.msToProcess
    % Progress indicator
    if mod(timeBlock, 100) == 0
        fprintf('Processing block %d/%d\n', timeBlock, settings.msToProcess);
    end
    
    for elementIdx = 1:settings.numberOfElements
        %% Read authentic signal data =====================================
        [realPart, realCount] = fread(signalRealFiles{elementIdx}, samplesPerMs, settings.dataType);
        [imagPart, imagCount] = fread(signalImagFiles{elementIdx}, samplesPerMs, settings.dataType);
        
        if realCount ~= samplesPerMs || imagCount ~= samplesPerMs
            error('Incomplete signal read for element %d at block %d', elementIdx, timeBlock);
        end
        signalData(:, elementIdx) = realPart + 1i * imagPart;
        
        %% Read interference data =========================================
        % Interference source 1
        if jam1.turnOn && timeBlock >= jam1StartTime
            [realJam, ~] = fread(interfRealFiles(elementIdx).jam1, samplesPerMs, settings.dataType);
            [imagJam, ~] = fread(interfImagFiles(elementIdx).jam1, samplesPerMs, settings.dataType);
            interferenceData.jam1(:, elementIdx) = realJam + 1i * imagJam;
        else
            interferenceData.jam1(:, elementIdx) = 0;
        end
        
        % Interference source 2 (spoofing)
        if jam2.turnOn && timeBlock >= jam2StartTime
            [realJam, ~] = fread(interfRealFiles(elementIdx).jam2, samplesPerMs, settings.dataType);
            [imagJam, ~] = fread(interfImagFiles(elementIdx).jam2, samplesPerMs, settings.dataType);
            interferenceData.jam2(:, elementIdx) = realJam + 1i * imagJam;
        else
            interferenceData.jam2(:, elementIdx) = 0;
        end
        
        % Interference source 3
        if jam3.turnOn && timeBlock >= jam3StartTime
            [realJam, ~] = fread(interfRealFiles(elementIdx).jam3, samplesPerMs, settings.dataType);
            [imagJam, ~] = fread(interfImagFiles(elementIdx).jam3, samplesPerMs, settings.dataType);
            interferenceData.jam3(:, elementIdx) = realJam + 1i * imagJam;
        else
            interferenceData.jam3(:, elementIdx) = 0;
        end
        
        %% Generate noise component =======================================
        % Generate complex Gaussian noise with proper power scaling
        noiseReal = randn(samplesPerMs, 1);
        noiseImag = randn(samplesPerMs, 1);
        noiseData(:, elementIdx) = sqrt(noisePower/2) * (noiseReal + 1i * noiseImag);
        
        %% Combine signal components ======================================
        combinedSignal = signalData(:, elementIdx) + ...
                         interferenceData.jam1(:, elementIdx) + ...
                         interferenceData.jam2(:, elementIdx) + ...
                         interferenceData.jam3(:, elementIdx) + ...
                         noiseData(:, elementIdx);
        
        %% Write output data ==============================================
        fwrite(outputRealFiles{elementIdx}, real(combinedSignal), settings.dataType);
        fwrite(outputImagFiles{elementIdx}, imag(combinedSignal), settings.dataType);
    end
end

%% Cleanup operations ====================================================
% Close all file handles
fclose('all');

% Report processing time
elapsedTime = toc(startTime);
fprintf('Data combination completed in %.2f seconds\n', elapsedTime);
end