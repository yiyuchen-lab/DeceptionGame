clear all 
load('../data/opt.mat')



for pair = 1:length(opt.participant_pair)
    
    clear segemented_trial_p segemented_trial_o event_no_error_p event_no_error_o
    
    fprintf('Event correction for pair session %d: %s - %s \n',...
            pair,opt.participant_pair{pair,1},opt.participant_pair{pair,2})
      
    event_orig_p = ft_read_event([opt.rawData_path opt.participant_pair{pair,1} '.vmrk']);
    event_orig_o = ft_read_event([opt.rawData_path opt.participant_pair{pair,2} '.vmrk']);
    
    %% clear 'comment' triggers
    [event_p,deleted_comments_p] = Event_clearComments(event_orig_p,0);
    [event_o,deleted_comments_o] = Event_clearComments(event_orig_o,0);
    
    %% remove imcomplete trials (due to trigger missing)
    [segemented_trial_p,...
     otherEvent_p,....
     trial_dur_p,...
     deleted_events_p,...
     deleted_trial_p] = Event_removeIncompleteTrials(event_p,opt.eegmarker_num.complete_trial_events);
 
    [segemented_trial_o,...
     otherEvent_o,...
     trial_dur_o,...
     deleted_events_o,...
     deleted_trial_o] = Event_removeIncompleteTrials(event_o,opt.eegmarker_num.complete_trial_events);
    
    %% Remove 'deleted_trial' from both the player and the observer's data if it is present in either's data.
    if ~isempty(deleted_trial_p) || ~isempty(deleted_trial_o)
        trial_to_delete    = [deleted_trial_p,deleted_trial_o];
        indx = true(1,484);
        indx(trial_to_delete)=false;
        
        cat_trial_p = cat(2,segemented_trial_p{indx});
        cat_trial_o = cat(2,segemented_trial_o{indx});
        
    else
        cat_trial_p = cat(2,segemented_trial_p{:});
        cat_trial_o = cat(2,segemented_trial_o{:});
    end
    
    %% make sure round and final result event is consistent
    % 11 (round result) + 1(final result) = 12
    if (length(otherEvent_o)==12 && length(otherEvent_p)==12)
        event_no_error_p = [cat_trial_p,otherEvent_p];
        event_no_error_o = [cat_trial_o,otherEvent_o];

       % sort in chronological order
       [~,order_p] = sort([event_no_error_p.sample]);
       [~,order_o] = sort([event_no_error_o.sample]);

       event_no_error_p = event_no_error_p(order_p);
       event_no_error_o = event_no_error_o(order_o);

    else
        warning('round or final result trigger is missing.')

    end
    %% Verify the delay in sampling time for each EEG event for both roles
    trial_p_sample=[event_no_error_p.sample];
    trial_o_sample=[event_no_error_o.sample];

    p=trial_p_sample-trial_p_sample(1);
    o=trial_o_sample-trial_o_sample(1);
    
    delay = p-o;
    % histogram(p-o)
    % close all
    % check_event(event_no_error_p,opt,1)
    % check_event(event_no_error_o,opt,1)
    
    
    %% modify event
    
    event_corrected_p = event_no_error_p;
    event_corrected_o = event_no_error_o;

    % stimulus
    % create sponL from spontaneous events according to 
    % sponL response (trigger numbser: 5x)
    % old: spon 31 --> new: sponL 30, sponT 31
    % (keep instL 32, instT 33)   
    for idx = 1:length(event_no_error_p) 
        if isequal(event_no_error_p(idx).value, 'S 31')
            trigger = event_no_error_p(idx+2).value;
            if isequal(trigger(1:3),'S 5')
                event_corrected_p(idx).value = 'S 30';
            end
        end
    end
    for idx = 1:length(event_no_error_o) 
        if isequal(event_no_error_o(idx).value, 'S 31')
            trigger = event_no_error_o(idx+2).value;
            if isequal(trigger(1:3),'S 5')
                event_corrected_o(idx).value = 'S 30';
            end
        end
    end
    

    % % Response input (uncomment to use):
    % % old: 5x(lie input) 6x(true input)
    % % new: 5x(sponL) 6x(sponT) 15x(instT) 16x(instL)
    % 
    % for idx = 1:length(event_no_error) 
    %     trigger = event_no_error(idx).value;
    %     if isequal(trigger(1:3), 'S 5') | isequal(trigger(1:3), 'S 6');
    %         stim = event_no_error(idx-2).value;
    %         if isequal(stim, 'S 30')
    %            event_modified(idx).value = ['S 5' trigger(end)];
    %         elseif isequal(stim, 'S 31')
    %            event_modified(idx).value = ['S 6' trigger(end)]; 
    %         elseif isequal(stim, 'S 33')   
    %            event_modified(idx).value = ['S15' trigger(end)];
    %         elseif isequal(stim, 'S 32')   
    %            event_modified(idx).value = ['S16' trigger(end)]; 
    %         end
    %     end
    % end
    save([opt.event_path opt.participant_pair{pair,1} '_' ,opt.participant_pair{pair,2} '.mat'],'event_corrected_o','event_corrected_p','delay')

end



