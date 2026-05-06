function results = plot_all_patients_joint_mechanics_save_data()
% PLOT_ALL_PATIENTS_JOINT_MECHANICS
% -------------------------------------------------------------
% ✔ Generates figures (mean ± CI)
% ✔ Saves processed data
% ✔ Returns structured output for SPM / ML / statistics
% ✔ Normalizes to 0–100% gait cycle (100 points)
%
% OUTPUT:
%   results struct with:
%       .time                (100x1)
%       .raw                 (Nx100 per variable)
%       .mean                (100x1)
%       .std                 (100x1)
%       .ci95                (100x1)
%       .labels              cell array
%
% Author: Adapted version
% -------------------------------------------------------------

    %% Directories
    results_directory = '../results';
    output_directory = '../mean_results/joint_mechanics';
    data_output_file = fullfile(output_directory, 'joint_mechanics_data.mat');

    if ~exist(output_directory, 'dir')
        mkdir(output_directory);
    end

    %% Parameters
    N = 100;
    time_norm = linspace(0, 100, N);
    ftype = fittype('linearinterp');

    %% Labels
    contact = {'contact_force_ap','contact_force_si','contact_force_ml'};
    moments = {'reaction_moment_ap','reaction_moment_si','reaction_moment_ml'};
    cop = {'cop_ap','cop_si','cop_ml'};
    all_labels = [contact, moments, cop];

    %% Initialize storage
    data = struct();
    for i = 1:length(all_labels)
        base = all_labels{i};
        data.(base) = [];
        data.([base '_medial']) = [];
        data.([base '_lateral']) = [];
    end

    %% Read folders
    subdirs = dir(results_directory);
    subdirs = subdirs([subdirs.isdir]);
    exclude = {'.','..','images_for_visualizations','paraview_template_files','reports'};
    subdirs = subdirs(~ismember({subdirs.name}, exclude));

    warning('off','MATLAB:table:ModifiedAndSavedVarnames');

    %% Loop patients
    for i = 1:length(subdirs)

        subdir = subdirs(i).name;
        patient_dir = fullfile(results_directory, subdir, 'joint_mechanics');
        patient_id = subdir(end-2:end);

        try
            [forces_data,~,~] = read_opensim_mot( ...
                fullfile(patient_dir, ['walking_' patient_id '_ForceReporter_forces.sto']));
        catch
            fprintf('ERROR loading %s\n', subdir);
            continue;
        end

        %% Normalize time
        t = forces_data(:,1);
        t_norm = (t - t(1)) / (t(end)-t(1)) * 100;

        %% Resample
        resampled = zeros(N, size(forces_data,2));

        for j = 2:size(forces_data,2)
            fitobj = fit(t_norm, forces_data(:,j), ftype);
            resampled(:,j) = feval(fitobj, time_norm');
        end

        %% Store variables
        for k = 1:3

            % CONTACT FORCES
            data.(contact{k}) = [data.(contact{k}); resampled(:,588+k)'];
            data.([contact{k} '_medial']) = [data.([contact{k} '_medial']); resampled(:,672+k)'];
            data.([contact{k} '_lateral']) = [data.([contact{k} '_lateral']); resampled(:,675+k)'];

            % MOMENTS
            data.(moments{k}) = [data.(moments{k}); resampled(:,591+k)'];
            data.([moments{k} '_medial']) = [data.([moments{k} '_medial']); resampled(:,690+k)'];
            data.([moments{k} '_lateral']) = [data.([moments{k} '_lateral']); resampled(:,693+k)'];

            % COP (mm)
            data.(cop{k}) = [data.(cop{k}); resampled(:,585+k)'*1000];
            data.([cop{k} '_medial']) = [data.([cop{k} '_medial']); resampled(:,654+k)'*1000];
            data.([cop{k} '_lateral']) = [data.([cop{k} '_lateral']); resampled(:,657+k)'*1000];
        end
    end

    warning('on','MATLAB:table:ModifiedAndSavedVarnames');

    %% Compute statistics
    results = struct();
    results.time = time_norm';
    results.labels = fieldnames(data);

    for i = 1:length(results.labels)

        label = results.labels{i};
        X = data.(label); % Nx100

        results.raw.(label)  = X;
        results.mean.(label) = mean(X,1)';
        results.std.(label)  = std(X,[],1)';
        results.ci95.(label) = 1.96 * results.std.(label) ./ sqrt(size(X,1));
    end

    %% Save processed data
    save(data_output_file, 'results');

    %% Display names
    names = containers.Map( ...
        {'contact_force_ap','contact_force_si','contact_force_ml', ...
         'reaction_moment_ap','reaction_moment_si','reaction_moment_ml', ...
         'cop_ap','cop_si','cop_ml'}, ...
        {'Contact Force AP','Contact Force SI','Contact Force ML', ...
         'Reaction Moment AP','Reaction Moment SI','Reaction Moment ML', ...
         'COP AP','COP SI','COP ML'});

    %% Plot
    plot_group(contact, 'Force [N]');
    plot_group(moments, 'Moment [Nm]');
    plot_group(cop, 'Position [mm]');

    %% Nested plotting function
    function plot_group(labels, ylabel_text)

        for i = 1:length(labels)

            base = labels{i};

            fig = figure('Visible','off','Color','w');
            hold on;

            plot_with_ci(results.mean.(base), results.ci95.(base), 'k', time_norm)
            plot_with_ci(results.mean.([base '_medial']), results.ci95.([base '_medial']), 'r', time_norm)
            plot_with_ci(results.mean.([base '_lateral']), results.ci95.([base '_lateral']), 'b', time_norm)

            title(names(base))
            xlabel('Gait Cycle [%]')
            ylabel(ylabel_text)
            legend('Total','','Medial','','Lateral')
            grid on

            saveas(fig, fullfile(output_directory, [base '.png']));
            %close(fig);
        end
    end

end

%% Helper function
function plot_with_ci(mean_data, ci, color, t)

    fill([t fliplr(t)], ...
         [mean_data'+ci' fliplr(mean_data'-ci')], ...
         color, 'FaceAlpha',0.2, 'EdgeColor','none');
    hold on
    plot(t, mean_data, 'Color',color, 'LineWidth',2);

end