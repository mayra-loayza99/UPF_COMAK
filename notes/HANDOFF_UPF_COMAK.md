# Handoff — Proyecto UPF_COMAK

Documento de contexto para retomar el trabajo en una nueva conversación.
Fecha del último corte: junio 2026.

---

## 1. Quién soy y qué hago

- **Mayra Loayza**, PhD researcher en UPF (Barcelona).
- Investigación en biomecánica de **knee osteoarthritis (KOA)** en mujeres.
- Pipeline: simulaciones musculoesqueléticas en **OpenSim + JAM plugin** ejecutadas desde **MATLAB**.
- Tres pasos del pipeline: **Inverse Kinematics (IK) → COMAK → Joint Mechanics (JM)**.
- Dos sub-proyectos: **HOLOA** y **STRATO**.
- Repo público: https://github.com/mayra-loayza99/UPF_COMAK

---

## 2. Arquitectura del filesystem (CRÍTICO)

Dos directorios principales con roles distintos:

| Carpeta | Rol | Modificable |
|---|---|---|
| `D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\` | Upstream / referencia / contiene los DATOS de la cohorte | **Read-only** |
| `D:\mayra\Descargas\UPF_COMAK\` | Workspace activo (mi fork con orquestación, scripts modificados, resultados) | Editable |

**Reglas inviolables:**
- Ningún agente toca `UPF_COMAK-master\`. Solo lectura.
- Todos los outputs caen en `UPF_COMAK\COMAK\results\<sujeto>\`.
- Los scripts de trabajo viven en `UPF_COMAK\COMAK\matlab_scripts\`.

**Sub-rutas importantes:**

```
UPF_COMAK-master\UPF_COMAK-master\COMAK\
├── data\                           ← templates XML
├── matlab_scripts\                 ← scripts ORIGINALES (referencia)
├── models\lenhart2015_generic\     ← modelo genérico
└── processed_data\<sujeto>\        ← DATOS DE ENTRADA (read-only)
    ├── model\                      ← .osim escalado por sujeto + Geometry\
    ├── walking\                    ← .trc, .mot, *Event*
    └── standing\

UPF_COMAK\
├── .claude\agents\                 ← subagents
│   ├── orchestrator.md
│   ├── executor.md
│   ├── code-writer.md
│   └── debugger.md (PENDIENTE — definición está en notes/)
├── .claude\settings.json           ← permisos (deny writes a master)
├── CLAUDE.md                       ← contexto del proyecto cargado automáticamente
├── COMAK\
│   ├── data\                       ← XMLs de actuadores (workspace)
│   │   ├── lenhart2015_reserve_actuators.xml      (huérfano, NO usado)
│   │   ├── lenhart2015_reserve_actuators_r.xml    (pierna derecha)
│   │   └── lenhart2015_reserve_actuators_l.xml    (pierna izquierda)
│   ├── matlab_scripts\             ← scripts ACTIVOS (ya reconciliados con master)
│   └── results\<sujeto>\           ← OUTPUTS van aquí
├── logs\                           ← logs de runs y análisis
├── notes\                          ← decisiones, rutas conocidas, pendientes
└── validation\                     ← criterios de validación, asserts
```

**Nota sobre la doble carpeta `UPF_COMAK-master\UPF_COMAK-master\`**: es la estructura real al descomprimir un zip de GitHub. No es bug.

---

## 3. Sistema multi-agente (Claude Code)

Trabajo con **Claude Code** (CLI, no la extensión web). Cuatro roles especializados, cada uno con su system prompt en `.claude/agents/<nombre>.md`. Los invoco con:

```
Usa el subagent <nombre> para <tarea>
```

### Roles

| Rol | Qué hace | Qué NO hace |
|---|---|---|
| **orchestrator** | Planifica tareas en pasos atómicos asignados a otros agentes | Ejecutar, modificar, diagnosticar |
| **executor** | Ejecuta comandos (bash, MATLAB, PowerShell) y reporta resultados | Diagnosticar, decidir, modificar código |
| **code-writer** | Aplica cambios mínimos al código según plan validado | Planificar, ejecutar, improvisar |
| **debugger** | Diagnostica fallos con hipótesis ordenadas por probabilidad | Arreglar, ejecutar |

**Disciplina de roles probada**: cuando se le pide a un agente algo fuera de su scope, lo rechaza citando sus propias reglas. Esto se ha validado empíricamente en esta sesión.

**Drift conocido**: a veces el orchestrator termina diciendo "¿Ejecuto?" en primera persona — no ejecuta de verdad, pero conviene reforzar si se vuelve crónico. El executor a veces hace análisis ligero que correspondería al debugger.

**Permisos del sandbox**: Claude Code restringe el acceso del agente a la carpeta desde donde se lanzó `claude`. Por eso `UPF_COMAK-master` está fuera de su alcance — protección efectiva. Para operaciones que requieren acceso a master (como copias master → workspace), se ejecutan manualmente con `!` (bash) o desde un cmd aparte.

---

## 4. Pipeline: estado actual

### Single-leg COMAK (pierna derecha)
- **Funciona** desde scripts de master.
- Última ejecución exitosa: HOLOA_040 en 1244 segundos.

### Bilateral COMAK (workflow nuevo en workspace)
- **Primer E2E ejecutado, falló en el primer paso real (IK)**.
- `preparar_modelo_bilateral.m` ✓ produjo modelo preparado (1315 KB).
- `run_ik.m` ✗ falló silenciosamente (try/catch tragó la excepción).
- Causa raíz: **archivos STL de geometría no se encuentran** porque están en `processed_data\HOLOA_040\model\Geometry\` y OpenSim los busca relativo al modelo preparado en `results\HOLOA_040\`.

### Entry points

| Script | Tipo | Uso |
|---|---|---|
| `main_comak_workflow_function.m` | función | Cohorte completa, single-leg (con `side='r'` por defecto) |
| `test_bilateral_comak.m` | script | E2E bilateral de un sujeto (HOLOA_040 hardcodeado) |

---

## 5. Reconciliación de scripts (completada)

Histórico: workspace y master habían divergido. **47 archivos comunes**, de los cuales:

- 42 cosméticos (CRLF/whitespace) — sin acción
- 5 con divergencia real:

| Archivo | Decisión final |
|---|---|
| `run_joint_mechanics.m` | Workspace tal cual |
| `main_comak_workflow_function.m` | Master → workspace (copia) + añadido parámetro `side` |
| `run_ik.m` | Workspace tal cual |
| `configurar_comak_base.m` | Workspace tal cual (tiene soporte bilateral con `side`) |
| `run_comak.m` | Master → workspace + 3 ediciones quirúrgicas: añadido `side` en firma, removida función local duplicada `configurar_comak_base`, paso de `side` a 4 llamadas internas |

**Estado**: 3 archivos modificados pasan `checkcode` sin errores. Solo warnings preexistentes (variables no usadas, etc.), nada bloqueante.

**3 archivos exclusivos del workspace (bilateral work, no en master):**
- `preparar_modelo_bilateral.m` — deshabilita fuerzas contralaterales en el modelo
- `espejo_cinematica.m` — copia coordenadas ipsilaterales a contralaterales
- `test_bilateral_comak.m` — entry point bilateral

---

## 6. Cómo se ejecuta el pipeline

### Single-leg (cohorte completa)

```cmd
cd D:\mayra\Descargas\UPF_COMAK\COMAK\matlab_scripts
matlab -batch "main_comak_workflow_function('D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\data')"
```

- Recorre todos los sujetos en `processed_data\`.
- Procesa con `side='r'` por defecto.
- Resultados en `UPF_COMAK\COMAK\results\<sujeto>\`.

### Bilateral (un sujeto)

```cmd
cd D:\mayra\Descargas\UPF_COMAK\COMAK\matlab_scripts
matlab -batch "test_bilateral_comak"
```

- Sujeto y SIDE hardcodeados en el script (actualmente HOLOA_040, 'r').
- Pipeline interno: `preparar_modelo_bilateral` → `run_ik` → `espejo_cinematica` → `run_comak` → `run_joint_mechanics`.

---

## 7. Bugs conocidos / fixes aplicados en esta sesión

### Aplicados

- `dir('*.osim')` con múltiples archivos concatenaba nombres → añadido `assert(numel(model_files) == 1)`.
- `toc` sin argumento cuando `tic` está en variable → cambiado a timers locales con ID (`comak_time_start = tic; toc(comak_time_start)`).
- `try/catch` en COMAK que tragaba errores y dejaba pipeline continuar → añadido `rethrow(ME)` + asserts post-COMAK (`.sto > 10KB`, `elapsed > 60s`).
- Función local `configurar_comak_base` duplicada al final de `run_comak.m` → eliminada (ahora usa la versión externa con soporte bilateral).

### Pendientes (anotados en `notes/pending_decisions.md`)

1. **`run_ik.m`: silent failure** — el try/catch traga excepciones del `COMAKInverseKinematicsTool` y reporta "IK completado" en 1.2 s. Aplicar mismo fix que se hizo a `main_comak_workflow_function`: rethrow + assert que `.mot` existe con tamaño razonable.
2. **`preparar_modelo_bilateral.m`: no replica `Geometry\`** — el modelo preparado va a `results\<sujeto>\` pero OpenSim busca los STL ahí. Fix: que la función cree automáticamente una junction `results\<sujeto>\Geometry\` → `processed_data\<sujeto>\model\Geometry\`. Resuelve para todos los sujetos.
3. **Limpieza: `lenhart2015_reserve_actuators.xml` (sin sufijo)** — usa nomenclatura vieja, no se referencia en código activo. Borrar o sincronizar a master.
4. **Limpieza: `lenhart2015_reserve_actuators.xml` en `models/lenhart2015_generic/`** — huérfano, no referenciado por ningún script ni por los `.osim`.
5. **Decisión: `run_comak` sobrescribe `time_start`/`time_stop`** — el bloque `arguments` los recibe pero el cuerpo los reemplaza por valores del archivo IK. ¿Intencional? Importante para futuras simulaciones donde queramos controlar ventana de tiempo.

---

## 8. Próximo paso inmediato

**Hacer correr el E2E bilateral de HOLOA_040 hasta el final.**

### Pasos concretos

1. **Crear junction de Geometry** (cmd como Administrador, no Claude Code):
   ```cmd
   mklink /J "D:\mayra\Descargas\UPF_COMAK\COMAK\results\HOLOA_040\Geometry" "D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\processed_data\HOLOA_040\model\Geometry"
   ```

2. **Verificar la junction**:
   ```cmd
   dir "D:\mayra\Descargas\UPF_COMAK\COMAK\results\HOLOA_040\Geometry" | findstr lenhart2015-R-femur
   ```
   Si lista el `.stl` con ~7.65 MB, OK.

3. **Re-lanzar el E2E** (en Claude Code):
   ```
   Usa el executor para re-lanzar test_bilateral_comak en background.
   Comando: matlab -batch "cd('D:\mayra\Descargas\UPF_COMAK\COMAK\matlab_scripts'); test_bilateral_comak"
   Log a: D:\mayra\Descargas\UPF_COMAK\logs\bilateral_e2e_HOLOA040_<fecha>.log
   Reportar shell_id para poll posterior.
   ```

4. **Esperar 20-40 minutos** (COMAK domina). Poll periódico:
   ```
   Usa el executor para BashOutput sobre shell_id <X>
   ```

5. **Verificar outputs al terminar**:
   - `model_two_legs_HOLOA_040_r_prepared.osim` (>1 MB)
   - `walking_040_ik.mot` (>10 KB)
   - `walking_040_ik_mirror.mot` (>10 KB)
   - `walking_040_states.sto` (>10 KB, COMAK >60 s)
   - `walking_040_ForceReporter_forces.sto` (>10 KB)

### Si falla otra vez

Invocar al **debugger** (primer trabajo real del agente):

```
Usa el subagent debugger para diagnosticar el fallo del último
E2E. Log en: D:\mayra\Descargas\UPF_COMAK\logs\bilateral_e2e_<fecha>.log
Contexto: ver HANDOFF_UPF_COMAK.md sección "Pipeline: estado actual".
```

---

## 9. Comandos / paths de referencia rápida

| Cosa | Comando o path |
|---|---|
| Lanzar Claude Code | `cd D:\mayra\Descargas\UPF_COMAK && claude` |
| Listar subagents | `/agents` dentro de Claude Code |
| Comando shell directo en Claude Code | Prefijo `!` (bash) |
| PowerShell desde bash de Claude Code | `!powershell -Command "..."` |
| Plugin JAM | `D:\mayra\Descargas\UPF_COMAK\bin\osimJAM.dll` |
| Modelo bilateral del sujeto | `processed_data\<sujeto>\model\model_two_legs_<ID>.osim` |
| Datos motion capture | `processed_data\<sujeto>\walking\*.trc, *.mot, *Event*` |
| Output esperado COMAK | `results\<sujeto>\comak\walking_<numID>_states.sto` |

---

## 10. Cómo iniciar la próxima conversación

Sugerencia de mensaje inicial:

> Hola. Adjunto el handoff de la sesión anterior. Quiero retomar desde el punto pendiente: ejecutar el E2E bilateral de HOLOA_040 tras crear la junction de Geometry. ¿Puedes ayudarme a continuar?

Adjunta este archivo (`HANDOFF_UPF_COMAK.md`) y el Claude nuevo tendrá todo el contexto necesario para retomar.

---

## 11. Filosofía operativa de las sesiones

Estos principios han funcionado bien y conviene mantenerlos:

- **Leer antes de ejecutar**: cualquier cambio o ejecución va precedido de lectura/análisis. Cuesta minutos, ahorra horas.
- **Asserts inline > try/catch silencioso**: si algo crítico puede fallar silenciosamente, prefiero un `assert` que pare el pipeline a un `try/catch` que continúe con datos basura.
- **Disciplina de roles**: usar orchestrator → executor → debugger → code-writer en el orden correcto. Saltarse pasos solo en tareas triviales bien definidas.
- **Master es sagrado**: nunca modificar. Todo cambio vive en el workspace.
- **Cambios mínimos**: el code-writer hace lo mínimo necesario, no "limpia de paso".
- **Validar después de cada cambio**: aunque sea con un check trivial. Eso es lo que vive en `validation/`.

---

*Fin del handoff. Buena suerte en la próxima sesión.*


