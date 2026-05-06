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