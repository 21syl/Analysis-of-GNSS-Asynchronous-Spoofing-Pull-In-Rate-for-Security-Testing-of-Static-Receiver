function caCodesTable = makeCaTable(settings)
%
%   Inputs:
%       settings        - receiver settings
%   Outputs:
%       caCodesTable    - an array of arrays (matrix) containing C/A codes
%                       for all satellite PRN-s

%--- Find number of samples per spreading code ----------------------------
samplesPerCode = round(settings.samplingFreq / ...
                           (settings.codeFreqBasis / settings.codeLength));

%--- Prepare the output matrix to speed up function -----------------------
caCodesTable = zeros(12, samplesPerCode);
 
%--- Find time constants --------------------------------------------------
ts = 1/settings.samplingFreq;   % Sampling period in sec
tc = 1/settings.codeFreqBasis;  % C/A chip period in sec
 
%=== For all satellite PRN-s ...
for PRN = 1:12
    %--- Generate CA code for given PRN -----------------------------------
%     caCode = generateCAcode(PRN);
    caCode = fB3CCodeGen(PRN);    
 
    %=== Digitizing =======================================================
    
    %--- Make index array to read C/A code values -------------------------
    % The length of the index array depends on the sampling frequency -
    % number of samples per millisecond (because one C/A code period is one
    % millisecond).
    codeValueIndex = ceil((ts * (1:samplesPerCode)) / tc);
    
    %--- Correct the last index (due to number rounding issues) -----------
%     codeValueIndex(end) = 10230;
    codeValueIndex(end) = 1023;

    
    %--- Make the digitized version of the C/A code -----------------------
    % The "upsampled" code is made by selecting values form the CA code
    % chip array (caCode) for the time instances of each sample.
    caCodesTable(PRN, :) = caCode(codeValueIndex);
    
end % for PRN = 1:32
