function ggcode = fCodeGen(satelliteID)
% FCODEGEN Generate GPS Gold code sequence for specified satellite
%
%   GGCODE = FCODEGEN(SATELLITEID) generates the Gold code sequence for a
%   GPS satellite specified by SATELLITEID (1-12)
%
%   Input:
%       satelliteID - Satellite identifier (integer between 1 and 12)
%
%   Output:
%       ggcode      - Gold code sequence in bipolar format (1 and -1)
%
%   Algorithm:
%       1. Generates two 13-bit m-sequences using preferred polynomials
%       2. Combines sequences with satellite-specific delay
%       3. Converts to bipolar representation
%
%   Polynomials:
%       f1(x) = 1 + x + x³ + x⁴ + x¹³
%       f2(x) = 1 + x + x⁵ + x⁶ + x⁷ + x⁹ + x¹⁰ + x¹² + x¹³

%% Initialize parameters
% G2 delay taps for satellites 1-12 (GPS standard)
g2Delays = [4, 11, 13, 22, 30, 36, 44, 48, 88, 104, 116, 129];

% Validate satellite ID
if satelliteID < 1 || satelliteID > 12
    error('Satellite ID must be between 1 and 12');
end

% Gold code parameters
sequenceLength = 1023;  % Standard GPS C/A code length
registerSize = 13;      % Shift register size
maxSequence = 2^registerSize - 1; % 8191 for 13-bit register

%% Generate m-sequence 1
% Polynomial: 1 + x + x³ + x⁴ + x¹³
mSeq1 = zeros(1, maxSequence);
registers1 = ones(1, registerSize); % Initialize with all 1s

for i = 1:maxSequence
    mSeq1(i) = registers1(registerSize);
    % Feedback: taps at positions 1, 3, 4, 13
    feedback = mod(registers1(1) + registers1(3) + registers1(4) + registers1(registerSize), 2);
    % Shift register
    registers1(2:end) = registers1(1:end-1);
    registers1(1) = feedback;
end

%% Generate m-sequence 2
% Polynomial: 1 + x + x⁵ + x⁶ + x⁷ + x⁹ + x¹⁰ + x¹² + x¹³
mSeq2 = zeros(1, maxSequence);
registers2 = ones(1, registerSize); % Initialize with all 1s

for i = 1:maxSequence
    mSeq2(i) = registers2(registerSize);
    % Feedback: taps at positions 1, 5, 6, 7, 9, 10, 12, 13
    feedback = mod(registers2(1) + registers2(5) + registers2(6) + registers2(7) + ...
               registers2(9) + registers2(10) + registers2(12) + registers2(registerSize), 2);
    % Shift register
    registers2(2:end) = registers2(1:end-1);
    registers2(1) = feedback;
end

%% Generate Gold code sequence
goldCode = zeros(1, sequenceLength);
delay = g2Delays(satelliteID); % Satellite-specific delay

for j = 1:sequenceLength
    % Combine sequences with modulo-2 addition
    idx1 = mod(j-1, maxSequence) + 1;
    idx2 = mod(j-1 + delay, maxSequence) + 1;
    goldCode(j) = mod(mSeq1(idx1) + mSeq2(idx2), 2);
end

%% Convert to bipolar representation
% 0 → +1, 1 → -1 (GPS standard)
ggcode = 1 - 2 * goldCode;
end