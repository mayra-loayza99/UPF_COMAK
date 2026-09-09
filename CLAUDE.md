# UPF_COMAK — Workspace de Mayra

## Contexto
Investigación PhD: biomecánica de KOA en mujeres. Pipeline OpenSim
(IK + COMAK + JointMechanics) ejecutado desde MATLAB sobre cohorte
HOLOA + STRATO.

## Layout físico de archivos

### Read-only (NUNCA modificar)
- Datos de entrada: `D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\processed_data\<sujeto>\`
  Estructura: `model/*.osim`, `walking/*.trc + *.mot + *Event*`,
  `standing/`, y `*.emt` (peso) en la raíz.
- Scripts originales (referencia, fallback): `UPF_COMAK-master\COMAK\matlab_scripts\`

### Workspace activo (este directorio: D:\mayra\Descargas\UPF_COMAK\)
- Scripts MATLAB de trabajo: `COMAK\matlab_scripts\`
  → Es donde se editan y se ejecutan los scripts. La versión que sí cambia.
- Resultados generados: `COMAK\results\<sujeto>\`
  → Outputs de IK, COMAK y JointMechanics aquí, no en master.
- Orquestación: `.claude/`, `validation/`, `notes/`, `workflows/`, `logs/`

### Reglas de paths para agentes
- Datos: leer de UPF_COMAK-master\UPF_COMAK-master\COMAK\processed_data\
- Scripts a ejecutar/editar: UPF_COMAK\COMAK\matlab_scripts\
- Resultados a verificar: UPF_COMAK\COMAK\results\<sujeto>\
- Si algo falla en los scripts del workspace, comparar con los de master
  como referencia (sin copiar de vuelta sin permiso explícito).

## Reglas inviolables

### Read-only paths
NUNCA modifiques, crees ni borres archivos en:
- D:\mayra\Descargas\UPF_COMAK-master\

Esa carpeta es el repositorio upstream. Solo se lee. Cualquier
modificación al pipeline se hace en este workspace y se documenta.

### Roles
Trabajamos con subagents especializados (.claude/agents/):
- orchestrator: planifica, no ejecuta
- executor: ejecuta comandos MATLAB/Python
- debugger: diagnostica errores, propone hipótesis
- code-writer: aplica cambios mínimos, solo tras hipótesis validada

Invócalos con la Task tool. Nunca uses un rol para algo fuera de su
ámbito.

### Validaciones
Después de cada paso del pipeline, ejecutar validation/check_outputs.py
con la etapa correspondiente. Si falla, abortar — no continuar.

## Pipeline canónico (un sujeto)
1. Verificar único .osim en data/<sujeto>/model/
2. IK     → ../results/<sujeto>/inverse_kinematics/*.mot
3. COMAK  → ../results/<sujeto>/comak/*_states.sto    (>60s, >10KB)
4. JM     → ../results/<sujeto>/joint_mechanics/*.sto

## Contexto persistente
- notes/known_paths.md → rutas reales del proyecto
- notes/pending_decisions.md → decisiones abiertas

## Histórico
Bugs ya resueltos (no repetir):
- `dir(*.osim)` con múltiples archivos concatena nombres → validar count==1
- `toc` sin argumento si `tic` está en variable → usar siempre tic/toc
  con ID local