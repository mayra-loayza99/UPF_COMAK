import os

def clean_column_name(name):
    """
    Lógica V4 (Con protección):
    0. PRE-CHEQUEO: Si ya tiene un punto en la primera posición de separación 
       (antes que cualquier _ o espacio), NO SE TOCA.
    1. Si tiene '_', reemplaza el PRIMERO por '.'
    2. Si tiene espacios:
       - El primer espacio se convierte en '.'
       - Todos los demás espacios se eliminan.
    """
    new_name = name.strip()
    
    # Si la celda está vacía, retornar vacío
    if not new_name:
        return ""

    # --- REGLA 0: PROTECCIÓN DE ARCHIVOS YA CORREGIDOS ---
    if '.' in new_name:
        idx_dot = new_name.index('.')
        idx_us = new_name.find('_')
        idx_space = new_name.find(' ')

        # Verificamos si el punto aparece ANTES que cualquier otro separador conflictivo
        # (Si find devuelve -1 significa que no existe ese caracter, lo cual es bueno aquí)
        
        is_dot_first_us = (idx_us == -1 or idx_dot < idx_us)
        is_dot_first_space = (idx_space == -1 or idx_dot < idx_space)

        if is_dot_first_us and is_dot_first_space:
            return new_name  # Ya está correcto, lo devolvemos intacto.

    # --- REGLA 1: GUIONES BAJOS ---
    if '_' in new_name:
        return new_name.replace('_', '.', 1)
    
    # --- REGLA 2: ESPACIOS (r knee m -> r.kneem) ---
    if ' ' in new_name:
        parts = new_name.split()
        if len(parts) > 1:
            return parts[0] + '.' + "".join(parts[1:])
        
    return new_name

def process_file(filepath, output_folder):
    filename = os.path.basename(filepath)
    ext = os.path.splitext(filename)[1].lower()
    
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"Error leyendo {filename}: {e}")
        return
    
    new_lines = []
    
    # --- PROCESAMIENTO .MOT ---
    if ext == '.mot':
        header_processed = False
        for line in lines:
            if not header_processed and line.lstrip().lower().startswith('time'):
                cols = line.strip().split('\t')
                new_cols = [clean_column_name(c) for c in cols]
                new_lines.append('\t'.join(new_cols) + '\n')
                header_processed = True
            else:
                new_lines.append(line)

    # --- PROCESAMIENTO .TRC ---
    elif ext == '.trc':
        header_processed = False
        for line in lines:
            if not header_processed and line.lstrip().startswith('Frame#'):
                cols = line.strip().split('\t')
                new_cols = []
                for index, col in enumerate(cols):
                    # Ignorar Frame# y Time
                    if index < 2:
                        new_cols.append(col)
                    else:
                        new_cols.append(clean_column_name(col))
                new_lines.append('\t'.join(new_cols) + '\n')
                header_processed = True
            else:
                new_lines.append(line)     
    else:
        return

    output_path = os.path.join(output_folder, filename)
    with open(output_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    print(f"-> OK: {filename}")

def main():
    current_folder = os.getcwd()
    output_folder = os.path.join(current_folder, 'processed_files')
    
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)
        
    print(f"--- Limpiando encabezados (V4 - Con Protección) ---")
    
    count = 0
    for file in os.listdir(current_folder):
        if file.lower().endswith(('.mot', '.trc')):
            process_file(os.path.join(current_folder, file), output_folder)
            count += 1
            
    print(f"\n¡Listo! {count} archivos procesados.")

if __name__ == "__main__":
    main()