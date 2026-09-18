% RUN_VALIDATION  Ejecuta validate_side sobre un sujeto de referencia
% para los dos valores posibles de `side` ('r' y 'l'), comprobando que
% la logica de seleccion de modelo y de evento (eRHS/eLHS) de
% main_comak_workflow_function.m esta correctamente conectada.

subject_dir = 'D:\mayra\Descargas\UPF_COMAK\COMAK\data\HOLOA_040';

validate_side(subject_dir, 'r');
validate_side(subject_dir, 'l');

fprintf('\n========================================\n');
fprintf('All side validations passed.\n');
fprintf('========================================\n');
