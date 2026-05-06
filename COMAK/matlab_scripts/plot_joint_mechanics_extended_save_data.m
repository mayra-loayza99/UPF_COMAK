```matlab id="j3k9pz"
function JointMech = plot_joint_mechanics_extended_save_data(project_id, numeric_id, forces_file, BW)
% PLOT_JOINT_MECHANICS_EXTENDED
% Generates plots AND saves structured joint mechanics data

    %% Load data
    [forces_data, ~, ~] = read_opensim_mot(forces_file);

    %% Normalize time (0–100%)
    forces_time = forces_data(:, 1);
    forces_time_norm = (forces_time - forces_time(1)) / (forces_time(end) - forces_time(1)) * 100;

    % Standard time base (100 points)
    time_100 = linspace(0,100,100);

    %% Body weight normalization
    BW_N = BW * 9.81;

    %% Output directory
    output_dir = ['../results/' project_id '_' numeric_id '/graphics/extended_joint_mechanics'];
    if ~isfolder(output_dir)
        mkdir(output_dir);
    end

    %% Labels
    info = {'AP', 'SI', 'ML'};

    %% Initialize structure
    JointMech.subject_id = numeric_id;
    JointMech.project_id = project_id;
    JointMech.time = time_100;

    %% =========================
    % CONTACT FORCES
    %% =========================
    for i = 1:3

        total = forces_data(:, 588 + i) / BW_N;
        medial = forces_data(:, 672 + i) / BW_N;
        lateral = forces_data(:, 675 + i) / BW_N;

        % Normalize to 100 points
        total_n = interp1(forces_time_norm, total, time_100);
        medial_n = interp1(forces_time_norm, medial, time_100);
        lateral_n = interp1(forces_time_norm, lateral, time_100);

        % Store
        JointMech.contact(i).direction = info{i};
        JointMech.contact(i).total = total_n;
        JointMech.contact(i).medial = medial_n;
        JointMech.contact(i).lateral = lateral_n;

        % Features (important!)
        JointMech.features.contact_peak_total(i) = max(total_n);
        JointMech.features.contact_peak_medial(i) = max(medial_n);
        JointMech.features.contact_peak_lateral(i) = max(lateral_n);

        % Plot
        fig = figure('Visible','off'); hold on
        plot(forces_time_norm, total,'k','LineWidth',2)
        plot(forces_time_norm, medial,'r','LineWidth',3)
        plot(forces_time_norm, lateral,'b','LineWidth',3)
        title(['Contact Forces - ' info{i}])
        xlabel('Gait Cycle [%]')
        ylabel('Force [BW]')
        legend('Total','Medial','Lateral')
        grid on

        saveas(fig, [output_dir '\Contact_Forces_' info{i} '.png'])
        close(fig)
    end

    %% =========================
    % REACTION MOMENTS
    %% =========================
    for i = 1:3

        total = forces_data(:, 591 + i);
        medial = forces_data(:, 690 + i);
        lateral = forces_data(:, 693 + i);

        total_n = interp1(forces_time_norm, total, time_100);
        medial_n = interp1(forces_time_norm, medial, time_100);
        lateral_n = interp1(forces_time_norm, lateral, time_100);

        JointMech.moments(i).direction = info{i};
        JointMech.moments(i).total = total_n;
        JointMech.moments(i).medial = medial_n;
        JointMech.moments(i).lateral = lateral_n;

        % Features
        JointMech.features.moment_peak_total(i) = max(abs(total_n));

        fig = figure('Visible','off'); hold on
        plot(forces_time_norm, total,'k','LineWidth',2)
        plot(forces_time_norm, medial,'r','LineWidth',3)
        plot(forces_time_norm, lateral,'b','LineWidth',3)
        title(['Reaction Moments - ' info{i}])
        xlabel('Gait Cycle [%]')
        ylabel('Moment [Nm]')
        legend('Total','Medial','Lateral')
        grid on

        saveas(fig, [output_dir '\Reaction_Moments_' info{i} '.png'])
        close(fig)
    end

    %% =========================
    % CENTER OF PRESSURE
    %% =========================
    for i = 1:3

        total = forces_data(:, 585 + i) * 1000;
        medial = forces_data(:, 654 + i) * 1000;
        lateral = forces_data(:, 657 + i) * 1000;

        total_n = interp1(forces_time_norm, total, time_100);
        medial_n = interp1(forces_time_norm, medial, time_100);
        lateral_n = interp1(forces_time_norm, lateral, time_100);

        JointMech.cop(i).direction = info{i};
        JointMech.cop(i).total = total_n;
        JointMech.cop(i).medial = medial_n;
        JointMech.cop(i).lateral = lateral_n;

        % Feature: path length (very useful biomarker)
        JointMech.features.cop_path_total(i) = sum(abs(diff(total_n)));

        fig = figure('Visible','off'); hold on
        plot(forces_time_norm, total,'k','LineWidth',2)
        plot(forces_time_norm, medial,'r','LineWidth',3)
        plot(forces_time_norm, lateral,'b','LineWidth',3)
        title(['CoP - ' info{i}])
        xlabel('Gait Cycle [%]')
        ylabel('CoP [mm]')
        legend('Total','Medial','Lateral')
        grid on

        saveas(fig, [output_dir '\CoP_' info{i} '.png'])
        close(fig)
    end

    %% Save structured data
    save([output_dir '\joint_mechanics_data.mat'], 'JointMech');

end
```
