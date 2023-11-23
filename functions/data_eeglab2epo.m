function  data_epo = data_eeglab2epo(data_eeglab, event_eeglab,classname)

 
% EPO struct
% .fs	        sampling rate [samples per second]
% .x	        multichannel signals (DOUBLE [T #channels #epochs]) where T is the number of samples within one epoch
% .clab	        channel labels (CELL {1 #channels})
% .y	        class labels (DOUBLE [#classes #epochs])
% .className	class names (CELL {1 #classes})
% .t	        time axis (DOUBLE [1 T])
% .event	    structure of further information; each field of epo.event provides information that is specified for each event, given in arrays that index the events in their first dimension. This is required such that functions like epo_selectEpochs can work properly on those variables.
% .mrk_info	    structure for other additional information copied from mrk
% .cnt_info	    structure for additional information copied from cnt
%  

if ~isempty(event_eeglab)
    event = event_eeglab;
else
    event = [event_eeglab.event.type];
    if length(event)>length(data_eeglab.epoch)
        warning('event length inconsistent')
    end
end

data_epo.fs        = data_eeglab.srate;
data_epo.x         = double(permute(data_eeglab.data,[2,1,3]));
data_epo.clab      = {data_eeglab.chanlocs.labels};
data_epo.y         = ind2label(event-min(event)+1);
data_epo.className = classname;
data_epo.t         = data_eeglab.times;
data_epo.filename  = data_eeglab.filename;
end