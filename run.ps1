# 一键运行：先重建全局类名缓存，再启动游戏。
# 必要性：Godot 的 class_name 全局类型依赖 .godot/global_script_class_cache.cfg。
# 缓存缺失时，脚本解析失败并报 "Could not find type Player/Sword/UpgradeUI"，
# 主场景加载不了，表现为直接崩溃。
param(
    [switch]$Test,
    [switch]$Headless
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host "[1/2] 重建资源与全局类名缓存..." -ForegroundColor Cyan
godot --headless --path $PSScriptRoot --import 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error "缓存重建失败 (exit $LASTEXITCODE)" }

if ($Test) {
    Write-Host "[2/2] 运行集成测试..." -ForegroundColor Cyan
    godot --headless --path $PSScriptRoot --script res://_test_integration.gd
    exit $LASTEXITCODE
}

Write-Host "[2/2] 启动游戏..." -ForegroundColor Cyan
$extra = @()
if ($Headless) { $extra = @('--headless', '--quit-after', '600') }
& godot --path $PSScriptRoot @extra
exit $LASTEXITCODE
