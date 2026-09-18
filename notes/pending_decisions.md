# Decisiones pendientes

- [ ] Crear validation/check_outputs.py (validador post-pipeline)
- [ ] Resolver dónde se guardan los resultados: ¿dejarlos en UPF_COMAK-master\COMAK\results\ o moverlos al workspace local? 
  - Argumento a favor de moverlos: master debería estar 100% intocable, ni siquiera para output
  - Argumento en contra: requiere modificar el script MATLAB o copiar post-ejecución
- [ ] Confirmar lista de sujetos disponibles
- [ ] Decidir: ¿borrar lenhart2015_reserve_actuators.xml (sin sufijo)?
      Usa nomenclatura vieja incompatible con el modelo bilateral actual.
      No está referenciado en código activo, pero es una mina latente
      si algún script futuro lo invoca por error.
- [ ] Limpieza: lenhart2015_reserve_actuators.xml en models/lenhart2015_generic/
      no se usa por ningún script ni por los .osim. Workspace y master
      tienen tamaños distintos. Decidir si borrarlo o sincronizar a master.
- [ ] run_ik.m: el try/catch traga la excepción del COMAKInverseKinematicsTool
      y reporta "IK completado" en 1.2 s aunque haya fallado. Esto es el
      patrón "silent failure" ya documentado para COMAK. Hay que aplicar
      el mismo fix: rethrow + assert de output. Trabajo del code-writer
      después de validar el pipeline E2E.

- [ ] **Fix post-regeneración `lenhart2015_left.osim`**: si se re-genera el modelo con
      `extract_left_model.py`, el `attached_geometry` del body `tibia_proximal_l`
      queda con `lenhart2015-R-tibia-cartilage.stl` (bug del script de extracción).
      Hay que corregir manualmente a `lenhart2015-L-tibia-cartilage.stl` en línea ~807.
      La API OpenSim no expone `attached_geometry` por nombre desde Python, así que
      es edición directa del XML hasta que eso cambie.

- [ ] preparar_modelo_bilateral.m: actualmente genera el modelo en
      results/<sujeto>/ pero no replica el directorio Geometry/ necesario
      para OpenSim/JAM. Fix: que la función cree la junction
      (o copie los STLs) automáticamente, así no hay que hacerlo manual
      por cada sujeto. Trabajo del code-writer.

## Auditoría estática side='l' — Paso C (2026-07-03)

Auditoría de main_comak_workflow_function.m y callees para soporte de
side='l'. Solo lectura, sin ejecución. Bugs críticos que bloquean 'l':

- [ ] **BLOCKER**: HOLOA_040/model/ tiene 3 archivos .osim
      (model_HOLOA_040.osim, model_two_legs_HOLOA_040.osim,
      model_HOLOA_040_left.osim). main_comak_workflow_function.m
      L103-105 y L167-168 usa dir('*.osim') asumiendo un único archivo
      (bug histórico ya conocido: "dir(*.osim) con múltiples archivos
      concatena nombres"). Bloquea el pipeline incluso para side='r'
      con estos datos. Hay que decidir explícitamente qué .osim
      corresponde a cada side antes de tocar código.
- [ ] main_comak_workflow_function.m L94-95: time_start/time_stop
      siempre usan hs_data.eRHS, ignorando side. Con side='l' la
      ventana temporal de IK/COMAK queda mal anclada (debería usar
      eLHS). eLHS/eLTO sí existen y son válidos en
      Event_Sequences_HOLOA_ID_40.emt, así que no es blocker de datos,
      solo falta el branch en código.
- [ ] main_comak_workflow_function.m L150: la llamada a run_ik no pasa
      el argumento side, así que run_ik siempre usa su default interno
      'r' aunque main reciba side='l' → inconsistencia IK↔COMAK.
- [ ] preparar_modelo_bilateral() y espejo_cinematica() manejan side
      correctamente pero nunca se invocan desde el workflow de
      producción (solo desde test_bilateral_comak.m). Falta decidir
      si/cómo integrarlos en main_comak_workflow_function.m.
- [ ] ~19 archivos de visualización/reportes (plot_kinematics.m,
      plot_activations.m, plot_primary_coordinates_vs_mocap.m,
      generateMeanReport.m, create_report.m, etc.) tienen hardcoding
      sistémico a sufijo _r. No auditados línea por línea todavía;
      es la superficie de cambio más grande fuera del pipeline
      núcleo IK/COMAK/JM.
- [ ] run_comak.m configurar_muscle_weights() (L153-184) tiene lista
      de músculos hardcoded a _r, pero la rama está dormida
      (custom_muscle_weights=false hoy). Riesgo de regresión silenciosa
      si alguien la activa con side='l' sin adaptarla antes.
- [ ] run_ik.m: confirmado que el try/catch silencioso en L22 sigue
      ahí (ver entrada anterior de este mismo archivo). No se toca en
      este paso, ya está trackeado arriba.

## Pipeline de espejo STRATO_001 — COMAK Bad Frames (2026-09-14)

- [ ] **Revisar frames 94, 95, 110, 112, 117, 130** de la corrida COMAK
      `COMAK/results/STRATO_001_mirror/comak/` (side='r', ventana IK
      t=[4.848, 5.944]s, 275 frames). El propio `Convergence Summary`
      de COMAKTool los marcó como "Bad Frames" (udot error 1.2-2.34),
      coincidiendo con 15 fallos puntuales de IPOPT en todo el log
      (6 "Maximum Number of Iterations Exceeded" + 9 "Restoration
      Failed!") — ninguno abortó la corrida, COMAK continuó al
      siguiente timestep en cada caso.
      Corresponden aprox. al 36-68% del ciclo de marcha normalizado
      (t≈5.238-5.598s), justo en la transición de apoyo a despegue del
      pie de interés (el apoyo real terminaba en t=5.476s según los
      datos de GRF).
      Confirmado visualmente en `graphics/kinematics/`: las curvas de
      ROTACIÓN (flexión/aducción/rotación tibiofemoral y patelofemoral)
      se ven suaves y fisiológicamente razonables, pero las curvas de
      TRASLACIÓN (`knee_tx_r`, `knee_ty_r`, `pf_ty_r`, `pf_tz_r`)
      muestran quiebres/zigzags pequeños pero reales justo en esa
      ventana (55-60% del ciclo) — no es solo ruido del solver que se
      autocorrigió sin dejar rastro.
      Decisión (2026-09-14): se avanzó a Joint Mechanics de todas
      formas, dejando esto anotado para volver a revisarlo si los
      resultados de contacto (presión/área) muestran algo anómalo en
      esa misma ventana temporal.

## ScaleTool en el rollout de espejo — 3 fixes descubiertos (2026-09-14)

Al escalar los 12 sujetos nuevos del rollout de espejo (notes/mirror_rollout_status.md),
`ScaleTool` falló de forma idéntica y sistemática en los 12. Diagnosticado por el
debugger, comparando contra los logs previos exitosos de STRATO_001/HOLOA_040
(`stdout_scale_strato_mirror.log` etc., en la raíz del workspace):

1. **No pasar la ruta absoluta del XML al constructor de `ScaleTool`.** Si se hace
   `ScaleTool('D:/.../Scale_Setup_X_mirror.xml')` con ruta absoluta, OpenSim antepone
   el directorio del XML a `<model_file>` aunque ese campo YA sea absoluto, produciendo
   una ruta anidada inexistente (`.../model/D:/.../lenhart2015.osim`) y fallando con
   "ScaleTool: No model specified." Fix: hacer `cd()` al directorio que contiene el
   XML y pasar solo el nombre de archivo relativo al constructor.
2. **`<marker_set_file>` debe ser ruta absoluta**, no relativa (`markers.xml`). Con el
   patrón `cd()` + nombre relativo del fix #1, las rutas relativas dentro del XML
   resuelven contra el nuevo CWD (el directorio del sujeto), no contra el directorio
   del modelo genérico donde vive `markers.xml` — así que hay que apuntarlo absoluto
   a `COMAK/models/lenhart2015_generic/markers.xml`.
3. **`<MarkerPlacer><apply>` viene en `false` en la plantilla genérica**
   (`COMAK/models/lenhart2015_generic/Scale_setup_003.xml`), pero debe ser `true`
   (así está en el XML de STRATO_001 que sí completó el pipeline). Con `apply=false`,
   ScaleTool corre el `ModelScaler` (genera `..._mirror_scaled.osim`) pero nunca corre
   el `MarkerPlacer`, así que nunca se genera `..._mirror.osim` (el modelo final que
   usan IK/COMAK) — y no lanza ningún error, simplemente se detiene ahí silenciosamente.

Los 3 fixes ya están aplicados en los 12 `Scale_Setup_<sujeto>_mirror.xml` del rollout
actual. Si se genera un `Scale_Setup_*_mirror.xml` nuevo para un sujeto futuro
(copiando la plantilla genérica), aplicar los 3 fixes de nuevo — la plantilla en sí
NO se corrigió (para no modificar un archivo compartido sin aprobación explícita).

RMS marker error de referencia tras el fix: HOLOA_144 = 37.6mm (max 88.7mm en
l.should), más alto que STRATO_001 (~20mm) pero se dejó pasar. Vigilar si algún
sujeto del lote sale notablemente más alto (podría indicar problema real de
marcadores, no solo del fix de Scale).

- [ ] **Paraview no es opcional en el workflow de producción**: la
      usuaria pidió que la visualización Paraview (`runParaviewVisualization.m`)
      sea un paso opcional "según la simulación", pero está cableada de
      forma incondicional (dentro de un try/catch, sin flag) en
      `main_comak_workflow_function.m` (L272) y `PLOT_EVERYTHING_RESULTS.m`
      (L47). Si se corre el workflow de producción completo para un
      sujeto, Paraview se dispara siempre, con el riesgo de que intente
      descargar ffmpeg de internet si el ffmpeg local
      (`COMAK/matlab_scripts/ffmpeg/ffmpeg-8.0.1-essentials_build/bin/`)
      no está en el PATH de esa sesión. Hacerlo verdaderamente opcional
      requeriría añadir un flag/parámetro a esos dos scripts — no se
      tocó porque implica editar código de producción sin aprobación
      explícita. Por ahora, la forma de mantenerlo "opcional" es seguir
      invocando `plot_joint_mechanics_extended`/`runParaviewVisualization`
      sueltas por fuera del workflow, como se hizo el 2026-09-14 para
      STRATO_001_mirror.