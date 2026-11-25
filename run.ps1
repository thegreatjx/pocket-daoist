# 一键脚本。
# 必要性：Godot 的 class_name 全局类型依赖 .godot/global_script_class_cache.cfg。
# 缓存缺失时报 "Could not find type Player/Sword"，主场景加载不了，表现为直接崩溃。
# 所有命令都先重建缓存再执行。
param(
    [switch]$Test,
    [switch]$Headless,
    [switch]$Export,
    [switch]$Fast     # 跳过缓存重建（缓存已存在时更快）
)

if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwsh) {
        $fwd = @()
        foreach ($kv in $PSBoundParameters.GetEnumerator()) {
            if ($kv.Value -is [switch]) {
                if ($kv.Value.IsPresent) { $fwd += "-$($kv.Key)" }
            } else {
                $fwd += "-$($kv.Key)", $kv.Value
            }
        }
        & $pwsh.Source -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath @fwd
        exit $LASTEXITCODE
    }
}

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not $Fast) {
    Write-Host "[1/2] 重建资源与全局类名缓存..." -ForegroundColor Cyan
    $importOut = & godot --headless --path $PSScriptRoot --import 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Write-Host $importOut
        Write-Error "缓存重建失败 (exit $LASTEXITCODE)"
    }
}

if ($Export) {
    Write-Host "导出 Windows 版本到 build ..." -ForegroundColor Cyan
    $exp = & godot --headless --path $PSScriptRoot --export-release "Windows" "build/百宝小道修.exe" 2>&1 | Out-String
    Write-Host $exp
    $exePath = Join-Path $PSScriptRoot "build\百宝小道修.exe"
    if (Test-Path $exePath) {
        Write-Host ("导出成功: build\百宝小道修.exe ({0:N1} MB)" -f ((Get-Item $exePath).Length / 1MB)) -ForegroundColor Green
    } else {
        Write-Host "导出失败：通常是缺少 Godot 导出模板。在编辑器中打开 项目 > 导出，按提示下载模板后重试。" -ForegroundColor Yellow
    }
    exit $LASTEXITCODE
}

if ($Test) {
    Write-Host "[2/2] 运行集成测试..." -ForegroundColor Cyan
    $testOut = & godot --headless --path $PSScriptRoot res://tests/integration.tscn 2>&1 | Out-String
    Write-Host $testOut
    $code = $LASTEXITCODE
    if ($testOut -match 'passes=(\d+) fails=(\d+)') {
        Write-Host ("SUMMARY: passes={0} fails={1}" -f $Matches[1], $Matches[2]) -ForegroundColor $(if ($Matches[2] -eq '0') { 'Green' } else { 'Red' })
    }
    exit $code
}

Write-Host "[2/2] 启动游戏..." -ForegroundColor Cyan
if ($Headless) {
    $runOut = & godot --headless --path $PSScriptRoot --quit-after 600 2>&1 | Out-String
    Write-Host $runOut
    exit $LASTEXITCODE
}
& godot --path $PSScriptRoot
exit $LASTEXITCODE
