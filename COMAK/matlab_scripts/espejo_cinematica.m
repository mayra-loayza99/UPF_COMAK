function mirror_file = espejo_cinematica(ik_dir, results_basename, side)
% espejo_cinematica  Mirror ipsilateral primary kinematics to contralateral leg.
%
%   mirror_file = espejo_cinematica(ik_dir, results_basename, side)
%
%   Reads  <ik_dir>/<results_basename>_ik.mot
%   Copies the PRIMARY coordinates of the ANALYZED leg into the
%   corresponding columns of the CONTRALATERAL leg, so that COMAK
%   prescribes the contralateral leg with the same motion as the
%   analyzed leg (symmetry assumption).
%
%   side = 'r'  →  right data overwrites left columns
%   side = 'l'  →  left  data overwrites right columns
%
%   Output saved as  <ik_dir>/<results_basename>_ik_mirror.mot
%   configurar_comak_base.m picks this file up automatically when it exists.
%
%   Coordinate pairs mirrored (right ↔ left):
%       hip_flex_r  /  hip_flex_l
%       hip_add_r   /  hip_add_l
%       hip_rot_r   /  hip_rot_l
%       knee_flex_r /  knee_flex_l
%       ankle_flex_r/  ankle_flex_l

    ik_file     = fullfile(ik_dir, [results_basename '_ik.mot']);
    mirror_file = fullfile(ik_dir, [results_basename '_ik_mirror.mot']);

    % ── Coordinate pairs {right_col, left_col} ───────────────────────────────
    pairs = {
        'hip_flex_r',   'hip_flex_l';
        'hip_add_r',    'hip_add_l';
        'hip_rot_r',    'hip_rot_l';
        'knee_flex_r',  'knee_flex_l';
        'ankle_flex_r', 'ankle_flex_l';
    };

    % ── Read raw lines ────────────────────────────────────────────────────────
    fid = fopen(ik_file, 'r');
    if fid < 0
        error('espejo_cinematica: cannot open %s', ik_file);
    end
    raw = {};
    while ~feof(fid)
        raw{end+1, 1} = fgetl(fid); %#ok<AGROW>
    end
    fclose(fid);

    % ── Find column-name header row (starts with "time") ─────────────────────
    hdr_idx = 0;
    for k = 1:numel(raw)
        if ischar(raw{k}) && startsWith(strtrim(raw{k}), 'time')
            hdr_idx = k;
            break;
        end
    end
    if hdr_idx == 0
        error('espejo_cinematica: cannot find header row in %s', ik_file);
    end

    col_names = strsplit(strtrim(raw{hdr_idx}));
    ncols     = numel(col_names);

    % ── Parse numeric data ────────────────────────────────────────────────────
    n_data = numel(raw) - hdr_idx;
    data   = nan(n_data, ncols);
    for k = 1:n_data
        line = raw{hdr_idx + k};
        if ~ischar(line), continue; end
        vals = sscanf(line, '%f')';
        if numel(vals) == ncols
            data(k, :) = vals;
        end
    end

    % ── Copy ipsilateral → contralateral ─────────────────────────────────────
    n_mirrored = 0;
    for p = 1:size(pairs, 1)
        r_col = pairs{p, 1};
        l_col = pairs{p, 2};
        r_idx = find(strcmp(col_names, r_col), 1);
        l_idx = find(strcmp(col_names, l_col), 1);
        if isempty(r_idx) || isempty(l_idx)
            fprintf('  [warn] espejo_cinematica: column pair (%s / %s) not found\n', ...
                    r_col, l_col);
            continue;
        end
        if strcmp(side, 'r')
            data(:, l_idx) = data(:, r_idx);   % right → left
        else
            data(:, r_idx) = data(:, l_idx);   % left  → right
        end
        n_mirrored = n_mirrored + 1;
    end

    % ── Write mirror file ─────────────────────────────────────────────────────
    fid = fopen(mirror_file, 'w');
    if fid < 0
        error('espejo_cinematica: cannot write %s', mirror_file);
    end

    % Header lines (including column-name row)
    for k = 1:hdr_idx
        fprintf(fid, '%s\n', raw{k});
    end

    % Data rows: time first, then tab-separated values
    for k = 1:n_data
        row = data(k, :);
        if any(isnan(row)), continue; end
        fprintf(fid, '%g', row(1));
        for j = 2:ncols
            fprintf(fid, '\t%g', row(j));
        end
        fprintf(fid, '\n');
    end
    fclose(fid);

    fprintf('espejo_cinematica: %d coord pairs mirrored (side=%s) -> %s\n', ...
            n_mirrored, side, [results_basename '_ik_mirror.mot']);
end
