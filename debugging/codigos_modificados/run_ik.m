function [] = run_ik(model_file, motion_file, ik_result_dir, numeric_id, project_id, results_basename, time_start, time_stop)
    %% Perform Inverse Kinematics
    % This function performs inverse kinematics using the COMAKInverseKinematicsTool.
    % It sets up the model, directories, and various parameters for the inverse 
    % kinematics analysis, including secondary constraints and marker tasks.
    %
    % Parameters:
    %   model_file (string): Path to the model .osim file.
    %   motion_file (string): Path to the motion .trc file.
    %   ik_result_dir (string): Directory to store the results.
    %   numeric_id: string, numerical identifier for results directories
    %   results_basename (string): Basename for the result files.
    %   time_start (double): Start time for the analysis.
    %   time_stop (double): Stop time for the analysis.
    if ~exist(ik_result_dir, 'dir')
        mkdir(ik_result_dir);
    end
    import org.opensim.modeling.*
    Logger.setLevelString('Debug');
    fprintf('Versión de OpenSim: %s\n', char(org.opensim.modeling.opensimCommon.GetVersion()));
    comak_ik = COMAKInverseKinematicsTool();
    comak_ik.set_model_file(model_file);
    comak_ik.set_results_directory(ik_result_dir);
    comak_ik.set_results_prefix(results_basename);
    comak_ik.set_perform_secondary_constraint_sim(true);
    comak_ik.set_secondary_coordinates(0,'/jointset/knee_r/knee_add_r');
    comak_ik.set_secondary_coordinates(1,'/jointset/knee_r/knee_rot_r');
    comak_ik.set_secondary_coordinates(2,'/jointset/knee_r/knee_tx_r');
    comak_ik.set_secondary_coordinates(3,'/jointset/knee_r/knee_ty_r');
    comak_ik.set_secondary_coordinates(4,'/jointset/knee_r/knee_tz_r');
    comak_ik.set_secondary_coordinates(5,'/jointset/pf_r/pf_flex_r');
    comak_ik.set_secondary_coordinates(6,'/jointset/pf_r/pf_rot_r');
    comak_ik.set_secondary_coordinates(7,'/jointset/pf_r/pf_tilt_r');
    comak_ik.set_secondary_coordinates(8,'/jointset/pf_r/pf_tx_r');
    comak_ik.set_secondary_coordinates(9,'/jointset/pf_r/pf_ty_r');
    comak_ik.set_secondary_coordinates(10,'/jointset/pf_r/pf_tz_r');
    comak_ik.set_secondary_coupled_coordinate('/jointset/knee_r/knee_flex_r');
    comak_ik.set_secondary_constraint_sim_settle_threshold(1e-4);
    comak_ik.set_secondary_constraint_sim_sweep_time(3.0);
    comak_ik.set_secondary_coupled_coordinate_start_value(0);
    comak_ik.set_secondary_coupled_coordinate_stop_value(100);
    comak_ik.set_secondary_constraint_sim_integrator_accuracy(1e-2);
    comak_ik.set_secondary_constraint_sim_internal_step_limit(10000);
    comak_ik.set_secondary_constraint_function_file(...
        [ik_result_dir '/secondary_coordinate_constraint_functions.xml']);
    comak_ik.set_constraint_function_num_interpolation_points(20);
    comak_ik.set_print_secondary_constraint_sim_results(true);
    comak_ik.set_constrained_model_file([ik_result_dir '/ik_constrained_model.osim']);
    comak_ik.set_perform_inverse_kinematics(true);
    comak_ik.set_marker_file(motion_file);
    
    comak_ik.set_output_motion_file([results_basename '_ik.mot']);
    comak_ik.set_time_range(0, time_start);
    comak_ik.set_time_range(1, time_stop);
    comak_ik.set_report_errors(true);
    comak_ik.set_report_marker_locations(false);
    comak_ik.set_ik_constraint_weight(100);
    comak_ik.set_ik_accuracy(1e-5);
    comak_ik.set_use_visualizer(false);
    comak_ik.set_verbose(10);
    
    
    ik_task_set = IKTaskSet();
    
    ik_task=IKMarkerTask();
    
    
    ik_task.setName('r.should');
    ik_task.setWeight(1);
    ik_task_set.cloneAndAppend(ik_task);
    
    ik_task.setName('l.should');
    ik_task.setWeight(1);
    ik_task_set.cloneAndAppend(ik_task);
    
    ik_task.setName('c7');
    ik_task.setWeight(1);
    ik_task_set.cloneAndAppend(ik_task);
    
    ik_task.setName('r.asis');
    ik_task.setWeight(15);
    ik_task_set.cloneAndAppend(ik_task);
    
    ik_task.setName('l.asis');
    ik_task.setWeight(15);
    ik_task_set.cloneAndAppend(ik_task);
    
    ik_task.setName('sacrum');
    ik_task.setWeight(15);
    ik_task_set.cloneAndAppend(ik_task);
    
    ik_task.setName('r.bar1');
    ik_task.setWeight(5);
    ik_task_set.cloneAndAppend(ik_task);
    
    ik_task.setName('r.knee1');
    ik_task.setWeight(20);
    ik_task_set.cloneAndAppend(ik_task);
    
    ik_task.setName('r.bar2');
    ik_task.setWeight(5);
    ik_task_set.cloneAndAppend(ik_task);
    
    ik_task.setName('r.mall');
    ik_task.setWeight(20);
    ik_task_set.cloneAndAppend(ik_task);
    
    ik_task.setName('r.heel');
    ik_task.setWeight(20);
    ik_task_set.cloneAndAppend(ik_task);
    
    ik_task.setName('r.met');
    ik_task.setWeight(20);
    ik_task_set.cloneAndAppend(ik_task);
    
    ik_task.setName('l.bar1');
    ik_task.setWeight(5);
    ik_task_set.cloneAndAppend(ik_task);
    
    ik_task.setName('l.knee1');
    ik_task.setWeight(20);
    ik_task_set.cloneAndAppend(ik_task);
    
    ik_task.setName('l.bar2');
    ik_task.setWeight(5);
    ik_task_set.cloneAndAppend(ik_task);
    
    ik_task.setName('l.mall');
    ik_task.setWeight(20);
    ik_task_set.cloneAndAppend(ik_task);
    
    ik_task.setName('l.heel');
    ik_task.setWeight(20);
    ik_task_set.cloneAndAppend(ik_task);
    
    ik_task.setName('l.met');
    ik_task.setWeight(20);
    ik_task_set.cloneAndAppend(ik_task);
    
    comak_ik.set_IKTaskSet(ik_task_set);
    
        % ===== VALIDACIÓN ANTES DE EJECUTAR =====
    disp('Validando configuración antes de ejecutar...');

    % 1. Verificar que el modelo existe y se puede cargar
    if ~exist(model_file, 'file')
        error('Modelo no encontrado: %s', model_file);
    end

    try
        test_model = Model(model_file);
        test_model.initSystem();
        disp('✓ Modelo válido');
        clear test_model;
    catch ME
        error('Error al cargar el modelo: %s', ME.message);
    end

    % 2. Verificar que el archivo TRC existe y tiene datos válidos
    if ~exist(motion_file, 'file')
        error('Archivo TRC no encontrado: %s', motion_file);
    end

    % Leer el TRC y verificar markers
    trc_data = importdata(motion_file, '\t', 6);
    if isfield(trc_data, 'colheaders')
        markers_in_trc = trc_data.colheaders(2:3:end); % Cada marker tiene X,Y,Z
        fprintf('✓ TRC válido con %d markers\n', length(markers_in_trc));
        disp('Markers en TRC:');
        disp(markers_in_trc);
    else
        error('No se pudieron leer los headers del TRC');
    end

    % 3. Verificar rango de tiempo
    if isfield(trc_data, 'data')
        trc_times = trc_data.data(:,2); % Segunda columna es tiempo
        fprintf('Rango de tiempo TRC: %.4f a %.4f\n', min(trc_times), max(trc_times));
        fprintf('Rango solicitado IK: %.4f a %.4f\n', time_start, time_stop);

        if time_start < min(trc_times) || time_stop > max(trc_times)
            error('El rango de tiempo solicitado (%.4f - %.4f) está fuera del rango del TRC (%.4f - %.4f)', ...
                time_start, time_stop, min(trc_times), max(trc_times));
        end
        disp('✓ Rango de tiempo válido');
    end

          % 4. Verificar coordenadas
    test_model = Model(model_file);
    test_model.initSystem();
    coord_set = test_model.getCoordinateSet();

    % Nombres de coordenadas (sin el path completo)
    secondary_coord_names = {
        'knee_add_r',
        'knee_rot_r', 
        'knee_tx_r',
        'knee_ty_r',
        'knee_tz_r',
        'pf_flex_r',
        'pf_rot_r',
        'pf_tilt_r',
        'pf_tx_r',
        'pf_ty_r',
        'pf_tz_r'
    };

    % Verificar usando nombres en lugar de paths
    for i = 1:length(secondary_coord_names)
        try
            coord = coord_set.get(secondary_coord_names{i});
            fprintf('✓ Encontrada: %s\n', secondary_coord_names{i});
        catch ME
            error('Coordenada NO encontrada: %s. Error: %s', secondary_coord_names{i}, ME.message);
        end
    end

    disp('✓ Todas las coordenadas secundarias existen en el modelo');
    clear test_model;
    
        % Verificar que los markers en el TRC coinciden con los markers en las IKTasks
    fprintf('\n--- Verificando markers ---\n');
    marker_tasks = {'r.should', 'l.should', 'c7', 'r.asis', 'l.asis', 'sacrum', ...
                    'r.bar1', 'r.knee1', 'r.bar2', 'r.mall', 'r.heel', 'r.met', ...
                    'l.bar1', 'l.knee1', 'l.bar2', 'l.mall', 'l.heel', 'l.met'};

    % Obtener markers del modelo
    test_model = Model(model_file);
    marker_set = test_model.getMarkerSet();

    for i = 1:length(marker_tasks)
        marker_name = marker_tasks{i};
        try
            marker = marker_set.get(marker_name);
            fprintf('✓ Marker en modelo: %s\n', marker_name);
        catch
            warning('⚠ Marker NO encontrado en modelo: %s', marker_name);
        end
    end

    % Verificar si los markers están en el TRC
    trc_data = importdata(motion_file, '\t', 6);
    trc_header_line = trc_data.textdata{5, 1}; % Línea con nombres de markers
    fprintf('\nMarkers en TRC header:\n%s\n', trc_header_line);

    comak_ik.print(['../inputs/' project_id '_' numeric_id '/comak_inverse_kinematics_settings.xml']);



    % Redirigir el logger de OpenSim a un archivo
    import org.opensim.modeling.*
    log_file_path = fullfile(ik_result_dir, 'opensim_debug_final.log');

    % Configurar el logger para escribir a archivo
    Logger.removeFileSink();  % Limpiar logs anteriores
    Logger.addFileSink(log_file_path);
    Logger.setLevelString('Debug');  % Máximo detalle

    disp(['Log de OpenSim se guardará en: ' log_file_path]);
    disp('Running COMAKInverseKinematicsTool...')

    try
        success = comak_ik.run();

        if success
            disp('✓ COMAK IK completado exitosamente');
        else
            % Leer el archivo de log
            if exist(log_file_path, 'file')
                pause(0.5);  % Dar tiempo para que se escriba el archivo
                log_content = fileread(log_file_path);
                fprintf('\n========== LOG DE OPENSIM ==========\n');
                fprintf('%s\n', log_content);
                fprintf('====================================\n\n');
            end
            error('COMAK IK retornó false. Ver log de OpenSim arriba.');
        end

    catch ME
        % Intentar leer el log
        if exist(log_file_path, 'file')
            pause(0.5);
            try
                log_content = fileread(log_file_path);
                fprintf('\n========== LOG DE OPENSIM (ERROR) ==========\n');
                fprintf('%s\n', log_content);
                fprintf('============================================\n\n');
            catch
                fprintf('No se pudo leer el archivo de log\n');
            end
        end
        rethrow(ME);
    end
%     comak_ik.run();

end