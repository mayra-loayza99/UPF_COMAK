function espejo_grf(archivo_in, archivo_out, eje_ml, swap_lados)
% espejo_grf  Mirror sagittal GRF data and optionally swap r./l. prefixes.
%
%   espejo_grf(archivo_in, archivo_out, eje_ml, swap_lados)
%
%   Mirrors ground reaction force / point-of-application / torque data
%   about the medio-lateral axis eje_ml (default 'z') and, if
%   swap_lados is true (default), swaps the 'r.'/'l.' column-label
%   prefixes on output so the mirrored file can be read as valid data
%   for the opposite side without having to touch external_loads.xml
%   (which references columns by name prefix).
%
%   eje_ml     : axis letter ('x','y', or 'z') identifying the
%                medio-lateral direction. Default 'z'.
%   swap_lados : if true, swap 'r.'/'l.' prefixes in output column
%                labels (data already mirrored per its own input
%                column). Default true.
%
%   Text-only parsing (no OpenSim API, fopen/fgetl/sscanf/fprintf
%   only). The header block (everything from line 1 up to and
%   including 'endheader') is treated as an opaque block of text and
%   copied literally to the output, without reinterpreting nRows=/
%   nColumns= (they do not change).

    if nargin < 3 || isempty(eje_ml)
        eje_ml = 'z';
    end
    if nargin < 4 || isempty(swap_lados)
        swap_lados = true;
    end

    % ── Read raw lines ────────────────────────────────────────────────
    fid = fopen(archivo_in, 'r');
    if fid < 0
        error('espejo_grf: cannot open %s', archivo_in);
    end
    raw = {};
    while ~feof(fid)
        raw{end+1, 1} = fgetl(fid); %#ok<AGROW>
    end
    fclose(fid);

    % ── Locate opaque header block (up to and including 'endheader') ──
    endheader_idx = 0;
    for k = 1:numel(raw)
        if ischar(raw{k}) && strcmp(strtrim(raw{k}), 'endheader')
            endheader_idx = k;
            break;
        end
    end
    if endheader_idx == 0
        error('espejo_grf: cannot find "endheader" line in %s', archivo_in);
    end
    header_block = raw(1:endheader_idx);

    % ── Column-name label line (first non-empty line after endheader) ─
    label_idx = 0;
    for k = (endheader_idx + 1):numel(raw)
        if ischar(raw{k}) && ~isempty(strtrim(raw{k}))
            label_idx = k;
            break;
        end
    end
    if label_idx == 0
        error('espejo_grf: cannot find column-label line after "endheader" in %s', archivo_in);
    end

    col_names_in = strsplit(strtrim(raw{label_idx}));
    ncols        = numel(col_names_in);

    % ── Parse numeric data block ──────────────────────────────────────
    data  = [];
    nrows = 0;
    for k = (label_idx + 1):numel(raw)
        line = raw{k};
        if ~ischar(line) || isempty(strtrim(line))
            continue;
        end
        vals = sscanf(line, '%f')';
        if numel(vals) ~= ncols
            error(['espejo_grf: column count mismatch at data row %d ' ...
                   '(file line %d of %s): expected %d columns, got %d'], ...
                   nrows + 1, k, archivo_in, ncols, numel(vals));
        end
        nrows = nrows + 1;
        data(nrows, :) = vals; %#ok<AGROW>
    end

    % ── Classify each input column and compute sign ───────────────────
    class_of = cell(1, ncols);
    sign_of  = ones(1, ncols);

    for j = 1:ncols
        name = col_names_in{j};

        if strcmp(name, 'time')
            class_of{j} = 'escalar';
            sign_of(j)  = 1;
            continue;
        end

        tok = regexp(name, '_[vp]([xyz])$', 'tokens', 'once');
        if ~isempty(tok)
            class_of{j} = 'vector_polar';
            ax = tok{1};
            if strcmpi(ax, eje_ml)
                sign_of(j) = -1;
            else
                sign_of(j) = 1;
            end
            continue;
        end

        tok = regexp(name, '_torque_([xyz])$', 'tokens', 'once');
        if ~isempty(tok)
            class_of{j} = 'pseudovector';
            ax = tok{1};
            if strcmpi(ax, eje_ml)
                sign_of(j) = 1;
            else
                sign_of(j) = -1;
            end
            continue;
        end

        error('espejo_grf: unrecognized column name "%s" in %s', name, archivo_in);
    end

    % ── Determine output labels (swap r./l. prefixes if requested) ────
    col_names_out = col_names_in;
    if swap_lados
        for j = 1:ncols
            name = col_names_in{j};
            if strncmp(name, 'r.', 2)
                col_names_out{j} = ['l.' name(3:end)];
            elseif strncmp(name, 'l.', 2)
                col_names_out{j} = ['r.' name(3:end)];
            end
        end
    end

    % ── Apply signs to data (per INPUT column classification) ─────────
    data_out = data .* sign_of;

    % ── Ensure output directory exists ─────────────────────────────────
    out_dir = fileparts(archivo_out);
    if ~isempty(out_dir) && ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end

    % ── Write output file ───────────────────────────────────────────────
    fid = fopen(archivo_out, 'w');
    if fid < 0
        error('espejo_grf: cannot write %s', archivo_out);
    end

    % Opaque header block, copied literally
    for k = 1:numel(header_block)
        fprintf(fid, '%s\n', header_block{k});
    end

    % Column-label line (post swap)
    fprintf(fid, '%s', col_names_out{1});
    for j = 2:ncols
        fprintf(fid, '\t%s', col_names_out{j});
    end
    fprintf(fid, '\n');

    % Numeric data block
    for k = 1:nrows
        fprintf(fid, '%.8f', data_out(k, 1));
        for j = 2:ncols
            fprintf(fid, '\t%.8f', data_out(k, j));
        end
        fprintf(fid, '\n');
    end
    fclose(fid);

    % ── Audit table (always printed) ────────────────────────────────────
    fprintf('%-20s %-20s %-15s %s\n', 'IN_COLUMN', 'OUT_COLUMN', 'CLASS', 'SIGN');
    for j = 1:ncols
        fprintf('%-20s %-20s %-15s %+d\n', ...
                col_names_in{j}, col_names_out{j}, class_of{j}, sign_of(j));
    end
end
