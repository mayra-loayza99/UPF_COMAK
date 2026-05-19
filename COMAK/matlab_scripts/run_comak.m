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
    
    % Lista de músculos con sus pesos (derecho e izquierdo)
    musculos = {
        % Right leg
        'gasmed_r',  '/forceset/gasmed_r',  4;
        'gaslat_r',  '/forceset/gaslat_r',  7;
        'soleus_r',  '/forceset/soleus_r',  0.9;
        'recfem_r',  '/forceset/recfem_r',  3;
        'glmed1_r',  '/forceset/glmed1_r',  0.9;
        'glmed2_r',  '/forceset/glmed2_r',  0.9;
        'glmed3_r',  '/forceset/glmed3_r',  0.9;
        'glmin1_r',  '/forceset/glmin1_r',  0.9;
        'glmin2_r',  '/forceset/glmin2_r',  0.9;
        'glmin3_r',  '/forceset/glmin3_r',  0.9;
        'bflh_r',    '/forceset/bflh_r',    2;
        'bfsh_r',    '/forceset/bfsh_r',    2;
        'semiten_r', '/forceset/semiten_r', 2;
        'semimem_r', '/forceset/semimem_r', 2;
        % Left leg (same weights, mirrored anatomy)
        'gasmed_l',  '/forceset/gasmed_l',  4;
        'gaslat_l',  '/forceset/gaslat_l',  7;
        'soleus_l',  '/forceset/soleus_l',  0.9;
        'recfem_l',  '/forceset/recfem_l',  3;
        'glmed1_l',  '/forceset/glmed1_l',  0.9;
        'glmed2_l',  '/forceset/glmed2_l',  0.9;
        'glmed3_l',  '/forceset/glmed3_l',  0.9;
        'glmin1_l',  '/forceset/glmin1_l',  0.9;
        'glmin2_l',  '/forceset/glmin2_l',  0.9;
        'glmin3_l',  '/forceset/glmin3_l',  0.9;
        'bflh_l',    '/forceset/bflh_l',    2;
        'bfsh_l',    '/forceset/bfsh_l',    2;
        'semiten_l', '/forceset/semiten_l', 2;
        'semimem_l', '/forceset/semimem_l', 2;
    };
    
    for i = 1:size(musculos, 1)
        cost_fun_param.setName(musculos{i,1});
        cost_fun_param.set_actuator(musculos{i,2});
        cost_fun_param.set_weight(Constant(musculos{i,3}));
        cost_fun_param_set.cloneAndAppend(cost_fun_param);
    end
end

% configurar_comak_base() bilateral implementation is in configurar_comak_base.m.