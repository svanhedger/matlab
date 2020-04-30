function toneCloud(numClouds, numDeviants, duration, dnameoutput)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Generate Tone Clouds %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% This function generates 'tone clouds' similar to those described
% in Ding et al. (2018) J. Neurosci.
%
% The function has four arguments.
%
% 1. numClouds = how many cloud stimuli to generate
%
% 2. numDeviants = how many deviants should the 3 Hz tone contain?
%
% 3. length = the length of the tone clouds (in seconds)
%
% 4. dnameoutput = output directory. If not provided in the function, a GUI
% will pop up asking you to select the location where the normalized files
% should be saved 
%
% Stephen Van Hedger, October 2019
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% clear workspace, variables
clc;
clearvars;

%% ask for essential variables if not specified

if ~exist('dnameoutput', 'var') || isempty(dnameoutput)
    dnameoutput = uigetdir(path, 'SELECT A DIRECTORY FOR OUTPUT FILES'); % select output directory
end

if ~exist('duration', 'var') || isempty(duration)
    prompt = sprintf('Duration of tone clouds (in seconds)?\n\n = ');
    duration = input(prompt);
end

if ~exist('numClouds', 'var') || isempty(numClouds)
    prompt = sprintf('How many tone clouds do you want to generate?\n\n = ');
    numClouds = input(prompt);
end

if ~exist('numDeviants', 'var') || isempty(numDeviants)
    prompt = sprintf('How many deviations should the steady tone contain?\n\n = ');
    numDeviants = input(prompt);
end

%% set up basic, constant attributes for the tones

% general
Fs = 44100; % sampling rate
Ts=1/Fs; % time-step for each sample

% stable tone
T=0.075; % specify duration of the tones (75 milliseconds)
t=0:Ts:T; % specify the number of samples for each tone
window = tukeywin(length(t), 0.25)'; %specify a cosine ramped envelope 

% silence for stable tone
Tsilence = 0.258333333; % 333ms - 75ms (to achieve 3Hz rate)

% specify the target frequency min/max range
Frq_min = 512;
Frq_max = 1024;

%define general attributes of the cloud stim timing
cloudBegin = 0.5; %offset (in seconds) from the standard tones
cloudDensity = 50; %number of distractor tones per second

%establish object that will store stimulus info
cloudInfo{1,1} = 'Target_Hz';
cloudInfo{1,2} = 'Num_Deviants';
cloudInfo{1,3} = 'Deviant_Loc';
cloudInfo{1,4} = 'File_Name';

%% This is the overarching loop that will generate 'numCloud' sounds
for a = 1:numClouds
%randomly choose the target frequency from specified min/max range
Target_Frq = round((Frq_max-Frq_min).*rand(1,1) + Frq_min);

%set up ranges for the clouds based on target frequency
cloudHigh_min = Target_Frq*1.5; %min range of cloud high
cloudHigh_max = Target_Frq*5; %max range of cloud high
cloudLow_min = Target_Frq*0.20; %min range of cloud low
cloudLow_max = Target_Frq*0.75; %max range of cloud low

cloudHigh_array = round((cloudHigh_max-cloudHigh_min).*rand(round((duration-0.5)*(cloudDensity/2)),1) + cloudHigh_min)';
cloudLow_array = round((cloudLow_max-cloudLow_min).*rand(round((duration-0.5)*(cloudDensity/2)),1) + cloudLow_min)';

cloudFinal_array = [cloudHigh_array, cloudLow_array];
cloudFinal_array = cloudFinal_array(randperm(length(cloudFinal_array)));

%% Create the clouds!

%set up empty vectors
cloudSilence = zeros(1, length(round(0:Ts:cloudBegin))-1); %silence for the length of cloudBegin
cloudSound = zeros(1, ((duration)*Fs));

%main loop
for i = 1:length(cloudFinal_array)
    if i == 1
        startPoint = 0;
    else
        startPoint = round(Fs*(1/(cloudDensity)*(i-1)));
    end
    yC = sin(2*pi*cloudFinal_array(i)*t); %make the i-th tone
    yC = yC.*window; %shape it by the cosine window
    tempVec = zeros(1, startPoint);%pad the onset accordingly
    tempVec = [tempVec, yC]; %add the tone
    endPad = zeros(1, length(cloudSound)-length(tempVec)); %end padding for addition
    tempVec = [tempVec, endPad]; %final representation of the tone in the array
    
    cloudSound = cloudSound + tempVec; %add everything to the cloud sound
    
end

cloudSoundFinal = [cloudSilence, cloudSound];


%% Create the 3Hz targets!
targetY = []; %array for the targets
totalTargets = duration*3; %number of steady beats in the cloud
targetDeviants = zeros(1, totalTargets); %zeros for length of num beats

deviantLoc = round(((totalTargets-10)-(10)).*rand(numDeviants,1) + (10));

%while loop to make sure deviants are separated by min 1s w/in range
while numDeviants > 1 && (max(deviantLoc) - min(deviantLoc)) < 3
    deviantLoc = round(((totalTargets-10)-(10)).*rand(numDeviants,1) + (10));
end    

%for loop to mark the locations of the deviant stimuli
for i = 1:length(targetDeviants)
    searchDev = find(deviantLoc == i, 1);
    if isempty(searchDev)
        targetDeviants(i) = 0;
    else
        targetDeviants(i) = 1;
    end
end

%main for loop to generate the isochronous stimuli
for i = 1:length(targetDeviants)
    if targetDeviants(i) == 0
        Y = sin(2*pi*Target_Frq*t);
        Y = Y.*window;
    else
        Y = sin(2*pi*(Target_Frq*1.122462)*t); %increase Hz by 2 semitones
        Y = Y.*window;
    end
    Y0 = zeros(1, round(Fs*Tsilence));  % Silent Interval
    Ys = repmat([Y Y0], 1, 1); % Full Tone With Silent Interval
    targetY = [targetY, Ys];   
end

%% Combine the tone cloud and the target streams!

%ramp the noises at very end (100ms) so there is no clip
cloudRamp = [linspace(1, 1, Fs*(duration-0.1)), linspace(1, 0, (Fs*0.1))];

%apply the 100ms fadeout to the cloud stream
cloudSoundFinal = cloudSoundFinal(1:length(targetY));
cloudSoundFinal = cloudSoundFinal.*cloudRamp;

%actually combine the two, rescale amplitude
combinedSoundFinal = rescale(targetY + cloudSoundFinal, -1, 1);


%write sound to specified directory
cd(dnameoutput);
Filename = ['toneCloud_',sprintf('%02d',duration), '_', sprintf('%02d',numDeviants), '_', sprintf('%02d',a), '.wav'];
audiowrite(Filename, combinedSoundFinal, Fs);

%write sound info as csv file to directory
INFO_FileName{a,1} = Filename;
INFO_TargetHz{a,1} = Target_Frq;
INFO_numDeviants{a,1} = numDeviants;
INFO_deviantLoc{a,1} = deviantLoc;

end

%%write file information to a csv
FilenameText = ['toneCloud_',sprintf('%02d',duration), '_', sprintf('%02d',numDeviants), '_INFO', '.csv'];
cloudTable = table(INFO_FileName, INFO_TargetHz, INFO_numDeviants, INFO_deviantLoc);
writetable(cloudTable, FilenameText);

end