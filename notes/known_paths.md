# Rutas reales del proyecto

## Datos de entrada
- Repositorio upstream (read-only): D:\mayra\Descargas\UPF_COMAK-master\
- Datos por sujeto: D:\mayra\Descargas\UPF_COMAK-master\COMAK\processed_data\<sujeto>\
  Estructura: model/*.osim, walking/*.trc + *.mot + *Event*, standing/, *.emt
- Sujetos disponibles actualmente: STRATO_001, HOLOA_040 (añadir conforme aparezcan)

## Resultados
- Generados por MATLAB en ruta relativa al script:
  COMAK/results/<sujeto>/  → resuelve a UPF_COMAK-master\COMAK\results\<sujeto>\
- TODO: decidir si copiamos resultados al workspace local o los enlazamos

## Scripts
- Entry point MATLAB: UPF_COMAK-master\COMAK\matlab_scripts\main_comak_workflow_function.m
- Comando: matlab -r "main_comak_workflow_function('<ruta_a_data>'); exit"
- Path master con doble anidación verificado: UPF_COMAK-master\UPF_COMAK-master\COMAK\matlab_scripts\
