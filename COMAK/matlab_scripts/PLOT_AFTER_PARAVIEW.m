sf_emg = 1000;
project_id= 'HOLOA';
numeric_id='143';
BW=69;
directory_walking = 'D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\data\HOLOA_143\walking';
file_hs = dir(fullfile(directory_walking, '*Event*'));
hs_data = readtable(fullfile(file_hs.folder, file_hs.name), 'FileType', 'text', 'Delimiter', '\t', 'HeaderLines', 7); 
time_start = hs_data.eRHS(1);
time_stop = hs_data.eRHS(2);

gif_save_path = 'D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\results\HOLOA_143\graphics\paraview';
forces_file = 'D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\results\HOLOA_143\joint_mechanics\walking_143_ForceReporter_forces.sto';
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
    