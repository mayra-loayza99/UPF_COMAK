# Subject staging — pasos manuales pendientes de automatizar

## Geometry/ en data/<subject>/model/

Descubrimiento (2026-07-29): HOLOA_040 en master
(`UPF_COMAK-master/COMAK/processed_data/HOLOA_040/`) NO tiene
carpeta `Geometry/` poblada, a diferencia del resto de sujetos
HOLOA en master, que sí la tienen. Causa desconocida, ver
pending_decisions.md.

Los STLs de contacto (14 archivos: bone y cartilage para femur,
tibia, fibula, patella, ambos lados L y R) se copiaron
manualmente desde:
  `UPF_COMAK-master/COMAK/data/HOLOA_040/model/Geometry/`
hacia:
  `UPF_COMAK/COMAK/data/HOLOA_040/model/Geometry/`

Sin esta copia, IK/COMAK/JM fallan en
`Smith2018ContactMesh::findMeshFile()` al no localizar los STLs
(OpenSim los busca relativos al `.osim`, en `Geometry/` adyacente).

## Acción para futuros sujetos

Al stagear un sujeto nuevo desde master, verificar antes de correr
el pipeline:
  `ls COMAK/data/<subject>/model/Geometry/lenhart2015-*-{bone,cartilage}.stl | wc -l`
Debe devolver 14. Si es menor, buscar los STLs en:
  1. `UPF_COMAK-master/COMAK/data/<subject>/model/Geometry/`
  2. Si no están ahí, otro sujeto del mismo proyecto puede servir
     de fuente (los STLs son iguales entre sujetos hasta scaling,
     y ScaleTool no reescribe STLs, solo añade scale_factors al
     `.osim`).

## Geometría de cuerpo completo (VTP) requerida para Joint Mechanics (2026-09-15)

Descubrimiento durante el rollout de espejo (notes/mirror_rollout_status.md):
las 7 STL de contacto (femur/tibia/fibula/patella lado R) son suficientes
para Scale/IK/COMAK, pero **`JointMechanicsTool` necesita además los ~150
archivos `.vtp` de visualización de cuerpo completo** (pelvis, columna,
manos, cráneo, fémur/tibia/patella del lado L, etc.) en el mismo directorio
`model/Geometry/`. Sin ellos, JM falla con
`Attached Geometry file doesn't exist: pelvis.vtp` — **y ese error NO se
propaga como excepción de MATLAB** (`JointMechanicsTool::run()` lo captura
internamente, lo loguea como `[error]` y retorna sin lanzar), así que un
`try/catch` alrededor de `run_joint_mechanics()` no lo detecta. Hay que
verificar explícitamente la existencia de
`<jnt_mech_result_dir>/<results_basename>_ForceReporter_forces.sto` después
de cada corrida, no confiar en la ausencia de excepción.

Acción para futuros sujetos, antes de correr Joint Mechanics:
  `cp COMAK/models/lenhart2015_generic/Geometry/*.vtp COMAK/data/<subject>/model/Geometry/`
(no sobrescribe las STL existentes, mismo formato). Verificar
`ls COMAK/data/<subject>/model/Geometry/ | wc -l` → debe dar 157
(mismo conteo que `COMAK/data/STRATO_001/model/Geometry/`, el único
precedente que corrió Joint Mechanics con éxito antes de este descubrimiento).

## Correción (2026-07-29 tarde)

Descubrimiento: los STLs del lado L en master/data/HOLOA_040 y
workspace/data/HOLOA_040 son idénticos entre sí pero están mal
orientados respecto al `.osim` (huesos del fémur/tibia L girados
en visualización, causa del cuelgue de IK en 40 min sin
convergencia).

Los STLs L del genérico (`COMAK/models/lenhart2015_generic/Geometry/`)
sí están correctamente orientados.

Los STLs R son idénticos entre las tres ubicaciones (master/data,
workspace/data, genérico), no requieren acción.

### Convención correcta para futuros sujetos con `side='l'`

Los 7 STLs L (`lenhart2015-L-{femur,tibia,fibula,patella}-{bone,cartilage}.stl`,
contando patella con bone+cartilage y fibula solo bone = 7)
deben copiarse de:
   `COMAK/models/lenhart2015_generic/Geometry/`
NO de:
   `master/COMAK/data/<subject>/model/Geometry/`

Los STLs R se pueden copiar de cualquiera de las dos fuentes
(son idénticos).

### Backup del intento anterior
Los 7 STLs L incorrectos que estaban en workspace/data hasta
2026-07-29 tarde se preservaron en:
   `archive/geometry_backup_20260729/`
para posibles investigaciones futuras sobre su origen.

## Configuración de prueba mínima (2026-07-29 tarde)

Tras 3 corridas de IK colgadas para HOLOA_040 side='l' (una por
STLs mal orientados, dos por mismatch de scaling entre .osim
escalado y mallas), se pivotó a validar el pipeline con
configuración mínima:

- `data/HOLOA_040/model/model_HOLOA_040_left.osim` fue sobrescrito
  con `models/lenhart2015_generic/lenhart2015_left.osim` (modelo
  genérico sin escalar).
- El `_left.osim` escalado original (Paso B) se preservó en
  `archive/model_backup_20260729/model_HOLOA_040_left_scaledInGUI.osim`.
- Las mallas L en `Geometry/` son las del genérico (reemplazadas
  en la corrección de esta mañana).

Objetivo: demostrar que el pipeline `side='l'` completa
end-to-end. Los resultados NO son biomecánicamente válidos porque
el modelo no está escalado al sujeto.

Para restaurar la configuración de análisis real:
```
cp -p archive/model_backup_20260729/model_HOLOA_040_left_scaledInGUI.osim COMAK/data/HOLOA_040/model/model_HOLOA_040_left.osim
```
Y decidir qué hacer con las mallas L (siguen sin coincidir con
el escalado del modelo).

## Restauración a configuración escalada original (2026-07-29 tarde-noche)

Tras validar que el pipeline no completa con configuración mínima
(`.osim` genérico + mallas genéricas → IK produce anatomía imposible,
huesos solapándose en GUI), se restauró la configuración escalada
original desde backups:

- `data/HOLOA_040/model/model_HOLOA_040_left.osim` ← restaurado
  desde `archive/model_backup_20260729/model_HOLOA_040_left_scaledInGUI.osim`
  (Paso B escalado en GUI).
- `data/HOLOA_040/model/Geometry/lenhart2015-L-*.stl` (7 archivos)
  ← restaurados desde `archive/geometry_backup_20260729/`
  (mallas de master/data que se ven giradas en GUI).

Esta es la misma configuración con la que arrancamos hace 2 días:
IK batch se cuelga en Time 0.26. Próximo paso: probar en OpenSim
GUI para ver qué está pasando visualmente durante IK (la caja
negra del batch nos ha estado escondiendo información).
