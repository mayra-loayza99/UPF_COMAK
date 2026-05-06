```matlab
function Activations = plot_activations_save_data(project_id, numeric_id)
% PLOT_ACTIVATIONS
% Generates plots AND saves structured muscle activation data

    %% Directories
    muscle_outputDir = ['../results/' project_id '_' numeric_id '/graphics/muscle_activations'];
    reserve_outputDir = ['../results/' project_id '_' numeric_id '/graphics/reserve_actuators'];

    if ~exist(muscle_outputDir, 'dir'); mkdir(muscle_outputDir); end
    if ~exist(reserve_outputDir, 'dir'); mkdir(reserve_outputDir); end

    %% Load data
    file_path = ['../results/' project_id '_' numeric_id '/comak/walking_' numeric_id '_activation.sto'];

    try
        [act_data, act_labels, ~] = read_opensim_mot(file_path);
    catch
        error(['Could not load data from: ' file_path]);
    end

    %% Normalize time
    act_time = act_data(:,1);
    act_time_norm = (act_time - act_time(1)) / (act_time(end)-act_time(1)) * 100;
    time_100 = linspace(0,100,100);

    %% Labels
    muscles = {... % (igual que tu lista original)
        'addbrev_r','addlong_r','addmagProx_r','addmagMid_r','addmagDist_r','addmagIsch_r',...
        'bflh_r','bfsh_r','edl_r','ehl_r','fdl_r','fhl_r','gaslat_r','gasmed_r','gem_r',...
        'glmax1_r','glmax2_r','glmax3_r','glmed1_r','glmed2_r','glmed3_r','glmin1_r','glmin2_r',...
        'glmin3_r','grac_r','iliacus_r','pect_r','perbrev_r','perlong_r','pertert_r','piri_r',...
        'psoas_r','quadfem_r','recfem_r','sart_r','semimem_r','semiten_r','soleus_r','tfl_r',...
        'tibant_r','tibpost_r','vasint_r','vaslat_r','vasmed_r'};

    reserves = {...
        'hip_flex_r_reserve','hip_add_r_reserve','hip_rot_r_reserve','pf_flex_r_reserve',...
        'pf_rot_r_reserve','pf_tilt_r_reserve','pf_tx_r_reserve','pf_ty_r_reserve','pf_tz_r_reserve',...
        'knee_flex_r_reserve','knee_add_r_reserve','knee_rot_r_reserve','knee_tx_r_reserve',...
        'knee_ty_r_reserve','knee_tz_r_reserve','ankle_flex_r_reserve'};

    all_labels = [muscles, reserves];

    %% Initialize structure
    Activations.subject_id = numeric_id;
    Activations.project_id = project_id;
    Activations.time = time_100;

    %% Loop through signals
    for i = 1:length(all_labels)

        label = all_labels{i};
        ind = find(contains(act_labels, label));

        if isempty(ind); continue; end

        raw = act_data(:, ind);

        % Normalize to 100 points
        norm_signal = interp1(act_time_norm, raw, time_100, 'linear');

        % Smooth (optional)
        norm_signal = sgolayfilt(norm_signal, 3, 11);

        %% STORE
        entry.name = label;
        entry.raw = raw;
        entry.normalized = norm_signal;

        % Features (important!)
        entry.peak = max(norm_signal);
        entry.mean = mean(norm_signal);
        entry.timing_peak = time_100(norm_signal == max(norm_signal));

        %% CLASSIFY
        if ismember(label, muscles)
            entry.type = 'muscle';

            Activations.muscles.(label) = entry;

            outputDir = muscle_outputDir;

        else
            entry.type = 'reserve';

            Activations.reserves.(label) = entry;

            outputDir = reserve_outputDir;
        end

        %% PLOT
        fig = figure('Visible','off');
        area(act_time_norm, raw, 'FaceColor',[0 0 0],'FaceAlpha',0.5,'EdgeColor','none');

        title(label)
        xlabel('Gait Cycle [%]')

        if strcmp(entry.type,'muscle')
            ylabel('Activation')
            ylim([0 1])
        else
            if contains(label, {'tx','ty','tz'})
                ylabel('Force (N)')
            else
                ylabel('Torque (Nm)')
            end
        end

        grid on
        saveas(fig, fullfile(outputDir, [label '.png']))
        close(fig)

    end

    %% GLOBAL FEATURES (VERY useful)

    % Example: Quadriceps vs Hamstrings
    try
        quad = Activations.muscles.vaslat_r.normalized + ...
               Activations.muscles.vasmed_r.normalized + ...
               Activations.muscles.vasint_r.normalized + ...
               Activations.muscles.recfem_r.normalized;

        ham = Activations.muscles.bflh_r.normalized + ...
              Activations.muscles.bfsh_r.normalized + ...
              Activations.muscles.semiten_r.normalized + ...
              Activations.muscles.semimem_r.normalized;

        ratio = quad ./ (ham + 1e-6);

        Activations.features.quad_ham_ratio = ratio;
        Activations.features.quad_ham_peak = max(ratio);

    catch
        warning('Could not compute quad/ham ratio');
    end

    %% Save data
    save([muscle_outputDir '\activations_data.mat'], 'Activations');

end
```
