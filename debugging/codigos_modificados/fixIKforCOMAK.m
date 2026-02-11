function ik_fixed_file = fixIKforCOMAK(ik_file, varargin)
%======================================================================
% fixIKforCOMAK
%
% Preprocesa un archivo IK (.mot) para hacerlo robusto antes de COMAK.
% - Aplica unwrap() a coordenadas angulares (ej. pelvis_rot)
% - Suaviza con media móvil opcional
% - Guarda un nuevo archivo *_ik_fixed.mot
%
% USO:
%   ik_fixed = fixIKforCOMAK("walking_004_ik.mot");
%
% OPCIONES:
%   ik_fixed = fixIKforCOMAK(file,'SmoothingWindow',5);
%
%======================================================================

%% --- Parámetros opcionales ---
p = inputParser;
addParameter(p,'SmoothingWindow',5,@isnumeric);
addParameter(p,'ApplySmoothing',true,@islogical);

parse(p,varargin{:});

window = p.Results.SmoothingWindow;
doSmooth = p.Results.ApplySmoothing;

%% --- Leer archivo IK ---
if ~isfile(ik_file)
    error("No se encontró el archivo IK: %s", ik_file);
end

ik = importdata(ik_file);

time    = ik.data(:,1);
q       = ik.data(:,2:end);
headers = ik.colheaders;

fprintf("\n[fixIKforCOMAK] Procesando archivo:\n%s\n", ik_file);

%% --- Coordenadas angulares típicas a corregir ---
angular_coords = {
    'pelvis_rot'
    'pelvis_tilt'
    'pelvis_list'
    'hip_flexion_r'
    'hip_adduction_r'
    'hip_rotation_r'
    'knee_angle_r'
    'ankle_angle_r'
    'hip_flexion_l'
    'hip_adduction_l'
    'hip_rotation_l'
    'knee_angle_l'
    'ankle_angle_l'
};

%% --- Aplicar unwrap donde exista ---
nFixed = 0;

for i = 1:length(angular_coords)

    coord = angular_coords{i};

    % Buscar columna
    col_idx = find(strcmp(headers, coord));

    if ~isempty(col_idx)

        q_col = col_idx - 1;

        fprintf("  → Unwrap aplicado a: %s\n", coord);

        % Unwrap angular
        q(:,q_col) = unwrap(q(:,q_col));

        % Suavizado opcional
        if doSmooth
            q(:,q_col) = smoothdata(q(:,q_col), 'movmean', window);
        end

        nFixed = nFixed + 1;
    end
end

if nFixed == 0
    warning("No se encontró ninguna coordenada angular típica para corregir.");
end

%% --- Generar nombre del archivo corregido ---
ik_fixed_file = strrep(ik_file, '_ik.mot', '_ik_fixed.mot');

%% --- Guardar archivo corregido ---
fid = fopen(ik_fixed_file, 'w');

fprintf(fid, 'Coordinates\n');
fprintf(fid, 'version=1\n');
fprintf(fid, 'nRows=%d\n', size(q,1));
fprintf(fid, 'nColumns=%d\n', size(q,2)+1);
fprintf(fid, 'inDegrees=no\n');
fprintf(fid, 'endheader\n\n');

% Column headers
for j = 1:length(headers)-1
    fprintf(fid, '%s\t', headers{j});
end
fprintf(fid, '%s\n', headers{end});

% Data
data_out = [time q];

for r = 1:size(data_out,1)
    fprintf(fid, '%.6f\t', data_out(r,1:end-1));
    fprintf(fid, '%.6f\n', data_out(r,end));
end

fclose(fid);

fprintf("\n[fixIKforCOMAK] Archivo corregido guardado:\n%s\n", ik_fixed_file);

end
