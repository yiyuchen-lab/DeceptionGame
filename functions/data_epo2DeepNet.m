
function  [data_X,data_y_player,pair_num, dataCh] = data_epo2DeepNet(epos_player,epos_observer,session_role)

% BBCI data format:
% epo.x           -  timesteps x channels x trials
% epo.y           -  classes x trials
%
% convert to data format:
% dataX           -  EEG data 
%                    [pariticipant x trials] x channels x timesteps x role
% pair_num        -  Participant pair session number (1~23)
%                    1 x [pariticipant x trials]  
% data_y_player   -  numeric trial label 
%                    1 x [pariticipant x trials]

    
for role = 1:length(session_role)
    epos   = eval(['epos_' session_role{role}]);
    X_cell = cellfun(@(epo) permute(epo.x,[3,2,1]), epos, 'UniformOutput', false);
    y_cell = cellfun(@(epo) label2ind(epo.y), epos, 'UniformOutput', false);

    eval(['data_X_' session_role{role} '= cat(1,X_cell{:});'])
    eval(['data_y_' session_role{role} '= cat(2,y_cell{:});'])
    
end
pair_num = cellfun(@(y,num) ones(1,length(y))*num, ...
                     y_cell, num2cell(1:length(y_cell)),...
                     'UniformOutput', false);
                 
pair_num = cat(2,pair_num{:});
dataCh = epos_player{1}.clab;
data_X = cat(4,data_X_player,data_X_observer);
if ~isequal(data_y_player,data_y_observer)
    warning('player and observer event is inconsistent!')
end

