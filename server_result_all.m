%% 该代码功能是为了测试接收机的所有环路参数下，不同的欺骗信号（功率、切入速度）下，成功欺骗码环的成功率
%% bulid by syl 2024.4.17
%% 初始化
clear; clc;
format ('compact');
format ('long', 'g');
addpath('E:\deskpot\arraySigProcessing\data_jam\'); % 如果需要，请调整路径
[settings, jam1, jam2, jam3] = initSettings(); % 初始化设置



% 初始化基本参数
% order = [1, 2, 3];
% order = 1;
order = 1;

% DLLNoiseBandwidth_values = [15, 25, 35, 45];
DLLNoiseBandwidth_values = 15;

% DLLDampingRatio_values = [0.3536, 0.7071, 2];
DLLDampingRatio_values = 0.7071;

power = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
% power = [2, 3, 4];
% power = [ 5,  7, 9];
% power = 10;

% v = 0.001:0.005:0.1;%1dB
% v = 0.01:0.05:1;%2-9dB
v = 0.01;

trycnt = 1;%每组参数循环次数

% cnt = 1800000; % 更新cnt值，以确保遍历所有1800种组合
cnt = trycnt * length(v) * length(order) * length(DLLNoiseBandwidth_values) * length(DLLDampingRatio_values) * length(power);

% 初始化参数成功统计结构体
% param_stats即一个索引map 将所有的参数集聚合在一起
param_stats = struct('paramString', {}, 'successCount', {}, 'totalCount', {}, 'v_value', {});
mapKeySet = {};

param_flag = zeros(1, (length(v) * length(order) * length(DLLNoiseBandwidth_values) * length(DLLDampingRatio_values) * length(power))); % 保存每一组参数的标志值

% 计数器
groupCounter = 1;

for test = 1:cnt
%     tic
    test
    % 计算当前的组合索引
    combinationIndex = mod((groupCounter-1), (length(v) * length(order) * length(DLLNoiseBandwidth_values) * length(DLLDampingRatio_values) * length(power))) + 1;
    
%     % 重新计算索引匹配参数组合，包括v
%     orderIndex = mod(floor((combinationIndex - 1) / (120*length(v))), 3) + 1;
%     DLLNoiseBandwidthIndex = mod(floor((combinationIndex - 1) / (30*length(v))), 4) + 1;
%     DLLDampingRatioIndex = mod(floor((combinationIndex - 1) / (10*length(v))), 3) + 1;
%     powerIndex = mod(floor((combinationIndex - 1) / length(v)), 10) + 1;
%     vIndex = mod(combinationIndex - 1, 500) + 1;
%     
    orderIndex = mod(floor((combinationIndex - 1) / (length(DLLDampingRatio_values)*length(DLLNoiseBandwidth_values)*length(power)*length(v))), length(order)) + 1;
    DLLNoiseBandwidthIndex = mod(floor((combinationIndex - 1) / (length(DLLDampingRatio_values)*length(power)*length(v))), length(DLLNoiseBandwidth_values)) + 1;
    DLLDampingRatioIndex = mod(floor((combinationIndex - 1) / (length(power)*length(v))), length(DLLDampingRatio_values)) + 1;
    powerIndex = mod(floor((combinationIndex - 1) / length(v)), length(power)) + 1;
    vIndex = mod(combinationIndex - 1, length(v)) + 1;


    % 得到系统参数组合
    currentPower = power(powerIndex);
    currentOrder = order(orderIndex);
    currentDLLDampingRatio = DLLDampingRatio_values(DLLDampingRatioIndex);
    currentDLLNoiseBandwidth = DLLNoiseBandwidth_values(DLLNoiseBandwidthIndex);
    currentV = v(vIndex); 

    %% 
    %接收机部分
    fSigDataGen(settings);

    %对于10dB 拉偏到2chips
    %测试dB 拉偏到1chips
    delay_cnt = 6/currentV; % 拉偏 delaycnt 范围 

    % 生成欺骗信号
    fCWIgen(settings, jam2, currentV, delay_cnt, currentPower);

    % 进行信号合成
    fDataComb(settings, jam1, jam2, jam3);

%     % 仿真数据文件名
%     combDataFileName = 'scenario1_Ant';   % 指定文件名（存放基带复信号数据）
%   
%     antiJamDataFileName = 'outputDataFileName';%不加抗干扰
% 
%     fSMI(settings, combDataFileName, antiJamDataFileName); 
% 
%         FileNameForAcq = antiJamDataFileName;
  

            % 仿真数据文件名
    combDataFileName = 'scenario1_Ant1';   % 指定文件名（存放基带复信号数据）
  
    FileNameForAcq = combDataFileName;


    acqResults = fMyAcquisition(settings, FileNameForAcq);
    
    [fidForAcq, message] = fopen(FileNameForAcq, 'r', 'ieee-be');  

    %跟踪
    if (any(acqResults.carrFreq))
        channel = preRun(acqResults, settings);
    else
        % No satellites to track, exit
        disp('No GNSS signals detected, signal processing finished.');
        trackResults = [];
        return;
    end  

    [trackResults, channel, flag, unlock] = fCnrEstV3(FileNameForAcq, channel, settings, currentDLLNoiseBandwidth, currentDLLDampingRatio, currentOrder, currentPower); 
%     toc
    plotTrackingfigure(channel, trackResults, settings);
    plotAcquisition(acqResults);


%     flag = randi([0, 1]); % 随机生成成功标志

    % 更新flag
    param_flag(combinationIndex) = param_flag(combinationIndex) + 1;
    
    % 构建参数描述字符串，现在包括v
    paramString = sprintf('power(%d)_order(%d)_DLLDampingRatio(%d)_DLLNoiseBandwidth(%d)_v(%.4f)', ...
        power(powerIndex), order(orderIndex), DLLDampingRatio_values(DLLDampingRatioIndex), DLLNoiseBandwidth_values(DLLNoiseBandwidthIndex), currentV);
    
    % 检查并添加参数描述到结构体
    if ~ismember(paramString, mapKeySet)
        mapKeySet{end+1} = paramString;
        param_stats(end+1).paramString = paramString;
        param_stats(end).successCount = 0;
        param_stats(end).totalCount = 0;
        param_stats(end).v_value = currentV; % 指定v的值
    end
    
    % 更新尝试总次数
    index = find(strcmp({param_stats.paramString}, paramString));
    param_stats(index).totalCount = param_stats(index).totalCount + 1;
    
    % 模拟成功条件并更新成功次数
    % flag = randi([0, 1]); % 随机生成成功标志
    if flag == 1
        param_stats(index).successCount = param_stats(index).successCount + 1;
    end
    
    param_stats(index).successRate = param_stats(index).successCount / param_stats(index).totalCount;


    % 每过1000次迭代更改一次参数组合，注意这里的逻辑也许需要根据实际需求调整
    if mod(test, trycnt) == 0
        groupCounter = groupCounter + 1;
    end

end