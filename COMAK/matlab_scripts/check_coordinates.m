import org.opensim.modeling.*

model = Model('D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\results\HOLOA_040\comak_inverse_kinematics\ik_constrained_model.osim');
coords = model.getCoordinateSet();

ik_labels = ik.colheaders(2:end);

for i = 1:length(ik_labels)
    if ~coords.contains(ik_labels{i})
        warning('Coordenada no encontrada en el modelo: %s', ik_labels{i});
    end
end
