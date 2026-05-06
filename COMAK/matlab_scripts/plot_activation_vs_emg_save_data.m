function EMGval = plot_activation_vs_emg_save_data(project_id, numeric_id, BW, time_start, time_stop, sf)
% PLOT_ACTIVATION_VS_EMG
% Generates plots AND saves structured EMG vs simulation validation data

    %% Parameters
    line_width = 2;
    time_100 = linspace(0,100,100);

    %% Output directory
    output_dir = ['../results/' project_id '_' numeric_id '/graphics/validation'];
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    %% Load simulation activations
    file_path = ['../results/' project_id '_' numeric_id '/comak/walking_' numeric_id '_activation.sto'];

    try
        [act_data, act_labels, ~] = read_opensim_mot(file_path);
    catch
        error(['Could not load data from: ' file_path]);
    end

    act_time = act_data(:,1);
    act_time_norm = (act_time - act_time(1)) / (act_time(end)-act_time(1)) * 100;

    %% Load EMG
    emg_file_1 = dir(fullfile(['../data/' project_id '_' numeric_id '/walking'], '*EMG*'));
    emg_file = [emg_file_1.folder '/' emg_file_1.name];

    warning('off','MATLAB:table:ModifiedAndSavedVarnames');

    try
        emt_data = readtable(emg_file,'FileType','text','Delimiter','\t','HeaderLines',10);
    catch
        error('No EMG file found');
    end

    %% Extract time window
    ind_start = find(emt_data.Time == time_start, 1);
    ind_stop  = find(emt_data.Time == time_stop, 1);

    %% Extract EMG signals
    tibant = preprocess_emg(emt_data.RightTibialisAnterior(ind_start:ind_stop), sf);
    vaslat = preprocess_emg(emt_data.RightVastusLateralis(ind_start:ind_stop), sf);
    gaslat = preprocess_emg(emt_data.RightGastrocnemiusLateralis(ind_start:ind_stop), sf);
    bflh   = preprocess_emg(emt_data.RightBicepsFemorisCaputLongus(ind_start:ind_stop), sf);

    emg_signals = {tibant, vaslat, gaslat, bflh};
    msls = {'tibant_r','vaslat_r','gaslat_r','bflh_r'};
    names = {'Tibialis Anterior','Vastus Lateralis','Gastrocnemius Lateralis','Biceps Femoris'};

    %% Initialize structure
    EMGval.subject_id = numeric_id;
    EMGval.project_id = project_id;
    EMGval.time = time_100;

    %% Plot + analysis
    fig = figure('Visible','off');
    set(gcf,'units','normalized','outerposition',[0 0 1 1]);

    for i = 1:length(msls)

        subplot(2,2,i); hold on

        % Simulation
        ind = find(contains(act_labels, msls{i}));
        sim = act_data(:,ind);

        sim_norm = interp1(act_time_norm, sim, time_100);
        emg_time = linspace(0,100,length(emg_signals{i}));
        emg_norm = interp1(emg_time, emg_signals{i}, time_100);

        % Smooth
        sim_norm = sgolayfilt(sim_norm,3,11);
        emg_norm = sgolayfilt(emg_norm,3,11);

        %% Cross-correlation
        [xc, lags] = xcorr(sim_norm, emg_norm, 'coeff');
        [max_corr, idx] = max(xc);
        lag = lags(idx);
        zero_corr = xc(lags==0);

        %% Store
        EMGval.muscle(i).name = msls{i};
        EMGval.muscle(i).label = names{i};
        EMGval.muscle(i).simulation = sim_norm;
        EMGval.muscle(i).emg = emg_norm;

        EMGval.muscle(i).metrics.max_corr = max_corr;
        EMGval.muscle(i).metrics.lag = lag;
        EMGval.muscle(i).metrics.zero_lag_corr = zero_corr;

        %% Plot
        yyaxis left
        plot(time_100, sim_norm,'b','LineWidth',line_width)
        ylabel('Activation')
        ylim([0 1])

        yyaxis right
        plot(time_100, emg_norm,'r','LineWidth',line_width/2)
        ylabel('EMG')

        title(names{i})
        xlabel('Gait Cycle [%]')
        legend('Simulation','EMG')

        text(10,0.8*max(emg_norm),['Lag: ' num2str(lag)])
        text(10,0.7*max(emg_norm),['Max Corr: ' num2str(max_corr,'%.2f')])
        text(10,0.6*max(emg_norm),['Corr0: ' num2str(zero_corr,'%.2f')])

        grid on

    end

    saveas(fig, [output_dir '\EMG_vs_simulation.png'])
    close(fig)

    %% GLOBAL METRICS (important for paper)

    all_corrs = arrayfun(@(x) x.metrics.max_corr, EMGval.muscle);
    EMGval.summary.mean_corr = mean(all_corrs);
    EMGval.summary.std_corr = std(all_corrs);

    %% Save data
    save([output_dir '\emg_validation_data.mat'], 'EMGval');

end

