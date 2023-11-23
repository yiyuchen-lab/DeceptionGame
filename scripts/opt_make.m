
%% -------------------  participant information -------------------

opt.session_role = {'player','observer'};
opt.epoch_type   = {'DecisionMaking','Feedback'};

opt.participant_pair = {'Player_sub01',	'Observer_sub02';
                        'Player_sub03',	'Observer_sub06';
                        'Player_sub04',	'Observer_sub05';
                        'Player_sub05',	'Observer_sub04';
                        'Player_sub06',	'Observer_sub03';
                        'Player_sub07',	'Observer_sub08';
                        'Player_sub08',	'Observer_sub07';
                        'Player_sub09',	'Observer_sub10';
                        'Player_sub10',	'Observer_sub09';
                        'Player_sub11',	'Observer_sub12';
                        'Player_sub12',	'Observer_sub11';
                        'Player_sub13',	'Observer_sub14';
                        'Player_sub14',	'Observer_sub13';
                        'Player_sub15',	'Observer_sub16';
                        'Player_sub16',	'Observer_sub15';
                        'Player_sub17',	'Observer_sub18';
                        'Player_sub18',	'Observer_sub17';
                        'Player_sub19',	'Observer_sub22';
                        'Player_sub20',	'Observer_sub21';
                        'Player_sub21',	'Observer_sub20';
                        'Player_sub22',	'Observer_sub19';
                        'Player_sub23',	'Observer_sub24';
                        'Player_sub24',	'Observer_sub23'};

%% ------------------- check toolboxes in search path -------------------

% Specify your toolbox location here
eeglabpath = [getenv('HOME') '/Documents/MATLAB/toolbox/eeglab2023.1'];
bbcipath   = [getenv('HOME') '/Documents/MATLAB/toolbox/bbci_old'];

if ~ismember(eeglabpath,regexp(path,pathsep,'Split'))
    addpath(eeglabpath)
    eeglab
    close all
end

ft_defaults 

if ~ismember(bbcipath,regexp(path,pathsep,'Split'))
    addpath(genpath(bbcipath))
    close all
end

addpath('../functions')

%% -------------------  prepare folder   ------------------

% download the dataset in the data folder
opt.rawData_path           ='../data/Dataset/Raw/';
opt.preprocessedData_path  ='../data/Dataset/Preprocessed/';


opt.intermediate_data_path ='../data/';
opt.figure_path            ='../fig/';

opt.event_path         = [opt.intermediate_data_path 'Corrected_event/'];
opt.OneDCNN_path       = [opt.intermediate_data_path 'OneDCNN/data/'];
opt.preprocessing_path = [opt.intermediate_data_path 'Preprocessing/'];
opt.continuous_path    = [opt.preprocessing_path     'continuous/'];
opt.ica_path           = [opt.preprocessing_path     'ICA_components/'];

% create folder to store intermediate data
if ~exist(opt.intermediate_data_path, 'dir')
   mkdir(opt.intermediate_data_path)
end


% create folder to store intermediate data
if ~exist(opt.figure_path, 'dir')
   mkdir(opt.figure_path)
end

% create folder to store event data
if ~exist(opt.event_path, 'dir')
   mkdir(opt.event_path)
end

% create folder to store preprocessed continuous data 
if ~exist(opt.continuous_path, 'dir')
   mkdir(opt.continuous_path)
end

% create folder to store ICA components data 
if ~exist(opt.ica_path, 'dir')
   mkdir(opt.ica_path)
end

% create folder to store OneDCNN data 
if ~exist(opt.OneDCNN_path, 'dir')
   mkdir(opt.OneDCNN_path)
end

% create folder to store preprocessed epoch data 
if ~exist([opt.preprocessedData_path opt.epoch_type{1}], 'dir')
   mkdir([opt.preprocessedData_path opt.epoch_type{1}])
end
if ~exist([opt.preprocessedData_path opt.epoch_type{2}], 'dir')
   mkdir([opt.preprocessedData_path opt.epoch_type{2}])
end




%% -------------------  trigger information -------------------


opt.eegmarker_num.showCross       = 21;
opt.eegmarker_num.showCard        = [30,31,32,33]; % sponL, sponT, instT, instL
opt.eegmarker_num.playerInp_start = 40;
opt.eegmarker_num.playerInp       = [51:56, 61:66]; 
opt.eegmarker_num.obserInp_start  = 41;
opt.eegmarker_num.obserInp        = [71,72];
opt.eegmarker_num.result_obsCor   = [101,102]; % correct, incorrect

opt.eegmarker_label.showCard       = {'sponL', 'sponT', 'instT', 'instL'};
opt.eegmarker_label.playerInp      = [strcat(repmat({'lie_input_'},1,6), ...
                                           arrayfun(@num2str, (1:6),'UniformOutput', 0)),...
                                     strcat(repmat({'truth_input_'},1,6), ...
                                           arrayfun(@num2str, (1:6),'UniformOutput', 0))]; 
opt.eegmarker_label.obserInp       = {'lie', 'truth'};
opt.eegmarker_label.result_obsCor  = {'Correct','Incorrect'};


opt.eegmarker_str.showCross       = 'S 21';
opt.eegmarker_str.showCard        = {'S 30','S 31','S 32','S 33'};
opt.eegmarker_str.playerInp_start = 'S 40';
opt.eegmarker_str.playerInp       = {'S 51','S 52','S 53','S 54','S 55','S 56',...
                                     'S 61','S 62','S 63','S 64','S 65','S 66'};
opt.eegmarker_str.obserInp_start  = 'S 41';
opt.eegmarker_str.obserInp        = {'S 71','S 72'};
opt.eegmarker_str.result_obsCor   = {'S101','S102'};

opt.eegmarker_num.complete_trial_events  = {opt.eegmarker_num.showCross,...
                                            opt.eegmarker_num.showCard,...
                                            opt.eegmarker_num.playerInp_start,...
                                            opt.eegmarker_num.playerInp,...
                                            opt.eegmarker_num.obserInp_start,...
                                            opt.eegmarker_num.obserInp,...
                                            opt.eegmarker_num.result_obsCor};
                                    
opt.eegmarker_str.complete_trial_events  = {opt.eegmarker_str.showCross,...
                                            opt.eegmarker_str.showCard,...
                                            opt.eegmarker_str.playerInp_start,...
                                            opt.eegmarker_str.playerInp,...
                                            opt.eegmarker_str.obserInp_start,...
                                            opt.eegmarker_str.obserInp,...
                                            opt.eegmarker_str.result_obsCor};

                                        
opt.eegmarker_num.eventOrder = {'showCross','showCard','playerInp_start',...
                                'playerInp','obserInp_start','obserInp','result_obsCor'};
                                                                    
opt.eegmarker_str.eventOrder = {'showCross','showCard','playerInp_start',...
                                'playerInp','obserInp_start','obserInp','result_obsCor'};
                            


%% save option
save([opt.intermediate_data_path 'opt.mat'],'opt')




