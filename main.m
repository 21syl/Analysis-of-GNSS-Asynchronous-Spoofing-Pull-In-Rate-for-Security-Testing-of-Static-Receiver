%% ========================================================================
%% Function: GNSS Spoofing Threshold Analysis
%% Purpose: Test receiver's spoofing success rate under various loop parameters
%%          and spoofing signal characteristics (power, pull-in rate)
%% ========================================================================

%% Initialization
clear; clc;
format('compact');
format('long', 'g');
addpath('E:\deskpot\arraySigProcessing\data_jam\'); % Adjust path if needed
[settings, jam1, jam2, jam3] = initSettings(); % Initialize system settings

%% Parameter Configuration
% Loop orders to test (1st/2nd/3rd order)
order = 1;

% DLL noise bandwidth values (Hz)
DLLNoiseBandwidth_values = 15;

% DLL damping ratio values
DLLDampingRatio_values = 0.7071;

% Spoofing signal power gains (dB)
power = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

% Spoofing pull-in rates (chips/ms)
v = 0.01;

% Test iterations per parameter set
trycnt = 1;

%% Experiment Setup
% Calculate total test combinations
test_combinations = trycnt * length(v) * length(order) * ...
                    length(DLLNoiseBandwidth_values) * ...
                    length(DLLDampingRatio_values) * length(power);

% Initialize parameter statistics structure
param_stats = struct('paramString', {}, 'successCount', {}, ...
                    'totalCount', {}, 'v_value', {}, 'successRate', {});
param_keys = {};

%% Main Test Loop
for test = 1:test_combinations
    % Calculate parameter indices
    orderIndex = mod(floor((test - 1) / (length(DLLDampingRatio_values)*...
                  length(DLLNoiseBandwidth_values)*length(power)*length(v))), ...
                  length(order)) + 1;
              
    bandwidthIndex = mod(floor((test - 1) / (length(DLLDampingRatio_values)*...
                  length(power)*length(v))), ...
                  length(DLLNoiseBandwidth_values)) + 1;
              
    dampingIndex = mod(floor((test - 1) / (length(power)*length(v))), ...
                  length(DLLDampingRatio_values)) + 1;
              
    powerIndex = mod(floor((test - 1) / length(v)), length(power)) + 1;
    vIndex = mod(test - 1, length(v)) + 1;

    % Set current parameters
    currentPower = power(powerIndex);
    currentOrder = order(orderIndex);
    currentDamping = DLLDampingRatio_values(dampingIndex);
    currentBandwidth = DLLNoiseBandwidth_values(bandwidthIndex);
    currentV = v(vIndex); 

    %% Signal Processing Pipeline
    % 1. Generate authentic GNSS signal
    fSigDataGen(settings);

    % 2. Generate spoofing signal
    delay_cnt = 6/currentV; % Pull-off range calculation
    fCWIgen(settings, jam2, currentV, delay_cnt, currentPower);

    % 3. Combine authentic and spoofing signals
    fDataComb(settings, jam1, jam2, jam3);

    % 4. Signal acquisition
    combDataFileName = 'scenario1_Ant1';  
    acqResults = fMyAcquisition(settings, combDataFileName);
    
    %% Tracking and Analysis
    if any(acqResults.carrFreq)
        channel = preRun(acqResults, settings);
        
        % 5. Signal tracking with current parameters
        [trackResults, channel, successFlag, unlockFlag] = ...
            fCnrEstV3(combDataFileName, channel, settings, ...
                     currentBandwidth, currentDamping, currentOrder, currentPower); 
        
        % 6. Visualization (optional)
        plotTrackingfigure(channel, trackResults, settings);
        plotAcquisition(acqResults);
    else
        disp('No GNSS signals detected');
        trackResults = [];
        continue;
    end  

    %% Result Recording
    % Create parameter signature string
    paramString = sprintf('P(%d)_O(%d)_Damp(%.2f)_BW(%d)_V(%.4f)', ...
        currentPower, currentOrder, currentDamping, currentBandwidth, currentV);
    
    % Find or create parameter entry
    if ~ismember(paramString, param_keys)
        param_keys{end+1} = paramString;
        param_stats(end+1) = struct(...
            'paramString', paramString, ...
            'successCount', 0, ...
            'totalCount', 0, ...
            'v_value', currentV, ...
            'successRate', 0);
    end
    
    % Update statistics
    idx = find(strcmp({param_stats.paramString}, paramString));
    param_stats(idx).totalCount = param_stats(idx).totalCount + 1;
    
    if successFlag == 1
        param_stats(idx).successCount = param_stats(idx).successCount + 1;
    end
    
    param_stats(idx).successRate = param_stats(idx).successCount / ...
                                  param_stats(idx).totalCount;
end