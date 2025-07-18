function [trackResults, channel, flag, unlock] = fCnrEstV3(fileName, channel, settings, DLLNoiseBandwidth, DLLDampingRatio, order, power)
% FCNRESTV3 GPS signal tracking with carrier-to-noise ratio estimation
%
%   [TRACKRESULTS, CHANNEL, FLAG, UNLOCK] = FCNRESTV3(FILENAME, CHANNEL, SETTINGS, DLLNOISEBANDWIDTH, DLLDAMPINGRATIO, ORDER, POWER)
%   performs GPS signal tracking with adaptive loop filtering, C/N0 estimation, 
%   and spoofing detection capabilities.
%
%   Input Parameters:
%       fileName            - Baseband signal filename prefix
%       channel             - Channel configuration structure
%       settings            - Receiver settings structure
%       DLLNoiseBandwidth   - DLL noise bandwidth [Hz]
%       DLLDampingRatio     - DLL damping ratio
%       order               - Loop filter order (1, 2, or 3)
%       power               - Spoofing signal power gain [dB]
%
%   Output Parameters:
%       trackResults - Tracking results structure
%       channel      - Updated channel information
%       flag         - Spoofing detection flag (1 = spoofing detected)
%       unlock       - Loss of lock indicator (1 = unlocked)

%% Initialize file handles ===============================================
fidForTrackReal = fopen([fileName '_real.dat'], 'r', 'ieee-be');
if fidForTrackReal < 0
    error('Cannot open real component file: %s_real.dat', fileName);
end

fidForTrackImag = fopen([fileName '_imag.dat'], 'r', 'ieee-be');
if fidForTrackImag < 0
    fclose(fidForTrackReal);
    error('Cannot open imaginary component file: %s_imag.dat', fileName);
end

%% Initialize tracking results structure =================================
unlock = 0; % Loss-of-lock flag

% Preallocate tracking results arrays
codePeriods = settings.msToProcess - 2; % Number of code periods to process

trackResults = struct(...
    'status',           '-',...          % Tracking status
    'PRN',              0,...            % Satellite PRN
    'absoluteSample',   zeros(1, codePeriods),... % Sample positions
    'codeFreq',         inf(1, codePeriods),...   % Code frequency
    'carrFreq',         inf(1, codePeriods),...  % Carrier frequency
    'I_P',              zeros(1, codePeriods),...  % Prompt I
    'I_E',              zeros(1, codePeriods),...  % Early I
    'I_L',              zeros(1, codePeriods),...  % Late I
    'Q_P',              zeros(1, codePeriods),...  % Prompt Q
    'Q_E',              zeros(1, codePeriods),...  % Early Q
    'Q_L',              zeros(1, codePeriods),...  % Late Q
    'dllDiscr',         inf(1, codePeriods),...   % DLL discriminator
    'dllDiscrFilt',     inf(1, codePeriods),...    % Filtered DLL
    'pllDiscr',         inf(1, codePeriods),...    % PLL discriminator
    'pllDiscrFilt',     inf(1, codePeriods),...    % Filtered PLL
    'dopplerFreq',      inf(1, settings.msToProcess),... % Doppler frequency
    'cnrEst',           [],...           % C/N0 estimates
    'remCarrPhase',     [],...           % Residual carrier phase
    'remCodePhase',     []);             % Residual code phase

% Replicate structure for all channels
trackResults = repmat(trackResults, 1, settings.numberOfChannels);

%% Initialize tracking parameters =======================================
fs = settings.samplingFreq;        % Sampling frequency
earlyLateSpc = settings.dllCorrelatorSpacing; % Early-late spacing [chips]
PDIcode = 0.001;                  % Code loop integration time [s]
PDIcarr = 0.001;                  % Carrier loop integration time [s]

% Calculate loop filter coefficients
[tau1code, tau2code, wn] = calcLoopCoef(DLLNoiseBandwidth, DLLDampingRatio, 1.0);
[tau1carr, tau2carr] = calcLoopCoef(settings.pllNoiseBandwidth, settings.pllDampingRatio, 0.25);

%% Main tracking loop ====================================================
for channelNr = 1:settings.numberOfChannels
    % Skip if no PRN assigned (failed acquisition)
    if channel(channelNr).PRN == 0
        continue;
    end
    
    % Initialize channel-specific tracking data
    prn = channel(channelNr).PRN;
    trackResults(channelNr).PRN = prn;
    
    % Position file pointers at start of signal
    fseek(fidForTrackReal, 8*(channel(channelNr).codePhase-1), 'bof');
    fseek(fidForTrackImag, 8*(channel(channelNr).codePhase-1), 'bof');
    
    % Generate C/A code with edge padding for circular indexing
    caCode = fB3CCodeGen(prn);
    caCode = [caCode(end) caCode caCode(1)];
    
    % Initialize tracking variables
    codeFreq = settings.codeFreqBasis;      % Initial code frequency
    remCodePhase = 0.0;                     % Residual code phase
    carrFreqBasis = channel(channelNr).acquiredFreq; % Nominal carrier frequency
    carrFreq = carrFreqBasis;               % Current carrier frequency
    remCarrPhase = 0.0;                      % Residual carrier phase
    
    % Initialize loop filter states
    oldCodeNco = 0.0;
    oldCodeError = 0.0;
    oldCarrNco = 0.0;
    oldCarrError = 0.0;
    
    % Third-order filter specific states
    if order == 3
        oldCodeNco2 = 0.0;
        oldCodeNco1 = 0.0;
        oldCodeError2 = 0.0;
        oldCodeError1 = 0.0;
        b3 = 2.4; % Third-order filter coefficients
        a3 = 1.1;
    end
    
    %% Process each code period ==========================================
    for loopCnt = 1:codePeriods
        % Calculate code phase step per sample
        codePhaseStep = codeFreq / fs;
        
        % Determine block size (1 ms of samples)
        blksize = ceil(1e-3 * fs);
        
        % Read signal block
        [rawSignalReal, realSamplesRead] = fread(fidForTrackReal, blksize, settings.dataType);
        [rawSignalImag, imagSamplesRead] = fread(fidForTrackImag, blksize, settings.dataType);
        
        % Verify complete read
        if realSamplesRead ~= blksize || imagSamplesRead ~= blksize
            warning('Incomplete signal block read at loop %d', loopCnt);
            break;
        end
        
        %% Code correlation ==============================================
        % Generate early, prompt, and late code segments
        promptCode = genCodeSegment(caCode, remCodePhase, codePhaseStep, blksize, 0);
        earlyCode = genCodeSegment(caCode, remCodePhase, codePhaseStep, blksize, -earlyLateSpc);
        lateCode = genCodeSegment(caCode, remCodePhase, codePhaseStep, blksize, earlyLateSpc);
        
        % Update residual code phase
        remCodePhase = rem(remCodePhase + blksize * codePhaseStep, 1023);
        
        %% Carrier mixing =================================================
        % Generate carrier mixing signals
        time = (0:blksize-1)' / fs;
        trigarg = 2 * pi * carrFreq * time + remCarrPhase;
        remCarrPhase = rem(trigarg(end) + 2*pi*carrFreq*1/fs, 2*pi);
        
        carrCos = cos(trigarg);
        carrSin = sin(trigarg);
        
        % Mix to baseband
        iBaseband = carrCos .* rawSignalReal + carrSin .* rawSignalImag;
        qBaseband = carrCos .* rawSignalImag - carrSin .* rawSignalReal;
        
        %% Correlate with code sequences ==================================
        I_E = sum(earlyCode .* iBaseband);
        Q_E = sum(earlyCode .* qBaseband);
        I_P = sum(promptCode .* iBaseband);
        Q_P = sum(promptCode .* qBaseband);
        I_L = sum(lateCode .* iBaseband);
        Q_L = sum(lateCode .* qBaseband);
        
        %% Carrier tracking loop ==========================================
        % Phase detector
        carrError = atan2(Q_P, I_P) / (2 * pi);
        
        % Loop filter (PI controller)
        carrNco = oldCarrNco + (tau2carr/tau1carr)*(carrError - oldCarrError) + ...
                  carrError * (PDIcarr/tau1carr);
        
        % Update states and frequency
        oldCarrNco = carrNco;
        oldCarrError = carrError;
        carrFreq = carrFreqBasis + carrNco;
        
        % Store results
        trackResults(channelNr).carrFreq(loopCnt) = carrFreq;
        trackResults(channelNr).dopplerFreq(loopCnt) = carrFreq - carrFreqBasis;
        
        %% Code tracking loop =============================================
        % Normalized early-minus-late power discriminator
        E = sqrt(I_E^2 + Q_E^2);
        L = sqrt(I_L^2 + Q_L^2);
        codeError = (E - L) / (E + L);
        
        % Loss-of-lock detection
        if abs(codeError) > 1
            unlock = 1;
        end
        
        % Order-specific loop filters
        switch order
            case 1 % First-order loop
                codeNco = oldCodeNco + wn * (codeError - oldCodeError);
                
            case 2 % Second-order loop
                codeNco = oldCodeNco + (tau2code/tau1code)*(codeError - oldCodeError) + ...
                         codeError * (PDIcode/tau1code);
                
            case 3 % Third-order loop
                codeNco = 2*oldCodeNco1 - oldCodeNco2 + ...
                          b3*wn*(codeError - 2*oldCodeError1 + oldCodeError2) + ...
                          PDIcode*a3*wn^2*(codeError - oldCodeError1) + ...
                          (PDIcode^2)*wn^3*codeError;
                
                % Update history states
                oldCodeNco2 = oldCodeNco1;
                oldCodeNco1 = codeNco;
                oldCodeError2 = oldCodeError1;
                oldCodeError1 = codeError;
        end
        
        % Update common states
        oldCodeNco = codeNco;
        oldCodeError = codeError;
        
        % Adjust code frequency
        codeFreq = settings.codeFreqBasis - codeNco;
        trackResults(channelNr).codeFreq(loopCnt) = codeFreq;
        
        %% Store correlation results ======================================
        trackResults(channelNr).absoluteSample(loopCnt) = ftell(fidForTrackReal);
        trackResults(channelNr).dllDiscr(loopCnt) = codeError;
        trackResults(channelNr).dllDiscrFilt(loopCnt) = codeNco;
        trackResults(channelNr).pllDiscr(loopCnt) = carrError;
        trackResults(channelNr).pllDiscrFilt(loopCnt) = carrNco;
        
        trackResults(channelNr).I_E(loopCnt) = I_E;
        trackResults(channelNr).I_P(loopCnt) = I_P;
        trackResults(channelNr).I_L(loopCnt) = I_L;
        trackResults(channelNr).Q_E(loopCnt) = Q_E;
        trackResults(channelNr).Q_P(loopCnt) = Q_P;
        trackResults(channelNr).Q_L(loopCnt) = Q_L;
        
        trackResults(channelNr).remCarrPhase(loopCnt) = remCarrPhase;
        trackResults(channelNr).remCodePhase(loopCnt) = remCodePhase;
    end
    
    %% Carrier-to-noise ratio estimation ================================
    cnrInterval = 5; % Estimation interval in ms
    cnrLoopN = floor(codePeriods / cnrInterval);
    trackResults(channelNr).cnrEst = zeros(1, cnrLoopN);
    Tc = 1e-3; % Coherent integration time
    
    for k = 1:cnrLoopN
        startIdx = cnrInterval*(k-1) + 1;
        endIdx = cnrInterval*k;
        
        I_data = trackResults(channelNr).I_P(startIdx:endIdx);
        Q_data = trackResults(channelNr).Q_P(startIdx:endIdx);
        
        % M2/M4 C/N0 estimator
        M2 = mean(I_data.^2 + Q_data.^2);
        M4 = mean((I_data.^2 + Q_data.^2).^2);
        cnr_temp = sqrt(2*M2^2 - M4) / (M2 - sqrt(2*M2^2 - M4)) / Tc;
        trackResults(channelNr).cnrEst(k) = 10*log10(cnr_temp);
    end
    
    %% Spoofing detection logic ==========================================
    % Calculate average prompt correlation at beginning and end
    meanStart = mean(trackResults(channelNr).I_P(500:1000));
    meanEnd = mean(trackResults(channelNr).I_P(end-1000:end));
    
    % Set detection threshold based on spoofing power
    if power >= 7
        threshold = 9e6;
    elseif power >= 4
        threshold = 7e6;
    elseif power >= 2
        threshold = 6e6;
    else
        threshold = 5.5e6;
    end
    
    % Detect spoofing based on correlation power increase
    flag = meanEnd > threshold;
end

%% Cleanup ===============================================================
fclose(fidForTrackReal);
fclose(fidForTrackImag);
end
%% Helper function =======================================================
function codeSeg = genCodeSegment(fullCode, remPhase, phaseStep, blksize, offset)
    % GENCODESEGMENT Generate code segment with offset handling
    t = remPhase + offset + (0:blksize-1)*phaseStep;
    idx = mod(floor(t), 1023) + 2; % +2 for padded code
    codeSeg = fullCode(idx);
end