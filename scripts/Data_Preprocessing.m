clear all 
load('../data/opt.mat')

role_order  = {'p','o'};

for pair = 1:length(opt.participant_pair)
    
    clear player_continuous observer_continuous
    
    fprintf('EEG preprocessing for pair session %d: %s - %s \n',...
            pair,opt.participant_pair{pair,1},opt.participant_pair{pair,2})
    pair_session = {opt.participant_pair{pair,1},opt.participant_pair{pair,2}};

    %% load corrected event struct ['event_corrected_p','event_corrected_o']
    pair_evt = load([opt.event_path strjoin(pair_session,'_')]);
    
    %% start preprocessing
    for role = 1:length(role_order)
        
        clearvars EEG*
        role_file = pair_session{role};
        
        event    = pair_evt.(['event_corrected_' role_order{role}]);
        dat      = ft_read_data([opt.rawData_path role_file '.eeg']);
        hdr      = ft_read_header([opt.rawData_path role_file '.vhdr']);
        EEG      = fieldtrip2eeglab(hdr, dat, event);
        
        %% remove {Oz, EOGv1}
        % electrode 'Oz' in some sessions had connection issues during recording 
        % electrode 'EOGv1' is under the right eye, which is not useful in 
        % current artifact rejection scenario

        EEG_noOz = pop_select(EEG,'nochannel',{'Oz','EOGv1'});
        idx = find(strcmp({EEG_noOz.chanlocs.labels},'POz'));

        % rename {POz} to {PO4} for participant Player_sub03
        if ~isempty(idx) 
            EEG_noOz.chanlocs(idx).labels = 'PO4';
        end
        clab_orig{pair,role} = {EEG.chanlocs.labels};

        

        %% downsample data
        EEG_noOz = pop_resample(EEG_noOz,100);
            
        %% bandpass filter
        EEG_noOz = pop_eegfiltnew(EEG_noOz,1,49);
        
        %% import channel info and read electrode position
        locs_template = readlocs('Standard-10-5-Cap385_witheog.elp');
        
        % remove unecessary channels and keep the order
        locs_updated      = [];
        for chan = 1:length(EEG_noOz.chanlocs)    
            idx           = ismember({locs_template.labels},EEG_noOz.chanlocs(chan).labels);
            locs_updated  = [locs_updated locs_template(idx)];
        end
        EEG_noOz.chanlocs = locs_updated;
        
        %% clean line noise
        EEG_cline = cleanline(EEG_noOz);
        
        
        %% reject bad channels and remove occasional artifacts using ASR
        EEG_clean     = clean_artifacts(EEG_cline,'WindowCriterion','off',...
                                                  'BurstCriterion',20);   

        %%  save artifact channels (later used for rank calculation in ICA)
        clab_arti{pair,role} = setdiff({EEG_cline.chanlocs.labels},{EEG_clean.chanlocs.labels});
        clab_arti{pair,role+2} = pair_session{role};

        %% Interpolate channel 
        EEG_interp = pop_interp(EEG_clean, EEG_noOz.chanlocs, 'spherical');
        
        %% Rereference to average(CAR)
        EEG_reref = fullRankAveRef(EEG_interp);
        
        
        %% Rename string event (e.g. 'S 12') to number event (e.g. [12])
        number_events          = cellfun(@(str) ...
                                str2double(str(2:end)), ...
                                {EEG_reref.event.type}, ...
                                'UniformOutput', false);
        EEG_rnevt              = EEG_reref;
        EEG_rnevt.event        = rmfield(EEG_reref.event,'type');
        [EEG_rnevt.event.type] = number_events{:};
        
         
        %% sumarize output data for this role
        EEG_continuous          = EEG_rnevt;
        EEG_continuous.filepath = [opt.rawData_path];
        EEG_continuous.filename = role_file;
        EEG_continuous.pairname = strjoin(pair_session,'_');

        
        eval([opt.session_role{role} '_continuous    = EEG_continuous;'])
    end
    save([opt.continuous_path strjoin(pair_session,'_') '.mat'], 'player_continuous','observer_continuous')
    
end    
save([opt.preprocessing_path  'clab_arti.mat'],'clab_arti')