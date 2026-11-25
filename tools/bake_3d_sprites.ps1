param(
    [string]$BlenderExe = "D:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe",
    [string]$InputModel = "",
    [string]$HeroDir = "",
    [string]$ActionName = "",
    [string]$OutPng = "",
    [int]$CellSize = 128,
    [int]$Frames = 8,
    [double]$YawOffset = 0,
    [switch]$Toon
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Script = Join-Path $PSScriptRoot "blender_bake_spritesheet.py"
$SpritesDir = Join-Path $Root "assets\sprites"

if ($HeroDir -ne "") {
    if (!(Test-Path $HeroDir)) { throw "HeroDir not found: $HeroDir" }
    $files = Get-ChildItem -Path $HeroDir -File | Where-Object { $_.Extension -in '.fbx', '.glb', '.gltf' }
    $slots = @(
        @{ Key = 'run'; Out = 'anim_hero_8dir_run.png'; Frames = 8 },
        @{ Key = 'idle'; Out = 'anim_hero_8dir_idle.png'; Frames = 6 },
        @{ Key = 'attack|slash'; Out = 'anim_hero_8dir_attack.png'; Frames = 6 }
    )
    $baked = 0
    foreach ($slot in $slots) {
        $match = $files | Where-Object { $_.BaseName -match $slot.Key } | Select-Object -First 1
        if ($match) {
            $outPath = Join-Path $SpritesDir $slot.Out
            Write-Host "Baking Hero $($slot.Key) from $($match.Name) -> $($slot.Out)..." -ForegroundColor Cyan
            & $BlenderExe -b --python $Script -- --input $match.FullName --out $outPath --cell-size $CellSize --frames $slot.Frames --yaw-offset $YawOffset --toon
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
            $baked++
        }
    }
    if ($baked -eq 0) { throw "No run/idle/attack(.fbx|.glb) found in $HeroDir" }
    Write-Host "Done ($baked sheets baked). Run 'godot_console --headless --path $Root --import' or launch Godot to reimport." -ForegroundColor Green
    exit 0
}

if ($InputModel -ne "") {
    if ($OutPng -eq "") { throw "Please specify -OutPng when baking an external model." }
    $extra = @()
    if ($ActionName -ne "") { $extra += @("--action", $ActionName) }
    if ($Toon) { $extra += @("--toon") }
    & $BlenderExe -b --python $Script -- --input $InputModel --out $OutPng --cell-size $CellSize --frames $Frames --yaw-offset $YawOffset @extra
    exit $LASTEXITCODE
}

Write-Host "[1/2] Baking Hero 8-direction sheets (128x128)..." -ForegroundColor Cyan
& $BlenderExe -b --python $Script -- --builtin hero --out-dir $SpritesDir --cell-size 128
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "[2/2] Baking Wolf Boss 8-direction multi-state sheets (192x192)..." -ForegroundColor Cyan
& $BlenderExe -b --python $Script -- --builtin wolf_boss --out-dir $SpritesDir --cell-size 192
exit $LASTEXITCODE
