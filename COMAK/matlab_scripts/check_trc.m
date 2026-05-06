
% Comparación de modelos
model_ok = org.opensim.modeling.Model('D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\processed_data\STRATO_001\model\model_STRATO_001.osim');
model_fail = org.opensim.modeling.Model('D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\data\STRATO_004\model\model_STRATO_004.osim');

fprintf('=== COMPARACIÓN DE MODELOS ===\n');

% Comparar masa total
mass_ok = 0;
mass_fail = 0;
bodySet_ok = model_ok.getBodySet();
bodySet_fail = model_fail.getBodySet();

for i = 0:bodySet_ok.getSize()-1
    mass_ok = mass_ok + bodySet_ok.get(i).getMass();
end
for i = 0:bodySet_fail.getSize()-1
    mass_fail = mass_fail + bodySet_fail.get(i).getMass();
end

fprintf('Masa total OK: %.2f kg\n', mass_ok);
fprintf('Masa total FAIL: %.2f kg\n', mass_fail);
fprintf('Diferencia: %.2f%%\n', abs(mass_ok - mass_fail) / mass_ok * 100);

% Comparar longitudes de segmentos clave
bodies_to_check = {'tibia_r', 'femur_r', 'talus_r'};
for i = 1:length(bodies_to_check)
    try
        body_ok = bodySet_ok.get(bodies_to_check{i});
        body_fail = bodySet_fail.get(bodies_to_check{i});
        
        mass_ok_body = body_ok.getMass();
        mass_fail_body = body_fail.getMass();
        
        fprintf('%s - OK: %.4f kg, FAIL: %.4f kg (diff: %.1f%%)\n', ...
            bodies_to_check{i}, mass_ok_body, mass_fail_body, ...
            abs(mass_ok_body - mass_fail_body) / mass_ok_body * 100);
    catch
        fprintf('No se pudo comparar %s\n', bodies_to_check{i});
    end
end
file_ok = 'D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\processed_data\STRATO_001\walking\W2_STRATO_ID_01.trc';  % El que funciona
file_fail = 'D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\data\STRATO_004\walking\W14_STRATO_ID_04.trc'; % El que falla

data_ok = importdata(file_ok);
data_fail = importdata(file_fail);

fprintf('=== COMPARACIÓN ===\n');
fprintf('Sujeto OK: %d frames, %d columnas\n', size(data_ok.data));
fprintf('Sujeto FAIL: %d frames, %d columnas\n', size(data_fail.data));

fprintf('\nNaNs sujeto OK: %d\n', sum(isnan(data_ok.data(:))));
fprintf('NaNs sujeto FAIL: %d\n', sum(isnan(data_fail.data(:))));

fprintf('\nRango X sujeto OK: [%.2f, %.2f]\n', min(data_ok.data(:,3:3:end),[],'all'), max(data_ok.data(:,3:3:end),[],'all'));
fprintf('Rango X sujeto FAIL: [%.2f, %.2f]\n', min(data_fail.data(:,3:3:end),[],'all'), max(data_fail.data(:,3:3:end),[],'all'));