function [segemented_trial,other_events,trial_dur,deleted_events,deleted_trial] = Event_removeIncompleteTrials(event,complete_trial_events)

event_value = {event.value};
event_sampe = [event.sample];
result_idx = find(ismember({event.value},{'S101', 'S102'}));
roundRlt_idx = find(ismember({event.value},{'S104','S105','S106'}));
finalRlt_idx = find(ismember({event.value},{'S107','S108','S109'}));
trial_dur = zeros(1,484);
deleted_trial = [];
preserved_trial_idx = [];
segemented_trial={};

if length(result_idx)==484
    
    for trial_i = 1:length(result_idx)
        
        position = result_idx(trial_i);
        while ~strcmp(event_value{position},'S 21')
            position = position - 1;
        end
        trial_dur(trial_i) = event_sampe(result_idx(trial_i))-event_sampe(position);
        
        %% make sure all trial events only occur once
        trial_events = event_value(position:result_idx(trial_i));
        trial_events = cell2mat(cellfun(@(str) ...
                            str2double(str(2:end)), ...
                            trial_events, ...
                            'UniformOutput', false));
        event_occur_count = [];
        for e = 1:length(trial_events)
            event_occur_count = [event_occur_count;
                                 cell2mat(cellfun(@(evts) ...
                                 any(ismember(trial_events(e),evts)),...
                                 complete_trial_events,'UniformOutput', ...
                                 false))];
        end
        if max(sum(event_occur_count,1))==1
            preserved_trial_idx       = [preserved_trial_idx, position:result_idx(trial_i)];
            segemented_trial{trial_i} = event(position:result_idx(trial_i));
        else
            deleted_trial = [deleted_trial trial_i];
        end
        
        
    end
    
    %  keep round and final result trigger
    other_events   = event(sort([roundRlt_idx finalRlt_idx]));
    deleted_events = setdiff(1:length(event),...
                             [preserved_trial_idx roundRlt_idx finalRlt_idx]);
    
 
end
