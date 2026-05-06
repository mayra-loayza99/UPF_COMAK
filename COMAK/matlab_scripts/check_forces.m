% Leer ambos archivos como texto
text1 = fileread('D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\processed_data\STRATO_001\model\model_STRATO_001.osim');
text2 = fileread('D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\data\STRATO_004\model\model_STRATO_004.osim');

% Buscar las secciones de Smith2018ArticularContactForce
pattern = '<Smith2018ArticularContactForce.*?</Smith2018ArticularContactForce>';
matches1 = regexp(text1, pattern, 'match', 'dotexceptnewline');
matches2 = regexp(text2, pattern, 'match', 'dotexceptnewline');

fprintf('Fuerzas de contacto en STRATO_001:\n');
for i = 1:length(matches1)
    fprintf('\n%s\n', matches1{i});
end

fprintf('\n\nFuerzas de contacto en STRATO_004:\n');
for i = 1:length(matches2)
    fprintf('\n%s\n', matches2{i});
end