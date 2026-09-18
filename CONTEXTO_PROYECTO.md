# Contexto del proyecto UPF_COMAK

**Investigadora:** Mayra Loayza (mayraalejandra.loayza@upf.edu)  
**Directorio raíz:** `D:\mayra\Descargas\UPF_COMAK`  
**Rama activa:** `visualization_python`

---

## Objetivo

Simular la biomecánica de rodilla (tibiofemoral + patelofemoral) durante la marcha usando **OpenSim + JAM (COMAK)** desde MATLAB. El workflow es bilateral: se analiza una pierna a la vez (izquierda o derecha) usando el modelo con dos piernas, deshabilitando los contactos y músculos de la pierna contralateral.

---

## Modelo OpenSim

**Modelo genérico:** `COMAK/models/lenhart2015_generic/lenhart2015.osim`  
- Base: Arnold 2011 full-body + rodilla 6-DOF Lenhart 2015.
- Tipo de músculos: `Millard2012EquilibriumMuscle`
- Contactos: `Smith2018ArticularContactForce` (plugin JAM/osimJAM)
- Ligamentos: `Blankevoort1991Ligament`

**Modelo bilateral** (con contactos en ambas piernas):  
`COMAK/python/model_two_legs_fixed.osim` → escalado por sujeto con:
```
python COMAK/python/tools/scale_two_legs_from_existing.py --subject HOLOA_040 --processed_dir ...
```
Genera: `<sujeto>/model/model_two_legs_<ID>.osim`

### Convención de nombres en el modelo bilateral

| Componente | Pierna derecha | Pierna izquierda |
|---|---|---|
| Músculos | `addbrev_r`, `gaslat_r`, … | `addbrev_l`, `gaslat_l`, … |
| Contacto TF | `tf_contact` (sin sufijo) | `tf_contact_l` |
| Contacto PF | `pf_contact` (sin sufijo) | `pf_contact_l` |
| Ligamentos | `MCLd1`, `ACLpl1`, … (sin sufijo) | `MCLd1_l`, `ACLpl1_l`, … |
| Coords secundarias TF | `knee_add_r`, `knee_rot_r`, `knee_tx/ty/tz_r` | idem con `_l` |
| Coords secundarias PF | `pf_flex/rot/tilt/tx/ty/tz_r` | idem con `_l` |

### Coordenadas del modelo

- **Pelvis:** 6 DOF (`pelvis_tx/ty/tz`, `pelvis_tilt/list/rot`)
- **Cadera:** `hip_flex/add/rot_r/l` (primarias)
- **Rodilla primaria:** `knee_flex_r/l`
- **Rodilla secundaria TF:** `knee_add/rot/tx/ty/tz_r/l` (optimizadas por COMAK)
- **Rótula secundaria PF:** `pf_flex/rot/tilt/tx/ty/tz_r/l` (optimizadas por COMAK)
- **Tobillo:** `ankle_flex_r/l` (primaria), `subt_angle_r/l`, `mtp_angle_r/l` (prescritas)
- **Tronco/cuello:** `lumbar_ext/latbend/rot`, `neck_ext/latbend/rot` (prescritas)
- **Brazos:** bilaterales (prescritas)

### Simetría del modelo `model_two_legs_10_06_2026.osim`
Verificada: 12 bodies, 12 joints, 14 DOF, 44 músculos y 1 constraint por lado. Simetría perfecta.

---

## Workflow MATLAB (pipeline de 3 pasos)

### Scripts principales en `COMAK/matlab_scripts/`

| Script | Función |
|---|---|
| `test_bilateral_comak.m` | Entry point — configura sujeto y ejecuta el pipeline completo |
| `run_ik.m` | Paso 1: Cinemática inversa (COMAKInverseKinematicsTool) |
| `run_comak.m` | Paso 2: Optimización COMAK |
| `configurar_comak_base.m` | Configura el COMAKTool (coordenadas, actuadores, optimizador) |
| `run_joint_mechanics.m` | Paso 3: Análisis de mecánica articular |
| `preparar_modelo_bilateral.m` | **NUEVO** — Deshabilita fuerzas contralaterales en el modelo |
| `espejo_cinematica.m` | **NUEVO** — Copia cinemática ipsilateral a columnas contralaterales en el .mot |

### Flujo completo (nuevo workflow bilateral)

```
1. Encontrar model_two_legs_<ID>.osim  (bilateral, con tf_contact + tf_contact_l)
2. preparar_modelo_bilateral(model, SIDE, result_root)
   → Deshabilita contactos + músculos + ligamentos contralaterales
   → Guarda <basename>_<side>_prepared.osim
3. run_ik(prepared_model, ...)
   → Genera walking_XXX_ik.mot
4. espejo_cinematica(ik_dir, results_base, SIDE)
   → Copia hip/knee/ankle ipsilateral → columnas contralaterales
   → Guarda walking_XXX_ik_mirror.mot
5. run_comak(prepared_model, ...)
   → configurar_comak_base detecta automáticamente *_ik_mirror.mot
   → Usa lenhart2015_reserve_actuators_r.xml o _l.xml según SIDE
6. run_joint_mechanics(prepared_model, ...)
```

---

## Configuración COMAK

### Coordenadas prescritas vs primarias vs secundarias

**Cuando `SIDE='r'` (análisis pierna derecha):**
- **Prescritas:** Pelvis(6) + subt/mtp ambos pies(4) + torso/cuello(6) + brazos(12) + cadera_l/rodilla_l/tobillo_l(5) + TF_l secundarias(5) + PF_l secundarias(6) = 44 total
- **Primarias:** `hip_flex/add/rot_r`, `knee_flex_r`, `ankle_flex_r` (5)
- **Secundarias COMAK:** TF_r(5) + PF_r(6) = 11

**Cuando `SIDE='l'` (análisis pierna izquierda):** — simétrico

### Reserve actuators (ficheros por lado)

| Fichero | Uso |
|---|---|
| `COMAK/data/lenhart2015_reserve_actuators_r.xml` | Simulación pierna derecha (TF/PF secondary de derecha; sin TF/PF secondary de izquierda) |
| `COMAK/data/lenhart2015_reserve_actuators_l.xml` | Simulación pierna izquierda (TF/PF secondary de izquierda; sin TF/PF secondary de derecha) |
| `COMAK/data/lenhart2015_reserve_actuators.xml` | Original bilateral (ambos lados — no se usa en el nuevo workflow) |

`configurar_comak_base.m` selecciona automáticamente el fichero correcto según `side`.

### Pesos musculares custom (run_comak.m)

```matlab
gasmed_r/l = 4,  gaslat_r/l = 7,  soleus_r/l = 0.9,  recfem_r/l = 3
glmed1-3_r/l = 0.9,  glmin1-3_r/l = 0.9
bflh/bfsh/semiten/semimem_r/l = 2
```

---

## Plugin JAM

- DLL: `D:\mayra\Descargas\UPF_COMAK\bin\osimJAM.dll`
- Se carga con `Model.LoadOpenSimLibrary(jam_plugin)` al inicio de cada sesión MATLAB
- Registra tipos: `Smith2018ArticularContactForce`, `Blankevoort1991Ligament`, `COMAKTool`, `COMAKInverseKinematicsTool`, etc.
- javaclasspath.txt → `sdk/Java/org-opensim-modeling.jar`
- javalibrarypath.txt → `bin/`

---

## Datos por sujeto

**Directorio:** `COMAK/processed_data/<HOLOA_XXX>` o `<STRATO_XXX>/`

```
<sujeto>/
  model/
    model_<ID>.osim              ← modelo escalado single-leg (con contactos derecha)
    model_two_legs_<ID>.osim     ← modelo bilateral escalado (NUEVO workflow)
  walking/
    *.trc                        ← marcadores motion capture
    *.mot                        ← GRF (ground reaction forces)
    *Event*                      ← tiempos de heel-strike (eRHS, eLHS)
    *loads.xml                   ← fuerzas externas (generado por createExternalLoadsXML)
```

**Resultados** en `COMAK/results/<PROJECT>_<ID>/`:
```
comak_inverse_kinematics/
  walking_XXX_ik.mot              ← cinemática IK
  walking_XXX_ik_mirror.mot       ← cinemática con contralateral espejada (NUEVO)
  ik_constrained_model.osim
comak/
  walking_XXX_states.sto          ← activaciones musculares + cinemática COMAK
joint_mechanics/
  walking_XXX_ContactForceReporter_*.sto
  *.vtp (ParaView)
```

---

## Archivos clave nuevos/modificados

| Archivo | Cambio |
|---|---|
| `COMAK/matlab_scripts/preparar_modelo_bilateral.m` | NUEVO — deshabilita fuerzas contralaterales |
| `COMAK/matlab_scripts/espejo_cinematica.m` | NUEVO — espeja cinemática ipsilateral a contralateral |
| `COMAK/data/lenhart2015_reserve_actuators_r.xml` | NUEVO — actuadores para simulación pierna derecha |
| `COMAK/data/lenhart2015_reserve_actuators_l.xml` | NUEVO — actuadores para simulación pierna izquierda |
| `COMAK/matlab_scripts/configurar_comak_base.m` | Modificado — selección automática de actuadores y detección de _ik_mirror.mot |
| `COMAK/matlab_scripts/test_bilateral_comak.m` | Modificado — busca modelo bilateral, llama preparar_modelo_bilateral y espejo_cinematica |

---

## Parámetros importantes del optimizador COMAK

```
time_step: 0.01 s
lowpass_filter: 6 Hz
settle_threshold: 1e-2
ipopt_convergence_tolerance: 1e-4
ipopt_constraint_tolerance: 1e-4
activation_exponent: 2 (mínimo cuadrado de activaciones)
non_muscle_actuator_weight: 1000
contact_energy_weight: 0–1000 (configurable, default 0 en test)
max_iterations: 25
```

---

## Tareas pendientes / próximos pasos

- Verificar que `preparar_modelo_bilateral` funciona con el plugin JAM cargado (los tipos `Smith2018ArticularContactForce` y `Blankevoort1991Ligament` deben estar registrados antes de llamar `getConcreteClassName()`)
- Validar que `espejo_cinematica` produce un .mot compatible con la versión de OpenSim del proyecto
- Comprobar que `run_joint_mechanics` reporta sólo los contactos de la pierna analizada (con el modelo prepared, los contactos contralaterales están deshabilitados)
- Posible extensión: añadir flag para desactivar el espejo de cinemática (`USE_MIRROR_IK = true/false`) en `test_bilateral_comak.m`
