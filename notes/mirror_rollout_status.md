# Estado del rollout COMAK de espejo (pierna izquierda vía mirroring)

Sujetos con OA Side='L' y Simulated Side='R' en subject_comak_status.xlsx.
Método: mirror de TRC+GRF (espejo_trc/espejo_grf) + pipeline estándar side='r'.
Ver notes/pending_decisions.md ("Pipeline de espejo STRATO_001") para el precedente.

Proceso manual, un sujeto a la vez: espejo → PAUSA (inspección visual de
marcadores en GUI OpenSim por la usuaria) → Scale → IK → COMAK → Joint Mechanics.
Validación mínima por paso (validation/check_outputs.py no existe todavía):
- Espejo: número par de nombres/columnas r./l. intercambiados, sin error.
- Scale: .osim de salida existe, log sin [error], RMS marker error razonable.
- IK: .mot de salida existe y bytes > 0 (run_ik.m traga excepciones — no confiar en el mensaje de consola).
- COMAK: _states.sto existe, > 10KB, duración de ejecución > 60s.
- Joint Mechanics: _ForceReporter_forces.sto existe, > 1KB.

Valores por celda: PENDING / OK / FAIL / BLOCKED / N-A

| Sujeto | Espejo (TRC/GRF) | Inspección GUI (usuaria) | Scale | IK | COMAK | Bad frames COMAK | Joint Mechanics | Estado | Última actualización | Notas |
|---|---|---|---|---|---|---|---|---|---|---|
| STRATO_001 | OK | N-A (retrospectiva) | OK | OK | OK (2 reintentos) | 94,95,110,112,117,130 (36-68% ciclo) | OK | DONE | 2026-09-14 | Piloto/referencia del método |
| HOLOA_040 | — | FAIL | — | — | — | — | — | EXCLUDED | 2026-09-14 | Marcadores lado izquierdo mal orientados (inspección visual GUI de la usuaria) — no forma parte del lote |
| HOLOA_144 | OK (20/16 nombres intercambiados, par) | OK | OK (RMS=37.6mm, max=88.7mm en l.should — más alto que referencia STRATO_001 ~20mm, vigilar) | OK (235349 bytes, 335.0s) | OK (211254 bytes, 1335.4s; BadFrame=1, MaxIter=1, RestFail=18) | | OK (1865872 bytes, 30.4s) | DONE | 2026-09-14 | Primer sujeto del lote. 3 fixes de ScaleTool descubiertos aquí (ver notes/pending_decisions.md) |
| HOLOA_026 | OK (20/16, par) | OK | OK (RMS=49.0mm, max=121.0mm en r.should) | OK (248879 bytes, 199.8s) | OK (223644 bytes, 1431.2s; BadFrame=1, MaxIter=6, RestFail=15) | | OK (1865601 bytes, 31.6s) | DONE | 2026-09-14 | Usuaria confirmó tras revisión GUI: hombros mal colocados pero no participan en MeasurementSet de escala ni pesan en IK |
| HOLOA_109 | OK (20/16, par) | OK | OK (RMS=20.0mm, max=44.9mm en r.bar1) | OK (285861 bytes, 80.7s) | OK (255889 bytes, 1359.1s; BadFrame=1, MaxIter=4, RestFail=20) | | OK (1865685 bytes, 30.0s) | DONE | 2026-09-14 | |
| HOLOA_118 | OK (20/16, par) | OK | OK (RMS=26.5mm, max=61.7mm en r.bar1) | OK (223623 bytes, 337.7s) | OK (200477 bytes, 1272.4s; BadFrame=1, MaxIter=8, RestFail=22) | | OK (1865873 bytes, 31.2s) | DONE | 2026-09-14 | |
| HOLOA_120 | OK (20/16, par) | OK | OK (RMS=25.8mm, max=59.1mm en r.bar1) | OK (263311 bytes, 372.7s) | OK (234516 bytes, 6229.9s; BadFrame=1, MaxIter=641, RestFail=742 -- muy lento, vigilar) | | OK (1869642 bytes, 43.0s) | DONE | 2026-09-14 | |
| HOLOA_139 | OK (20/16, par) | OK | OK (RMS=37.8mm, max=97.9mm en r.bar1) | OK (297587 bytes, 353.6s) | OK (259199 bytes, 1451.2s; BadFrame=1, MaxIter=20, RestFail=16) | | OK (1847585 bytes, 40.6s) | DONE | 2026-09-14 | Usuaria vio en grabación que r.bar1 no está bien colocado; confirmó continuar (r.bar1 no participa en MeasurementSet, peso IK bajo=5) |
| HOLOA_153 | OK (20/16, par) | OK | OK (RMS=35.2mm, max=84.1mm en r.bar1) | OK (281351 bytes, 393.7s) | OK (251771 bytes, 671.7s; BadFrame=1, MaxIter=5, RestFail=5) | | OK (1865586 bytes, 40.5s) | DONE | 2026-09-14 | |
| HOLOA_154 | OK (20/16, par) | OK | OK (RMS=24.0mm, max=44.9mm en l.bar1) | OK (258801 bytes, 364.0s) | OK CON VENTANA TRUNCADA (127454 bytes; "COMAK Converged! 4 iteraciones", sin crash) — ventana recortada de [5.742,6.884]s a [5.744,6.348]s (~53% del ciclo original) para evitar la divergencia patelofemoral en swing. IK original completo respaldado en walking_154_mirror_ik_FULL_backup.mot | 0 tras truncar | OK (1865561 bytes, 41.6s) | DONE | 2026-09-15 | ⚠️ CICLO PARCIAL, no completo como el resto del lote — anotar en cualquier análisis/reporte posterior |
| HOLOA_156 | OK (20/16, par) | OK | OK (RMS=25.1mm, max=55.0mm en r.bar1) | OK (254291 bytes, 399.2s) | OK (229431 bytes, 969.8s; RestFail=21, MaxIter=0) | | OK (1865789 bytes, 38.7s) | DONE | 2026-09-15 | |
| HOLOA_165 | OK (20/16, par) | OK | OK (RMS=25.2mm, max=55.8mm en l.should) | OK (242565 bytes, 319.4s) | FAIL — diverge casi de inmediato (Frame 9/107, t≈5.23s, error dominante en ankle_flex_r), patrón DISTINTO a HOLOA_154 (no patelofemoral/swing, sino tobillo/apoyo temprano) | — | | EXCLUDED | 2026-09-15 | Investigado sin causa concreta: pelvis_rot≈-173° descartado (normal, igual en HOLOA_144), onset abrupto de GRF descartado (HOLOA_144 tiene onset igual o más abrupto y no falla). Excluido del lote por decisión de la usuaria, retornos decrecientes en seguir diagnosticando |
| HOLOA_169 | OK (20/16, par) | OK | OK (RMS=32.8mm, max=64.5mm en c7) | OK (253389 bytes, 351.1s) | OK (227245 bytes, 1182.2s) | | OK (1865779 bytes, 41.4s) | DONE | 2026-09-15 | |
| HOLOA_175 | OK (20/16, par) | OK | OK (RMS=24.0mm, max=60.2mm en r.bar1) | OK (255193 bytes, 201.2s) | OK (228099 bytes, 1452.5s) | | OK (1866529 bytes, 42.4s) | DONE | 2026-09-15 | |
| HOLOA_008 | OK (20/16, par) | N-A | OK (RMS=24.7mm, max=60.6mm en r.bar1) | OK (312019 bytes, 345 frames en 3s) | OK (274583 bytes, ~21min, "Converged! 3 iteraciones", sin crash LAPACK; bad frames en 7.382-7.542s) | | OK (1847474 bytes) | DONE | 2026-09-17 | ⚠️ DISTINTO a los anteriores: aquí se mirroreó la pierna IZQUIERDA REAL (afectada), no la derecha sana — el GRF original solo tenía datos de esa placa (l.gr_force_v*). Científicamente mejor que el mirror por simetría contralateral. Primer sujeto exitoso de la nueva extracción |
| HOLOA_032 | OK (20/16, par) | N-A | OK (RMS=36.7mm, max=81.3mm en r.bar1, ventana 2-4s confirmada) | OK (280449 bytes, 310 frames en 3s) | OK (249750 bytes, ~21min, "Converged! 3 iteraciones"; bad frames en 114-119,152 con udot elevado, recuperados solos, sin crash) | | OK (1865590 bytes) | DONE | 2026-09-17 | Mismo caso que HOLOA_008 (mirror de pierna izquierda REAL). ⚠️ Se encontró contaminación cruzada: walking/ tenía Event_sequences_HOLOA_ID_02.emt (copia exacta de HOLOA_002, ignorado) junto al correcto _ID_32.emt — revisar el extractor de la usuaria. Standing más corto de lo habitual (solo 4.9s) — time_range de Scale ajustado a "2 4" en vez de "5 7" |
