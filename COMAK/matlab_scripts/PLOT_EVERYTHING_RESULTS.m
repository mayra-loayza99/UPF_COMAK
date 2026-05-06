 %% ========================================================
%  PARÁMETROS DEL PACIENTE - MODIFICAR SOLO ESTA SECCIÓN
%% ========================================================
project_id  = 'HOLOA';   % ID del proyecto
numeric_id  = '199';      % ID numérico del paciente % Peso corporal (kg)

% Directorio raíz del proyecto (ajustar según instalación)
base_dir = 'D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK';


%% ========================================================
%  RUTAS DERIVADAS AUTOMÁTICAMENTE - NO MODIFICAR
%% ========================================================
patient_id       = [project_id '_' numeric_id];
BW= extract_bodyweight_from_emt(fullfile(base_dir, 'data', patient_id));
directory_walking = fullfile(base_dir, 'data',    patient_id, 'walking');
results_dir       = fullfile(base_dir, 'results', patient_id);
forces_file       = fullfile(results_dir, 'joint_mechanics', ['walking_' numeric_id '_ForceReporter_forces.sto']);
gif_save_path     = fullfile(results_dir, 'graphics', 'paraview');

%% ========================================================
%  LECTURA DE EVENTOS DE MARCHA
%% ========================================================
sf_emg  = 1000;
file_hs = dir(fullfile(directory_walking, '*Event*'));
hs_data = readtable(fullfile(file_hs.folder, file_hs.name), ...
                    'FileType',    'text', ...
                    'Delimiter',   '\t',   ...
                    'HeaderLines', 7);
time_start = hs_data.eRHS(1);
time_stop  = hs_data.eRHS(2);

%% ========================================================
%  VISUALIZACIONES
%% ========================================================
fprintf('\n--- GENERANDO VISUALIZACIONES PARA %s ---\n', patient_id);

set(0, 'DefaultLineLineWidth',                  2);
set(0, 'DefaultAxesFontSize',                   14);
set(0, 'DefaultAxesLabelFontSizeMultiplier',    1.2);
set(0, 'DefaultAxesTitleFontSizeMultiplier',    1.4);
set(0, 'DefaultLegendFontSize',                 12);
set(0, 'DefaultFigureColor',                    'w');

try
    % Paraview Visualization of vtp files
    runParaviewVisualization(numeric_id, project_id);
    % Plot joint mechanics
    create_animated_joint_mechanics_gif(project_id, numeric_id, forces_file, BW, gif_save_path);
    plot_joint_mechanics_extended(project_id, numeric_id, forces_file, BW);
    % Plot all kinematics (tibiofemoral and patellofemoral)
    plot_kinematics(numeric_id, project_id);
    % Compare IK results with MoCap
    plot_primary_coordinates_vs_mocap(numeric_id, project_id, directory_walking);
    % Plot muscle activations and reserve actuators
    plot_activations(project_id, numeric_id);
    % Compare results with EMG data
    plot_activation_vs_emg(project_id, numeric_id, BW, time_start, time_stop, sf_emg);
    % Create output text file
    save_output_to_text_file(project_id, numeric_id, forces_file);

    fprintf('✓ Visualizaciones completadas para %s\n', patient_id);
catch ME
    fprintf('✗ ERROR en visualizaciones para %s:\n%s\n', patient_id, ME.message);
end