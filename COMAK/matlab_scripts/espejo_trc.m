function espejo_trc(archivo_in, archivo_out, eje_ml, swap_lados)
% espejo_trc  Mirror sagittal TRC marker data and optionally swap r./l. prefixes.
%
%   espejo_trc(archivo_in, archivo_out, eje_ml, swap_lados)
%
%   Mirrors motion-capture marker positions about the medio-lateral
%   axis eje_ml (default 'z') and, if swap_lados is true (default),
%   swaps the 'r.'/'l.' marker-name prefixes on output so the mirrored
%   .trc file can be read as valid data for the opposite side.
%
%   eje_ml     : axis letter ('x','y', or 'z') identifying the
%                medio-lateral direction. Default 'z'.
%   swap_lados : if true, swap 'r.'/'l.' prefixes in output marker
%                names (data already mirrored per its own input
%                column). Default true.
%
%   Text-only parsing (no OpenSim API, fopen/fgetl/sscanf/fprintf
%   only), to preserve the literal header exactly as espejo_grf.m does
%   for .mot files.
%
%   TRC layout (fixed, 6-line header):
%     line 1: PathFileType ...            (literal, preserved)
%     line 2: DataRate CameraRate NumFrames NumMarkers Units ...
%     line 3: numeric values for line-2 fields (NumFrames, NumMarkers
%             extracted from here)
%     line 4: Frame# Time <marker1> <blank> <blank> <marker2> ...
%             (each marker name occupies 1 name-cell + 2 blank cells,
%             covering its X/Y/Z columns; Frame#/Time have no blanks)
%     line 5: sub-labels X1 Y1 Z1 X2 Y2 Z2 ... (literal, preserved)
%     line 6: blank line (literal, preserved)
%     line 7+: numeric data, Frame# Time then 3 columns per marker

    if nargin < 3 || isempty(eje_ml)
        eje_ml = 'z';
    end
    if nargin < 4 || isempty(swap_lados)
        swap_lados = true;
    end

    axis_idx = find(lower(eje_ml) == 'xyz', 1);
    if isempty(axis_idx)
        error('espejo_trc: eje_ml must be one of ''x'', ''y'', ''z'' (got "%s")', eje_ml);
    end

    % ── Read raw lines ────────────────────────────────────────────────
    fid = fopen(archivo_in, 'r');
    if fid < 0
        error('espejo_trc: cannot open %s', archivo_in);
    end
    raw = {};
    while ~feof(fid)
        raw{end+1, 1} = fgetl(fid); %#ok<AGROW>
    end
    fclose(fid);

    if numel(raw) < 6
        error('espejo_trc: %s has fewer than 6 header lines', archivo_in);
    end

    line1 = raw{1};
    line2 = raw{2};
    line3 = raw{3};
    line4 = raw{4};
    line5 = raw{5};
    line6 = raw{6};

    % ── Parse line 2/3 to recover NumFrames and NumMarkers ─────────────
    fields2 = strsplit(line2, sprintf('\t'), 'CollapseDelimiters', false);
    values3 = strsplit(line3, sprintf('\t'), 'CollapseDelimiters', false);

    idx_numframes  = find(strcmp(fields2, 'NumFrames'), 1);
    idx_nummarkers = find(strcmp(fields2, 'NumMarkers'), 1);
    if isempty(idx_numframes) || isempty(idx_nummarkers)
        error('espejo_trc: cannot locate NumFrames/NumMarkers fields in line 2 of %s', archivo_in);
    end
    if idx_numframes > numel(values3) || idx_nummarkers > numel(values3)
        error('espejo_trc: line 3 of %s has fewer fields than line 2', archivo_in);
    end

    NumFrames_in = round(str2double(values3{idx_numframes}));
    NumMarkers   = round(str2double(values3{idx_nummarkers}));
    if isnan(NumFrames_in) || isnan(NumMarkers)
        error('espejo_trc: cannot parse NumFrames/NumMarkers as numbers in %s', archivo_in);
    end

    % ── Parse line 4: locate marker-name cells (skip Frame#, Time) ─────
    cells4 = strsplit(line4, sprintf('\t'), 'CollapseDelimiters', false);
    if numel(cells4) < 2
        error('espejo_trc: line 4 of %s does not contain Frame#/Time columns', archivo_in);
    end

    marker_idx = [];
    for j = 3:numel(cells4)
        if ~isempty(cells4{j})
            marker_idx(end+1) = j; %#ok<AGROW>
        end
    end
    marker_names_in = cells4(marker_idx);

    if numel(marker_names_in) ~= NumMarkers
        error(['espejo_trc: number of non-empty marker names in line 4 of %s ' ...
               '(%d) does not match NumMarkers (%d)'], ...
               archivo_in, numel(marker_names_in), NumMarkers);
    end

    % ── Parse numeric data block (from line 7 onward) ──────────────────
    expected_cols = 2 + 3 * NumMarkers;
    data  = [];
    nrows = 0;
    for k = 7:numel(raw)
        line = raw{k};
        if ~ischar(line) || isempty(strtrim(line))
            continue;
        end
        vals = sscanf(line, '%f')';
        if numel(vals) ~= expected_cols
            error(['espejo_trc: column count mismatch at data row %d ' ...
                   '(file line %d of %s): expected %d columns, got %d'], ...
                   nrows + 1, k, archivo_in, expected_cols, numel(vals));
        end
        nrows = nrows + 1;
        data(nrows, :) = vals; %#ok<AGROW>
    end

    % ── Negate the medio-lateral component of each marker's X/Y/Z triple
    %    Purely positional classification: column block k occupies data
    %    columns 2+3*(k-1)+[1,2,3] = X,Y,Z; negate the component whose
    %    in-block index matches eje_ml. No name-suffix classification
    %    here (unlike espejo_grf.m), since every marker is a polar
    %    vector regardless of side/midline naming. ──────────────────────
    data_out = data;
    for k = 1:NumMarkers
        col = 2 + 3 * (k - 1) + axis_idx;
        data_out(:, col) = -data_out(:, col);
    end

    % ── Determine output marker names (swap r./l. prefixes if requested)
    marker_names_out = marker_names_in;
    n_swapped = 0;
    if swap_lados
        for k = 1:numel(marker_names_in)
            name = marker_names_in{k};
            if strncmp(name, 'r.', 2)
                marker_names_out{k} = ['l.' name(3:end)];
                n_swapped = n_swapped + 1;
            elseif strncmp(name, 'l.', 2)
                marker_names_out{k} = ['r.' name(3:end)];
                n_swapped = n_swapped + 1;
            end
        end
    end

    if mod(n_swapped, 2) ~= 0
        error(['espejo_trc: odd number (%d) of r./l. marker names swapped in %s ' ...
               '-- a lateral marker is missing its opposite-side counterpart'], ...
               n_swapped, archivo_in);
    end

    % ── Rebuild line 4 in place, preserving the original blank-cell
    %    pattern (name + trailing blanks) exactly as read ───────────────
    cells4_out = cells4;
    cells4_out(marker_idx) = marker_names_out;
    line4_out = strjoin(cells4_out, sprintf('\t'));

    % ── Line 3: NumFrames should always equal the parsed row count
    %    (mirroring does not add/remove frames). If it ever does not,
    %    this is a safeguard, not the expected path: update the
    %    NumFrames field in line 3 rather than write a stale value. ────
    if nrows == NumFrames_in
        line3_out = line3;
    else
        values3_out = values3;
        values3_out{idx_numframes} = num2str(nrows);
        line3_out = strjoin(values3_out, sprintf('\t'));
    end

    % ── Ensure output directory exists ─────────────────────────────────
    out_dir = fileparts(archivo_out);
    if ~isempty(out_dir) && ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end

    % ── Write output file ───────────────────────────────────────────────
    fid = fopen(archivo_out, 'w');
    if fid < 0
        error('espejo_trc: cannot write %s', archivo_out);
    end

    fprintf(fid, '%s\n', line1);
    fprintf(fid, '%s\n', line2);
    fprintf(fid, '%s\n', line3_out);
    fprintf(fid, '%s\n', line4_out);
    fprintf(fid, '%s\n', line5);
    fprintf(fid, '%s\n', line6);

    % Numeric data block. Frame# is written as an integer (%d); Time and
    % all X/Y/Z marker columns are written with a uniform %.8f, matching
    % the precision convention already established for the Time column
    % in espejo_grf.m (decision carried over, not re-litigated here).
    for k = 1:nrows
        fprintf(fid, '%d', round(data_out(k, 1)));
        for j = 2:expected_cols
            fprintf(fid, '\t%.8f', data_out(k, j));
        end
        fprintf(fid, '\n');
    end
    fclose(fid);

    % ── Audit table (always printed) ────────────────────────────────────
    fprintf('%-15s %-15s %s\n', 'IN_MARKER', 'OUT_MARKER', 'Z');
    for k = 1:NumMarkers
        fprintf('%-15s %-15s %s\n', marker_names_in{k}, marker_names_out{k}, 'negado');
    end
    fprintf('Nombres intercambiados: %d\n', n_swapped);
end
