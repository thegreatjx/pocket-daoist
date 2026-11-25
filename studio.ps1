param(
    [switch]$Serve,
    [switch]$Strict,
    [int]$Port = 8765,
    [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if ($Strict) {
    & python tools/studio_audit.py --strict
    exit $LASTEXITCODE
}

if ($Serve) {
    if ($NoOpen) {
        & python tools/studio_audit.py --serve --port $Port
    } else {
        & python tools/studio_audit.py --serve --port $Port --open
    }
    exit $LASTEXITCODE
}

& python tools/studio_audit.py
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if (-not $NoOpen) {
    Start-Process (Resolve-Path "tools\studio_hub\index.html").Path
}
