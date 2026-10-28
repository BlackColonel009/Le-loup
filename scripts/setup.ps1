$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    if (-not (Test-Path backend/.venv/Scripts/python.exe)) {
        python -m venv backend/.venv
        if ($LASTEXITCODE -ne 0) { throw 'Création du venv impossible.' }
    }
    & backend/.venv/Scripts/python.exe -m pip install -e './backend[dev]'
    if ($LASTEXITCODE -ne 0) { throw 'Installation Python impossible.' }
    Push-Location apps/mordeviel
    try {
        flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'Installation Flutter impossible.' }
    } finally { Pop-Location }
} finally { Pop-Location }
