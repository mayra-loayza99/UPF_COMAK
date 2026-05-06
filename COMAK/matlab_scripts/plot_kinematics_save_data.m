function Kinematics = plot_kinematics_save_data(numeric_id, project_id)
% PLOT_KINEMATICS 
% Generates plots AND saves structured kinematic data for analysis.
%
% OUTPUT:
%   Kinematics (struct) → ready for SPM/statistics

    %% Plot parameters
    line_width = 2;

    %% Load data
    try
        [values_data, values_labels, ~] = read_opensim_mot( ...
            ['../results/' project_id '_' numeric_id '/comak/walking_' numeric_id '_values.sto']);
    catch
        error('Simulation results not found!');
    end

    %% Normalize time (0–100%)
    time = values_data(:, 1);
    Time_normed = (time - time(1)) / (time(end) - time(1)) * 100;

    %% Coordinate definitions
    tf_coords_rot = {...
        {'knee_flex_r','knee\_flex\_r','Flexion','Angle [deg]'},...
        {'knee_add_r','knee\_add\_r','Adduction','Angle [deg]'},...
        {'knee_rot_r','knee\_rot\_r','Internal Rotation','Angle [deg]'}};

    tf_coords_trans = {...
        {'knee_tx_r','knee\_tx\_r','Anterior Translation','Translation [mm]'},...
        {'knee_ty_r','knee\_ty\_r','Superior Translation','Translation [mm]'},...
        {'knee_tz_r','knee\_tz\_r','Lateral Translation','Translation [mm]'}};

    pf_coords_rot = {...
        {'pf_flex_r','pf\_flex\_r','Flexion','Angle [deg]'},...
        {'pf_rot_r','pf\_rot\_r','Rotation','Angle [deg]'},...
        {'pf_tilt_r','pf\_tilt\_r','Tilt','Angle [deg]'}};

    pf_coords_trans = {...
        {'pf_tx_r','pf\_tx\_r','Anterior Translation','Translation [mm]'},...
        {'pf_ty_r','pf\_ty\_r','Superior Translation','Translation [mm]'},...
        {'pf_tz_r','pf\_tz\_r','Lateral Translation','Translation [mm]'}};

    %% Output directory
    output_dir = ['../results/' project_id '_' numeric_id '/graphics/kinematics'];
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    %% Process and plot
    Kinematics.TF_rot = plot_and_save_kinematics(tf_coords_rot, values_data, values_labels, Time_normed, line_width, ...
        [output_dir '\tibiofemoral_rotations.png'], 'Tibiofemoral Rotations');

    Kinematics.TF_trans = plot_and_save_kinematics(tf_coords_trans, values_data, values_labels, Time_normed, line_width, ...
        [output_dir '\tibiofemoral_translations.png'], 'Tibiofemoral Translations');

    Kinematics.PF_rot = plot_and_save_kinematics(pf_coords_rot, values_data, values_labels, Time_normed, line_width, ...
        [output_dir '\patellofemoral_rotations.png'], 'Patellofemoral Rotations');

    Kinematics.PF_trans = plot_and_save_kinematics(pf_coords_trans, values_data, values_labels, Time_normed, line_width, ...
        [output_dir '\patellofemoral_translations.png'], 'Patellofemoral Translations');

    %% Metadata
    Kinematics.metadata.subject_id = numeric_id;
    Kinematics.metadata.project_id = project_id;

    %% Save structured data
    save([output_dir '\kinematics_data.mat'], 'Kinematics');

end


function Kinematics = plot_and_save_kinematics(coords, values_data, values_labels, Time_normed, line_width, save_path, fig_name)

    kin_fig = figure('Name', fig_name, 'Position', [100, 100, 1000, 600], 'Visible', 'off');
    set(gcf, 'units', 'normalized', 'outerposition', [0 0 1 1]);

    Kinematics = struct();

    for i = 1:length(coords)
        subplot(3, 1, i);
        hold on;

        % Extract variable
        ind = find(contains(values_labels, coords{i}{1}));
        data = values_data(:, ind);

        % Convert translations to mm
        if contains(coords{i}{4}, 'Translation')
            data = data * 1000;
        end

        % Normalize to 100 points (CRITICAL for SPM)
        data_norm = interp1(Time_normed, data, linspace(0,100,100), 'linear');

        % Smooth (optional but recommended)
        data_norm = sgolayfilt(data_norm, 3, 11);

        % Store data
        Kinematics(i).name = coords{i}{1};
        Kinematics(i).label = coords{i}{3};
        Kinematics(i).unit = coords{i}{4};
        Kinematics(i).time = linspace(0,100,100);
        Kinematics(i).raw_time = Time_normed;
        Kinematics(i).raw = data;
        Kinematics(i).normalized = data_norm;

        % Plot
        plot(Time_normed, data, 'LineWidth', line_width)
        title([coords{i}{3} ' (' coords{i}{2} ')'])
        ylabel(coords{i}{4})
        grid on;
        set(gca, 'GridAlpha', 0.3);
    end

    xlabel('Gait Cycle [%]')

    % Save figure
    saveas(kin_fig, save_path)

    close(kin_fig);

end

