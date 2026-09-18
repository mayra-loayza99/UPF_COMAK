# Handoff V4 — Proyecto UPF_COMAK

Sustituye a `HANDOFF_UPF_COMAK_V3.md` como documento de contexto
principal. V3 queda como histórico (fase de intento de soporte
directo `side='l'`, abandonada — ver sección 2 de este documento).

Fecha del corte: **2026-09-18**.

---

## 1. Quién soy y qué hago

- **Mayra Loayza**, PhD researcher en UPF (Barcelona).
- Investigación en biomecánica de **knee osteoarthritis (KOA)** en mujeres.
- Pipeline: simulaciones musculoesqueléticas en **OpenSim + JAM (COMAK)** ejecutadas desde **MATLAB**.
- Cuatro pasos del pipeline: **Scale → Inverse Kinematics (IK) → COMAK → Joint Mechanics (JM)**.
- Dos sub-proyectos: **HOLOA** y **STRATO**.
- Repo: `https://github.com/mayra-loayza99/UPF_COMAK.git`, rama `visualization_python`.
- Email: mayraalejandra.loayza@upf.edu

---

## 2. Cambio de estrategia desde V3: de `side='l'` directo a "espejo de datos"

V3 documentaba un intento de hacer que `main_comak_workflow_function.m`
soportara `side='l'` directamente, usando los datos reales de la
pierna izquierda de cada sujeto. Ese intento se **abandonó** tras
varios días de troubleshooting (documentado en `notes/subject_staging.md`):
STLs de geometría izquierda mal orientadas causando cuelgues de IK de
40+ minutos, mismatches de escalado entre el `.osim` y las mallas, y
~19 scripts de visualización con hardcoding sistémico a sufijo `_r`.

**La estrategia que sí funciona (validada en 13+ sujetos)**: en vez de
correr `side='l'` directamente, se **espeja** (refleja sagitalmente)
el TRC/GRF de una pierna hacia el otro lado — swap de prefijos `r.`/`l.`
en nombres de marcador + negación del eje medio-lateral (Z) — y se
corre el pipeline estándar `side='r'`, ya maduro y confiable, sobre
esos datos espejados. Dos variantes según qué pierna se mirrorea:

1. **Mirror por simetría contralateral** (rollout original, 12
   sujetos HOLOA): el sujeto tiene OA en la pierna izquierda pero solo
   se simuló originalmente la derecha (sana). Se mirrorea la derecha
   para producir un proxy de la izquierda. Asume simetría L-R —
   aproximación razonable pero no perfecta.
2. **Mirror de la pierna real afectada** (extracción nueva, sujetos
   HOLOA_008/032 y más por venir): la captura ya tiene datos reales
   de la pierna afectada (ej. GRF solo de la placa izquierda). Se
   mirrorea esa pierna real hacia la derecha para poder usar el mismo
   pipeline `side='r'` — **mejor científicamente** que la variante 1,
   porque no depende de asumir simetría.

También existe el caso **directo sin mirror**: cuando la pierna
afectada coincide con la que tiene datos limpios (ej. HOLOA_002,
HOLOA_033, HOLOA_037: OA derecha + datos reales de la derecha) — se
corre `side='r'` tal cual, sin ningún paso de espejo.

Herramientas clave: `COMAK/matlab_scripts/espejo_trc.m` (mirror de
marcadores TRC), `espejo_grf.m` (mirror de fuerzas de reacción del
suelo). Ambos parsing de texto puro, sin dependencia de la API de
OpenSim.

---

## 3. Arquitectura del filesystem (sin cambios desde V2/V3)

| Carpeta | Rol | Modificable |
|---|---|---|
| `D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\` | Upstream / referencia / datos de la cohorte | **Read-only** |
| `D:\mayra\Descargas\UPF_COMAK\` | Workspace activo (este repo) | Editable |

**Reglas inviolables**: ningún agente toca `UPF_COMAK-master\` (ni
siquiera para escribir resultados). Todos los outputs van a
`UPF_COMAK\COMAK\results\<sujeto>\`. Guardrail reforzado a nivel de
herramienta en `.claude/settings.json` (deny Edit/Write/rm sobre
`UPF_COMAK-master\**`).

**Convención de nombres de sujeto mirroreado**: `<PROJECT>_<numeric_id>_mirror`
(ej. `HOLOA_144_mirror`), con `results_basename = walking_<numeric_id>_mirror`.
Para sujetos directos (sin mirror): `<PROJECT>_<numeric_id>` normal.

---

## 4. Qué NO está en git (por diseño, ver `.gitignore`)

Decisión explícita de la usuaria (2026-09-18): mantener fuera de
control de versiones todo lo que sea dato de sujeto/paciente, aunque
el repo sea privado:

- `COMAK/data/HOLOA_*/`, `COMAK/data/STRATO_*/` — datos crudos
  staged por sujeto (TRC/GRF, modelos escalados).
- `COMAK/results/` — resultados de IK/COMAK/JM por sujeto.
- `COMAK/inputs/` — settings XML generados por sujeto.
- `subject_comak_status.xlsx`, `HOLOASTRATO-OASide_DATA_*.csv` (raíz
  y `COMAK/python/`) — tracking de OA side/sexo/grupo por voluntario.
- `notes/subjects_pending_extraction.md` — misma naturaleza que el
  Excel (ID + OA side de los ~97 sujetos aún sin simular).
- `**/opensim.log` — crece sin límite (llegó a 320MB en esta sesión,
  por encima del límite duro de 100MB/archivo de GitHub). Si se
  necesita evidencia de un run puntual, redirigir a un archivo con
  nombre propio (patrón `stdout_<algo>.log` ya usado en `logs/` y
  `validation/`) en vez de dejar que crezca el log compartido.

El resto de `notes/` (handoffs, pending_decisions, tracking de
pipeline por sujeto con RMS/tamaños/duraciones) SÍ está en git —
es documentación de proceso, no dato clínico crudo.

---

## 5. Estado del rollout de espejo (12 sujetos, ver `notes/mirror_rollout_status.md`)

11 de 12 completaron el pipeline entero (IK→COMAK→JM):
HOLOA_144, 026, 109, 118, 120, 139, 153, 156, 169, 175 (ciclo
completo) + HOLOA_154 (ciclo **truncado** al 53%, ver más abajo).

**Excluidos**: HOLOA_040 (marcadores izquierdos mal orientados,
detectado por inspección visual GUI antes de escalar — mismo tipo de
problema que hizo abandonar el enfoque `side='l'` directo en V3).
HOLOA_165 (diverge en fase de apoyo temprano, coordenada `ankle_flex_r`,
sin causa concreta identificada tras investigación).

**3 fixes de ScaleTool descubiertos durante el rollout** (documentados
en detalle en `notes/pending_decisions.md`, sección "ScaleTool en el
rollout de espejo"):
1. Invocar `ScaleTool` con `cd()` al directorio del XML + nombre de
   archivo **relativo** (no ruta absoluta) al constructor — evita que
   OpenSim concatene el directorio del XML con un `model_file` ya
   absoluto, produciendo una ruta rota.
2. `<marker_set_file>` debe ser ruta absoluta (no relativa), porque
   con el fix #1 las rutas relativas del XML resuelven contra el
   nuevo CWD (el directorio del sujeto), no contra el directorio del
   modelo genérico.
3. `<MarkerPlacer><apply>` debe ser `true` — la plantilla genérica
   trae `false`, lo que hace que ScaleTool corra el `ModelScaler`
   pero nunca el `MarkerPlacer`, sin lanzar ningún error.

**Geometría de cuerpo completo para Joint Mechanics** (ver
`notes/subject_staging.md`): las 7 STL de contacto no bastan —
`JointMechanicsTool` necesita además los ~150 `.vtp` de visualización
de cuerpo completo en el mismo `model/Geometry/`. Sin ellos falla con
`Attached Geometry file doesn't exist: pelvis.vtp`, y **ese error no
se propaga como excepción de MATLAB** (hay que verificar
explícitamente la existencia del `.sto` de salida, no confiar en la
ausencia de excepción). Comando: `cp COMAK/models/lenhart2015_generic/Geometry/*.vtp COMAK/data/<subject>/model/Geometry/`.

**HOLOA_154, ventana truncada**: COMAK divergía en coordenadas
patelofemorales (`pf_tilt_r`, `pf_rot_r`) durante swing, crash
determinista de LAPACK ("DLASCL parameter number 4") confirmado en
proceso aislado. Se truncó la ventana IK a t≤6.348s (antes de la
escalada real del error, Frame 62/115) en vez de la ventana completa
[5.742, 6.884]s — conserva ~53% del ciclo, converge sin crash. El IK
original completo queda respaldado en
`walking_154_mirror_ik_FULL_backup.mot`.

---

## 6. Nueva extracción de datos (en curso, ver `notes/direct_simulation_status.md`)

La usuaria está extrayendo datos crudos desde una fuente nueva (fuera
de `processed_data` de master) hacia `COMAK/data/<subject>/`, sujeto
por sujeto, en lotes pequeños (5 a la vez) para detectar problemas de
formato temprano antes de escalar a los ~97 pendientes
(`notes/subjects_pending_extraction.md`).

**Completados con éxito**: HOLOA_002 (directo), HOLOA_008 (mirror de
pierna izquierda real), HOLOA_032 (mirror de pierna izquierda real).

**Detenidos por lentitud anormal de COMAK** (no crash, solo
progresión extremadamente lenta — ver diagnóstico del debugger más
abajo): HOLOA_011 (nunca pasó del settle inicial de IK, 87 min
atascado), HOLOA_033 (COMAK detenido en Frame 72/253 tras 3h17min),
HOLOA_037 (COMAK detenido en Frame 91/109 tras 3h49min, sin crash).
Los 3 tienen su staging (modelo escalado, IK cuando aplica) intacto
para retomar.

### Problemas de formato ya encontrados en esta extracción nueva

1. **Convención de nombres inconsistente** (HOLOA_002): el standing
   usaba puntos (`r.should`) correctamente, pero el walking usaba
   espacios (`r should`, `r bar 1`) y guion bajo en el GRF
   (`r_gr_force_vx` en vez de `r.gr_force_vx`). Corregido manualmente
   con backup del original (`*_ORIGINAL_backup.trc/.mot`). Sugiere dos
   herramientas/pasos de exportación distintos para standing vs walking.
2. **Contaminación cruzada de archivos de eventos** (HOLOA_032):
   `Event_sequences_HOLOA_ID_02.emt` (copia exacta de HOLOA_002) se
   coló junto al correcto `_ID_32.emt`. Verificar siempre que el
   Event_sequences usado corresponda al ID correcto antes de derivar
   la ventana temporal.
3. **Duración de standing variable**: HOLOA_032 solo tenía 4.9s de
   standing (vs. ~9-11s habitual) — el `time_range` por defecto "5 7"
   del Scale_Setup cae fuera de rango. Hay que verificar la duración
   real de cada standing antes de generar el XML.
4. **Marcadores mediales ausentes** (hallazgo del debugger, pendiente
   de confirmar si es sistémico de esta extracción o solo de algunos
   sujetos): el marker set de HOLOA_037 no incluye `r.kneem`/`r.mallm`
   (medial de rodilla/tobillo), solo los laterales. El eje de flexión
   de rodilla queda subrestringido mediolateralmente — hipótesis
   principal para el "temblor" en `pf_tilt_r`/`pf_rot_r` que la
   usuaria detectó visualmente en los resultados de IK de ese sujeto.

### Diagnóstico pendiente de acción (debugger, 2026-09-18)

Para los 3 sujetos detenidos por lentitud, el debugger propuso
hipótesis por sujeto (texto completo en el historial de la sesión,
resumen aquí):
- **HOLOA_011**: el settle atascado es un barrido sintético de
  `knee_flex_r` 0→100° (`sweep_time=3.0`s), independiente de la
  ventana de marcha — "Time=0.03" reportado es ~1° de flexión, casi
  extensión completa. Las coordenadas que divergen (`pf_tilt_r`,
  `pf_flex_r`) tienen `SpringGeneralizedForce` con `stiffness=0` (solo
  damping) en el modelo — mismo punto de fragilidad que causó los
  crashes de HOLOA_154/165 en el rollout de espejo.
- **HOLOA_033**: IK limpio (confirmado numéricamente contra un sujeto
  exitoso de referencia), pero COMAK nunca converge desde el Frame 1
  — patrón estructural, no un frame difícil aislado. Hipótesis
  principal: carga de contacto (GRF/BW≈1.13x, algo bajo) generando
  ambigüedad en el reparto músculo/contacto del optimizador.
- **HOLOA_037**: cuantitativamente confirmado que el "temblor" que
  reportó la usuaria está concentrado en `pf_tilt_r`/`pf_rot_r`
  (deltas 1.5-2.6x mayores que la referencia), no en el resto del
  cuerpo — coherente con la hipótesis de marcadores mediales ausentes.
  COMAK sí avanzó bastante (83%) con fallos recuperables, similar en
  tipo (no en volumen) al patrón ya tolerado de STRATO_001_mirror.

**Próximo paso sugerido**: confirmar si la ausencia de marcadores
mediales es sistémica de todos los sujetos de la extracción nueva
(afectaría a los ~97 pendientes) antes de escalar la extracción en
bloque.

---

## 7. Sistema multi-agente (Claude Code)

Cuatro roles especializados (`.claude/agents/`, invocados vía Task tool):

| Rol | Qué hace | Qué NO hace |
|---|---|---|
| **orchestrator** | Planifica tareas en pasos atómicos | Ejecutar, modificar, diagnosticar |
| **executor** | Ejecuta comandos (MATLAB, bash) y reporta | Diagnosticar, decidir, modificar código |
| **code-writer** | Aplica cambios mínimos según plan validado | Planificar, ejecutar, improvisar |
| **debugger** | Diagnostica con hipótesis + plan de verificación; solo Read/Glob/Grep | Arreglar, ejecutar comandos |

Patrón operativo validado en esta fase: para pipelines largos (IK/
COMAK pueden tardar 15min-3h+), lanzar el executor en background y
pedirle explícitamente que encadene llamadas bloqueantes dentro de su
propio turno en vez de devolver el control prematuramente — de lo
contrario el sistema de notificaciones dispara antes de que el
proceso realmente termine.

**Verificación de PID antes de matar procesos**: cuando hay que
detener una corrida colgada, confirmar el PID exacto vía
`Get-CimInstance Win32_Process ... | Select CommandLine` antes de
`taskkill`, especialmente si hay múltiples corridas MATLAB en
paralelo — evita matar el proceso equivocado.

---

## 8. Git (reorganizado 2026-09-18)

Repo privado. 9 commits nuevos organizados por tema (gitignore/
untracking, pipeline core + side='l', geometría L, validation/,
logs de debugging, agentes, notes, tooling) — ver `git log` para el
detalle. Rama `visualization_python`, **pendiente de `git push`** al
cierre de esta sesión (confirmar con la usuaria antes de empujar).

Limpieza hecha: eliminados archivos basura en la raíz (`npm`, `node`
vacíos, script mal nombrado, modelo bilateral suelto, 2 logs con
nombre de archivo corrupto por un path de Windows mal escapado).

`COMAK/python/model_two_legs.osim` (borrado) y
`model_two_legs_fixed.osim` (modificado) siguen sin comittear — son
del experimento bilateral previo, explícitamente fuera de alcance
("no tocar sin más contexto", heredado de V3). `archive/` y
`COMAK/python/Geometry/` (duplicado del genérico) también quedan
fuera de git, sin decisión explícita tomada sobre ellos — bajo riesgo,
no bloquean nada.

---

## 9. Próximos pasos sugeridos

1. Confirmar con la usuaria si hacer `git push` de los 9 commits (+ 6
   que ya estaban ahead desde antes).
2. Decidir cómo proceder con HOLOA_011/033/037 (reintentar con más
   paciencia vs. investigar más a fondo la causa de lentitud) usando
   el diagnóstico del debugger de la sección 6.
3. Confirmar si la ausencia de marcadores mediales (r.kneem/r.mallm)
   es sistémica de la extracción nueva antes de escalar a más sujetos.
4. Seguir con el lote piloto de 5 sujetos de la nueva extracción
   (van 5 de 5: 002, 008, 011, 032, 033, 037 — en realidad ya son 6,
   confirmar con la usuaria si el piloto se da por completo o si
   sigue agregando sujetos antes de decidir extraer los ~97 en bloque).

---

*Fin del handoff V4.*
