function KINgroup = plot_all_patients_kinematics_save_data()

    %% Directories
    results_directory = '../results';
    output_directory = '../mean_results/kinematics';

    if ~exist(output_directory, 'dir')
        mkdir(output_directory);
    end

    %% Parameters
    Time_steps = 100;
    Time_normed = linspace(0, 100, Time_steps);
    ftype = fittype('linearinterp');

    %% Labels
    tf_coords_rot = {'knee_flex_r', 'knee_add_r', 'knee_rot_r'};
    tf_coords_trans = {'knee_tx_r', 'knee_ty_r', 'knee_tz_r'};
    pf_coords_rot = {'pf_flex_r', 'pf_rot_r', 'pf_tilt_r'};
    pf_coords_trans = {'pf_tx_r', 'pf_ty_r', 'pf_tz_r'};

    all_labels = [tf_coords_rot, tf_coords_trans, pf_coords_rot, pf_coords_trans];

    %% Initialize storage
    all_kin_data = struct();
    for i = 1:length(all_labels)
        all_kin_data.(all_labels{i}) = [];
    end

    warning('off','MATLAB:table:ModifiedAndSavedVarnames');

    %% Loop patients
    subdirs = dir(results_directory);
    subdirs = subdirs([subdirs.isdir]);

    exclude_dirs = {'.','..','images_for_visualizations','paraview_template_files','reports'};
    subdirs = subdirs(~ismember({subdirs.name}, exclude_dirs));

    patient_ids = {};

    for i = 1:length(subdirs)

        subdir = subdirs(i).name;
        patient_ids{end+1} = subdir;

        project_patient_dir = fullfile(results_directory, subdir, 'comak');
        patient_id = subdir(end-2:end);

        try
            [values_data, values_labels, ~] = read_opensim_mot(...
                fullfile(project_patient_dir, ['walking_' patient_id '_values.sto']));
        catch
            disp(['Missing: ' subdir])
            continue;
        end

        %% Normalize + resample
        time = values_data(:,1);
        time_norm = (time - time(1)) / (time(end)-time(1)) * 100;

        resampled = zeros(length(Time_normed), size(values_data,2));

        for j = 2:size(values_data,2)
            fit_values = fit(time_norm, values_data(:,j), ftype);
            resampled(:,j) = feval(fit_values, Time_normed');
        end

        %% Store
        for j = 1:length(all_labels)
            ind = find(contains(values_labels, all_labels{j}));
            if ~isempty(ind)
                all_kin_data.(all_labels{j}) = ...
                    [all_kin_data.(all_labels{j}); resampled(:,ind)'];
            end
        end
    end

    warning('on','MATLAB:table:ModifiedAndSavedVarnames');

    %% Compute statistics
    mean_kin = struct();
    std_kin = struct();
    ci_kin = struct();

    for i = 1:length(all_labels)
        label = all_labels{i};

        data = all_kin_data.(label);   % [subjects x time]

        mean_kin.(label) = mean(data,1)';
        std_kin.(label)  = std(data,[],1)';
        ci_kin.(label)   = 1.96 * std_kin.(label) / sqrt(size(data,1));
    end

    %% Build output struct
    KINgroup.time = Time_normed;
    KINgroup.labels = all_labels;
    KINgroup.mean = mean_kin;
    KINgroup.std = std_kin;
    KINgroup.ci = ci_kin;
    KINgroup.raw = all_kin_data;
    KINgroup.n_subjects = size(all_kin_data.(all_labels{1}),1);
    KINgroup.patient_ids = patient_ids;

    %% SAVE DATA (CRITICAL)
    save(fullfile(output_directory,'group_kinematics_data.mat'),'KINgroup');

    %% ====== PLOTTING ======

    tf_coords_rot_plot = {
        {'knee_flex_r','knee_flex_r','Knee Flexion','Angle [deg]'},...
        {'knee_add_r','knee_add_r','Knee Adduction','Angle [deg]'},...
        {'knee_rot_r','knee_rot_r','Knee Internal Rotation','Angle [deg]'}};

    tf_coords_trans_plot = {
        {'knee_tx_r','knee_tx_r','Knee Anterior Translation','Translation [mm]'},...
        {'knee_ty_r','knee_ty_r','Knee Superior Translation','Translation [mm]'},...
        {'knee_tz_r','knee_tz_r','Knee Lateral Translation','Translation [mm]'}};

    pf_coords_rot_plot = {
        {'pf_flex_r','pf_flex_r','Patellofemoral Flexion','Angle [deg]'},...
        {'pf_rot_r','pf_rot_r','Patellofemoral Rotation','Angle [deg]'},...
        {'pf_tilt_r','pf_tilt_r','Patellofemoral Tilt','Angle [deg]'}};

    pf_coords_trans_plot = {
        {'pf_tx_r','pf_tx_r','Patellofemoral Anterior Translation','Translation [mm]'},...
        {'pf_ty_r','pf_ty_r','Patellofemoral Superior Translation','Translation [mm]'},...
        {'pf_tz_r','pf_tz_r','Patellofemoral Lateral Translation','Translation [mm]'}};

    plot_and_save_kinematics(tf_coords_rot_plot, Time_normed, mean_kin, ci_kin, output_directory, 'tibiofemoral_rotations.png', 'Tibiofemoral Rotations');
    plot_and_save_kinematics(tf_coords_trans_plot, Time_normed, mean_kin, ci_kin, output_directory, 'tibiofemoral_translations.png', 'Tibiofemoral Translations');
    plot_and_save_kinematics(pf_coords_rot_plot, Time_normed, mean_kin, ci_kin, output_directory, 'patellofemoral_rotations.png', 'Patellofemoral Rotations');
    plot_and_save_kinematics(pf_coords_trans_plot, Time_normed, mean_kin, ci_kin, output_directory, 'patellofemoral_translations.png', 'Patellofemoral Translations');

end

function plot_and_save_kinematics(coords, Time_normed, mean_kin, ci_kin, output_directory, save_filename, fig_name)
    % PLOT_AND_SAVE_KINEMATICS Plots and saves kinematic variables with confidence intervals.
    %
    % Inputs:
    %   coords - Cell array of coordinate details for the plots
    %   Time_normed - Normalized time array
    %   mean_kin - Struct containing mean kinematic data
    %   ci_kin - Struct containing confidence interval data
    %   output_directory - Directory to save the output files
    %   save_filename - Filename to save the plot
    %   fig_name - Figure title
    %
    % Outputs:
    %   None (saves figure as PNG files)

    kin_fig = figure('Name', fig_name, 'Position', [100, 100, 1000, 600], 'Visible', 'off');
    set(gcf, 'units', 'normalized', 'outerposition', [0 0 1 1])
    for i = 1:length(coords)
        subplot(3, 1, i);
        hold on;

        % Plot data
        label = coords{i}{1};
        if contains(coords{i}{4}, 'Translation')
            mean_data = mean_kin.(label) * 1000;
            ci_data = ci_kin.(label) * 1000;
        else
            mean_data = mean_kin.(label);
            ci_data = ci_kin.(label);
        end
        shadedErrorBar(Time_normed, mean_data, ci_data, {'-b', 'LineWidth', 2}, 0.2);
        title([coords{i}{3} ' (' strrep(coords{i}{2}, '_', '\_') ')']);
        ylabel(coords{i}{4})
        grid on;
        set(gca, 'GridAlpha', 0.3);
    end
    xlabel('Gait Cycle [%]')

    % Save figure
    saveas(kin_fig, fullfile(output_directory, save_filename))
    close(kin_fig);
end

