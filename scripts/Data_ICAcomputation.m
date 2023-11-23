clear all 
load('../data/opt.mat')
load([opt.intermediate_data_path 'clab_arti.mat'])



for pair = 1:length(opt.participant_pair)
    
    clear data_pair EEG
    
    fprintf('Computing ICA for pair session %d: %s - %s \n',...
            pair,opt.participant_pair{pair,1},opt.participant_pair{pair,2})
    pair_session = {opt.participant_pair{pair,1},opt.participant_pair{pair,2}};
    
    %% load continuous data
    data_pair    = load([opt.continuous_path strjoin(pair_session,'_')]);
    
     
    for role = 1:length(opt.session_role)
       
        EEG = data_pair.([opt.session_role{role} '_continuous']);
        
        %% calculate ICA
        rank_num              = 30-length(clab_arti{pair,role});
        [weights,sphere,mods] = runamica15(EEG.data,'pcakeep',rank_num, ...
                                                    'max_threads',14);
        
        EEG.icaweights = weights;
        EEG.icasphere = sphere(1:size(weights,1),:);
        EEG.icawinv = mods.A(:,:,1);
        EEG.mods = mods;
        
        pop_saveset( EEG, 'filename',['[' strjoin(pair_session,'_') ']_', ...
                          opt.session_role{role}], ...
                          'filepath', opt.ica_path);

        
    end            
       
end