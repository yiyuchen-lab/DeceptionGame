            
function [event_no_error,deleted_events] = Event_clearComments(event_orig,verbose) 
            

            deleted_events.newSegment    = [];
            deleted_events.overflow      = [];
            deleted_events.Comment       = [];
            deleted_events.deleteOrder   = {};
            
            %% delete "new segement" comment
            
            new_segment = cellfun(@isempty,{event_orig.value});
            delete_data_idx = find(new_segment==1);
            event = event_orig ;
            event(delete_data_idx) = [];
            deleted_events.newSegment = delete_data_idx;
            deleted_events.deleteOrder{end+1}='newSegment';
                                      
            
            %% find overflow comment

            id_overflow = find(ismember({event.value},'Buffer Overflow'));
            id_trial_start = find(ismember({event.value},'S 21'));
            trial_dur  = [3500,6100];
            
            irrelevent_event = [110,111,120,121,20];% roundShow,break_start/end,experiment_start/end
            irrelevent_idx = find(ismember(cell2mat(cellfun(@(str) ...
                                                str2double(str(2:end)), ...
                                                {event.value}, ...
                                                'UniformOutput', false)),...
                                            irrelevent_event));

            indices_delete = [];

            if ~isempty(id_overflow)
                for of_trial = 1:length(id_overflow)
                    fprintf('%dth overflow: id%d\n',of_trial,id_overflow(of_trial))
                    
                    % get events in trial ahead and behind [overflow]
                    % ** if there is any buffer overflow event, it
                    % should occur at previous_trial **
                    previous_trial_start = id_trial_start(find(id_trial_start<id_overflow(of_trial),1,'last'));
                    previous_trial_end   = id_trial_start(find(id_trial_start>id_overflow(of_trial),1,'first'))-1;
                    next_trial_start = previous_trial_end+1;
                    next_trial_end   = id_trial_start(find(id_trial_start>next_trial_start,1,'first'))-1;

                    previous_trial_evtIdx = previous_trial_start:previous_trial_end;
                    previous_trial_evtIdx=previous_trial_evtIdx(~ismember(previous_trial_evtIdx,irrelevent_idx));
                    is_overflow = ismember(previous_trial_evtIdx,id_overflow(of_trial));
                    overflow_inside_trial = find(is_overflow)~=length(is_overflow)&&any(is_overflow);
                    previous_trial_evtIdx = previous_trial_evtIdx(~is_overflow);
                    

                    next_trial_evtIdx = next_trial_start:next_trial_end; 
                    next_trial_evtIdx=next_trial_evtIdx(~ismember(next_trial_evtIdx,irrelevent_idx));
                    next_trial_evtIdx = next_trial_evtIdx(~ismember(next_trial_evtIdx,id_overflow(of_trial)));
                    
                    if verbose
                        % get trial durations
                        previous_trial_length = range([event(previous_trial_evtIdx).sample]);
                        next_trial_length     = range([event(next_trial_evtIdx).sample]);

                        fprintf('previous %d [ms]  >> \n', previous_trial_length)
                        disp({event(previous_trial_evtIdx).value})
                        disp(diff([event(previous_trial_evtIdx).sample]*2))

                        fprintf('next %d [ms]  >> \n',next_trial_length)
                        disp({event(next_trial_evtIdx).value})
                        disp(diff([event(next_trial_evtIdx).sample]*2))
                    end
                   
                    indices_delete = [indices_delete,previous_trial_evtIdx,next_trial_evtIdx] ;
                end
                indices_delete = [indices_delete, id_overflow];
                event(indices_delete)=[];
                deleted_events.overflow = indices_delete;
            end
            deleted_events.deleteOrder{end+1}='overflow';


            
            %% delete other comment events and log the comment type
            
            comment_index  = ismember({event.type},'Comment');
            comment_values = {event.value};
            delete_values  = unique(comment_values(comment_index));
            delete_index   = {};
            for val_idx = 1:length(delete_values)
                delete_index{val_idx} = find(ismember(comment_values,delete_values{val_idx}));
            end
            
            event(cell2mat(delete_index))=[];
            deleted_events.Comment.value = delete_values;
            deleted_events.Comment.index = delete_index;
            deleted_events.deleteOrder{end+1}='Comment';
            
            event_no_error = event;
end
        