function list_model_coordinates(model_file)
    import org.opensim.modeling.*
    
    model = Model(model_file);
    model.initSystem();
    
    coord_set = model.getCoordinateSet();
    n_coords = coord_set.getSize();
    
    fprintf('\n========== COORDENADAS EN EL MODELO ==========\n');
    fprintf('Total de coordenadas: %d\n\n', n_coords);
    
    for i = 0:n_coords-1
        coord = coord_set.get(i);
        coord_name = char(coord.getName());
        coord_path = char(coord.getAbsolutePathString());
        fprintf('%d. Nombre: %s\n   Path: %s\n\n', i+1, coord_name, coord_path);
    end
    fprintf('==============================================\n\n');
end