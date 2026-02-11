ik = importdata('D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\results\test5_HOLOA_129\comak_inverse_kinematics\walking_129_ik.mot');

time = ik.data(:,1);
q    = ik.data(:,2:end);

dq = diff(q);

threshold = 0.1; % ajuste según su modelo

jump_frames = find(any(abs(dq) > threshold, 2));

if ~isempty(jump_frames)
    fprintf("Saltos detectados en %d frames.\n", length(jump_frames));
    disp(jump_frames(1:min(10,length(jump_frames))));
else
    fprintf("No se detectaron saltos bruscos mayores que %.2f.\n", threshold);
end
%%

idx_list = jump_frames;

for k = 1:length(idx_list)

    idx = idx_list(k);

    fprintf("\n============================\n");
    fprintf("Frame problemático: %d\n", idx);
    fprintf("Tiempo: %.4f s\n", time(idx));

    % Diferencia respecto al frame anterior
    delta = q(idx,:) - q(idx-1,:);

    % Coordenada con mayor salto
    [maxJump, j] = max(abs(delta));

    fprintf("Mayor salto: %.3f\n", maxJump);
    fprintf("Coordenada responsable: %s\n", ik.colheaders{j+1});
    
    
    fprintf("Valor antes: %.3f\n", q(idx-1,j));
    fprintf("Valor después: %.3f\n", q(idx,j));

end
%%
headers = ik.colheaders;

col_idx = find(strcmp(headers, 'pelvis_rot'));

if isempty(col_idx)
    error('No se encontró pelvis_rot en el archivo IK.');
end

% Convertir índice a columna numérica dentro de q
pelvis_rot_col = col_idx - 1;

%%

q(:, pelvis_rot_col) = unwrap(q(:, pelvis_rot_col));
%%

q(:, pelvis_rot_col) = smoothdata(q(:, pelvis_rot_col), ...
                                 'movmean', 5);
%%
ik_fixed_file = ('D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\results\test5_HOLOA_129\comak_inverse_kinematics\walking_129_ik_fixed.mot');
%%
fid = fopen(ik_fixed_file, 'w');

% Escribir encabezado básico
fprintf(fid, 'Coordinates\n');

fprintf(fid, 'version=1\n');
fprintf(fid, 'nRows=%d\n', size(q,1));
fprintf(fid, 'nColumns=%d\n', size(q,2)+1);
fprintf(fid, 'inDegrees=no\n');
fprintf(fid, 'endheader\n\n');

% Escribir nombres de columnas
fprintf(fid, '%s\t', headers{1:end-1});
fprintf(fid, '%s\n', headers{end});

% Escribir datos
data_out = [time q];

for i = 1:size(data_out,1)
    fprintf(fid, '%.6f\t', data_out(i,1:end-1));
    fprintf(fid, '%.6f\n', data_out(i,end));
end

fclose(fid);

fprintf("Archivo IK corregido guardado en:\n%s\n", ik_fixed_file);


