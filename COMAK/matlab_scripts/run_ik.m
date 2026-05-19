function [] = run_ik(model_file, motion_file, ik_result_dir, numeric_id, project_id, results_basename, time_start, time_stop)
    %% Perform Inverse Kinematics – bilateral (right + left knee)
    %
    % The COMAK IK tool only accepts one secondary_coupled_coordinate, so the
    % secondary constraint simulation is split into three phases:
    %   Phase 1 – constraint sim for the RIGHT knee secondary DOFs
    %   Phase 2 – constraint sim for the LEFT  knee secondary DOFs
    %             (input model = Phase 1 output so right constraints are kept)
    %   Phase 3 – merge constraint function XMLs, then run actual IK with all
    %             22 secondary DOFs

    import org.opensim.modeling.*
    Logger.setLevelString('Debug');

    limpiar_archivos_ik(ik_result_dir);

    % ── Secondary coordinate lists ────────────────────────────────────────────
    sec_r = {
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

    sec_l = {
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

    % ── File paths ────────────────────────────────────────────────────────────
    constrained_r   = [ik_result_dir '/ik_constrained_model_r.osim'];
    constrained_rl  = [ik_result_dir '/ik_constrained_model.osim'];
    functions_r     = [ik_result_dir '/constraint_functions_r.xml'];
    functions_l     = [ik_result_dir '/constraint_functions_l.xml'];
    functions_all   = [ik_result_dir '/secondary_coordinate_constraint_functions.xml'];

    % =========================================================================
    % PHASE 1 – Right-knee constraint simulation
    % =========================================================================
    fprintf('\n=== FASE 1/3: Constraint sim DERECHO ===\n');
    fprintf('Paciente: %s_%s\n', project_id, numeric_id);

    ik1 = crear_herramienta_ik(model_file, motion_file, ik_result_dir, results_basename, time_start, time_stop, sec_r);
    ik1.set_secondary_coupled_coordinate('/jointset/knee_r/knee_flex_r');
    ik1.set_secondary_constraint_function_file(functions_r);
    ik1.set_constrained_model_file(constrained_r);
    ik1.set_perform_secondary_constraint_sim(true);
    ik1.set_perform_inverse_kinematics(false);

    ik1.run();
    clear ik1
    java.lang.System.gc()
    pause(0.3)
    fprintf('Constraint sim derecho completado.\n');

    % =========================================================================
    % PHASE 2 – Left-knee constraint simulation
    %           Uses Phase 1 constrained model so right constraints are preserved
    % =========================================================================
    fprintf('\n=== FASE 2/3: Constraint sim IZQUIERDO ===\n');

    ik2 = crear_herramienta_ik(constrained_r, motion_file, ik_result_dir, results_basename, time_start, time_stop, sec_l);
    ik2.set_secondary_coupled_coordinate('/jointset/knee_l/knee_flex_l');
    ik2.set_secondary_constraint_function_file(functions_l);
    ik2.set_constrained_model_file(constrained_rl);
    ik2.set_perform_secondary_constraint_sim(true);
    ik2.set_perform_inverse_kinematics(false);

    ik2.run();
    clear ik2
    java.lang.System.gc()
    pause(0.3)
    fprintf('Constraint sim izquierdo completado.\n');

    % =========================================================================
    % PHASE 3 – Merge constraint functions + run actual bilateral IK
    % =========================================================================
    fprintf('\n=== FASE 3/3: Fusionar funciones + IK bilateral ===\n');

    merge_constraint_functions(functions_r, functions_l, functions_all);

    sec_all = [sec_r; sec_l];   % 22 secondary DOFs total
    ik3 = crear_herramienta_ik(constrained_rl, motion_file, ik_result_dir, results_basename, time_start, time_stop, sec_all);
    ik3.set_secondary_constraint_function_file(functions_all);
    ik3.set_constrained_model_file(constrained_rl);
    ik3.set_perform_secondary_constraint_sim(false);
    ik3.set_perform_inverse_kinematics(true);

    ik3.print(['../inputs/' project_id '_' numeric_id '/comak_inverse_kinematics_settings.xml']);
    disp('Running bilateral COMAKInverseKinematicsTool...')
    ik3.run();
    clear ik3
    java.lang.System.gc()
    pause(0.2)

    fprintf('IK bilateral completado y memoria limpiada.\n');
end


% ─────────────────────────────────────────────────────────────────────────────
% Helper: build a fully configured COMAKInverseKinematicsTool
% ─────────────────────────────────────────────────────────────────────────────
function ik = crear_herramienta_ik(model_file, motion_file, ik_result_dir, results_basename, time_start, time_stop, sec_coords)
    import org.opensim.modeling.*

    ik = COMAKInverseKinematicsTool();
    ik.set_model_file(model_file);
    ik.set_results_directory(ik_result_dir);
    ik.set_results_prefix(results_basename);
    ik.set_perform_secondary_constraint_sim(true);

    % Secondary coordinates
    for k = 0:length(sec_coords)-1
        ik.set_secondary_coordinates(k, sec_coords{k+1});
    end

    % Constraint sim parameters
    ik.set_secondary_constraint_sim_settle_threshold(1e-4);
    ik.set_secondary_constraint_sim_sweep_time(3.0);
    ik.set_secondary_coupled_coordinate_start_value(0);
    ik.set_secondary_coupled_coordinate_stop_value(100);
    ik.set_secondary_constraint_sim_integrator_accuracy(1e-2);
    ik.set_secondary_constraint_sim_internal_step_limit(10000);
    ik.set_constraint_function_num_interpolation_points(20);
    ik.set_print_secondary_constraint_sim_results(true);

    % IK parameters
    ik.set_marker_file(motion_file);
    ik.set_output_motion_file([results_basename '_ik.mot']);
    ik.set_time_range(0, time_start);
    ik.set_time_range(1, time_stop);
    ik.set_report_errors(true);
    ik.set_report_marker_locations(false);
    ik.set_ik_constraint_weight(100);
    ik.set_ik_accuracy(1e-5);
    ik.set_use_visualizer(false);
    ik.set_verbose(10);

    % Marker weights
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

    ik.set_IKTaskSet(ik_task_set);
end


% ─────────────────────────────────────────────────────────────────────────────
% Helper: merge two constraint-function XML files into one
% ─────────────────────────────────────────────────────────────────────────────
function merge_constraint_functions(file_r, file_l, out_file)
    xml_r = fileread(file_r);
    xml_l = fileread(file_l);

    % Extract content of <objects>...</objects> from each file
    tok_r = regexp(xml_r, '<objects>(.*?)</objects>', 'tokens', 'once', 'dotall');
    tok_l = regexp(xml_l, '<objects>(.*?)</objects>', 'tokens', 'once', 'dotall');

    if isempty(tok_r) || isempty(tok_l)
        error('merge_constraint_functions: could not parse <objects> section in constraint function files.');
    end

    combined = [tok_r{1}, tok_l{1}];
    merged = regexprep(xml_r, '(<objects>)(.*?)(</objects>)', ...
        ['$1' combined '$3'], 'dotall', 'once');

    fid = fopen(out_file, 'w');
    fwrite(fid, merged, 'char');
    fclose(fid);
    fprintf('Constraint functions merged -> %s\n', out_file);
end


% ─────────────────────────────────────────────────────────────────────────────
% Helper: clean previous IK output files
% ─────────────────────────────────────────────────────────────────────────────
function limpiar_archivos_ik(ik_result_dir)
    if ~exist(ik_result_dir, 'dir')
        mkdir(ik_result_dir);
        return;
    end

    archivos_criticos = {
        'secondary_coordinate_constraint_functions.xml',
        'constraint_functions_r.xml',
        'constraint_functions_l.xml',
        'ik_constrained_model_r.osim',
        'ik_constrained_model.osim'
    };
    for k = 1:length(archivos_criticos)
        f = fullfile(ik_result_dir, archivos_criticos{k});
        if exist(f, 'file'), delete(f); fprintf('Eliminado: %s\n', f); end
    end

    delete(fullfile(ik_result_dir, '*.mot'));
    delete(fullfile(ik_result_dir, '*.sto'));
    delete(fullfile(ik_result_dir, '*.log'));
end
