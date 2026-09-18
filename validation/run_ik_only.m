% RUN_IK_ONLY  Ejecuta el paso de Inverse Kinematics de forma aislada
% (sin COMAK ni Joint Mechanics) para HOLOA_040 con side='l', para
% validar el fix #3 (propagacion de `side` a run_ik) con una corrida real.
%
% El setup (project_id, numeric_id, results_basename, directorios de
% resultados/inputs) replica el subset minimo que
% COMAK/matlab_scripts/main_comak_workflow_function.m usa antes de
% invocar run_ik. Rango de lineas citado en cada bloque de abajo,
% verificado contra el archivo tal como quedo tras los commits
% 0f9c834 / e120b45.

subject_dir = 'D:/mayra/Descargas/UPF_COMAK/COMAK/data/HOLOA_040';
side = 'l';

% --- Paths del repo ---
this_dir = fileparts(mfilename('fullpath'));                 % .../validation
comak_root = fileparts(fileparts(subject_dir));               % .../COMAK
matlab_scripts_dir = fullfile(comak_root, 'matlab_scripts');   % .../COMAK/matlab_scripts

addpath(this_dir);
addpath(matlab_scripts_dir);

% run_ik.m resuelve internamente una ruta relativa
% ('../inputs/<project>_<id>/comak_inverse_kinematics_settings.xml',
% ver run_ik.m linea 123), asumiendo que el directorio de trabajo (pwd)
% es COMAK/matlab_scripts. main_comak_workflow_function.m garantiza esto
% con cd(currentDirectory) en su linea 33. Replicamos el mismo cd aqui
% por la misma razon.
cd(matlab_scripts_dir);

% --- Validacion aislada de side (ya probada): resuelve y assert-ea ---
% model_file, time_start, time_stop coinciden con lo que
% main_comak_workflow_function.m calcularia para este subject/side.
[model_file, time_start, time_stop] = validate_side(subject_dir, side);

% --- Derivar project_id / numeric_id / results_basename ---
% Replica main_comak_workflow_function.m lineas 57 (subdir), 66
% (numeric_id), 67 (results_basename), 69-75 (project_id).
[~, subdir_name] = fileparts(subject_dir);
if startsWith(subdir_name, 'HOLOA')
    project_id = 'HOLOA';
elseif startsWith(subdir_name, 'STRATO')
    project_id = 'STRATO';
else
    error('run_ik_only:unknownProject', ...
        'No se pudo determinar project_id para "%s".', subdir_name);
end
numeric_id = subdir_name(end-2:end);
results_basename = ['walking_', numeric_id];

% --- Motion file ---
% Replica main_comak_workflow_function.m lineas 120-122.
directory_walking = fullfile(subject_dir, 'walking');
motion_file_1 = dir(fullfile(directory_walking, '*.trc'));
assert(numel(motion_file_1) == 1, ...
    'Expected exactly 1 *.trc file in %s, found %d', directory_walking, numel(motion_file_1));
motion_file = fullfile(motion_file_1.folder, motion_file_1.name);

% --- Directorio de resultados de IK ---
% Replica main_comak_workflow_function.m lineas 137-150 (solo el
% subconjunto comak_inverse_kinematics; alli currentDirectory es
% matlab_scripts_dir y 'dir_path' se arma con fullfile(currentDirectory,
% ['../results/' project_id '_' numeric_id '/' result_dirs{j}])).
comak_inverse_kinematics_result_dir = fullfile(comak_root, 'results', ...
    [project_id '_' numeric_id], 'comak_inverse_kinematics');
if ~isfolder(comak_inverse_kinematics_result_dir)
    mkdir(comak_inverse_kinematics_result_dir);
end

% --- Directorio de inputs (necesario para que run_ik pueda imprimir
% comak_inverse_kinematics_settings.xml via ruta relativa) ---
% Replica main_comak_workflow_function.m lineas 153-155.
inputs_dir = fullfile(comak_root, 'inputs', [project_id '_' numeric_id]);
if ~isfolder(inputs_dir)
    mkdir(inputs_dir);
end

% --- Banner previo a la ejecucion ---
fprintf('\n========================================\n');
fprintf('RUN_IK_ONLY - validacion real de side=''%s''\n', side);
fprintf('========================================\n');
fprintf('subject_dir: %s\n', subject_dir);
fprintf('side: %s\n', side);
fprintf('model_file: %s\n', model_file);
fprintf('motion_file: %s\n', motion_file);
fprintf('time_start: %g\n', time_start);
fprintf('time_stop: %g\n', time_stop);
fprintf('comak_inverse_kinematics_result_dir: %s\n', comak_inverse_kinematics_result_dir);
fprintf('========================================\n\n');

% --- Ejecutar IK con timing ---
% Firma identica a la llamada productiva en
% main_comak_workflow_function.m linea 162.
ik_time_start = tic;
run_ik(model_file, motion_file, comak_inverse_kinematics_result_dir, numeric_id, project_id, results_basename, time_start, time_stop, side);
elapsed = toc(ik_time_start);
fprintf('\n✓ IK completado en %.2f segundos\n', elapsed);

% --- Verificacion post-IK: listar outputs generados (sin asserts fuertes) ---
fprintf('\n--- Contenido de %s ---\n', comak_inverse_kinematics_result_dir);
listing = dir(comak_inverse_kinematics_result_dir);
listing = listing(~ismember({listing.name}, {'.', '..'}));
for k = 1:numel(listing)
    fprintf('  %-50s %10d bytes\n', listing(k).name, listing(k).bytes);
end

expected_mot = fullfile(comak_inverse_kinematics_result_dir, [results_basename '_ik.mot']);
fprintf('\nArchivo .mot esperado: %s\n', expected_mot);
if isfile(expected_mot)
    info = dir(expected_mot);
    fprintf('  Existe. Tamano: %d bytes\n', info.bytes);
else
    fprintf('  NO ENCONTRADO.\n');
end

fprintf('\n========================================\n');
fprintf('RUN_IK_ONLY finalizado.\n');
fprintf('========================================\n');
