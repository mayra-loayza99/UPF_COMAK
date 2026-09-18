# Handoff V3 — Proyecto UPF_COMAK

Documento de contexto para retomar el trabajo en una **nueva conversación,
fuera de Claude Code** (ej. un chat normal). Sustituye a `HANDOFF_UPF_COMAK.md`
(V2), que queda como histórico — no lo borres, pero da prioridad a este.

Fecha del último corte: **2026-07-03**.

---

## 1. Quién soy y qué hago

- **Mayra Loayza**, PhD researcher en UPF (Barcelona).
- Investigación en biomecánica de **knee osteoarthritis (KOA)** en mujeres.
- Pipeline: simulaciones musculoesqueléticas en **OpenSim + JAM plugin** ejecutadas desde **MATLAB**.
- Tres pasos del pipeline: **Inverse Kinematics (IK) → COMAK → Joint Mechanics (JM)**.
- Dos sub-proyectos: **HOLOA** y **STRATO**.
- Repo público: https://github.com/mayra-loayza99/UPF_COMAK
- Email: mayraalejandra.loayza@upf.edu

---

## 2. Objetivo activo de esta fase: soporte `side='l'`

Desde V2, el foco cambió de "hacer correr el E2E bilateral" a: **hacer que
el pipeline de producción (`main_comak_workflow_function.m`) soporte
correctamente `side='l'` (pierna izquierda) además de `side='r'`**, de forma
no-bilateral (una pierna a la vez, seleccionable).

Sujeto de referencia para todo este trabajo: **HOLOA_040**.

### Qué se hizo (en orden)

1. **Auditoría estática (Paso C)** de `main_comak_workflow_function.m` y
   sus callees, buscando hardcoding hacia el lado derecho. Solo lectura,
   sin ejecutar nada. Hallazgos completos en `notes/pending_decisions.md`
   (sección "Auditoría estática side='l' — Paso C (2026-07-03)"). Resumen
   de los 3 bugs críticos encontrados:
   - `time_start`/`time_stop` siempre usaban `hs_data.eRHS` (evento derecho),
     ignorando `side`.
   - La llamada a `run_ik` no propagaba el argumento `side` (aunque
     `run_ik.m` ya lo soporta internamente).
   - `dir('*.osim')` asumía un único archivo `.osim` por sujeto, pero
     `HOLOA_040/model/` tiene **3**: `model_HOLOA_040.osim`,
     `model_two_legs_HOLOA_040.osim`, `model_HOLOA_040_left.osim`. Esto
     bloqueaba el pipeline incluso para `side='r'`.
   - Confirmado (sin blocker): `Event_Sequences_HOLOA_ID_40.emt` sí tiene
     columnas `eLHS`/`eLTO` válidas, no solo `eRHS`/`eRTO`.
   - Gaps de integración adicionales (no arreglados aún): `preparar_modelo_bilateral()`
     y `espejo_cinematica()` manejan `side` bien pero nunca se invocan desde
     el workflow de producción; ~19 archivos de visualización/reportes
     (`plot_kinematics.m`, `plot_activations.m`, `plot_primary_coordinates_vs_mocap.m`,
     `generateMeanReport.m`, `create_report.m`, etc.) tienen hardcoding
     sistémico a sufijo `_r`, no auditados línea por línea todavía.

2. **Copia de datos**: `HOLOA_040` completo copiado de
   `UPF_COMAK-master\...\processed_data\HOLOA_040\` (solo lectura, intacto)
   a `UPF_COMAK\COMAK\data\HOLOA_040\` (workspace, editable). Estructura
   completa: `Masses_HOLOA_040.emt`, `model/` (con `Geometry/` y los 3
   `.osim` originales), `standing/`, `walking/`.

3. **Movido `model_two_legs_HOLOA_040.osim`** fuera de
   `COMAK/data/HOLOA_040/model/` hacia `UPF_COMAK\archive\bilateral\`
   (directorio nuevo, creado para esto). **Estado actual**: quedan **2**
   `.osim` en `HOLOA_040/model/` (`model_HOLOA_040.osim` y
   `model_HOLOA_040_left.osim`), no 1. Esto ya no rompe
   `main_comak_workflow_function.m` porque el fix #3 de abajo elimina el
   uso de `dir('*.osim')` ahí, pero **cualquier otro script que todavía use
   `dir('*.osim')` sobre esta carpeta seguiría rompiendo** (no auditado
   cuáles, si los hay, fuera de `main_comak_workflow_function.m`).

4. **3 fixes quirúrgicos aplicados** por el code-writer en
   `COMAK/matlab_scripts/main_comak_workflow_function.m` (verificados
   línea por línea con `Read` y `git diff` — confirmados correctos):

   - **Firma + default**: `function main_comak_workflow_function(directory_path, side)`
     (L1) con `if nargin < 2 || isempty(side); side = 'r'; end` (L14-16).
   - **Eventos según lado** (L94-100): branch `strcmp(side,'l')` → usa
     `hs_data.eLHS(1)/(2)` si `'l'`, `hs_data.eRHS(1)/(2)` si `'r'`.
   - **Selección explícita de modelo** (L107-117 y L179-187, dos sitios):
     reemplaza `dir(fullfile(directory_model, '*.osim'))` por
     `sprintf('model_%s_%s%s.osim', project_id, numeric_id, if_left)` +
     `isfile()` check con `error()` si no existe. Patrón de nombre
     confirmado contra datos reales: `model_<project_id>_<numeric_id>.osim`
     / `model_<project_id>_<numeric_id>_left.osim` (ej. `project_id='HOLOA'`,
     `numeric_id='040'` → `model_HOLOA_040.osim` / `model_HOLOA_040_left.osim`).
   - **Propagación de `side` a `run_ik`** (L162): se añadió `side` como
     9º argumento posicional (coincide con la signature de `run_ik.m`,
     que ya tiene `side = 'r'` como default en su bloque `arguments`).

5. **Hallazgo importante sobre el estado de git**: el archivo
   `main_comak_workflow_function.m` tiene en su working tree (sin
   commitear) una **mezcla de dos cosas distintas**:
   - (A) Los 3 fixes de `side='l'` de arriba (recién aplicados).
   - (B) Cambios **preexistentes**, ya en el archivo antes de esta fase de
     trabajo, no relacionados con `side='l'`: reestructuración de la
     llamada a `run_comak` (usa `rethrow(ME)` en vez de `continue` en el
     catch, imprime stack trace, formato multi-línea), `assert`s post-COMAK
     (tamaño del `.sto` > 10KB, duración > 60s), y una línea suelta
     `sf_emg = 1000;` en la sección de reportes poblacionales (candidata a
     código huérfano — pendiente de confirmar si se usa en algún otro
     sitio).
   - **Se pidió a un debugger preparar un plan de staging (`git add -p`)**
     para separar esto en 2 commits distintos. **Esta tarea estaba en
     progreso (background) al momento de escribir este handoff — no se
     confirmó el resultado todavía.** Ver sección 8, punto 1.
   - **También se pidió un dump crudo de `git status`/`git log`/`git diff --stat`**
     al executor (el debugger inicial rechazó la tarea correctamente,
     porque ejecutar comandos no es su rol — solo tiene Read/Glob/Grep,
     sin Bash). **Esta tarea también estaba en progreso al momento de
     escribir este handoff.** Ver sección 8, punto 2.

### Qué falta (inmediato)

- Recoger los resultados de las dos tareas en progreso (plan de staging +
  dump de git) y decidir/ejecutar los 2 commits separados.
- Ejecutar el pipeline con `side='l'` para HOLOA_040 al menos hasta IK, para
  validar los 3 fixes end-to-end (no se ha ejecutado nada todavía — todo
  el trabajo de esta fase fue estático: auditoría, copia de archivos,
  edición de código).
- Decidir si se ataca ahora el hardcoding de los ~19 archivos de
  visualización/reportes, o se deja para una fase posterior (no bloquea
  IK/COMAK/JM, solo afecta gráficos y reportes).
- Confirmar si algún otro script (aparte de `main_comak_workflow_function.m`)
  todavía usa `dir('*.osim')` sobre `HOLOA_040/model/`, dado que ahí quedan
  2 archivos (no 1).

---

## 3. Arquitectura del filesystem (CRÍTICO — sin cambios desde V2)

Dos directorios principales con roles distintos:

| Carpeta | Rol | Modificable |
|---|---|---|
| `D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\` | Upstream / referencia / contiene los DATOS de la cohorte | **Read-only** |
| `D:\mayra\Descargas\UPF_COMAK\` | Workspace activo (fork con orquestación, scripts modificados, resultados) | Editable |

**Reglas inviolables:**
- Ningún agente toca `UPF_COMAK-master\`. Solo lectura.
- Todos los outputs caen en `UPF_COMAK\COMAK\results\<sujeto>\`.
- Los scripts de trabajo viven en `UPF_COMAK\COMAK\matlab_scripts\`.

**Sub-rutas importantes (actualizado):**

```
UPF_COMAK-master\UPF_COMAK-master\COMAK\
├── data\                           ← templates XML
├── matlab_scripts\                 ← scripts ORIGINALES (referencia)
├── models\lenhart2015_generic\     ← modelo genérico
└── processed_data\<sujeto>\        ← DATOS DE ENTRADA (read-only)
    ├── model\                      ← .osim escalado por sujeto + Geometry\
    ├── walking\                    ← .trc, .mot, *Event* (eRHS/eRTO/eLHS/eLTO)
    └── standing\

UPF_COMAK\
├── .claude\agents\                 ← subagents (orchestrator, executor, code-writer, debugger)
├── archive\bilateral\              ← NUEVO: model_two_legs_HOLOA_040.osim (movido aquí)
├── CLAUDE.md                       ← contexto del proyecto cargado automáticamente
├── COMAK\
│   ├── data\                       ← XMLs de actuadores (workspace)
│   │   ├── lenhart2015_reserve_actuators.xml      (huérfano, NO usado)
│   │   ├── lenhart2015_reserve_actuators_r.xml    (pierna derecha)
│   │   └── lenhart2015_reserve_actuators_l.xml    (pierna izquierda)
│   ├── data\HOLOA_040\             ← NUEVO: copia de trabajo del sujeto (ver sección 2.2)
│   │   ├── model\                  ← 2 .osim (right + left), Geometry\, Scale_Setup
│   │   ├── standing\
│   │   └── walking\                ← incluye Event_Sequences con eLHS/eLTO válidos
│   ├── matlab_scripts\             ← scripts ACTIVOS
│   └── results\<sujeto>\           ← OUTPUTS van aquí
├── logs\                           ← logs de runs y análisis
├── notes\
│   ├── HANDOFF_UPF_COMAK.md        ← V2 (histórico)
│   ├── HANDOFF_UPF_COMAK_V3.md     ← este archivo
│   ├── known_paths.md
│   └── pending_decisions.md        ← lista viva de pendientes, incluye auditoría Paso C completa
└── validation\
```

**Nota sobre la doble carpeta `UPF_COMAK-master\UPF_COMAK-master\`**: es la estructura real al descomprimir un zip de GitHub. No es bug.

---

## 4. Sistema multi-agente (Claude Code)

Trabajo con **Claude Code** (CLI). Cuatro roles especializados:

| Rol | Qué hace | Qué NO hace |
|---|---|---|
| **orchestrator** | Planifica tareas en pasos atómicos asignados a otros agentes | Ejecutar, modificar, diagnosticar |
| **executor** | Ejecuta comandos (bash, MATLAB, PowerShell) y reporta resultados | Diagnosticar, decidir, modificar código |
| **code-writer** | Aplica cambios mínimos al código según plan validado | Planificar, ejecutar, improvisar |
| **debugger** | Diagnostica fallos con hipótesis ordenadas por probabilidad; solo Read/Glob/Grep, **sin Bash** | Arreglar, ejecutar comandos |

**Disciplina de roles validada de nuevo en esta fase**: cuando se le pidió
al debugger ejecutar `git status`/`git log` (comandos, no lectura de
archivos), **rechazó correctamente la tarea** explicando que no tiene
Bash y que eso es trabajo del executor. Reasignado sin fricción.

**Permisos del sandbox**: Claude Code restringe el acceso a la carpeta
desde donde se lanzó `claude`. Por eso `UPF_COMAK-master` está fuera de su
alcance para escritura — protección efectiva. Lectura sí funciona
(confirmado repetidamente en esta fase, ej. lectura de
`Event_Sequences_HOLOA_ID_40.emt` desde agentes).

---

## 5. Pipeline: estado actual

### Single-leg COMAK (pierna derecha), scripts pre-side='l'
- Funcionaba desde scripts de master / workspace antes de estos fixes.
- Última ejecución exitosa conocida: HOLOA_040 en 1244 segundos (V2, previo a esta fase).

### Bilateral COMAK
- Sin cambios desde V2: primer E2E ejecutado falló en IK (STL de geometría
  no encontrados). Fix propuesto (junction de `Geometry\`) documentado en
  V2 sección 8, **no se ha vuelto a intentar en esta fase** — el foco
  cambió a `side='l'` no-bilateral.

### `side='l'` (esta fase)
- **3 fixes aplicados, 0 ejecuciones todavía.** Ver sección 2.

### Entry points

| Script | Tipo | Uso |
|---|---|---|
| `main_comak_workflow_function.m` | función | Cohorte completa; ahora acepta `side` ('r' default, 'l' soportado tras los 3 fixes) |
| `test_bilateral_comak.m` | script | E2E bilateral de un sujeto (HOLOA_040 hardcodeado, no tocado en esta fase) |

---

## 6. Bugs conocidos / fixes aplicados (acumulado V2 + V3)

### Aplicados en V2 (ver `HANDOFF_UPF_COMAK.md` para detalle completo)
- Poda de markers corregida en `extract_left_model.py`.
- `attached_geometry` de `tibia_proximal_l` corregido manualmente en XML.
- `dir('*.osim')` con múltiples archivos → assert `numel==1` (fix genérico, previo a los fixes de V3 que además evitan `dir` del todo en `main_comak_workflow_function.m`).
- `toc` sin argumento → timers locales con ID.
- `try/catch` en COMAK que tragaba errores → `rethrow(ME)` + asserts post-COMAK.
- Función local duplicada `configurar_comak_base` en `run_comak.m` → eliminada.

### Aplicados en V3 (esta fase)
- Ver sección 2, punto 4 (los 3 fixes de `side='l'`).

### Pendientes (lista viva en `notes/pending_decisions.md` — no duplicar aquí, solo referenciar)
- `run_ik.m`: silent failure del try/catch (L22, `Logger.setLevelString` envuelto en try/catch vacío) — confirmado que sigue ahí, no tocado.
- `preparar_modelo_bilateral()` y `espejo_cinematica()` nunca se invocan desde el workflow de producción.
- ~19 archivos de visualización/reportes con hardcoding a `_r`.
- `configurar_muscle_weights()` en `run_comak.m` con lista de músculos hardcoded a `_r` (rama dormida, `custom_muscle_weights=false` hoy).
- Limpieza de `lenhart2015_reserve_actuators.xml` (sin sufijo, huérfano) — decisión abierta.
- `sf_emg = 1000;` en `main_comak_workflow_function.m` — candidata a línea muerta, pendiente de confirmar con grep si se usa en algún otro sitio (tarea en progreso al cierre de este handoff, ver sección 8).
- Separar en 2 commits los cambios mezclados en `main_comak_workflow_function.m` (fixes side='l' vs cambios preexistentes de run_comak/asserts/sf_emg).

---

## 7. Tools & resources (sin cambios desde V2)

### Entornos Python

| Entorno | Python | Uso | Activación |
|---|---|---|---|
| `base` (anaconda3) | 3.12 | General | `conda activate base` |
| `analytics` | 3.9.21 | Scripts de visualización (`COMAK/python/*.py`, requieren numpy≥1.26) | `conda activate analytics` |
| `osim37` | 3.7.1 | SDK JAM bundleado — único env compatible con `_simbody.pyd` | `conda activate osim37` |
| `paraview-env` | 3.13 | ParaView (creado manualmente) | `conda activate paraview-env` |

**Regla osim37**: no instalar paquetes adicionales sin razón documentada.

### Comandos / paths de referencia rápida

| Cosa | Comando o path |
|---|---|
| Lanzar Claude Code | `cd D:\mayra\Descargas\UPF_COMAK && claude` |
| Listar subagents | `/agents` dentro de Claude Code |
| Comando shell directo en Claude Code | Prefijo `!` (bash) |
| Repo git | rama actual `visualization_python`, remote `origin` → `https://github.com/mayra-loayza99/UPF_COMAK.git`, tracking `origin/visualization_python` |
| Plugin JAM | `D:\mayra\Descargas\UPF_COMAK\bin\osimJAM.dll` |
| Datos de HOLOA_040 (workspace, editable) | `COMAK\data\HOLOA_040\` |
| Datos de HOLOA_040 (master, solo lectura) | `UPF_COMAK-master\UPF_COMAK-master\COMAK\processed_data\HOLOA_040\` |

---

## 8. Próximo paso inmediato

Al momento de cerrar esta sesión, había **una tarea de debugger corriendo
en background sin confirmar resultado** (plan de staging), y **una segunda
tarea (dump crudo de git) que ya terminó** — su resultado se incorpora
aquí directamente para no perderlo.

### 8.1. Estado real de git (confirmado, vía executor)

- Rama actual: `visualization_python`. Remote `origin` →
  `https://github.com/mayra-loayza99/UPF_COMAK.git`. **0 commits ahead, 0
  behind** respecto a `origin/visualization_python` (todo lo pendiente es
  working tree, nada divergente a nivel de commits).
- `git log --oneline -- COMAK/matlab_scripts/main_comak_workflow_function.m`
  → solo 2 commits en toda su historia: `ba88b6d script modificados` y
  `932317c Add files`. Ninguno de los commits recientes de la rama
  (`ef15d43`, `e89782b`, `20af36c`, etc.) tocó este archivo — confirma que
  los cambios "preexistentes" (rethrow/asserts/`sf_emg`) llevan tiempo sin
  commitear, no vienen de un commit reciente.
- **Importante**: `git status` muestra `COMAK/matlab_scripts/run_comak.m`
  con una copia **staged** (`Changes to be committed`) Y otra **unstaged**
  distinta (`Changes not staged`) — es decir, ese archivo ya tiene algo en
  el índice de una sesión anterior, y además cambios nuevos encima sin
  añadir. Cuidado al preparar el `git add -p`: revisar primero
  `git diff --cached -- COMAK/matlab_scripts/run_comak.m` para saber qué
  hay ya staged antes de tocarlo.
- `main_comak_workflow_function.m` está **completamente unstaged** (nada
  en el índice todavía) — más simple de separar con `git add -p`.
- Muchos archivos `.vtp`/`.stl` de `COMAK/models/lenhart2015_generic/Geometry/`
  aparecen modificados solo por line-endings (LF→CRLF, warnings de git,
  no contenido real) — no relacionado con `side='l'`, ignorar para el plan
  de staging de `main_comak_workflow_function.m`.
- Hay **`COMAK/python/model_two_legs.osim` borrado** (20712 líneas) y
  `COMAK/python/model_two_legs_fixed.osim` modificado — trabajo previo no
  relacionado con esta fase, no tocar sin más contexto.
- Untracked relevante: `.claude/`, `CLAUDE.md`, `COMAK/data/HOLOA_040/`
  (la copia hecha en esta fase), `COMAK/data/lenhart2015_reserve_actuators_l.xml`
  y `_r.xml`, `notes/`, `logs/`, `archive/` (incluye el
  `model_two_legs_HOLOA_040.osim` movido en esta fase), y varios scripts
  Python de extracción de modelo izquierdo (`extract_left_model.py`,
  `create_left_cartilage_meshes.py`, etc.). **Nada de esto está commiteado
  todavía** — toda la infraestructura de agentes (`.claude/`, `CLAUDE.md`)
  y los datos/notas de esta fase son untracked. Decidir en algún momento
  qué de esto se quiere versionar.

### 8.2. Plan de staging confirmado (debugger, lectura estática — sin `git diff` real por falta de Bash en su rol)

Los 6 hunks de `side='l'` (Commit 1) están limpios y se pueden stagear con
`git add -p` normal (`y`): firma de función (L1), default `nargin<2` (L14-16),
bloque `eLHS`/`eRHS` (L92-100), selección de modelo sitio 1 (L106-118),
llamada a `run_ik` con `side` (L161-163), selección de modelo sitio 2 (L177-188).

**Un hallazgo crítico que cambia el plan**: la línea 199 (llamada a
`run_comak`) mezcla en la **misma línea física** el reformateo multi-línea
preexistente (cambio B) **y** el argumento `side` añadido al final (cambio
A, propagación de side a `run_comak`, que también es parte del trabajo de
esta fase y no se había listado explícitamente antes). Esto significa que
`git add -p` con y/n simple **no puede separar limpiamente ese hunk** — va
a requerir edición manual del hunk (`e`) para dejar solo `, side` en el
Commit 1 y el resto (indentación L196, reformateo L198-199, cambio
`continue`→stack trace+`rethrow` en L203-209) en el Commit 2.

`sf_emg = 1000;` (L341) **NO es código muerto** — confirmado con grep, se
usa en L361 (`plot_all_patients_activation_vs_emg(sf_emg)`) en el mismo
bloque de reportes poblacionales. Corrección respecto a lo anotado antes en
este handoff: es cambio B (preexistente, redundante con la asignación
equivalente en L264 del loop por-paciente), pero funcional, no huérfano.

**Hallazgo nuevo, requiere decisión del usuario (no es bug de side='l',
es diseño)**: el `rethrow(ME)` en el catch de COMAK (L209) no tiene ningún
`try/catch` externo que lo capture — el `for` que itera sobre todos los
pacientes no está envuelto en try/catch. Si COMAK falla para un paciente,
**aborta el procesamiento de todos los pacientes restantes del batch**,
a diferencia de IK y Joint Mechanics, que usan `continue` para saltar solo
al paciente fallido. Confirmar con el usuario si esto es intencional
(COMAK como paso crítico que debe detener todo) o si debería alinearse con
el patrón `continue` de los otros dos pasos — es una decisión de diseño,
no algo que el code-writer deba resolver por su cuenta.

Además: la sección "REPORTES POBLACIONALES (OPCIONAL)" (L339 en adelante)
tiene un comentario que dice "Descomentar si quieres generar reportes" pero
el código **no está comentado** — se ejecuta siempre al terminar el `for`.
Puede ser sorpresa funcional; preexistente, no relacionado con side='l'.

### 8.3. Pendiente real para la próxima sesión

1. Ejecutar el `git add -p` real con el plan de 8.2, incluyendo la edición
   manual (`e`) del hunk mezclado de la línea 199.
2. Decidir sobre el `rethrow` vs `continue` en COMAK (ver 8.2) antes o
   después de separar los commits — es independiente de side='l' pero vive
   en el mismo archivo.
3. Confirmar si `D:\mayra\Descargas\UPF_COMAK-master\COMAK\matlab_scripts\`
   (mencionado en `CLAUDE.md` como fallback read-only) existe realmente —
   el debugger no pudo acceder a esa ruta (timeout en Glob/Read), a
   diferencia de `UPF_COMAK-master\UPF_COMAK-master\COMAK\...` que sí es
   accesible y es la ruta real usada en toda esta fase. Puede ser solo una
   limitación de sandbox del debugger, no necesariamente que la ruta no
   exista — verificar con el executor.
4. Decidir qué hacer con los archivos untracked de infraestructura
   (`.claude/`, `CLAUDE.md`, `notes/`) — ¿se commitean en algún momento o
   se quedan locales?

### Pasos concretos para la próxima sesión

1. Retomar/relanzar las 2 tareas de arriba si no dieron resultado.
2. Con el plan de staging en mano, ejecutar el `git add -p` real (manual,
   no delegar el `git add`/`git commit` real a un agente sin confirmación
   explícita — son operaciones que afectan el historial compartido).
3. Ejecutar el pipeline `main_comak_workflow_function('...', 'l')` para
   HOLOA_040 (usando los datos ya copiados en `COMAK/data/HOLOA_040/`) al
   menos hasta el paso de IK, para validar los 3 fixes de esta fase.
4. Si falla: invocar al debugger con el log de la ejecución.
5. Decidir si se ataca el hardcoding de los archivos de visualización
   (~19 archivos) en esta misma fase o se pospone.

---

## 9. Cómo iniciar la próxima conversación

Sugerencia de mensaje inicial:

> Hola. Adjunto el handoff V3 de la sesión anterior (`HANDOFF_UPF_COMAK_V3.md`).
> Quiero retomar desde el punto pendiente: confirmar el resultado del plan
> de staging de git (separar fixes de side='l' de cambios preexistentes en
> main_comak_workflow_function.m), y luego ejecutar el pipeline con
> side='l' para HOLOA_040 para validar los 3 fixes aplicados. ¿Puedes
> ayudarme a continuar?

Adjunta este archivo y, si es posible, también `notes/pending_decisions.md`
(tiene el detalle completo de la auditoría Paso C que no se repitió aquí
para no duplicar contenido).

---

## 10. Filosofía operativa de las sesiones (sin cambios desde V2 — sigue funcionando)

- **Leer antes de ejecutar**: cualquier cambio o ejecución va precedido de lectura/análisis.
- **Asserts inline > try/catch silencioso**: preferir que el pipeline pare a que continúe con datos basura.
- **Disciplina de roles**: orchestrator → executor → debugger → code-writer, en orden. Los agentes rechazan tareas fuera de su rol — dejar que lo hagan, no forzar.
- **Master es sagrado**: nunca modificar. Todo cambio vive en el workspace.
- **Cambios mínimos**: el code-writer hace lo mínimo necesario, no "limpia de paso" — validado de nuevo en esta fase (los 3 fixes de side='l' no tocaron nada fuera de alcance).
- **Validar con `git diff` después de cada edición de agente**: no asumir que el reporte del code-writer es completo — leer el diff real. Esto reveló la mezcla de cambios preexistentes en esta fase.
- **Operaciones de git que afectan historial compartido (`add`, `commit`, `push`) requieren confirmación explícita del usuario**, nunca delegarlas a un agente sin más.

---

*Fin del handoff V3. Buena suerte en la próxima sesión.*
