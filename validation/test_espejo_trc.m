% TEST_ESPEJO_TRC  Test autonomo de espejo_trc.m (mirror de marcadores
% .trc y swap de prefijos r./l.).
%
% Uso:
%   matlab -batch "cd('d:/mayra/Descargas/UPF_COMAK'); addpath('validation'); test_espejo_trc"
%
% Tres bloques independientes:
%   A) Test sintetico de signos: archivo .trc inventado con 4
%      marcadores (r.knee1, l.knee1, r.heel, l.heel), 3 frames, valores
%      conocidos y distinguibles por marcador/eje/fila, comprobacion
%      celda a celda de las 4 igualdades esperadas.
%   B) Involucion: aplicar espejo_trc dos veces debe devolver el
%      archivo original (mismos nombres, mismo orden, mismos valores).
%   C) Archivo real: espejo_trc sobre
%      COMAK/data/HOLOA_040/walking/W1_HOLOA_ID_40.trc (solo lectura),
%      salida en COMAK/data/HOLOA_040/walking_mirror/ (se conserva).
%
% No usa la API de OpenSim (nada de TRCFileAdapter): parseo de texto
% plano propio (local functions al final de este script), independiente
% del parseo interno de espejo_trc.m.
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
fprintf('TEST_ESPEJO_TRC\n');
fprintf('========================================\n');
fprintf('repo_root: %s\n', repo_root);
fprintf('espejo_trc en path: %d\n', ~isempty(which('espejo_trc')));
fprintf('========================================\n\n');

%% ======================================================================
%% BLOQUE A - Test sintetico de signos
%% ======================================================================
fprintf('---------------------------------------------------------\n');
fprintf('BLOQUE A - Test sintetico de signos\n');
fprintf('---------------------------------------------------------\n');

% 4 marcadores sinteticos, 2 pares laterales, sin marcador de linea
% media (no hace falta para este bloque).
marker_names_synth = {'r.knee1', 'l.knee1', 'r.heel', 'l.heel'};
n_markers_synth = numel(marker_names_synth);
n_rows_synth = 3;

% Valores de entrada CONOCIDOS y DISTINGUIBLES:
%   X/Y/Z de marcador m, eje a (X=1,Y=2,Z=3), fila r:
%     valor(r, m, a) = m*100 + a*10 + r
% Frame# = r; Time = 1000 + r (entero, para no arrastrar redondeo de
% texto al comparar contra los valores en memoria).
% Columnas de datos: 1=Frame#, 2=Time, 3..14 = X1 Y1 Z1 X2 Y2 Z2 X3 Y3 Z3 X4 Y4 Z4
n_cols_synth = 2 + 3 * n_markers_synth;
data_in_synth = zeros(n_rows_synth, n_cols_synth);
for r = 1:n_rows_synth
    data_in_synth(r, 1) = r;
    data_in_synth(r, 2) = 1000 + r;
    for m = 1:n_markers_synth
        for a = 1:3
            col = 2 + 3 * (m - 1) + a;
            data_in_synth(r, col) = m * 100 + a * 10 + r;
        end
    end
end

tmp_dir = tempname();
mkdir(tmp_dir);
synth_in  = fullfile(tmp_dir, 'test_synth.trc');
synth_out = fullfile(tmp_dir, 'synth_out.trc');

header_lines_synth = {
    sprintf('PathFileType\t4\t(X/Y/Z)\ttest_synth.trc')
    sprintf('DataRate\tCameraRate\tNumFrames\tNumMarkers\tUnits\tOrigDataRate\tOrigDataStartFrame\tOrigNumFrames')
    sprintf('100.00\t100.00\t%d\t%d\tmm\t100.00\t1\t%d', n_rows_synth, n_markers_synth, n_rows_synth)
    build_line4(marker_names_synth)
    build_line5(n_markers_synth)
    ''
    };

write_synthetic_trc(synth_in, header_lines_synth, data_in_synth);

% Ejecutar espejo_trc con defaults (eje_ml='z', swap_lados=true).
espejo_trc(synth_in, synth_out);

out_a = read_trc_simple(synth_out);

n_total_a = 0;
n_fail_a  = 0;

% Las 4 comprobaciones esperadas (marcador de salida <- marcador de
% entrada, X/Y sin cambio, Z negada), agregadas por marcador+eje
% cubriendo las 3 filas en cada una.
checks_a = {
    'r.knee1', 'l.knee1';
    'l.knee1', 'r.knee1';
    'r.heel',  'l.heel';
    'l.heel',  'r.heel';
    };

for k = 1:size(checks_a, 1)
    label_out = checks_a{k, 1};
    label_in  = checks_a{k, 2};

    col_x_out = marker_col_idx(out_a.marker_names, label_out);
    col_x_in_synth = find(strcmp(marker_names_synth, label_in), 1);
    col_x_in = 2 + 3 * (col_x_in_synth - 1) + 1;

    for a = 1:3
        axis_letter = 'XYZ';
        col_out = col_x_out + (a - 1);
        col_in  = col_x_in + (a - 1);
        if a == 3
            sign_exp = -1;
        else
            sign_exp = 1;
        end
        expected = sign_exp * data_in_synth(:, col_in);
        obtained = out_a.data(:, col_out);
        pass = all(abs(expected - obtained) < 1e-9);
        desc = sprintf('salida %s (%s, 3 filas) == %+d * entrada %s (%s)', ...
            label_out, axis_letter(a), sign_exp, label_in, axis_letter(a));
        detail = sprintf(' (expected=[%s], obtained=[%s])', ...
            num2str(expected'), num2str(obtained'));
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
fprintf('BLOQUE B - Involucion (espejo_trc aplicado dos veces)\n');
fprintf('---------------------------------------------------------\n');

tmp1 = fullfile(tmp_dir, 'synth_tmp1.trc');
tmp2 = fullfile(tmp_dir, 'synth_tmp2.trc');

espejo_trc(synth_in, tmp1);
espejo_trc(tmp1, tmp2);

in_b  = read_trc_simple(synth_in);
out_b = read_trc_simple(tmp2);

n_total_b = 0;
n_fail_b  = 0;

names_match = isequal(out_b.marker_names, in_b.marker_names);
desc = 'Bloque B: nombres de marcador de tmp2 idénticos y en el mismo orden que synth_in';
detail = sprintf(' (in = {%s}, tmp2 = {%s})', ...
    strjoin(in_b.marker_names, ','), strjoin(out_b.marker_names, ','));
[n_total_b, n_fail_b] = report_check(desc, names_match, detail, n_total_b, n_fail_b);

frame_col = 1;
frames_match = isequal(round(out_b.data(:, frame_col)), round(in_b.data(:, frame_col)));
desc = 'Bloque B: Frame# de tmp2 idéntico (entero) al de synth_in';
detail = sprintf(' (in=[%s], tmp2=[%s])', ...
    num2str(in_b.data(:, frame_col)'), num2str(out_b.data(:, frame_col)'));
[n_total_b, n_fail_b] = report_check(desc, frames_match, detail, n_total_b, n_fail_b);

max_diff = max(abs(out_b.data(:) - in_b.data(:)));
diff_ok = max_diff < 1e-9;
desc = 'Bloque B: valores numericos (Time+X/Y/Z) de tmp2 idénticos a synth_in (tol 1e-9)';
detail = sprintf(' (max_diff_abs=%.3e)', max_diff);
[n_total_b, n_fail_b] = report_check(desc, diff_ok, detail, n_total_b, n_fail_b);

fprintf('BLOQUE B: %d/%d PASS (%d FAIL)\n\n', n_total_b - n_fail_b, n_total_b, n_fail_b);
n_total_total = n_total_total + n_total_b;
n_fail_total  = n_fail_total + n_fail_b;

%% ======================================================================
%% BLOQUE C - Archivo real
%% ======================================================================
fprintf('---------------------------------------------------------\n');
fprintf('BLOQUE C - Archivo real (W1_HOLOA_ID_40.trc)\n');
fprintf('---------------------------------------------------------\n');

real_in  = fullfile(repo_root, 'COMAK', 'data', 'HOLOA_040', 'walking', ...
    'W1_HOLOA_ID_40.trc');
real_out = fullfile(repo_root, 'COMAK', 'data', 'HOLOA_040', 'walking_mirror', ...
    'W1_HOLOA_ID_40_mirror.trc');

fprintf('real_in:  %s\n', real_in);
fprintf('real_out: %s\n', real_out);

espejo_trc(real_in, real_out);

in_c  = read_trc_simple(real_in);
out_c = read_trc_simple(real_out);

n_total_c = 0;
n_fail_c  = 0;

% 1) NumMarkers y NumFrames de salida == entrada
n_markers_in  = numel(in_c.marker_names);
n_markers_out = numel(out_c.marker_names);
n_frames_in   = size(in_c.data, 1);
n_frames_out  = size(out_c.data, 1);
pass = (n_markers_out == n_markers_in) && (n_frames_out == n_frames_in);
desc = 'Bloque C.1: NumMarkers y NumFrames de salida == entrada';
detail = sprintf(' (in: markers=%d frames=%d; out: markers=%d frames=%d)', ...
    n_markers_in, n_frames_in, n_markers_out, n_frames_out);
[n_total_c, n_fail_c] = report_check(desc, pass, detail, n_total_c, n_fail_c);

% 2) Nombres de salida == resultado esperado de intercambiar r./l. en
%    los nombres de entrada reales (comparado contra la lista real
%    leida del propio archivo de entrada, no un literal hardcodeado).
expected_names_out = in_c.marker_names;
for k = 1:numel(expected_names_out)
    name = expected_names_out{k};
    if strncmp(name, 'r.', 2)
        expected_names_out{k} = ['l.' name(3:end)];
    elseif strncmp(name, 'l.', 2)
        expected_names_out{k} = ['r.' name(3:end)];
    end
end
names_ok = isequal(out_c.marker_names, expected_names_out);
desc = 'Bloque C.2: nombres de salida == swap r./l. de los nombres de entrada';
detail = sprintf(' (expected = {%s}, obtained = {%s})', ...
    strjoin(expected_names_out, ','), strjoin(out_c.marker_names, ','));
[n_total_c, n_fail_c] = report_check(desc, names_ok, detail, n_total_c, n_fail_c);

% 3) c7 y sacrum aparecen sin cambio de nombre en la misma posicion
midline_names = {'c7', 'sacrum'};
midline_ok = true;
for k = 1:numel(midline_names)
    idx_in  = find(strcmp(in_c.marker_names, midline_names{k}), 1);
    idx_out = find(strcmp(out_c.marker_names, midline_names{k}), 1);
    if isempty(idx_in) || isempty(idx_out) || idx_in ~= idx_out
        midline_ok = false;
    end
end
desc = 'Bloque C.3: c7 y sacrum conservan su nombre y posicion en la salida';
detail = '';
[n_total_c, n_fail_c] = report_check(desc, midline_ok, detail, n_total_c, n_fail_c);

% 4) Par lateral real r.heel/l.heel: salida r.heel Z == -entrada l.heel Z
col_out_x = marker_col_idx(out_c.marker_names, 'r.heel');
col_in_x  = marker_col_idx(in_c.marker_names, 'l.heel');
col_out_z = col_out_x + 2;
col_in_z  = col_in_x + 2;
max_diff = max(abs(out_c.data(:, col_out_z) + in_c.data(:, col_in_z)));
pass = max_diff < 1e-6;
desc = 'Bloque C.4: max(abs(salida r.heel_Z + entrada l.heel_Z)) < 1e-6';
detail = sprintf(' (max_diff=%.3e)', max_diff);
[n_total_c, n_fail_c] = report_check(desc, pass, detail, n_total_c, n_fail_c);

% 5) Linea media c7: Z tambien negada aunque el nombre no cambie
col_out_x = marker_col_idx(out_c.marker_names, 'c7');
col_in_x  = marker_col_idx(in_c.marker_names, 'c7');
col_out_z = col_out_x + 2;
col_in_z  = col_in_x + 2;
max_diff = max(abs(out_c.data(:, col_out_z) + in_c.data(:, col_in_z)));
pass = max_diff < 1e-6;
desc = 'Bloque C.5: max(abs(salida c7_Z + entrada c7_Z)) < 1e-6';
detail = sprintf(' (max_diff=%.3e)', max_diff);
[n_total_c, n_fail_c] = report_check(desc, pass, detail, n_total_c, n_fail_c);

% 6) Sin NaN ni Inf en toda la matriz de datos de salida
has_nan = any(isnan(out_c.data(:)));
has_inf = any(isinf(out_c.data(:)));
pass = ~has_nan && ~has_inf;
desc = 'Bloque C.6: sin NaN ni Inf en la matriz de datos de salida';
detail = sprintf(' (any_nan=%d, any_inf=%d)', has_nan, has_inf);
[n_total_c, n_fail_c] = report_check(desc, pass, detail, n_total_c, n_fail_c);

% 7) Informativo: NumFrames real de salida (para comparar despues
%    contra el .mot; no se calcula esa comparacion cruzada aqui).
fprintf('  INFO: NumFrames de salida (Bloque C) = %d\n', n_frames_out);

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
fprintf('RESUMEN TEST_ESPEJO_TRC\n');
fprintf('========================================\n');
fprintf('Bloque A: %d PASS, %d FAIL (de %d)\n', n_total_a - n_fail_a, n_fail_a, n_total_a);
fprintf('Bloque B: %d PASS, %d FAIL (de %d)\n', n_total_b - n_fail_b, n_fail_b, n_total_b);
fprintf('Bloque C: %d PASS, %d FAIL (de %d)\n', n_total_c - n_fail_c, n_fail_c, n_total_c);
fprintf('TOTAL:    %d PASS, %d FAIL (de %d)\n', ...
    n_total_total - n_fail_total, n_fail_total, n_total_total);
fprintf('========================================\n\n');

if n_fail_total > 0
    error('test_espejo_trc: %d comprobaciones fallaron de %d totales', ...
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

function line4 = build_line4(marker_names)
% BUILD_LINE4  Construye la linea 4 del .trc sintetico: Frame#, Time,
% y cada nombre de marcador seguido de 2 celdas en blanco (patron fijo
% del formato .trc), separadas por TAB.
    cells4 = {'Frame#', 'Time'};
    for k = 1:numel(marker_names)
        cells4 = [cells4, {marker_names{k}, '', ''}]; %#ok<AGROW>
    end
    line4 = strjoin(cells4, sprintf('\t'));
end

function line5 = build_line5(n_markers)
% BUILD_LINE5  Construye la linea 5 del .trc sintetico: 2 celdas en
% blanco (Frame#/Time) seguidas de X/Y/Z numerados por marcador.
    cells5 = {'', ''};
    for k = 1:n_markers
        cells5 = [cells5, {sprintf('X%d', k), sprintf('Y%d', k), sprintf('Z%d', k)}]; %#ok<AGROW>
    end
    line5 = strjoin(cells5, sprintf('\t'));
end

function write_synthetic_trc(filepath, header_lines, data)
% WRITE_SYNTHETIC_TRC  Escribe un archivo .trc sintetico minimo
% (6 lineas de cabecera literales + bloque numerico entero separado por
% TAB) para los Bloques A/B del test. Independiente del escritor
% interno de espejo_trc.m.
    fid = fopen(filepath, 'w');
    if fid < 0
        error('test_espejo_trc: cannot write synthetic file %s', filepath);
    end
    for k = 1:numel(header_lines)
        fprintf(fid, '%s\n', header_lines{k});
    end
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

function out = read_trc_simple(filepath)
% READ_TRC_SIMPLE  Parseo de texto plano propio (no reutiliza el
% parseo interno de espejo_trc.m) de un archivo .trc: separa las 6
% lineas de cabecera, los nombres de marcador (linea 4, celdas no
% vacias tras Frame#/Time), y la matriz numerica completa de datos
% (Frame#, Time, y 3 columnas por marcador).
    fid = fopen(filepath, 'r');
    if fid < 0
        error('test_espejo_trc: cannot open %s for reading', filepath);
    end
    raw = {};
    while ~feof(fid)
        raw{end+1, 1} = fgetl(fid); %#ok<AGROW>
    end
    fclose(fid);

    if numel(raw) < 6
        error('test_espejo_trc: %s has fewer than 6 header lines', filepath);
    end
    header_lines = raw(1:6);

    line4 = raw{4};
    cells4 = strsplit(line4, sprintf('\t'), 'CollapseDelimiters', false);
    if numel(cells4) < 2
        error('test_espejo_trc: line 4 of %s does not contain Frame#/Time columns', filepath);
    end
    marker_idx = [];
    for j = 3:numel(cells4)
        if ~isempty(cells4{j})
            marker_idx(end+1) = j; %#ok<AGROW>
        end
    end
    marker_names = cells4(marker_idx);
    n_markers = numel(marker_names);

    expected_cols = 2 + 3 * n_markers;
    data  = [];
    nrows = 0;
    for k = 7:numel(raw)
        line = raw{k};
        if ~ischar(line) || isempty(strtrim(line))
            continue;
        end
        vals = sscanf(line, '%f')';
        if numel(vals) ~= expected_cols
            error(['test_espejo_trc: column count mismatch in %s at line %d: ' ...
                   'expected %d, got %d'], filepath, k, expected_cols, numel(vals));
        end
        nrows = nrows + 1;
        data(nrows, :) = vals; %#ok<AGROW>
    end

    out.header_lines  = header_lines;
    out.marker_names  = marker_names;
    out.frame_col     = 1;
    out.time_col      = 2;
    out.data          = data;
end

function idx = marker_col_idx(marker_names, name)
% MARKER_COL_IDX  Indice de la columna de datos X del marcador "name"
% dentro de la matriz "data" devuelta por read_trc_simple (columna de
% datos = 2 + 3*(k-1) + 1, siendo k la posicion del marcador en la
% lista marker_names).
    k = find(strcmp(marker_names, name), 1);
    if isempty(k)
        error('test_espejo_trc: marker "%s" not found', name);
    end
    idx = 2 + 3 * (k - 1) + 1;
end
