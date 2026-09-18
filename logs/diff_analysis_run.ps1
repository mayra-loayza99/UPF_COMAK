$ErrorActionPreference = 'Continue'

# ── PASO 1: Verificar precondiciones ─────────────────────────────────────────
$carpetaA = 'D:\mayra\Descargas\UPF_COMAK-master\UPF_COMAK-master\COMAK\matlab_scripts'
$carpetaB = 'D:\mayra\Descargas\UPF_COMAK\COMAK\matlab_scripts'
$logsDir  = 'D:\mayra\Descargas\UPF_COMAK\logs'
$fecha    = '2026-06-17'

$archivos = @(
    'main_comak_workflow_function.m',
    'run_comak.m',
    'configurar_comak_base.m',
    'run_ik.m',
    'run_joint_mechanics.m'
)

Write-Host "=== PASO 1: PRECONDICIONES ==="
$preOk = $true
foreach ($f in $archivos) {
    $eA = Test-Path (Join-Path $carpetaA $f)
    $eB = Test-Path (Join-Path $carpetaB $f)
    $estado = if ($eA -and $eB) { 'OK' } else { 'FALTA' }
    Write-Host "  $estado  A:$eA  B:$eB  $f"
    if (-not $eA -or -not $eB) { $preOk = $false }
}
$logsOk = Test-Path $logsDir
Write-Host "  logs/ existe: $logsOk"
if (-not $logsOk) { Write-Host "ERROR BLOQUEANTE: logs/ no existe"; exit 1 }

# ── PASO 2: Confirmar git --no-index ─────────────────────────────────────────
Write-Host ""
Write-Host "=== PASO 2: TEST GIT ==="
$gitVer = git --version 2>&1
Write-Host "  $gitVer"
$testDiff = git diff --no-index --ignore-all-space --ignore-cr-at-eol `
    -- (Join-Path $carpetaA 'run_joint_mechanics.m') `
       (Join-Path $carpetaB 'run_joint_mechanics.m') 2>&1
$gitOk = $LASTEXITCODE -le 1
Write-Host "  exit code: $LASTEXITCODE  (0=igual, 1=hay diffs, >1=error)"
if (-not $gitOk) { Write-Host "ERROR BLOQUEANTE: git diff fallo"; exit 1 }
Write-Host "  git --no-index: OK"

# ── PASO 3: Bloque central ────────────────────────────────────────────────────
Write-Host ""
Write-Host "=== PASO 3: ANALISIS DE DIFFS ==="

$keywordsBilateral = @('_l\b','_r\b','side','bilateral','pierna','derecha','izquierda')
$keywordsBugfix    = @('\btic\b','\btoc\b','assert','dir\(','isfile','error\(')

function Categorizar-Hunk {
    param([string[]]$lineasHunk)
    $texto = $lineasHunk -join ' '
    $esBilateral = $false
    $esBugfix    = $false
    foreach ($kw in $keywordsBilateral) {
        if ($texto -imatch $kw) { $esBilateral = $true; break }
    }
    foreach ($kw in $keywordsBugfix) {
        if ($texto -imatch $kw) { $esBugfix = $true; break }
    }
    if     ($esBilateral -and $esBugfix) { return 'bilateral+bugfix' }
    elseif ($esBilateral)                { return 'probable bilateral' }
    elseif ($esBugfix)                   { return 'probable bugfix' }
    else                                 { return 'indeterminado' }
}

$reporteLineas = [System.Collections.Generic.List[string]]::new()
$reporteLineas.Add("REPORTE DIFF MATLAB SCRIPTS - $fecha")
$reporteLineas.Add("=" * 70)

foreach ($archivo in $archivos) {
    $rutaA    = Join-Path $carpetaA $archivo
    $rutaB    = Join-Path $carpetaB $archivo
    $base     = [System.IO.Path]::GetFileNameWithoutExtension($archivo)
    $diffFile = Join-Path $logsDir "diff_${base}_${fecha}.diff"
    $esTrivial = ($archivo -eq 'run_joint_mechanics.m')

    $reporteLineas.Add("")
    $reporteLineas.Add("ARCHIVO: $archivo")
    $reporteLineas.Add("-" * 50)

    if (-not (Test-Path $rutaA) -or -not (Test-Path $rutaB)) {
        $msg = "  AVISO: archivo ausente - diff omitido"
        Write-Host $msg
        $reporteLineas.Add($msg)
        continue
    }

    $diffLineas = git diff --no-index --ignore-all-space --ignore-cr-at-eol `
                      -- $rutaA $rutaB 2>&1
    $diffLineas | Set-Content -Path $diffFile -Encoding UTF8

    # Parseo de hunks
    $numHunks    = 0
    $totalAdd    = 0
    $totalDel    = 0
    $hunkActual  = [System.Collections.Generic.List[string]]::new()
    $resumenHunks = [System.Collections.Generic.List[string]]::new()

    foreach ($linea in $diffLineas) {
        if ($linea -match '^@@') {
            if ($numHunks -gt 0 -and -not $esTrivial) {
                $cat  = Categorizar-Hunk -lineasHunk $hunkActual.ToArray()
                $addH = ($hunkActual | Where-Object { $_ -match '^\+' -and $_ -notmatch '^\+\+\+'} | Measure-Object).Count
                $delH = ($hunkActual | Where-Object { $_ -match '^-'  -and $_ -notmatch '^---'  } | Measure-Object).Count
                $resumenHunks.Add("    Hunk $numHunks : +$addH / -$delH  [$cat]")
            }
            $numHunks++
            $hunkActual = [System.Collections.Generic.List[string]]::new()
            $hunkActual.Add($linea)
        } elseif ($linea -match '^\+' -and $linea -notmatch '^\+\+\+') {
            $totalAdd++
            $hunkActual.Add($linea)
        } elseif ($linea -match '^-' -and $linea -notmatch '^---') {
            $totalDel++
            $hunkActual.Add($linea)
        } else {
            $hunkActual.Add($linea)
        }
    }
    # Cerrar ultimo hunk
    if ($numHunks -gt 0 -and -not $esTrivial) {
        $cat  = Categorizar-Hunk -lineasHunk $hunkActual.ToArray()
        $addH = ($hunkActual | Where-Object { $_ -match '^\+' -and $_ -notmatch '^\+\+\+'} | Measure-Object).Count
        $delH = ($hunkActual | Where-Object { $_ -match '^-'  -and $_ -notmatch '^---'  } | Measure-Object).Count
        $resumenHunks.Add("    Hunk $numHunks : +$addH / -$delH  [$cat]")
    }

    $cab = "  Hunks: $numHunks   +$totalAdd lineas   -$totalDel lineas   -> diff_${base}_${fecha}.diff"
    Write-Host ""
    Write-Host "ARCHIVO: $archivo"
    Write-Host $cab
    $reporteLineas.Add($cab)

    if ($esTrivial) {
        Write-Host "  [TRIVIAL - diff completo:]"
        $diffLineas | ForEach-Object { Write-Host "    $_" }
        $reporteLineas.Add("  [TRIVIAL - diff completo:]")
        $diffLineas | ForEach-Object { $reporteLineas.Add("    $_") }
    } else {
        foreach ($r in $resumenHunks) {
            Write-Host $r
            $reporteLineas.Add($r)
        }
    }
}

# ── PASO 4: Guardar reporte y verificar outputs ───────────────────────────────
$reporteFile = Join-Path $logsDir "reporte_diff_${fecha}.txt"
$reporteLineas | Set-Content -Path $reporteFile -Encoding UTF8

Write-Host ""
Write-Host "=== PASO 4: VERIFICACION DE OUTPUTS ==="
$esperados = @(
    "diff_main_comak_workflow_function_${fecha}.diff",
    "diff_run_comak_${fecha}.diff",
    "diff_configurar_comak_base_${fecha}.diff",
    "diff_run_ik_${fecha}.diff",
    "diff_run_joint_mechanics_${fecha}.diff",
    "reporte_diff_${fecha}.txt"
)
$todoOk = $true
foreach ($nombre in $esperados) {
    $ruta = Join-Path $logsDir $nombre
    $existe = Test-Path $ruta
    $tam    = if ($existe) { (Get-Item $ruta).Length } else { 0 }
    $estado = if ($existe -and $tam -gt 0) { 'OK' } else { 'FALLO' }
    Write-Host "  $estado  [$tam bytes]  $nombre"
    if ($estado -eq 'FALLO') { $todoOk = $false }
}
if ($todoOk) {
    Write-Host ""
    Write-Host "TODOS LOS OUTPUTS GENERADOS CORRECTAMENTE."
} else {
    Write-Host ""
    Write-Host "ERROR: uno o mas outputs ausentes o vacios."
}
