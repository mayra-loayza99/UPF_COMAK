function [] = run_comak(model_file, ext_load_file, comak_result_dir, numeric_id, project_id, results_basename, time_start, time_stop, contact_energy_weight, custom_muscle_weights, comak_muscle_weight_result_dir, compare_contact_energy_weight, comak_contact_energy_result_dir)
    % Perform COMAK simulation
    %
    % This function performs a COMAK (Concurrent Optimization of Muscle
    % Activations and Kinematics) simulation using the provided model 
    % and various parameters. It optionally allows for custom muscle 
    % weights and comparison of different contact energy weights.
    %
    % Parameters:
    % model_file: string, path to the model file
    % ext_load_file: string, path to the external loads file
    % comak_result_dir: string, directory to save the COMAK results
    % numeric_id: string, numerical identifier for results directories
    % results_basename: string, base name for the results files
    % time_start: double, start time of the simulation
    % time_stop: double, stop time of the simulation
    % contact_energy_weight: double, weight for the contact energy in the simulation
    % custom_muscle_weights: boolean, flag to use custom muscle weights
    % comak_muscle_weight_result_dir: string, directory to save results with custom muscle weights
    % compare_contact_energy_weight: double or boolean, contact energy weight for comparison (false if not comparing)
    % comak_contact_energy_result_dir: string, directory to save comparison results


    % Set default values
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
     
    % Run COMAK
    import org.opensim.modeling.*
    Logger.setLevelString('Debug');
    
        % Ruta al archivo de cinemática
    ik_file = ['../results/' project_id '_' numeric_id ...
               '/comak_inverse_kinematics/' results_basename '_ik.mot'];
%     ik_fixed_file = fixIKforCOMAK(ik_file);
    ik_file
    % Leer archivo IK
    ik_data = importdata(ik_file);

    % Extraer vector de tiempo (primera columna)
    time = ik_data.data(:,1);

    % Verificación básica
    if isempty(time) || any(isnan(time))
        error('El archivo IK no contiene datos de tiempo válidos.');
    end

    % Derivar tiempos de inicio y fin con margen de seguridad
    time_start= time(1);
    time_stop= time(end);


    comak = COMAKTool();
    comak.set_model_file(model_file);
    comak.set_coordinates_file(['../results/' project_id '_' numeric_id '/comak_inverse_kinematics/' results_basename '_ik.mot']);
%     comak.set_coordinates_file(ik_fixed_file);
    comak.set_external_loads_file(ext_load_file);
    comak.set_results_directory(comak_result_dir);
    comak.set_results_prefix(results_basename);
    comak.set_replace_force_set(false);
    comak.set_force_set_file('../data/lenhart2015_reserve_actuators.xml');
    mid_time = time(1) + 1* (time(end) - time(1));
    comak.set_start_time(time_start);
    comak.set_stop_time(mid_time);
    comak.set_time_step(0.01);
    comak.set_lowpass_filter_frequency(6);
    comak.set_print_processed_input_kinematics(false);
    comak.set_prescribed_coordinates(0,'/jointset/gnd_pelvis/pelvis_tx');
    comak.set_prescribed_coordinates(1,'/jointset/gnd_pelvis/pelvis_ty');
    comak.set_prescribed_coordinates(2,'/jointset/gnd_pelvis/pelvis_tz');
    comak.set_prescribed_coordinates(3,'/jointset/gnd_pelvis/pelvis_tilt');
    comak.set_prescribed_coordinates(4,'/jointset/gnd_pelvis/pelvis_list');
    comak.set_prescribed_coordinates(5,'/jointset/gnd_pelvis/pelvis_rot');
    comak.set_prescribed_coordinates(6,'/jointset/subtalar_r/subt_angle_r');
    comak.set_prescribed_coordinates(7,'/jointset/mtp_r/mtp_angle_r');
    comak.set_prescribed_coordinates(8,'/jointset/hip_l/hip_flex_l');
    comak.set_prescribed_coordinates(9,'/jointset/hip_l/hip_add_l');
    comak.set_prescribed_coordinates(10,'/jointset/hip_l/hip_rot_l');
    comak.set_prescribed_coordinates(11,'/jointset/pf_l/pf_l_r3');
    comak.set_prescribed_coordinates(12,'/jointset/pf_l/pf_l_tx');
    comak.set_prescribed_coordinates(13,'/jointset/pf_l/pf_l_ty');
    comak.set_prescribed_coordinates(14,'/jointset/knee_l/knee_flex_l');
    comak.set_prescribed_coordinates(15,'/jointset/ankle_l/ankle_flex_l');
    comak.set_prescribed_coordinates(16,'/jointset/subtalar_l/subt_angle_l');
    comak.set_prescribed_coordinates(17,'/jointset/mtp_l/mtp_angle_l');
    comak.set_prescribed_coordinates(18,'/jointset/pelvis_torso/lumbar_ext');
    comak.set_prescribed_coordinates(19,'/jointset/pelvis_torso/lumbar_latbend');
    comak.set_prescribed_coordinates(20,'/jointset/pelvis_torso/lumbar_rot');
    comak.set_prescribed_coordinates(21,'/jointset/torso_neckhead/neck_ext');
    comak.set_prescribed_coordinates(22,'/jointset/torso_neckhead/neck_latbend');
    comak.set_prescribed_coordinates(23,'/jointset/torso_neckhead/neck_rot');
    comak.set_prescribed_coordinates(24,'/jointset/acromial_r/arm_add_r');
    comak.set_prescribed_coordinates(25,'/jointset/acromial_r/arm_flex_r');
    comak.set_prescribed_coordinates(26,'/jointset/acromial_r/arm_rot_r');
    comak.set_prescribed_coordinates(27,'/jointset/elbow_r/elbow_flex_r');
    comak.set_prescribed_coordinates(28,'/jointset/radioulnar_r/pro_sup_r');
    comak.set_prescribed_coordinates(29,'/jointset/radius_hand_r/wrist_flex_r');
    comak.set_prescribed_coordinates(30,'/jointset/acromial_l/arm_add_l');
    comak.set_prescribed_coordinates(31,'/jointset/acromial_l/arm_flex_l');
    comak.set_prescribed_coordinates(32,'/jointset/acromial_l/arm_rot_l');
    comak.set_prescribed_coordinates(33,'/jointset/elbow_l/elbow_flex_l');
    comak.set_prescribed_coordinates(34,'/jointset/radioulnar_l/pro_sup_l');
    comak.set_prescribed_coordinates(35,'/jointset/radius_hand_l/wrist_flex_l');
     
    comak.set_primary_coordinates(0,'/jointset/hip_r/hip_flex_r');
    comak.set_primary_coordinates(1,'/jointset/hip_r/hip_add_r');
    comak.set_primary_coordinates(2,'/jointset/hip_r/hip_rot_r');
    comak.set_primary_coordinates(3,'/jointset/knee_r/knee_flex_r');
    comak.set_primary_coordinates(4,'/jointset/ankle_r/ankle_flex_r');
    
    secondary_coord_set = COMAKSecondaryCoordinateSet(); 
    secondary_coord = COMAKSecondaryCoordinate();
    
    secondary_coord.setName('knee_add_r');
    secondary_coord.set_max_change(0.01);
    secondary_coord.set_coordinate('/jointset/knee_r/knee_add_r');
    secondary_coord_set.cloneAndAppend(secondary_coord);
    
    secondary_coord.setName('knee_rot_r');
    secondary_coord.set_max_change(0.01);
    secondary_coord.set_coordinate('/jointset/knee_r/knee_rot_r');
    secondary_coord_set.cloneAndAppend(secondary_coord);
    
    secondary_coord.setName('knee_tx_r');
    secondary_coord.set_max_change(0.05);
    secondary_coord.set_coordinate('/jointset/knee_r/knee_tx_r');
    secondary_coord_set.cloneAndAppend(secondary_coord);
    
    secondary_coord.setName('knee_ty_r');
    secondary_coord.set_max_change(0.05);
    secondary_coord.set_coordinate('/jointset/knee_r/knee_ty_r');
    secondary_coord_set.cloneAndAppend(secondary_coord);
    
    secondary_coord.setName('knee_tz_r');
    secondary_coord.set_max_change(0.05);
    secondary_coord.set_coordinate('/jointset/knee_r/knee_tz_r');
    secondary_coord_set.cloneAndAppend(secondary_coord);
    
    secondary_coord.setName('pf_flex_r');
    secondary_coord.set_max_change(0.01);
    secondary_coord.set_coordinate('/jointset/pf_r/pf_flex_r');
    secondary_coord_set.cloneAndAppend(secondary_coord);
    
    secondary_coord.setName('pf_rot_r');
    secondary_coord.set_max_change(0.01);
    secondary_coord.set_coordinate('/jointset/pf_r/pf_rot_r');
    secondary_coord_set.cloneAndAppend(secondary_coord);
    
    secondary_coord.setName('pf_tilt_r');
    secondary_coord.set_max_change(0.01);
    secondary_coord.set_coordinate('/jointset/pf_r/pf_tilt_r');
    secondary_coord_set.cloneAndAppend(secondary_coord);
    
    secondary_coord.setName('pf_tx_r');
    secondary_coord.set_max_change(0.005);
    secondary_coord.set_coordinate('/jointset/pf_r/pf_tx_r');
    secondary_coord_set.cloneAndAppend(secondary_coord);
    
    secondary_coord.setName('pf_ty_r');
    secondary_coord.set_max_change(0.005);
    secondary_coord.set_coordinate('/jointset/pf_r/pf_ty_r');
    secondary_coord_set.cloneAndAppend(secondary_coord);
    
    secondary_coord.setName('pf_tz_r');
    secondary_coord.set_max_change(0.005);
    secondary_coord.set_coordinate('/jointset/pf_r/pf_tz_r');
    secondary_coord_set.cloneAndAppend(secondary_coord);
    
    comak.set_COMAKSecondaryCoordinateSet(secondary_coord_set);
    
    comak.set_settle_secondary_coordinates_at_start(true);
    comak.set_settle_threshold(1e-3);
    comak.set_settle_accuracy(1e-2);
    comak.set_settle_internal_step_limit(10000);
    comak.set_print_settle_sim_results(true);
    comak.set_settle_sim_results_directory(comak_result_dir);
    comak.set_settle_sim_results_prefix('walking_settle_sim');
    comak.set_max_iterations(25);
    comak.set_udot_tolerance(1);
    comak.set_udot_worse_case_tolerance(50);
    comak.set_unit_udot_epsilon(1e-6);
    comak.set_optimization_scale_delta_coord(1);
    comak.set_ipopt_diagnostics_level(3);
    comak.set_ipopt_max_iterations(500);
    comak.set_ipopt_convergence_tolerance(1e-4);
    comak.set_ipopt_constraint_tolerance(1e-4);
    comak.set_ipopt_limited_memory_history(200);
    comak.set_ipopt_nlp_scaling_max_gradient(10000);
    comak.set_ipopt_nlp_scaling_min_value(1e-8);
    comak.set_ipopt_obj_scaling_factor(1);
    comak.set_activation_exponent(2);
    comak.set_contact_energy_weight(contact_energy_weight);
    comak.set_non_muscle_actuator_weight(1000);
    comak.set_model_assembly_accuracy(1e-12);
    comak.set_use_visualizer(false);
    comak.set_verbose(2);

    if custom_muscle_weights == true
        % Perform COMAK simulation with muscle weights
        comak_muscle_weight = comak.clone();
        comak_muscle_weight.set_results_directory(comak_muscle_weight_result_dir);
        comak_muscle_weight.set_results_prefix([results_basename '_muscle_weight']);
        comak_muscle_weight.set_contact_energy_weight(contact_energy_weight);

        cost_fun_param_set = COMAKCostFunctionParameterSet();
        cost_fun_param = COMAKCostFunctionParameter();
        
        cost_fun_param.setName('gasmed_r');
        cost_fun_param.set_actuator('/forceset/gasmed_r');
        cost_fun_param.set_weight(Constant(4));
        cost_fun_param_set.cloneAndAppend(cost_fun_param);
        
        cost_fun_param.setName('gaslat_r');
        cost_fun_param.set_actuator('/forceset/gaslat_r');
        cost_fun_param.set_weight(Constant(7));
        cost_fun_param_set.cloneAndAppend(cost_fun_param);
        
        cost_fun_param.setName('soleus_r');
        cost_fun_param.set_actuator('/forceset/soleus_r');
        cost_fun_param.set_weight(Constant(0.9));
        cost_fun_param_set.cloneAndAppend(cost_fun_param);
        
        cost_fun_param.setName('recfem_r');
        cost_fun_param.set_actuator('/forceset/recfem_r');
        cost_fun_param.set_weight(Constant(3));
        cost_fun_param_set.cloneAndAppend(cost_fun_param);
        
        cost_fun_param.setName('glmed1_r');
        cost_fun_param.set_actuator('/forceset/glmed1_r');
        cost_fun_param.set_weight(Constant(0.9));
        cost_fun_param_set.cloneAndAppend(cost_fun_param);
        
        cost_fun_param.setName('glmed2_r');
        cost_fun_param.set_actuator('/forceset/glmed1_r');
        cost_fun_param.set_weight(Constant(0.9));
        cost_fun_param_set.cloneAndAppend(cost_fun_param);
        
        cost_fun_param.setName('glmed3_r');
        cost_fun_param.set_actuator('/forceset/glmed3_r');
        cost_fun_param.set_weight(Constant(0.9));
        cost_fun_param_set.cloneAndAppend(cost_fun_param);
        
        cost_fun_param.setName('glmin1_r');
        cost_fun_param.set_actuator('/forceset/glmin1_r');
        cost_fun_param.set_weight(Constant(0.9));
        cost_fun_param_set.cloneAndAppend(cost_fun_param);
        
        cost_fun_param.setName('glmin2_r');
        cost_fun_param.set_actuator('/forceset/glmin2_r');
        cost_fun_param.set_weight(Constant(0.9));
        cost_fun_param_set.cloneAndAppend(cost_fun_param);
        
        cost_fun_param.setName('glmin3_r');
        cost_fun_param.set_actuator('/forceset/glmin3_r');
        cost_fun_param.set_weight(Constant(0.9));
        cost_fun_param_set.cloneAndAppend(cost_fun_param);
        
        cost_fun_param.setName('bflh_r');
        cost_fun_param.set_actuator('/forceset/bflh_r');
        cost_fun_param.set_weight(Constant(2));
        cost_fun_param_set.cloneAndAppend(cost_fun_param);
        
        cost_fun_param.setName('bfsh_r');
        cost_fun_param.set_actuator('/forceset/bfsh_r');
        cost_fun_param.set_weight(Constant(2));
        cost_fun_param_set.cloneAndAppend(cost_fun_param);
        
        cost_fun_param.setName('semiten_r');
        cost_fun_param.set_actuator('/forceset/semiten_r');
        cost_fun_param.set_weight(Constant(2));
        cost_fun_param_set.cloneAndAppend(cost_fun_param);
        
        cost_fun_param.setName('semimem_r');
        cost_fun_param.set_actuator('/forceset/semimem_r');
        cost_fun_param.set_weight(Constant(2));
        cost_fun_param_set.cloneAndAppend(cost_fun_param);
        
        comak_muscle_weight.set_COMAKCostFunctionParameterSet(cost_fun_param_set);
        comak_muscle_weight.print(['../inputs/' project_id '_' numeric_id '/comak_muscle_weights_settings.xml']);
        
        disp(['Running COMAK Tool with custom muscle weights and contact energy weight = ' num2str(contact_energy_weight) ' ...'])
        comak_muscle_weight.run();

        if compare_contact_energy_weight ~= 0
            % Perform COMAK simulation with other contact energy weight
            comak_contact_energy = comak_muscle_weight.clone();
            comak_contact_energy.set_results_directory(comak_contact_energy_result_dir);
            comak_contact_energy.set_results_prefix([results_basename '_contact_energy_2_' num2str(compare_contact_energy_weight)]);
            
            comak_contact_energy.set_contact_energy_weight(compare_contact_energy_weight);
            
            comak_contact_energy.print(['../inputs/' project_id '_' numeric_id '/comak_contact_energy_2_' num2str(compare_contact_energy_weight) '_settings.xml']);
            
            disp(['Running COMAK Tool again with contact energy weight = ' num2str(compare_contact_energy_weight) '...'])
            comak_contact_energy.run();
        end
    else
        comak.print(['../inputs/' project_id '_' numeric_id '/comak_settings.xml']);
        disp(['Running COMAK Tool with default muscle weights and contact energy weight = ' num2str(contact_energy_weight) ' ...'])
        comak.run();

        if compare_contact_energy_weight ~= 0
            % Perform COMAK simulation with other contact energy weight
            comak_contact_energy = comak.clone();
            comak_contact_energy.set_results_directory(comak_contact_energy_result_dir);
            comak_contact_energy.set_results_prefix([results_basename '_contact_energy_' compare_contact_energy_weight]);
            
            comak_contact_energy.set_contact_energy_weight(compare_contact_energy_weight);
            
            comak_contact_energy.print(['../inputs/' project_id '_' numeric_id '/comak_contact_energy_' num2str(compare_contact_energy_weight) '_settings.xml']);
            
            disp(['Running COMAK Tool again with contact energy weight = ' num2str(compare_contact_energy_weight) ' ...'])
            comak_contact_energy.run();
        end
    end
end
