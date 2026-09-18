% RUN_JOINT_MECHANICS_ONLY — Ejecuta el paso Joint Mechanics de forma
% aislada para STRATO_001_mirror (side='r'), reusando el COMAK ya
% validado. Replica el patron de rethrow + asserts post-run usado en
% run_comak_only.m, porque run_joint_mechanics.m no incluye ese
% hardening internamente, y el hardening productivo en
% main_comak_workflow_function.m L237-245 solo hace `continue` en el
% catch (sin rethrow, sin asserts de archivo/tamaño).
%
% NOTA: run_joint_mechanics.m no tiene el patron de listas de
% coordenadas hardcodeadas por lado que afecto a configurar_comak_base.m
% / run_ik.m (verificado: sin referencias a knee_l/pf_l/knee_add_l), por
% lo que no requiere el mismo fix antes de poder ejecutarse.

project_id        = 'STRATO';
numeric_id         = '001_mirror';
results_basename   = 'walking_001_mirror';

% Ventana temporal identica a la usada en IK/COMAK para este sujeto
% (ver COMAK/inputs/STRATO_001_mirror/comak_settings.xml L19,21).
time_start = 4.8479999999999999;
time_stop  = 5.944;

% print_vtp=false: el pipeline canonico (CLAUDE.md) solo exige *.sto.
% Generar .vtp (default=true en run_joint_mechanics.m) multiplicaria
% drasticamente tiempo/disco para 275 frames. Cambiar a true si se
% necesita visualizacion en Paraview.
print_vtp = false;

comak_root = 'D:\mayra\Descargas\UPF_COMAK\COMAK';
matlab_scripts_dir = fullfile(comak_root, 'matlab_scripts');
addpath(matlab_scripts_dir);
cd(matlab_scripts_dir);   % necesario: ruta relativa '../inputs/...' dentro de run_joint_mechanics.m

model_file        = fullfile(comak_root, 'data', 'STRATO_001', 'model', 'model_STRATO_001_mirror.osim');
comak_result_dir  = fullfile(comak_root, 'results', [project_id '_' numeric_id], 'comak');
jnt_mech_result_dir = fullfile(comak_root, 'results', [project_id '_' numeric_id], 'joint_mechanics');
input_states_file = fullfile(comak_result_dir, [results_basename '_states.sto']);

assert(isfile(model_file), 'Modelo no encontrado: %s', model_file);
assert(isfolder(comak_result_dir), 'Directorio COMAK no encontrado: %s', comak_result_dir);
assert(isfile(input_states_file), 'States de COMAK no encontrado: %s', input_states_file);

if ~isfolder(jnt_mech_result_dir), mkdir(jnt_mech_result_dir); end

fprintf('\n========================================\n');
fprintf('RUN_JOINT_MECHANICS_ONLY - STRATO_001_mirror side=r\n');
fprintf('========================================\n');
fprintf('model_file: %s\n', model_file);
fprintf('comak_result_dir: %s\n', comak_result_dir);
fprintf('jnt_mech_result_dir: %s\n', jnt_mech_result_dir);
fprintf('input_states_file: %s\n', input_states_file);
fprintf('time_start: %g, time_stop: %g\n', time_start, time_stop);
fprintf('print_vtp: %d\n', print_vtp);
fprintf('========================================\n\n');

jm_time_start = tic;
try
    run_joint_mechanics(model_file, comak_result_dir, jnt_mech_result_dir, ...
        numeric_id, project_id, results_basename, time_start, time_stop, print_vtp);
    elapsed_jm = toc(jm_time_start);
    fprintf('\n Joint Mechanics completado para %s_%s: %.2f segundos\n', project_id, numeric_id, elapsed_jm);
catch ME
    fprintf('\n ERROR en Joint Mechanics para %s_%s:\n%s\n', project_id, numeric_id, ME.message);
    fprintf('Stack trace:\n');
    for k = 1:length(ME.stack)
        fprintf('  en %s (linea %d)\n', ME.stack(k).name, ME.stack(k).line);
    end
    rethrow(ME);
end

% Validaciones post-JM (no hay heuristica de tiempo documentada para JM
% como la de COMAK ">60s"; JM es forward-pass, no optimizacion iterativa,
% asi que no se asume "rapido = sospechoso" ciegamente. Se valida en su
% lugar existencia/tamano del artefacto conocido y un piso de cordura minimo).
expected_forces_sto = fullfile(jnt_mech_result_dir, [results_basename '_ForceReporter_forces.sto']);
assert(isfile(expected_forces_sto), 'Joint Mechanics no genero %s', expected_forces_sto);
info = dir(expected_forces_sto);
assert(info.bytes > 1000, 'Joint Mechanics genero un .sto sospechosamente pequeno (%d bytes)', info.bytes);
assert(elapsed_jm > 0, 'Tiempo de ejecucion invalido: %.2f s', elapsed_jm);

fprintf('\n--- Contenido de %s ---\n', jnt_mech_result_dir);
listing = dir(jnt_mech_result_dir);
listing = listing(~ismember({listing.name}, {'.', '..'}));
for k = 1:numel(listing)
    fprintf('  %-50s %10d bytes\n', listing(k).name, listing(k).bytes);
end

fprintf('\n========================================\n');
fprintf('RUN_JOINT_MECHANICS_ONLY finalizado.\n');
fprintf('========================================\n');
