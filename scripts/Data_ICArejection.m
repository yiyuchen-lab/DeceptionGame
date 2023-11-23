clear all 
load('../data/opt.mat')


for typeName = opt.epoch_type

    players   = {};
    observers = {};
    
    %% define epoch
    if strcmp(typeName,'DecisionMaking')
        event_name ='showCard';
        time_interval     = [-0.5, 3]; 
    elseif strcmp(typeName,'Feedback')
        event_name ='result_obsCor'; 
        time_interval     = [-0.2 1]; 
    end
    event_number = opt.eegmarker_num.(event_name);
    event_label  = opt.eegmarker_label.(event_name);
    
    %% create path
    save_path = [opt.preprocessedData_path char(typeName)];
    if ~exist(save_path, 'dir')
       mkdir(save_path)
    end

    %% ---------------------------ICA Rejection --------------------------
    
    for pair = 1:length(opt.participant_pair)
        
        clear player observer 
         
        fprintf('Rejecting ICA components for pair session %d: %s - %s \n',...
                pair,opt.participant_pair{pair,1},opt.participant_pair{pair,2})
        pair_session = {opt.participant_pair{pair,1},opt.participant_pair{pair,2}};
        
        for role = 1:length(opt.session_role)
        
            %% load EEG dataset
            EEG =  pop_loadset('filename',['[' strjoin(pair_session,'_') ']_' opt.session_role{role} '.set'],...
                               'filepath',  opt.ica_path);
            
            %% automatica component rejection using (ICLabel)
            EEG       = iclabel(EEG, 'default');
            EyeIdx    = find(strcmp(EEG.etc.ic_classification.ICLabel.classes,'Eye'));
            goodIcIdx = find(EEG.etc.ic_classification.ICLabel.classifications(:,EyeIdx) < 0.7);
            
            if size(EEG.icasphere,1) == length(goodIcIdx)
                EEG_ica = EEG;
            else
                EEG_ica   = pop_subcomp(EEG, goodIcIdx,0,1);
            end
            
            %% epoch data
            EEG_selected = pop_selectevent(EEG,'type',event_number, 'deleteevents','on');
            EEG_epoch    = pop_epoch(EEG_selected,{},time_interval);      
            
            %% baseline correction
            EEG_baseline = pop_rmbase(EEG_epoch,[time_interval(1)*1000 0]);
            
            %% convert to BBCI toolbox format
            event = [EEG_baseline.event.type];
            event = event(ismember(event,event_number));
            epo   = data_eeglab2epo(EEG_baseline,event,event_label);
            
            
            %% sumarize output data for this role
            pair_r = opt.session_role{role};
            eval([pair_r '=epo;']);
            
        end
        players   = [players player];
        observers = [observers observer];
        save([save_path '/' strjoin(pair_session,'_')],'player','observer')
    
    end
    
    %% ----------------- convert for 1DCNN classification -----------------
    [data_X,data_y,pair_num, dataCh] = data_epo2DeepNet(players,observers, opt.session_role);
    participant_pairs = opt.participant_pair;
    className         = event_label;
    save([opt.OneDCNN_path char(typeName) '.mat'],'data_X','data_y','pair_num','dataCh','className','participant_pairs')
end