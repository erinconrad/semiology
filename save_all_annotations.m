overwrite = 0;

%% Get locations
locations = semiology_locs;
main_folder = locations.main_folder;
results_folder = [main_folder,'results/'];
scripts_folder = locations.script_folder;
ieeg_folder = locations.ieeg_folder;
ieeg_pw_file = locations.ieeg_pw_file;
ieeg_login = locations.ieeg_login;
addpath(genpath(scripts_folder))

%% Define annotation file
annotation_file = [results_folder,'annotations/annotations.csv'];

%% If no overwrite, just start at (and redo) last patient in table
if overwrite == 0
    T = readtable(annotation_file);
    nrows = size(T,1);
    if nrows == 0
        curr_num = 64;
    else
        last_hup_id = T.HUPID{nrows};
        curr_num = str2double(regexp(last_hup_id,'\d+','match'));
    
        % remove all rows for that hup id, start there
        T(strcmp(T.HUPID,last_hup_id),:) = [];
    end
    
else
    curr_num = 64; % starting number
end

% Loop over HUP numbers
i = 64;%curr_num; 
last_num = 280;
while 1
    hupid = sprintf('HUP%d',i);

    fprintf('\nDoing %s\n',hupid);

    %% Try a few different ways to find ieeg files for this patient
    % Say I have not found the patient
    found_pt = 0;

    % Make base name
    if ismember(i,[69,71,76,77,93,94,96,97,98])
        base_ieeg_name = sprintf('HUP0%d_phaseII',i);
    else
        base_ieeg_name = sprintf('HUP%d_phaseII',i);
    end

    % Initialize stuff for ieeg files
    dcount = 0; % which file
    add_it = 0; % should I add info
    finished = 0; % done with pt
    
    while 1
        if dcount == 0
            
            % Try to get ieeg file with just the base name
            ieeg_name = base_ieeg_name;
            
            try
                session = IEEGSession(ieeg_name,ieeg_login,ieeg_pw_file);
                finished = 1;
                add_it = 1;
                dcount = 1;
            catch
                
                fprintf('\nDid not find %s, adding an appendage\n',ieeg_name);
                if exist('session','var') ~= 0
                    session.delete;
                end
                
            end
            
        else % if dcount > 0, trying appendage
            % Try it with an appendage
            ieeg_name = [base_ieeg_name,'_D0',sprintf('%d',dcount)];
            try
                session = IEEGSession(ieeg_name,ieeg_login,ieeg_pw_file);
                finished = 0;
                add_it = 1;
            catch
                add_it = 0;
                finished = 1; % if I can't find it adding appendage, nothing else to check
            end
            
        end

        % Get annotations for that file name
        if add_it == 1

            % Open the annotation table
            T = readtable(annotation_file);
            
            clear ann
            % Add annotations
            n_layers = length(session.data.annLayer);

            for ai = 1:n_layers
                clear event
                a=session.data.annLayer(ai).getEvents(0);
                n_ann = length(a);
                for k = 1:n_ann

                    % Add annotations
                    curr_anns = {hupid,ieeg_name,a(k).start/(1e6),a(k).stop/(1e6),...
                        a(k).type,a(k).description};
                    
                    T = [T;curr_anns];
                end
            end
            
            found_pt = 1; % say I found the patient

            % overwrite the annotation table
            writetable(T,annotation_file);

        end

        % done with patient
        if finished == 1
            if exist('session','var') ~= 0
                session.delete;
            end
            break % break out of ieeg loop for that patient
        end

        dcount = dcount + 1; % if not finished, see if another appendage
        if exist('session','var') ~= 0
            session.delete;
        end

    end

    % advance count regardless
    i = i + 1;
    if i > last_num
        break
    end

end

