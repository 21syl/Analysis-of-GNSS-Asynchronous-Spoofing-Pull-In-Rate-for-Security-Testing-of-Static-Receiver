function [settings, jam1, jam2, jam3] = initSettings()
% INITSETTINGS Initialize simulation parameters for GPS receiver
%
%   [SETTINGS, JAM1, JAM2, JAM3] = INITSETTINGS() creates and initializes
%   parameter structures for GPS signal processing simulations.
%
%   Outputs:
%       settings - Main configuration structure
%       jam1     - Jammer configuration 1
%       jam2     - Jammer configuration 2
%       jam3     - Jammer configuration 3
%
%   Configuration Sections:
%       1. Array Configuration
%       2. Sampling & Front-End Parameters
%       3. Signal Parameters
%       4. Jammer Configurations
%       5. Receiver Processing Parameters
%       6. Tracking Loop Parameters

%% Array Configuration =================================================
% Number of antenna elements
settings.numberOfElements = 1;

% Element positions in wavelengths [x, y, z] per element
settings.elementsPosition = [0, 0, 0]; 

%% Sampling & Front-End Parameters ======================================
% Sampling frequency [Hz]
settings.samplingFreq = 20.48e5; 

% Receiver front-end bandwidth [Hz]
settings.receiverBw = 20e6; 

% Intermediate frequency [Hz]
settings.IF = 1000; 

% Signal duration to process [ms]
settings.msToProcess = 5000; 

% Data type for signal samples
settings.dataType = 'float64';

% Output directory for generated files
settings.directory = 'E:\deskpot\arraySigProcessing\data_jam\';

%% Signal Parameters ====================================================
% Baseband signal file prefix
settings.sigFileName = 'navSig';

% RF carrier frequency [Hz]
settings.sigCarrierFreq = 1227.6e6; 

% PRN number of satellite signal (1-32)
settings.PRN = 1; 

% Code chipping rate [Hz]
settings.codeFreqBasis = 10.23e5; 

% Code length [chips]
settings.codeLength = 1023;

% Signal direction of arrival [elevation, azimuth] in degrees
settings.sigDoa = [80, 320]; 

% Carrier-to-noise ratio [dB-Hz]
settings.cnr = 45; 

%% Jammer Configurations ===============================================
% Jammer 1: Wideband Gaussian Noise
jam1.turnOn = false;     % Enable/disable jammer
jam1.type = 'WGN';       % Jammer type
jam1.doa = [15, 120];    % Direction of arrival [deg]
jam1.jsr = 60;           % Jammer-to-signal ratio [dB]

% Jammer 2: Continuous Wave Interference
jam2.turnOn = false;
jam2.type = 'CWI';
jam2.doa = [10, 50];
jam2.jsr = 60;

% Jammer 3: Continuous Wave Interference
jam3.turnOn = false;
jam3.type = 'CWI';
jam3.doa = [2, 60];
jam3.jsr = 60;

%% Noise Parameter =====================================================
% Noise power spectral density [dBW/Hz]
settings.noisePsd = 0; 

%% Combined Data Parameters =============================================
% Output filename for combined signals
settings.combDataFileName = 'scenario1_Ant'; 

%% Receiver Processing Parameters ======================================
% Number of processing channels
settings.numberOfChannels = 1; 

% Bypass acquisition stage
settings.skipAcquisition = false; 

% PRNs to acquire (satellite list)
settings.acqSatelliteList = 1; 

% Acquisition frequency search bandwidth [kHz]
settings.acqSearchBand = 14; 

% Acquisition detection threshold
settings.acqThreshold = 1.0; 

%% Tracking Loop Parameters ============================================
% DLL damping ratio
settings.dllDampingRatio = 0.7071; 

% DLL noise bandwidth [Hz]
settings.dllNoiseBandwidth = 15; 

% DLL correlator spacing [chips]
settings.dllCorrelatorSpacing = 0.5; 

% PLL damping ratio
settings.pllDampingRatio = 0.7; 

% PLL noise bandwidth [Hz]
settings.pllNoiseBandwidth = 25; 

%% Anti-Jamming Parameters ============================================
% Spatial-temporal filter taps
settings.mTaps = 5; 

% Anti-jamming method ('MVDR', 'LCMV', or 'none')
settings.principle = 'MVDR'; 
end