function acqResults = fMyAcquisition(settings, fileName)
% FMYACQUISITION GPS signal acquisition function for complex baseband signals
%
%   ACQRESULTS = FMYACQUISITION(SETTINGS, FILENAME) performs GPS signal
%   acquisition using parallel code phase search in frequency domain.
%
%   Input Parameters:
%       settings  - Receiver configuration structure
%       fileName  - Baseband signal filename prefix (without extension)
%
%   Output:
%       acqResults - Structure containing acquisition results:
%           carrFreq    : Estimated carrier frequencies for each PRN
%           codePhase   : Estimated code phases for each PRN
%           peakMetric  : Peak-to-secondary-peak ratio for each PRN

%% Initialize parameters ================================================
fs = settings.samplingFreq;       % Sampling frequency [Hz]
ts = 1 / fs;                       % Sampling period [s]
nominalIF = settings.IF;           % Nominal intermediate frequency [Hz]

% Calculate samples per C/A code period
samplesPerCode = round(fs / (settings.codeFreqBasis / settings.codeLength));

% Frequency search parameters
searchBand = settings.acqSearchBand;     % Acquisition frequency band [kHz]
freqStep = 0.5;                         % Frequency bin step size [kHz]
numFreqBins = round(searchBand * 2 / freqStep) + 1; % Number of frequency bins

%% Read signal data =====================================================
% Open real and imaginary component files
fidReal = fopen([fileName '_real.dat'], 'r', 'ieee-be');
if fidReal < 0
    error('Cannot open real component file: %s_real.dat', fileName);
end

fidImag = fopen([fileName '_imag.dat'], 'r', 'ieee-be');
if fidImag < 0
    fclose(fidReal);
    error('Cannot open imaginary component file: %s_imag.dat', fileName);
end

% Read 11 ms of signal data (2 ms for correlation, 9 ms for DC removal)
sigLength = 11 * samplesPerCode;
sigReal = fread(fidReal, sigLength, settings.dataType)';
sigImag = fread(fidImag, sigLength, settings.dataType)';
fclose('all');

% Extract first two 1-ms blocks for correlation
sigBlock1 = complex(sigReal(1:samplesPerCode), sigImag(1:samplesPerCode));
sigBlock2 = complex(sigReal(samplesPerCode+1:2*samplesPerCode), ...
                   sigImag(samplesPerCode+1:2*samplesPerCode));

% Create DC-removed signal for fine frequency estimation
dcRemovedSig = complex(sigReal - mean(sigReal), sigImag - mean(sigImag));

%% Generate local signals ================================================
% Create carrier phase vector
phasePoints = (0 : (samplesPerCode-1)) * 2 * pi * ts;

% Generate C/A code table for all PRNs
caCodesTable = generateCaCodeTable(settings);

% Preallocate results arrays
results = zeros(numFreqBins, samplesPerCode); % Correlation results
freqBins = nominalIF - (searchBand/2)*1000 + freqStep*1000*(0:numFreqBins-1);

% Initialize acquisition results structure
acqResults = struct(...
    'carrFreq',    zeros(1, 12), ...  % Estimated carrier frequencies
    'codePhase',   zeros(1, 12), ...   % Estimated code phases
    'peakMetric',  zeros(1, 12));      % Peak-to-secondary ratio

%% Process each PRN in acquisition list =================================
for prn = settings.acqSatelliteList
    %% Frequency domain correlation ======================================
    % Transform C/A code to frequency domain
    caCodeFreqDom = conj(fft(caCodesTable(prn, :)));
    
    for freqIdx = 1:numFreqBins
        %% Generate local carrier signals ================================
        sinCarrier = sin(freqBins(freqIdx) * phasePoints);
        cosCarrier = cos(freqBins(freqIdx) * phasePoints);
        
        %% Downconvert signal blocks =====================================
        % Block 1
        i1 = real(sigBlock1) .* cosCarrier + imag(sigBlock1) .* sinCarrier;
        q1 = imag(sigBlock1) .* cosCarrier - real(sigBlock1) .* sinCarrier;
        iq1 = fft(i1 + 1i*q1);
        
        % Block 2
        i2 = real(sigBlock2) .* cosCarrier + imag(sigBlock2) .* sinCarrier;
        q2 = imag(sigBlock2) .* cosCarrier - real(sigBlock2) .* sinCarrier;
        iq2 = fft(i2 + 1i*q2);
        
        %% Perform correlation ==========================================
        corr1 = abs(ifft(iq1 .* caCodeFreqDom)).^2;
        corr2 = abs(ifft(iq2 .* caCodeFreqDom)).^2;
        
        % Select block with higher correlation peak
        if max(corr1) > max(corr2)
            results(freqIdx, :) = corr1;
        else
            results(freqIdx, :) = corr2;
        end
    end
    
    %% Find correlation peaks ===========================================
    % Find highest peak in frequency domain
    [maxFreqVals, freqIdx] = max(results, [], 1);
    [peakSize, codePhase] = max(maxFreqVals);
    
    % Calculate exclusion range around peak (1 chip width)
    chipSamples = round(fs / settings.codeFreqBasis);
    excludeStart = max(1, codePhase - chipSamples);
    excludeEnd = min(samplesPerCode, codePhase + chipSamples);
    
    % Create exclusion mask
    exclusionMask = true(1, samplesPerCode);
    exclusionMask(excludeStart:excludeEnd) = false;
    
    % Find secondary peak outside exclusion zone
    secondaryPeak = max(results(freqIdx(codePhase), exclusionMask));
    
    % Calculate peak metric ratio
    peakMetric = peakSize / secondaryPeak;
    acqResults.peakMetric(prn) = peakMetric;
    
    %% Process significant peaks ========================================
    if peakMetric > settings.acqThreshold
        %% Fine frequency estimation =====================================
        % Generate 10 ms C/A code sequence
        fullCaCode = generateCaCode(prn);
        timeIndices = floor(ts * (0:10*samplesPerCode-1) * settings.codeFreqBasis);
        longCaCode = fullCaCode(mod(timeIndices, 1023) + 1);
        
        % Extract signal segment and remove C/A code modulation
        sigSegment = dcRemovedSig(codePhase:codePhase+10*samplesPerCode-1);
        basebandSignal = sigSegment .* longCaCode.';
        
        % Perform high-resolution FFT
        fftPts = 8 * 2^nextpow2(length(basebandSignal));
        fftResult = abs(fft(basebandSignal, fftPts));
        
        % Find frequency bin with maximum energy
        validBins = 5:ceil((fftPts+1)/2)-5;
        [~, maxBin] = max(fftResult(validBins));
        freqBins = (0:fftPts-1) * fs / fftPts;
        
        %% Store acquisition results ====================================
        acqResults.carrFreq(prn) = freqBins(validBins(1) + maxBin - 1);
        acqResults.codePhase(prn) = codePhase;
    end
end
end