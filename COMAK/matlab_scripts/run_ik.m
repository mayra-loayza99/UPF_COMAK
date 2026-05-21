function [] = run_ik(model_file, motion_file, ik_result_dir, numeric_id, project_id, results_basename, time_start, time_stop, side)
    %% Perform Inverse Kinematics for one leg (right or left).
    %
    %  side  'r' (default) or 'l'
    %
    % Uses the COMAKInverseKinematicsTool: single constraint sim pass for the
    % requested knee, then IK in the same call.

    arguments
        model_file
        motion_file
        ik_result_dir
        numeric_id
        project_id
        results_basename
        time_start = -1
        time_stop  = -1
        side       = 'r'
    end

    import org.opensim.modeling.*
    Logger.setLevelString('Debug');

    limpiar_archivos_ik(ik_result_dir);

    if strcmp(side, 'l')
        secondary_coords = {
            '/jointset/knee_l/knee_add_l';
            '/jointset/knee_l/knee_rot_l';
            '/jointset/knee_l/knee_tx_l';
            '/jointset/knee_l/knee_ty_l';
            '/jointset/knee_l/knee_tz_l';
            '/jointset/pf_l/pf_flex_l';
            '/jointset/pf_l/pf_rot_l';
            '/jointset/pf_l/pf_tilt_l';
            '/jointset/pf_l/pf_tx_l';
            '/jointset/pf_l/pf_ty_l';
            '/jointset/pf_l/pf_tz_l';
        };
        coupled_coord = '/jointset/knee_l/knee_flex_l';
    else
        secondary_coords = {
            '/jointset/knee_r/knee_add_r';
            '/jointset/knee_r/knee_rot_r';
            '/jointset/knee_r/knee_tx_r';
            '/jointset/knee_r/knee_ty_r';
            '/jointset/knee_r/knee_tz_r';
            '/jointset/pf_r/pf_flex_r';
            '/jointset/pf_r/pf_rot_r';
            '/jointset/pf_r/pf_tilt_r';
            '/jointset/pf_r/pf_tx_r';
            '/jointset/pf_r/pf_ty_r';
            '/jointset/pf_r/pf_tz_r';
        };
        coupled_coord = '/jointset/knee_r/knee_flex_r';
    end

    comak_ik = COMAKInverseKinematicsTool();
    comak_ik.set_model_file(model_file);
    comak_ik.set_results_directory(ik_result_dir);
    comak_ik.set_results_prefix(results_basename);
    comak_ik.set_perform_secondary_constraint_sim(true);

    for k = 0:length(secondary_coords)-1
        comak_ik.set_secondary_coordinates(k, secondary_coords{k+1});
    end

    comak_ik.set_secondary_coupled_coordinate(coupled_coord);
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

    function agregar_marker(nombre, peso)
        marker_task = IKMarkerTask();
        marker_task.setName(nombre);
        marker_task.setWeight(peso);
        ik_task_set.cloneAndAppend(marker_task);
        clear marker_task
    end

    agregar_marker('r.should', 1);
    agregar_marker('l.should', 1);
    agregar_marker('c7',       1);
    agregar_marker('r.asis',  15);
    agregar_marker('l.asis',  15);
    agregar_marker('sacrum',  15);
    agregar_marker('r.bar1',   5);
    agregar_marker('r.knee1', 20);
    agregar_marker('r.bar2',   5);
    agregar_marker('r.mall',  20);
    agregar_marker('r.heel',  20);
    agregar_marker('r.met',   20);
    agregar_marker('l.bar1',   5);
    agregar_marker('l.knee1', 20);
    agregar_marker('l.bar2',   5);
    agregar_marker('l.mall',  20);
    agregar_marker('l.heel',  20);
    agregar_marker('l.met',   20);

    comak_ik.set_IKTaskSet(ik_task_set);

    comak_ik.print(['../inputs/' project_id '_' numeric_id '/comak_inverse_kinematics_settings.xml']);

    fprintf('=== EJECUTANDO IK: %s ===\n', datestr(now));
    fprintf('Paciente: %s_%s  |  Side: %s\n', project_id, numeric_id, upper(side));
    disp('Running COMAKInverseKinematicsTool...')

    comak_ik.run();

    clear comak_ik ik_task_set
    java.lang.System.gc()
    pause(0.2)

    fprintf('IK completado y memoria limpiada.\n');
end


function limpiar_archivos_ik(ik_result_dir)
    if ~exist(ik_result_dir, 'dir')
        mkdir(ik_result_dir);
        return;
    end

    f = fullfile(ik_result_dir, 'secondary_coordinate_constraint_functions.xml');
    if exist(f, 'file'), delete(f); fprintf('Eliminado: %s\n', f); end

    delete(fullfile(ik_result_dir, '*.mot'));
    delete(fullfile(ik_result_dir, '*.sto'));
    delete(fullfile(ik_result_dir, '*.log'));
end
