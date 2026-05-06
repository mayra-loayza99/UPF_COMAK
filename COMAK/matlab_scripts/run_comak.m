function [] = run_comak(model_file, ext_load_file, comak_result_dir, numeric_id, project_id, results_basename, time_start, time_stop, contact_energy_weight, custom_muscle_weights, comak_muscle_weight_result_dir, compare_contact_energy_weight, comak_contact_energy_result_dir)
    
    arguments
        model_file
        ext_load_file
        comak_result_dir
        numeric_id
        project_id
        results_basename
        time_start = -1
        time_stop = -1
        contact_energy_weight = 100
        custom_muscle_weights = false
        comak_muscle_weight_result_dir = [] 
        compare_contact_energy_weight = 0
        comak_contact_energy_result_dir = []
    end
     
    % LIMPIEZA INICIAL
    import org.opensim.modeling.*
    Logger.setLevelString('Debug');
    
    % Limpiar directorios de resultados
    limpiar_archivos_comak(comak_result_dir);
    if ~isempty(comak_muscle_weight_result_dir)
        limpiar_archivos_comak(comak_muscle_weight_result_dir);
    end
    if ~isempty(comak_contact_energy_result_dir)
        limpiar_archivos_comak(comak_contact_energy_result_dir);
    end
    
    ik_file = ['../results/' project_id '_' numeric_id ...
               '/comak_inverse_kinematics/' results_basename '_ik.mot'];
           
    % Leer archivo IK
    ik_data = importdata(ik_file);
    time = ik_data.data(:,1);

    if isempty(time) || any(isnan(time))
        error('El archivo IK no contiene datos de tiempo válidos.');
    end

    % Derivar tiempos
    time_start = time(1);
    time_stop = time(end);  % ✅ CAMBIADO: Simular ciclo completo
    % Si quieres mantener el 90%: 
%     time_stop = time(1) + 1 * (time(end) - time(1));

    fprintf('=== CONFIGURACIÓN COMAK ===\n');
    fprintf('Paciente: %s_%s\n', project_id, numeric_id);
    fprintf('Tiempo: %.3f - %.3f s\n', time_start, time_stop);
    fprintf('Contact energy weight: %.1f\n', contact_energy_weight);

    if custom_muscle_weights == true
        % ✅ CREAR OBJETO NUEVO (no clonar)
        comak_muscle_weight = configurar_comak_base(model_file, ext_load_file, ...
            results_basename, time_start, time_stop, contact_energy_weight, ...
            comak_muscle_weight_result_dir, [results_basename '_muscle_weight'], ...
            project_id, numeric_id);
        
        % Configurar muscle weights
        cost_fun_param_set = configurar_muscle_weights();
        comak_muscle_weight.set_COMAKCostFunctionParameterSet(cost_fun_param_set);
        
        comak_muscle_weight.print(['../inputs/' project_id '_' numeric_id '/comak_muscle_weights_settings.xml']);
        
        disp(['Running COMAK Tool with custom muscle weights and contact energy weight = ' num2str(contact_energy_weight) ' ...'])
        comak_muscle_weight.run();
        
        % LIMPIEZA CRÍTICA
        clear comak_muscle_weight cost_fun_param_set
        java.lang.System.gc()
        pause(0.3)
        fprintf('COMAK con muscle weights completado y limpiado.\n');

        if compare_contact_energy_weight ~= 0
            % ✅ CREAR OBJETO COMPLETAMENTE NUEVO
            comak_contact_energy = configurar_comak_base(model_file, ext_load_file, ...
                results_basename, time_start, time_stop, compare_contact_energy_weight, ...
                comak_contact_energy_result_dir, [results_basename '_contact_energy_2_' num2str(compare_contact_energy_weight)], ...
                project_id, numeric_id);
            
            % Volver a configurar muscle weights
            cost_fun_param_set = configurar_muscle_weights();
            comak_contact_energy.set_COMAKCostFunctionParameterSet(cost_fun_param_set);
            
            comak_contact_energy.print(['../inputs/' project_id '_' numeric_id '/comak_contact_energy_2_' num2str(compare_contact_energy_weight) '_settings.xml']);
            
            disp(['Running COMAK Tool again with contact energy weight = ' num2str(compare_contact_energy_weight) '...'])
            comak_contact_energy.run();
            
            % LIMPIEZA
            clear comak_contact_energy cost_fun_param_set
            java.lang.System.gc()
            pause(0.3)
            fprintf('COMAK con contact energy alternativo completado y limpiado.\n');
        end
    else
        % ✅ CREAR OBJETO NUEVO
        comak = configurar_comak_base(model_file, ext_load_file, ...
            results_basename, time_start, time_stop, contact_energy_weight, ...
            comak_result_dir, results_basename, project_id, numeric_id);
        
        comak.print(['../inputs/' project_id '_' numeric_id '/comak_settings.xml']);
        disp(['Running COMAK Tool with default muscle weights and contact energy weight = ' num2str(contact_energy_weight) ' ...'])
        comak.run();
        
        % LIMPIEZA CRÍTICA
        clear comak
        java.lang.System.gc()
        pause(0.3)
        fprintf('COMAK default completado y limpiado.\n');

        if compare_contact_energy_weight ~= 0
            % ✅ CREAR OBJETO COMPLETAMENTE NUEVO
            comak_contact_energy = configurar_comak_base(model_file, ext_load_file, ...
                results_basename, time_start, time_stop, compare_contact_energy_weight, ...
                comak_contact_energy_result_dir, [results_basename '_contact_energy_' num2str(compare_contact_energy_weight)], ...
                project_id, numeric_id);
            
            comak_contact_energy.print(['../inputs/' project_id '_' numeric_id '/comak_contact_energy_' num2str(compare_contact_energy_weight) '_settings.xml']);
            
            disp(['Running COMAK Tool again with contact energy weight = ' num2str(compare_contact_energy_weight) ' ...'])
            comak_contact_energy.run();
            
            % LIMPIEZA
            clear comak_contact_energy
            java.lang.System.gc()
            pause(0.3)
            fprintf('COMAK con contact energy alternativo completado y limpiado.\n');
        end
    end
    
    % LIMPIEZA FINAL AGRESIVA
%     clear all
    java.lang.System.gc()
    fprintf('=== COMAK FINALIZADO ===\n\n');
end

function limpiar_archivos_comak(result_dir)
    if ~exist(result_dir, 'dir')
        mkdir(result_dir);
        return;
    end
    
    % Eliminar archivos de resultados previos
    delete(fullfile(result_dir, '*.sto'));
    delete(fullfile(result_dir, '*.mot'));
    delete(fullfile(result_dir, '*.log'));
end

function cost_fun_param_set = configurar_muscle_weights()
    % Crea y configura los muscle weights
    import org.opensim.modeling.*
    
    cost_fun_param_set = COMAKCostFunctionParameterSet();
    cost_fun_param = COMAKCostFunctionParameter();
    
    % Lista de músculos con sus pesos
    musculos = {
        'gasmed_r', '/forceset/gasmed_r', 4;
        'gaslat_r', '/forceset/gaslat_r', 7;
        'soleus_r', '/forceset/soleus_r', 0.9;
        'recfem_r', '/forceset/recfem_r', 3;
        'glmed1_r', '/forceset/glmed1_r', 0.9;
        'glmed2_r', '/forceset/glmed1_r', 0.9;  % Nota: usa glmed1_r (parece ser del código original)
        'glmed3_r', '/forceset/glmed3_r', 0.9;
        'glmin1_r', '/forceset/glmin1_r', 0.9;
        'glmin2_r', '/forceset/glmin2_r', 0.9;
        'glmin3_r', '/forceset/glmin3_r', 0.9;
        'bflh_r', '/forceset/bflh_r', 2;
        'bfsh_r', '/forceset/bfsh_r', 2;
        'semiten_r', '/forceset/semiten_r', 2;
        'semimem_r', '/forceset/semimem_r', 2;
    };
    
    for i = 1:size(musculos, 1)
        cost_fun_param.setName(musculos{i,1});
        cost_fun_param.set_actuator(musculos{i,2});
        cost_fun_param.set_weight(Constant(musculos{i,3}));
        cost_fun_param_set.cloneAndAppend(cost_fun_param);
    end
end

% [La función configurar_comak_base() va aquí - es la misma que te proporcioné antes]

function comak_tool = configurar_comak_base(model_file, ext_load_file, results_basename, time_start, time_stop, contact_energy_weight, result_dir, result_prefix, project_id, numeric_id)
    % Crea un objeto COMAKTool NUEVO con configuración completa
    
    import org.opensim.modeling.*
    
    comak_tool = COMAKTool();  % ✅ OBJETO NUEVO
    comak_tool.set_model_file(model_file);
    comak_tool.set_coordinates_file(['../results/' project_id '_' numeric_id '/comak_inverse_kinematics/' results_basename '_ik.mot']);
    comak_tool.set_external_loads_file(ext_load_file);
    comak_tool.set_results_directory(result_dir);
    comak_tool.set_results_prefix(result_prefix);
    comak_tool.set_replace_force_set(false);
    comak_tool.set_force_set_file('../data/lenhart2015_reserve_actuators.xml');
    comak_tool.set_start_time(time_start);
    comak_tool.set_stop_time(time_stop);
    comak_tool.set_time_step(0.01);
    comak_tool.set_lowpass_filter_frequency(6);
    comak_tool.set_print_processed_input_kinematics(false);
    
    % Prescribed coordinates
    comak_tool.set_prescribed_coordinates(0,'/jointset/gnd_pelvis/pelvis_tx');
    comak_tool.set_prescribed_coordinates(1,'/jointset/gnd_pelvis/pelvis_ty');
    comak_tool.set_prescribed_coordinates(2,'/jointset/gnd_pelvis/pelvis_tz');
    comak_tool.set_prescribed_coordinates(3,'/jointset/gnd_pelvis/pelvis_tilt');
    comak_tool.set_prescribed_coordinates(4,'/jointset/gnd_pelvis/pelvis_list');
    comak_tool.set_prescribed_coordinates(5,'/jointset/gnd_pelvis/pelvis_rot');
    comak_tool.set_prescribed_coordinates(6,'/jointset/subtalar_r/subt_angle_r');
    comak_tool.set_prescribed_coordinates(7,'/jointset/mtp_r/mtp_angle_r');
    comak_tool.set_prescribed_coordinates(8,'/jointset/hip_l/hip_flex_l');
    comak_tool.set_prescribed_coordinates(9,'/jointset/hip_l/hip_add_l');
    comak_tool.set_prescribed_coordinates(10,'/jointset/hip_l/hip_rot_l');
    comak_tool.set_prescribed_coordinates(11,'/jointset/pf_l/pf_l_r3');
    comak_tool.set_prescribed_coordinates(12,'/jointset/pf_l/pf_l_tx');
    comak_tool.set_prescribed_coordinates(13,'/jointset/pf_l/pf_l_ty');
    comak_tool.set_prescribed_coordinates(14,'/jointset/knee_l/knee_flex_l');
    comak_tool.set_prescribed_coordinates(15,'/jointset/ankle_l/ankle_flex_l');
    comak_tool.set_prescribed_coordinates(16,'/jointset/subtalar_l/subt_angle_l');
    comak_tool.set_prescribed_coordinates(17,'/jointset/mtp_l/mtp_angle_l');
    comak_tool.set_prescribed_coordinates(18,'/jointset/pelvis_torso/lumbar_ext');
    comak_tool.set_prescribed_coordinates(19,'/jointset/pelvis_torso/lumbar_latbend');
    comak_tool.set_prescribed_coordinates(20,'/jointset/pelvis_torso/lumbar_rot');
    comak_tool.set_prescribed_coordinates(21,'/jointset/torso_neckhead/neck_ext');
    comak_tool.set_prescribed_coordinates(22,'/jointset/torso_neckhead/neck_latbend');
    comak_tool.set_prescribed_coordinates(23,'/jointset/torso_neckhead/neck_rot');
    comak_tool.set_prescribed_coordinates(24,'/jointset/acromial_r/arm_add_r');
    comak_tool.set_prescribed_coordinates(25,'/jointset/acromial_r/arm_flex_r');
    comak_tool.set_prescribed_coordinates(26,'/jointset/acromial_r/arm_rot_r');
    comak_tool.set_prescribed_coordinates(27,'/jointset/elbow_r/elbow_flex_r');
    comak_tool.set_prescribed_coordinates(28,'/jointset/radioulnar_r/pro_sup_r');
    comak_tool.set_prescribed_coordinates(29,'/jointset/radius_hand_r/wrist_flex_r');
    comak_tool.set_prescribed_coordinates(30,'/jointset/acromial_l/arm_add_l');
    comak_tool.set_prescribed_coordinates(31,'/jointset/acromial_l/arm_flex_l');
    comak_tool.set_prescribed_coordinates(32,'/jointset/acromial_l/arm_rot_l');
    comak_tool.set_prescribed_coordinates(33,'/jointset/elbow_l/elbow_flex_l');
    comak_tool.set_prescribed_coordinates(34,'/jointset/radioulnar_l/pro_sup_l');
    comak_tool.set_prescribed_coordinates(35,'/jointset/radius_hand_l/wrist_flex_l');
     
    % Primary coordinates
    comak_tool.set_primary_coordinates(0,'/jointset/hip_r/hip_flex_r');
    comak_tool.set_primary_coordinates(1,'/jointset/hip_r/hip_add_r');
    comak_tool.set_primary_coordinates(2,'/jointset/hip_r/hip_rot_r');
    comak_tool.set_primary_coordinates(3,'/jointset/knee_r/knee_flex_r');
    comak_tool.set_primary_coordinates(4,'/jointset/ankle_r/ankle_flex_r');
    
    % Secondary coordinates
    secondary_coord_set = COMAKSecondaryCoordinateSet(); 
    secondary_coord = COMAKSecondaryCoordinate();
    
    coordenadas_secundarias = {
        'knee_add_r', '/jointset/knee_r/knee_add_r', 0.01;
        'knee_rot_r', '/jointset/knee_r/knee_rot_r', 0.01;
        'knee_tx_r', '/jointset/knee_r/knee_tx_r', 0.05;
        'knee_ty_r', '/jointset/knee_r/knee_ty_r', 0.05;
        'knee_tz_r', '/jointset/knee_r/knee_tz_r', 0.05;
        'pf_flex_r', '/jointset/pf_r/pf_flex_r', 0.01;
        'pf_rot_r', '/jointset/pf_r/pf_rot_r', 0.01;
        'pf_tilt_r', '/jointset/pf_r/pf_tilt_r', 0.01;
        'pf_tx_r', '/jointset/pf_r/pf_tx_r', 0.005;
        'pf_ty_r', '/jointset/pf_r/pf_ty_r', 0.005;
        'pf_tz_r', '/jointset/pf_r/pf_tz_r', 0.005;
    };
    
    for i = 1:size(coordenadas_secundarias, 1)
        secondary_coord.setName(coordenadas_secundarias{i,1});
        secondary_coord.set_coordinate(coordenadas_secundarias{i,2});
        secondary_coord.set_max_change(coordenadas_secundarias{i,3});
        secondary_coord_set.cloneAndAppend(secondary_coord);
    end
    
    comak_tool.set_COMAKSecondaryCoordinateSet(secondary_coord_set);
    
    % Optimizer settings
    comak_tool.set_settle_secondary_coordinates_at_start(true);
    comak_tool.set_settle_threshold(1e-3);
    comak_tool.set_settle_accuracy(1e-2);
    comak_tool.set_settle_internal_step_limit(10000);
    comak_tool.set_print_settle_sim_results(true);
    comak_tool.set_settle_sim_results_directory(result_dir);
    comak_tool.set_settle_sim_results_prefix('walking_settle_sim');
    comak_tool.set_max_iterations(25);
    comak_tool.set_udot_tolerance(1);
    comak_tool.set_udot_worse_case_tolerance(50);
    comak_tool.set_unit_udot_epsilon(1e-6);
    comak_tool.set_optimization_scale_delta_coord(1);
    comak_tool.set_ipopt_diagnostics_level(3);
    comak_tool.set_ipopt_max_iterations(500);
    comak_tool.set_ipopt_convergence_tolerance(1e-4);
    comak_tool.set_ipopt_constraint_tolerance(1e-4);
    comak_tool.set_ipopt_limited_memory_history(200);
    comak_tool.set_ipopt_nlp_scaling_max_gradient(10000);
    comak_tool.set_ipopt_nlp_scaling_min_value(1e-8);
    comak_tool.set_ipopt_obj_scaling_factor(1);
    comak_tool.set_activation_exponent(2);
    comak_tool.set_contact_energy_weight(contact_energy_weight);
    comak_tool.set_non_muscle_actuator_weight(1000);
    comak_tool.set_model_assembly_accuracy(1e-12);
    comak_tool.set_use_visualizer(false);
    comak_tool.set_verbose(2);
end