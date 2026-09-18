# Estado de simulaciones directas (sin espejo)

Sujetos donde la pierna afectada (OA Side) coincide con la pierna que
tiene datos de marcha limpios disponibles — no requieren espejo_trc/espejo_grf,
se corre el pipeline estándar `side='r'` (o `side='l'` si se resuelve esa vía
en el futuro) directamente sobre los datos reales de la pierna afectada.

Ver notes/subjects_pending_extraction.md para la lista completa de 97 sujetos
sin simular. La mayoría requiere extracción de datos crudos primero (fuera de
processed_data de master); HOLOA_011 es la única excepción conocida (datos ya
disponibles, solo nunca se corrió el pipeline).

Validación mínima por paso (igual que notes/mirror_rollout_status.md):
- IK: .mot existe y bytes > 0 (no confiar en mensaje de consola).
- COMAK: _states.sto existe, > 10KB, duración de ejecución > 60s.
- Joint Mechanics: _ForceReporter_forces.sto existe, > 1KB (verificar
  explícitamente — JointMechanicsTool puede fallar sin lanzar excepción MATLAB).

| Sujeto | OA Side | Modelo ya escalado | Ventana (evento usado) | IK | COMAK | Joint Mechanics | Estado | Última actualización | Notas |
|---|---|---|---|---|---|---|---|---|---|
| HOLOA_002 | R | Sí (Scale corrido en esta sesión, RMS=39.1mm, max=88.2mm en r.bar1) | eRHS(1)=7.010, eRHS(2)=8.208 | OK (271429 bytes, settle convergió en 2.14s, sin cuelgue) | OK (240763 bytes, ~22min, "Converged! 3 iteraciones", sin crash LAPACK; bad frames puntuales en 7.552-7.892s, normal) | OK (1847480 bytes, ~1min) | DONE | 2026-09-17 | Primer sujeto exitoso de la nueva extracción directa. Convención de nombres del walking (espacios/guion bajo) distinta al standing (puntos) — corregida manualmente (backup en W11_HOLOA_ID_002_ORIGINAL_backup.trc/.mot). GRF solo tiene datos de pierna derecha (sin FP2/calcn_l). Pendiente: revisar si el extractor de la usuaria produce la misma convención inconsistente en los próximos 5 sujetos |
| HOLOA_033 | R | OK (RMS=20.7mm, max=48.4mm en r.bar1) | eRHS(1)=4.614, eRHS(2)=5.624 | OK (229035 bytes, 253 frames en 3s) | DETENIDA POR USUARIA — COMAK llevaba 3h17min atascado en Frame 70/253 (24+ iteraciones sin avanzar), vs. 15-25min típico. Procesos MATLAB matados (PID 26948/4244) | — | STOPPED | 2026-09-17 | No se diagnosticó la causa del atasco — pendiente retomar más adelante. Staging (incl. modelo escalado e IK) queda intacto para reintentar solo COMAK |
| HOLOA_037 | R | OK (RMS=22.1mm, max=45.0mm en r.bar1) | eRHS(1)=7.472, eRHS(2)=8.558 | OK (247075 bytes, 273 frames en 2s, sin estancamiento) | DETENIDA POR USUARIA en Frame 91/109 (83%, ~3h49min) — sin crash LAPACK, solo lenta (muchos "Maximum iterations exceeded" recuperables por frame). Procesos MATLAB matados (PID 34188/21316) | — | STOPPED | 2026-09-17 | Llegó mucho más lejos que HOLOA_033 (28%) antes de detenerse — pendiente retomar. Staging (modelo escalado e IK) queda intacto para reintentar solo COMAK |
| HOLOA_011 | R | Sí (model_HOLOA_11.osim, scale_factors≠1) | eRHS(1)=5.084, eRHS(2)=6.048 | DETENIDA POR USUARIA — settle de IK llevaba 87 min sin terminar (vs. 80-400s normal en otros sujetos), proceso MATLAB.exe matado manualmente (PID 27564/9840). Se quedó atascado en Time=0.03 de la settling simulation, con deltas grandes en pf_tilt_r (11.03) y pf_flex_r (2.99) sin progresar | — | | STOPPED | 2026-09-16 | No se diagnosticó la causa del cuelgue — pendiente retomar más adelante si hace falta. Staging (model/Geometry/standing/walking/external_loads.xml) queda intacto en COMAK/data/HOLOA_011/ para cuando se retome |
