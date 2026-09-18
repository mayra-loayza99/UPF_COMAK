% RUN_COMAK_ONLY — Ejecuta el paso COMAK de forma aislada para
% STRATO_001_mirror (side='r'), reusando el IK ya validado.
% Replica el patron productivo de main_comak_workflow_function.m
% L196-218 (llamada + rethrow + asserts post-run), porque run_comak.m
% no incluye ese hardening internamente.

project_id        = 'STRATO';
numeric_id         = '001_mirror';
results_basename   = 'walking_001_mirror';
side               = 'r';
contact_energy_weight = 100;

comak_root = 'D:\mayra\Descargas\UPF_COMAK\COMAK';
matlab_scripts_dir = fullfile(comak_root, 'matlab_scripts');
addpath(matlab_scripts_dir);
cd(matlab_scripts_dir);   % necesario: rutas relativas '../data/...' y '../inputs/...' dentro de run_comak.m

model_file    = fullfile(comak_root, 'data', 'STRATO_001', 'model', 'model_STRATO_001_mirror.osim');
ext_load_file = fullfile(comak_root, 'data', 'STRATO_001', 'walking_mirror', 'external_loads_mirror.xml');
comak_result_dir = fullfile(comak_root, 'results', [project_id '_' numeric_id], 'comak');
ik_mot_file   = fullfile(comak_root, 'results', [project_id '_' numeric_id], 'comak_inverse_kinematics', [results_basename '_ik.mot']);

assert(isfile(model_file), 'Modelo no encontrado: %s', model_file);
assert(isfile(ext_load_file), 'External loads no encontrado: %s', ext_load_file);
assert(isfile(ik_mot_file), 'IK .mot no encontrado: %s', ik_mot_file);

if ~isfolder(comak_result_dir), mkdir(comak_result_dir); end

fprintf('\n========================================\n');
fprintf('RUN_COMAK_ONLY - STRATO_001_mirror side=%s\n', side);
fprintf('========================================\n');
fprintf('model_file: %s\n', model_file);
fprintf('ext_load_file: %s\n', ext_load_file);
fprintf('comak_result_dir: %s\n', comak_result_dir);
fprintf('ik_mot_file (referencia, run_comak lo relee internamente): %s\n', ik_mot_file);
fprintf('========================================\n\n');

comak_time_start = tic;
try
    run_comak(model_file, ext_load_file, comak_result_dir, numeric_id, ...
              project_id, results_basename, -1, -1, contact_energy_weight, ...
              false, [], 0, [], side);
    elapsed_comak = toc(comak_time_start);
    fprintf('\n COMAK completado para %s_%s: %.2f segundos\n', project_id, numeric_id, elapsed_comak);
catch ME
    fprintf('\n ERROR en COMAK para %s_%s:\n%s\n', project_id, numeric_id, ME.message);
    fprintf('Stack trace:\n');
    for k = 1:length(ME.stack)
        fprintf('  en %s (linea %d)\n', ME.stack(k).name, ME.stack(k).line);
    end
    rethrow(ME);
end

% Validaciones post-COMAK (replican main_comak_workflow_function.m L212-218)
expected_sto = fullfile(comak_result_dir, [results_basename '_states.sto']);
assert(isfile(expected_sto), 'COMAK no genero %s', expected_sto);
info = dir(expected_sto);
assert(info.bytes > 10000, 'COMAK genero un .sto vacio (%d bytes)', info.bytes);
assert(elapsed_comak > 60, ...
    'COMAK termino en %.1f s - sospechosamente rapido, revisa logs', elapsed_comak);

fprintf('\n--- Contenido de %s ---\n', comak_result_dir);
listing = dir(comak_result_dir);
listing = listing(~ismember({listing.name}, {'.', '..'}));
for k = 1:numel(listing)
    fprintf('  %-50s %10d bytes\n', listing(k).name, listing(k).bytes);
end

fprintf('\n========================================\n');
fprintf('RUN_COMAK_ONLY finalizado.\n');
fprintf('========================================\n');
