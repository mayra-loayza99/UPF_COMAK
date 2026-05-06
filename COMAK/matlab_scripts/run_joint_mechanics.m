function [] = run_joint_mechanics(model_file, comak_result_dir, jnt_mech_result_dir, numeric_id, project_id, results_basename, time_start, time_stop, print_vtp)
    %% Perform Joint Mechanics Analysis
    %
    % This function initializes and runs the Joint Mechanics Tool to perform
    % joint mechanics analysis based on the provided inputs.
    %
    % Parameters:
    % model_file: string, path to the model file
    % comak_result_dir: string, directory containing COMAK results
    % jnt_mech_result_dir: string, directory to save Joint Mechanics results
    % numeric_id: string, numerical identifier for directories
    % project_id: string, project identifier
    % results_basename: string, base name for the results files
    % time_start: double, start time of the analysis
    % time_stop: double, stop time of the analysis
    % print_vtp: boolean, flag to print vtp files (e.g., for paraview visualization)
     
    % Set default values
    arguments
        model_file
        comak_result_dir
        jnt_mech_result_dir
        numeric_id
        project_id
        results_basename
        time_start = 0
        time_stop = -1
        print_vtp = true
    end
    
    % LIMPIEZA INICIAL
    import org.opensim.modeling.*
    Logger.setLevelString('Debug');
    
    % Limpiar archivos previos de Joint Mechanics
    limpiar_archivos_jm(jnt_mech_result_dir);
    
    fprintf('=== CONFIGURACIÓN JOINT MECHANICS ===\n');
    fprintf('Paciente: %s_%s\n', project_id, numeric_id);
    fprintf('Directorio resultados: %s\n', jnt_mech_result_dir);
    
    % ✅ CREAR OBJETO NUEVO (no reutilizar)
    jnt_mech = JointMechanicsTool();
    jnt_mech.set_model_file(model_file);
    jnt_mech.set_use_muscle_physiology(false);
    jnt_mech.set_results_file_basename(results_basename);
    jnt_mech.set_results_directory(jnt_mech_result_dir);
    jnt_mech.set_start_time(time_start);
    jnt_mech.set_stop_time(time_stop);
    jnt_mech.set_resample_step_size(-1);
    jnt_mech.set_normalize_to_cycle(true);
    jnt_mech.set_lowpass_filter_frequency(-1);
    jnt_mech.set_print_processed_kinematics(false);
    jnt_mech.set_contacts(0,'all');
    jnt_mech.set_contact_outputs(0,'all');
    jnt_mech.set_contact_mesh_properties(0,'none');
    jnt_mech.set_ligaments(0,'all');
    jnt_mech.set_ligament_outputs(0,'all');
    jnt_mech.set_muscles(0,'all');
    jnt_mech.set_muscle_outputs(0,'all');
    jnt_mech.set_attached_geometry_bodies(0,'all');
    jnt_mech.set_output_orientation_frame('ground');
    jnt_mech.set_output_position_frame('ground');
    jnt_mech.set_write_vtp_files(print_vtp);
    jnt_mech.set_vtp_file_format('binary');
    jnt_mech.set_write_h5_file(false);
    jnt_mech.set_h5_kinematics_data(true);
    jnt_mech.set_h5_states_data(true);
    jnt_mech.set_write_transforms_file(false);
    jnt_mech.set_output_transforms_file_type('sto');
    jnt_mech.set_use_visualizer(false);
    jnt_mech.set_verbose(0);
    
    % ✅ CREAR ForceReporter NUEVO (no reutilizar)
    analysis_set = AnalysisSet();
    frc_reporter = ForceReporter();
    frc_reporter.setName('ForceReporter');
    analysis_set.cloneAndAppend(frc_reporter);
    jnt_mech.set_AnalysisSet(analysis_set);
    
    % Limpiar objetos temporales
    clear frc_reporter
    
    % Set input states file
    jnt_mech.set_input_states_file([comak_result_dir '/' results_basename '_states.sto']);
    jnt_mech.set_results_directory(jnt_mech_result_dir);
    
    % Print settings
    jnt_mech.print(['../inputs/' project_id '_' numeric_id '/joint_mechanics_settings.xml']);
    
    disp('Running JointMechanicsTool...');
    jnt_mech.run();
    
    % LIMPIEZA POST-EJECUCIÓN
    clear jnt_mech analysis_set
    java.lang.System.gc()
    pause(0.2)
    
    fprintf('Joint Mechanics completado y memoria limpiada.\n');
    fprintf('=== JOINT MECHANICS FINALIZADO ===\n\n');
end

function limpiar_archivos_jm(jnt_mech_result_dir)
    % Limpia archivos de Joint Mechanics previos
    if ~exist(jnt_mech_result_dir, 'dir')
        mkdir(jnt_mech_result_dir);
        return;
    end
    
    % Eliminar archivos de resultados previos
    % Joint Mechanics genera MUCHOS archivos, así que limpiamos agresivamente
    delete(fullfile(jnt_mech_result_dir, '*.sto'));
    delete(fullfile(jnt_mech_result_dir, '*.mot'));
    delete(fullfile(jnt_mech_result_dir, '*.vtp'));
    delete(fullfile(jnt_mech_result_dir, '*.h5'));
    delete(fullfile(jnt_mech_result_dir, '*.log'));
    delete(fullfile(jnt_mech_result_dir, '*.xml'));
    
    fprintf('Archivos previos de Joint Mechanics eliminados.\n');
end