function [] = run_ik(model_file, motion_file, ik_result_dir, numeric_id, project_id, results_basename, time_start, time_stop)
    %% Perform Inverse Kinematics
    % This function performs inverse kinematics using the COMAKInverseKinematicsTool.
    
    % LIMPIEZA INICIAL
    import org.opensim.modeling.*
    Logger.setLevelString('Debug');
    
    % Verificar y limpiar archivos previos de IK
    limpiar_archivos_ik(ik_result_dir);

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
    
    % ✅ SOLUCIÓN: Crear objeto NUEVO para cada marker
    ik_task_set = IKTaskSet();
    
    % Helper function para crear markers
    function agregar_marker(nombre, peso)
        marker_task = IKMarkerTask();  % NUEVO objeto cada vez
        marker_task.setName(nombre);
        marker_task.setWeight(peso);
        ik_task_set.cloneAndAppend(marker_task);
        clear marker_task  % Limpiar referencia
    end
    
    % Agregar todos los markers
    agregar_marker('r.should', 1);
    agregar_marker('l.should', 1);
    agregar_marker('c7', 1);
    agregar_marker('r.asis', 15);
    agregar_marker('l.asis', 15);
    agregar_marker('sacrum', 15);
    agregar_marker('r.bar1', 5);
    agregar_marker('r.knee1', 20);
    agregar_marker('r.bar2', 5);
    agregar_marker('r.mall', 20);
    agregar_marker('r.heel', 20);
    agregar_marker('r.met', 20);
    agregar_marker('l.bar1', 5);
    agregar_marker('l.knee1', 20);
    agregar_marker('l.bar2', 5);
    agregar_marker('l.mall', 20);
    agregar_marker('l.heel', 20);
    agregar_marker('l.met', 20);
    
    comak_ik.set_IKTaskSet(ik_task_set);
    
    comak_ik.print(['../inputs/' project_id '_' numeric_id '/comak_inverse_kinematics_settings.xml']);
    
    fprintf('=== EJECUTANDO IK: %s ===\n', datestr(now));
    fprintf('Paciente: %s_%s\n', project_id, numeric_id);
    disp('Running COMAKInverseKinematicsTool...')
    
    comak_ik.run();
    
    % LIMPIEZA POST-EJECUCIÓN
    clear comak_ik ik_task_set
    java.lang.System.gc()
    pause(0.2)
    
    fprintf('IK completado y memoria limpiada.\n');
end

function limpiar_archivos_ik(ik_result_dir)
    % Limpia archivos críticos de IK previos
    if ~exist(ik_result_dir, 'dir')
        mkdir(ik_result_dir);
        return;
    end
    
    % CRÍTICO: Eliminar el archivo de restricciones secundarias
    constraint_file = fullfile(ik_result_dir, 'secondary_coordinate_constraint_functions.xml');
    if exist(constraint_file, 'file')
        delete(constraint_file);
        fprintf('Eliminado: %s\n', constraint_file);
    end
    
    % Eliminar otros archivos de resultados previos
    delete(fullfile(ik_result_dir, '*.mot'));
    delete(fullfile(ik_result_dir, '*.sto'));
    delete(fullfile(ik_result_dir, '*.log'));
end