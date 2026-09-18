function [model_file, time_start, time_stop] = validate_side(directory_path, side)
% VALIDATE_SIDE  Re-deriva de forma aislada (sin ejecutar IK/COMAK) la
% logica de seleccion de lado ('l' / 'r') usada en
% main_comak_workflow_function.m, y comprueba que ambas ramas
% (seleccion de modelo y seleccion de evento eLHS/eRHS) esten
% correctamente conectadas al parametro `side`.
%
% Uso:
%   validate_side(directory_path, side)
%
% directory_path debe ser la carpeta de UN paciente concreto
% (p.ej. ...\COMAK\data\HOLOA_040), NO una carpeta que contenga
% varios pacientes.

    % --- Derivar project_id / numeric_id a partir del nombre de carpeta ---
    [~, subdir_name] = fileparts(directory_path);

    if startsWith(subdir_name, 'HOLOA')
        project_id = 'HOLOA';
    elseif startsWith(subdir_name, 'STRATO')
        project_id = 'STRATO';
    else
        error('validate_side:unknownProject', ...
            'No se pudo determinar project_id: la carpeta "%s" no empieza por HOLOA ni STRATO.', subdir_name);
    end

    numeric_id = subdir_name(end-2:end);

    % --- Directorios del sujeto ---
    directory_model = fullfile(directory_path, 'model');
    directory_walking = fullfile(directory_path, 'walking');

    % --- Validacion de seleccion de modelo (fix de side) ---
    if strcmp(side, 'l')
        model_filename = sprintf('model_%s_%s_left.osim', project_id, numeric_id);
    else
        model_filename = sprintf('model_%s_%s.osim', project_id, numeric_id);
    end
    model_file = fullfile(directory_model, model_filename);

    fprintf('model_filename: %s\n', model_filename);
    fprintf('model_file (abs): %s\n', model_file);
    fprintf('isfile(model_file): %d\n', isfile(model_file));

    assert(isfile(model_file), 'Model file not found: %s', model_file);

    % --- Localizar archivo de eventos (heel-strike) ---
    file_hs = dir(fullfile(directory_walking, '*Event*'));
    assert(numel(file_hs) == 1, ...
        'Expected exactly 1 *Event* file in %s, found %d', directory_walking, numel(file_hs));

    hs_data = readtable(fullfile(file_hs.folder, file_hs.name), 'FileType', 'text', 'Delimiter', '\t', 'HeaderLines', 7);

    % --- Imprimir SIEMPRE ambos lados, independientemente de `side` ---
    % Esto es el punto clave del test: si el strcmp(side,'l') estuviera
    % invertido, este print no dejaria que pasara desapercibido, porque
    % comparamos explicitamente contra el lado esperado mas abajo.
    fprintf('hs_data.eRHS(1:2): %g, %g\n', hs_data.eRHS(1), hs_data.eRHS(2));
    fprintf('hs_data.eLHS(1:2): %g, %g\n', hs_data.eLHS(1), hs_data.eLHS(2));

    % --- Validacion de seleccion de evento (fix de side) ---
    if strcmp(side, 'l')
        time_start = hs_data.eLHS(1);
        time_stop  = hs_data.eLHS(2);
    else
        time_start = hs_data.eRHS(1);
        time_stop  = hs_data.eRHS(2);
    end

    fprintf('time_start: %g\n', time_start);
    fprintf('time_stop: %g\n', time_stop);

    % --- Asegurar que la rama correcta se ejecuto realmente ---
    if strcmp(side, 'l')
        assert(time_start == hs_data.eLHS(1) && time_stop == hs_data.eLHS(2), ...
            'side=''l'' pero time_start/time_stop no coinciden con hs_data.eLHS(1:2)');
    else
        assert(time_start == hs_data.eRHS(1) && time_stop == hs_data.eRHS(2), ...
            'side=''%s'' (!= ''l'') pero time_start/time_stop no coinciden con hs_data.eRHS(1:2)', side);
    end

    fprintf('\n✓ side=''%s'' validation PASSED\n\n', side);

end
