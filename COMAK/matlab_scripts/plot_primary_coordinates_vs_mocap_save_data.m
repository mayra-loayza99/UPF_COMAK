```matlab
function Validation = plot_primary_coordinates_vs_mocap_save_data(numeric_id, project_id, directory_walking)
% PLOT_PRIMARY_COORDINATES_VS_MOCAP
% Generates plots AND saves validation metrics + processed data

    %% Parameters
    Time_steps = 100;
    Time_normed = linspace(0,100,Time_steps);
    ftype = fittype('linearinterp');

    %% Output directory
    output_dir = ['../results/' project_id '_' numeric_id '/graphics/validation'];
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    %% Load simulation data
    try
        [values_data, values_labels, ~] = read_opensim_mot( ...
            ['../results/' project_id '_' numeric_id '/comak/walking_' numeric_id '_values.sto']);
    catch  
        error('Simulation results not found!');
    end

    %% Load IK marker errors
    try
        [error_data, ~, ~] = read_opensim_mot( ...
            ['../results/' project_id '_' numeric_id '/comak_inverse_kinematics/walking_' numeric_id '_ik_marker_errors.sto']);
    catch  
        error('IK marker error file not found!');
    end

    %% Marker error statistics
    mean_err = mean(error_data(:, 3));
    std_err = std(error_data(:, 3));
    mean_max = mean(error_data(:, 4));
    std_max = std(error_data(:, 4));

    n = size(error_data, 1);
    df = n - 1;
    t_value = tinv(0.975, df);

    margin_err = t_value * (std_err / sqrt(n));
    margin_max = t_value * (std_max / sqrt(n));

    %% Normalize simulation data
    time_data = values_data(:, 1);
    time_norm = linspace(0, 100, length(time_data));

    resampled = zeros(length(Time_normed), size(values_data,2));
    resampled(:,1) = Time_normed;

    for i = 2:size(values_data,2)
        fit_1 = fit(time_norm', values_data(:,i), ftype);
        resampled(:,i) = feval(fit_1, Time_normed');
    end

    values_data = resampled;

    %% Load mocap data
    emt_file_1 = dir(fullfile(directory_walking, '*Angle*'));
    emt_file = [emt_file_1.folder '/' emt_file_1.name];

    warning('off', 'MATLAB:table:ModifiedAndSavedVarnames');

    emt_data = readtable(emt_file, 'FileType','text','Delimiter','\t','HeaderLines',7);

    acmRKFE = emt_data.acmRKFE_M;
    acm_time = emt_data.Sample;

    %% Extract simulation knee flexion
    ind = find(contains(values_labels, 'knee_flex_r'));
    sim_knee = values_data(:, ind);

    %% Metrics
    mae_value = mean(abs(acmRKFE - sim_knee));
    max_error = max(abs(acmRKFE - sim_knee));

    r = corr(acmRKFE, sim_knee);
    R2 = r^2;

    %% Bland-Altman
    differences = sim_knee - acmRKFE;
    averages = (sim_knee + acmRKFE)/2;
    mean_diff = mean(differences);
    std_diff = std(differences);

    loa_upper = mean_diff + 1.96*std_diff;
    loa_lower = mean_diff - 1.96*std_diff;

    %%
```
