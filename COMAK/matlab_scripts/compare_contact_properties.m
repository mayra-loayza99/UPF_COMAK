function compare_contact_properties(model_file_1, model_file_2)
    import org.opensim.modeling.*
    
    model1 = Model(model_file_1);
    model1.initSystem();
    
    model2 = Model(model_file_2);
    model2.initSystem();
    
    fprintf('\n========== COMPARACIÓN DE FUERZAS DE CONTACTO ==========\n\n');
    
    force_set1 = model1.getForceSet();
    force_set2 = model2.getForceSet();
    
    % Buscar fuerzas Smith2018
    for i = 0:force_set1.getSize()-1
        force1 = force_set1.get(i);
        force_name = char(force1.getName());
        
        if contains(force_name, 'Smith2018') || contains(force_name, 'contact')
            try
                force2 = force_set2.get(force_name);
                
                % Intentar hacer downcast a Smith2018ArticularContactForce
                if strcmp(char(force1.getConcreteClassName()), 'Smith2018ArticularContactForce')
                    cf1 = Smith2018ArticularContactForce.safeDownCast(force1);
                    cf2 = Smith2018ArticularContactForce.safeDownCast(force2);
                    
                    fprintf('Fuerza: %s\n', force_name);
                    fprintf('  STRATO_001 | STRATO_004\n');
                    fprintf('  ---------  | ----------\n');
                    
                    % Usar getProperty en lugar de get_
                    try
                        stiff1 = cf1.getPropertyByName('stiffness').getValueAsDouble();
                        stiff2 = cf2.getPropertyByName('stiffness').getValueAsDouble();
                        fprintf('  Stiffness:        %.2e | %.2e', stiff1, stiff2);
                        if abs(stiff1 - stiff2) > 1e-6
                            fprintf(' ⚠ DIFERENTE\n');
                        else
                            fprintf('\n');
                        end
                    catch
                        fprintf('  Stiffness: (no se pudo obtener)\n');
                    end
                    
                    try
                        diss1 = cf1.getPropertyByName('dissipation').getValueAsDouble();
                        diss2 = cf2.getPropertyByName('dissipation').getValueAsDouble();
                        fprintf('  Dissipation:      %.2e | %.2e', diss1, diss2);
                        if abs(diss1 - diss2) > 1e-6
                            fprintf(' ⚠ DIFERENTE\n');
                        else
                            fprintf('\n');
                        end
                    catch
                        fprintf('  Dissipation: (no se pudo obtener)\n');
                    end
                    
                    try
                        sf1 = cf1.getPropertyByName('static_friction').getValueAsDouble();
                        sf2 = cf2.getPropertyByName('static_friction').getValueAsDouble();
                        fprintf('  Static friction:  %.4f | %.4f', sf1, sf2);
                        if abs(sf1 - sf2) > 1e-6
                            fprintf(' ⚠ DIFERENTE\n');
                        else
                            fprintf('\n');
                        end
                    catch
                        fprintf('  Static friction: (no se pudo obtener)\n');
                    end
                    
                    try
                        df1 = cf1.getPropertyByName('dynamic_friction').getValueAsDouble();
                        df2 = cf2.getPropertyByName('dynamic_friction').getValueAsDouble();
                        fprintf('  Dynamic friction: %.4f | %.4f', df1, df2);
                        if abs(df1 - df2) > 1e-6
                            fprintf(' ⚠ DIFERENTE\n');
                        else
                            fprintf('\n');
                        end
                    catch
                        fprintf('  Dynamic friction: (no se pudo obtener)\n');
                    end
                    
                    fprintf('\n');
                end
            catch ME
                fprintf('ERROR procesando %s: %s\n\n', force_name, ME.message);
            end
        end
    end
    fprintf('=======================================================\n\n');
end