% TEST_ESPEJO_GRF  Test autonomo de espejo_grf.m (mirror de GRF/torque
% y swap de prefijos r./l.).
%
% Uso:
%   matlab -batch "cd('d:/mayra/Descargas/UPF_COMAK'); addpath('validation'); test_espejo_grf"
%
% Tres bloques independientes:
%   A) Test sintetico de signos: archivo .mot inventado con las mismas
%      19 columnas que W1_HOLOA_ID_40.mot, valores conocidos y
%      distinguibles por columna/fila, comprobacion celda a celda de
%      las 14 igualdades (7 direcciones r.<-l. + 7 simetricas l.<-r.).
%   B) Involucion: aplicar espejo_grf dos veces debe devolver el
%      archivo original (mismas etiquetas, mismos valores).
%   C) Archivo real: espejo_grf sobre
%      COMAK/data/HOLOA_040/walking/W1_HOLOA_ID_40.mot (solo lectura),
%      salida en COMAK/data/HOLOA_040/walking_mirror/ (se conserva).
%
% No usa STOFileAdapter ni la API de OpenSim: parseo de texto plano
% propio (local functions al final de este script), independiente del
% parseo interno de espejo_grf.m.
%
% No usa try/catch: los fallos de comprobacion se acumulan en un
% contador y se reportan PASS/FAIL explicitamente; si al final el
% contador de fallos es > 0, se llama a error(...) para que
% "matlab -batch" termine con codigo de salida distinto de cero.

% --- Paths del repo (robusto frente al pwd desde el que se invoque) ---
this_dir   = fileparts(mfilename('fullpath'));   % .../UPF_COMAK/validation
repo_root  = fileparts(this_dir);                % .../UPF_COMAK
matlab_scripts_dir = fullfile(repo_root, 'COMAK', 'matlab_scripts');
addpath(matlab_scripts_dir);

n_fail_total = 0;
n_total_total = 0;

fprintf('\n========================================\n');
fprintf('TEST_ESPEJO_GRF\n');
fprintf('========================================\n');
fprintf('repo_root: %s\n', repo_root);
fprintf('espejo_grf en path: %d\n', ~isempty(which('espejo_grf')));
fprintf('========================================\n\n');

%% ======================================================================
%% BLOQUE A - Test sintetico de signos
%% ======================================================================
fprintf('---------------------------------------------------------\n');
fprintf('BLOQUE A - Test sintetico de signos\n');
fprintf('---------------------------------------------------------\n');

% Mismas 19 etiquetas, mismo orden, que W1_HOLOA_ID_40.mot.
col_names_synth = {'time', ...
    'r.gr_force_vx', 'r.gr_force_vy', 'r.gr_force_vz', ...
    'r.gr_force_px', 'r.gr_force_py', 'r.gr_force_pz', ...
    'l.gr_force_vx', 'l.gr_force_vy', 'l.gr_force_vz', ...
    'l.gr_force_px', 'l.gr_force_py', 'l.gr_force_pz', ...
    'r.gr_torque_x', 'r.gr_torque_y', 'r.gr_torque_z', ...
    'l.gr_torque_x', 'l.gr_torque_y', 'l.gr_torque_z'};

header_lines_synth = {'version=1'; 'nRows=3'; 'nColumns=19'; ...
    'inDegrees=yes'; ''; 'endheader'};

% Valores de entrada CONOCIDOS y DISTINGUIBLES: data_in(r,c) = c*10 + r
% (c = indice de columna 1..19, r = indice de fila 1..3). Todos son
% enteros, asi que no hay ambiguedad de redondeo al comparar contra la
% salida en punto flotante (%.8f). P.ej. data_in(1, 4) = 41
% (r.gr_force_vz, fila 1); data_in(2, 10) = 102 (l.gr_force_vz, fila 2).
n_rows_synth = 3;
n_cols_synth = numel(col_names_synth);
data_in_synth = zeros(n_rows_synth, n_cols_synth);
for c = 1:n_cols_synth
    for r = 1:n_rows_synth
        data_in_synth(r, c) = c * 10 + r;
    end
end

tmp_dir = tempname();
mkdir(tmp_dir);
synth_in  = fullfile(tmp_dir, 'synth_in.mot');
synth_out = fullfile(tmp_dir, 'synth_out.mot');

write_synthetic_mot(synth_in, header_lines_synth, col_names_synth, data_in_synth);

% Ejecutar espejo_grf con defaults (eje_ml='z', swap_lados=true).
espejo_grf(synth_in, synth_out);

out_a = read_mot_simple(synth_out);

% Las 14 comprobaciones: {label_salida, label_entrada, signo_esperado}
checks_a = {
    'r.gr_force_vx', 'l.gr_force_vx',  1;
    'r.gr_force_vy', 'l.gr_force_vy',  1;
    'r.gr_force_vz', 'l.gr_force_vz', -1;
    'r.gr_force_pz', 'l.gr_force_pz', -1;
    'r.gr_torque_x', 'l.gr_torque_x', -1;
    'r.gr_torque_y', 'l.gr_torque_y', -1;
    'r.gr_torque_z', 'l.gr_torque_z',  1;
    'l.gr_force_vx', 'r.gr_force_vx',  1;
    'l.gr_force_vy', 'r.gr_force_vy',  1;
    'l.gr_force_vz', 'r.gr_force_vz', -1;
    'l.gr_force_pz', 'r.gr_force_pz', -1;
    'l.gr_torque_x', 'r.gr_torque_x', -1;
    'l.gr_torque_y', 'r.gr_torque_y', -1;
    'l.gr_torque_z', 'r.gr_torque_z',  1;
};

n_total_a = 0;
n_fail_a  = 0;
for k = 1:size(checks_a, 1)
    label_out = checks_a{k, 1};
    label_in  = checks_a{k, 2};
    sign_exp  = checks_a{k, 3};

    idx_out = col_idx(out_a.col_names, label_out);
    idx_in  = col_idx(col_names_synth, label_in);

    for r = 1:n_rows_synth
        expected = sign_exp * data_in_synth(r, idx_in);
        obtained = out_a.data(r, idx_out);
        pass = abs(expected - obtained) < 1e-9;
        desc = sprintf('salida %s (fila %d) == %+d * entrada %s (fila %d)', ...
            label_out, r, sign_exp, label_in, r);
        detail = sprintf(' (expected=%.8f, obtained=%.8f)', expected, obtained);
        [n_total_a, n_fail_a] = report_check(desc, pass, detail, n_total_a, n_fail_a);
    end
end

fprintf('BLOQUE A: %d/%d PASS (%d FAIL)\n\n', n_total_a - n_fail_a, n_total_a, n_fail_a);
n_total_total = n_total_total + n_total_a;
n_fail_total  = n_fail_total + n_fail_a;

%% ======================================================================
%% BLOQUE B - Involucion
%% ======================================================================
fprintf('---------------------------------------------------------\n');
fprintf('BLOQUE B - Involucion (espejo_grf aplicado dos veces)\n');
fprintf('---------------------------------------------------------\n');

tmp1 = fullfile(tmp_dir, 'synth_tmp1.mot');
tmp2 = fullfile(tmp_dir, 'synth_tmp2.mot');

espejo_grf(synth_in, tmp1);
espejo_grf(tmp1, tmp2);

out_b = read_mot_simple(tmp2);

n_total_b = 0;
n_fail_b  = 0;

labels_match = isequal(out_b.col_names, col_names_synth);
desc = 'Bloque B: etiquetas de tmp2 idénticas y en el mismo orden que synth_in';
detail = sprintf(' (col_names_synth = {%s}, tmp2 = {%s})', ...
    strjoin(col_names_synth, ','), strjoin(out_b.col_names, ','));
[n_total_b, n_fail_b] = report_check(desc, labels_match, detail, n_total_b, n_fail_b);

max_diff = max(abs(out_b.data(:) - data_in_synth(:)));
diff_ok = max_diff < 1e-9;
desc = 'Bloque B: valores numericos de tmp2 idénticos a synth_in (tol 1e-9)';
detail = sprintf(' (max_diff_abs=%.3e)', max_diff);
[n_total_b, n_fail_b] = report_check(desc, diff_ok, detail, n_total_b, n_fail_b);

fprintf('BLOQUE B: %d/%d PASS (%d FAIL)\n\n', n_total_b - n_fail_b, n_total_b, n_fail_b);
n_total_total = n_total_total + n_total_b;
n_fail_total  = n_fail_total + n_fail_b;

%% ======================================================================
%% BLOQUE C - Archivo real
%% ======================================================================
fprintf('---------------------------------------------------------\n');
fprintf('BLOQUE C - Archivo real (W1_HOLOA_ID_40.mot)\n');
fprintf('---------------------------------------------------------\n');

real_in  = fullfile(repo_root, 'COMAK', 'data', 'HOLOA_040', 'walking', ...
    'W1_HOLOA_ID_40.mot');
real_out = fullfile(repo_root, 'COMAK', 'data', 'HOLOA_040', 'walking_mirror', ...
    'W1_HOLOA_ID_40_mirror.mot');

fprintf('real_in:  %s\n', real_in);
fprintf('real_out: %s\n', real_out);

espejo_grf(real_in, real_out);

in_c  = read_mot_simple(real_in);
out_c = read_mot_simple(real_out);

n_total_c = 0;
n_fail_c  = 0;

% 1) Filas y columnas
[nrows_out, ncols_out] = size(out_c.data);
pass = (nrows_out == 1089) && (ncols_out == 19);
desc = 'Bloque C.1: tamaño de la matriz de salida == [1089 x 19]';
detail = sprintf(' (obtained=[%d x %d])', nrows_out, ncols_out);
[n_total_c, n_fail_c] = report_check(desc, pass, detail, n_total_c, n_fail_c);

% 2) Cabecera identica literal, linea por linea
header_match = isequal(in_c.header_lines, out_c.header_lines);
desc = 'Bloque C.2: cabecera de salida idéntica literal a la de entrada';
if header_match
    detail = '';
else
    detail = sprintf(' (n_lineas_in=%d, n_lineas_out=%d)', ...
        numel(in_c.header_lines), numel(out_c.header_lines));
end
[n_total_c, n_fail_c] = report_check(desc, header_match, detail, n_total_c, n_fail_c);

% 3) salida r.gr_force_vy == entrada l.gr_force_vy
idx_out = col_idx(out_c.col_names, 'r.gr_force_vy');
idx_in  = col_idx(in_c.col_names, 'l.gr_force_vy');
max_diff = max(abs(out_c.data(:, idx_out) - in_c.data(:, idx_in)));
pass = max_diff < 1e-6;
desc = 'Bloque C.3: max(abs(salida r.gr_force_vy - entrada l.gr_force_vy)) < 1e-6';
detail = sprintf(' (max_diff=%.3e)', max_diff);
[n_total_c, n_fail_c] = report_check(desc, pass, detail, n_total_c, n_fail_c);

% 4) salida r.gr_force_vz == -entrada l.gr_force_vz
idx_out = col_idx(out_c.col_names, 'r.gr_force_vz');
idx_in  = col_idx(in_c.col_names, 'l.gr_force_vz');
max_diff = max(abs(out_c.data(:, idx_out) + in_c.data(:, idx_in)));
pass = max_diff < 1e-6;
desc = 'Bloque C.4: max(abs(salida r.gr_force_vz + entrada l.gr_force_vz)) < 1e-6';
detail = sprintf(' (max_diff=%.3e)', max_diff);
[n_total_c, n_fail_c] = report_check(desc, pass, detail, n_total_c, n_fail_c);

% 5) salida r.gr_torque_y == -entrada l.gr_torque_y
idx_out = col_idx(out_c.col_names, 'r.gr_torque_y');
idx_in  = col_idx(in_c.col_names, 'l.gr_torque_y');
max_diff = max(abs(out_c.data(:, idx_out) + in_c.data(:, idx_in)));
pass = max_diff < 1e-6;
desc = 'Bloque C.5: max(abs(salida r.gr_torque_y + entrada l.gr_torque_y)) < 1e-6';
detail = sprintf(' (max_diff=%.3e)', max_diff);
[n_total_c, n_fail_c] = report_check(desc, pass, detail, n_total_c, n_fail_c);

% 6) salida r.gr_torque_z == entrada l.gr_torque_z
idx_out = col_idx(out_c.col_names, 'r.gr_torque_z');
idx_in  = col_idx(in_c.col_names, 'l.gr_torque_z');
max_diff = max(abs(out_c.data(:, idx_out) - in_c.data(:, idx_in)));
pass = max_diff < 1e-6;
desc = 'Bloque C.6: max(abs(salida r.gr_torque_z - entrada l.gr_torque_z)) < 1e-6';
detail = sprintf(' (max_diff=%.3e)', max_diff);
[n_total_c, n_fail_c] = report_check(desc, pass, detail, n_total_c, n_fail_c);

% 7) Sin NaN ni Inf en toda la matriz de salida
has_nan = any(isnan(out_c.data(:)));
has_inf = any(isinf(out_c.data(:)));
pass = ~has_nan && ~has_inf;
desc = 'Bloque C.7: sin NaN ni Inf en la matriz de datos de salida';
detail = sprintf(' (any_nan=%d, any_inf=%d)', has_nan, has_inf);
[n_total_c, n_fail_c] = report_check(desc, pass, detail, n_total_c, n_fail_c);

fprintf('BLOQUE C: %d/%d PASS (%d FAIL)\n\n', n_total_c - n_fail_c, n_total_c, n_fail_c);
n_total_total = n_total_total + n_total_c;
n_fail_total  = n_fail_total + n_fail_c;

%% ======================================================================
%% Limpieza de temporales (solo Bloque A/B; Bloque C se conserva)
%% ======================================================================
if isfolder(tmp_dir)
    rmdir(tmp_dir, 's');
end

%% ======================================================================
%% Resumen final
%% ======================================================================
fprintf('========================================\n');
fprintf('RESUMEN TEST_ESPEJO_GRF\n');
fprintf('========================================\n');
fprintf('Bloque A: %d PASS, %d FAIL (de %d)\n', n_total_a - n_fail_a, n_fail_a, n_total_a);
fprintf('Bloque B: %d PASS, %d FAIL (de %d)\n', n_total_b - n_fail_b, n_fail_b, n_total_b);
fprintf('Bloque C: %d PASS, %d FAIL (de %d)\n', n_total_c - n_fail_c, n_fail_c, n_total_c);
fprintf('TOTAL:    %d PASS, %d FAIL (de %d)\n', ...
    n_total_total - n_fail_total, n_fail_total, n_total_total);
fprintf('========================================\n\n');

if n_fail_total > 0
    error('test_espejo_grf: %d comprobaciones fallaron de %d totales', ...
        n_fail_total, n_total_total);
end

fprintf('✓ TODOS LOS BLOQUES (A, B, C) PASSED\n');


%% ========================================================================
%% Local functions
%% ========================================================================

function [n_total_out, n_fail_out] = report_check(desc, passed, detail_str, n_total_in, n_fail_in)
% REPORT_CHECK  Imprime PASS/FAIL para una comprobacion individual y
% devuelve los contadores actualizados de total/fallos.
    n_total_out = n_total_in + 1;
    if passed
        status = 'PASS';
        n_fail_out = n_fail_in;
    else
        status = 'FAIL';
        n_fail_out = n_fail_in + 1;
    end
    fprintf('  %s: %s%s\n', status, desc, detail_str);
end

function write_synthetic_mot(filepath, header_lines, col_names, data)
% WRITE_SYNTHETIC_MOT  Escribe un archivo .mot minimo (cabecera literal
% + linea de etiquetas + bloque numerico separado por TAB) para el
% Bloque A del test. Independiente del escritor interno de espejo_grf.
    fid = fopen(filepath, 'w');
    if fid < 0
        error('test_espejo_grf: cannot write synthetic file %s', filepath);
    end
    for k = 1:numel(header_lines)
        fprintf(fid, '%s\n', header_lines{k});
    end
    fprintf(fid, '%s', col_names{1});
    for j = 2:numel(col_names)
        fprintf(fid, '\t%s', col_names{j});
    end
    fprintf(fid, '\n');
    [nrows, ncols] = size(data);
    for r = 1:nrows
        fprintf(fid, '%d', data(r, 1));
        for c = 2:ncols
            fprintf(fid, '\t%d', data(r, c));
        end
        fprintf(fid, '\n');
    end
    fclose(fid);
end

function out = read_mot_simple(filepath)
% READ_MOT_SIMPLE  Parseo de texto plano propio (no reutiliza el
% parseo interno de espejo_grf.m) de un archivo .mot: separa el bloque
% de cabecera (lineas hasta 'endheader' inclusive), la linea de
% etiquetas de columna, y la matriz numerica de datos.
    fid = fopen(filepath, 'r');
    if fid < 0
        error('test_espejo_grf: cannot open %s for reading', filepath);
    end
    raw = {};
    while ~feof(fid)
        raw{end+1, 1} = fgetl(fid); %#ok<AGROW>
    end
    fclose(fid);

    endheader_idx = 0;
    for k = 1:numel(raw)
        if ischar(raw{k}) && strcmp(strtrim(raw{k}), 'endheader')
            endheader_idx = k;
            break;
        end
    end
    if endheader_idx == 0
        error('test_espejo_grf: cannot find "endheader" line in %s', filepath);
    end
    header_lines = raw(1:endheader_idx);

    label_idx = 0;
    for k = (endheader_idx + 1):numel(raw)
        if ischar(raw{k}) && ~isempty(strtrim(raw{k}))
            label_idx = k;
            break;
        end
    end
    if label_idx == 0
        error('test_espejo_grf: cannot find column-label line after "endheader" in %s', filepath);
    end
    col_names = strsplit(strtrim(raw{label_idx}));
    ncols = numel(col_names);

    data = [];
    nrows = 0;
    for k = (label_idx + 1):numel(raw)
        line = raw{k};
        if ~ischar(line) || isempty(strtrim(line))
            continue;
        end
        vals = sscanf(line, '%f')';
        if numel(vals) ~= ncols
            error('test_espejo_grf: column count mismatch in %s at line %d: expected %d, got %d', ...
                filepath, k, ncols, numel(vals));
        end
        nrows = nrows + 1;
        data(nrows, :) = vals; %#ok<AGROW>
    end

    out.header_lines = header_lines;
    out.col_names = col_names;
    out.data = data;
end

function idx = col_idx(col_names, target)
% COL_IDX  Indice de la columna cuyo nombre es exactamente target.
    idx = find(strcmp(col_names, target), 1);
    if isempty(idx)
        error('test_espejo_grf: column "%s" not found', target);
    end
end
