# 创建桌面快捷方式：双击即玩，无控制台黑窗。
# 重新创建：pwsh -File toolsmake_shortcut.ps1

$ErrorActionPreference = 'Stop'
$projectDir = Split-Path $PSScriptRoot -Parent
$icoPath = Join-Path $projectDir (Join-Path 'assets' 'icon.ico')
$vbsPath = Join-Path $projectDir 'play.vbs'

if (-not (Test-Path $vbsPath)) { throw "缺少启动器: $vbsPath" }

$desktop = [Environment]::GetFolderPath('Desktop')
$lnkPath = Join-Path $desktop '百宝小道修.lnk'

$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut($lnkPath)
$lnk.TargetPath = 'wscript.exe'
$lnk.Arguments = '"' + $vbsPath + '"'
$lnk.WorkingDirectory = $projectDir
$lnk.Description = '百宝小道修 (Pocket Daoist) · 修仙肉鸽割草游戏'
if (Test-Path $icoPath) {
    $lnk.IconLocation = $icoPath
} else {
    Write-Warning "图标缺失，使用默认图标: $icoPath"
}
$lnk.Save()

# 回读验证快捷方式内容正确
$chk = $ws.CreateShortcut($lnkPath)
Write-Output ("SHORTCUT=" + $lnkPath)
Write-Output ("  target=" + $chk.TargetPath)
Write-Output ("  args=" + $chk.Arguments)
Write-Output ("  workdir=" + $chk.WorkingDirectory)
Write-Output ("  icon=" + $chk.IconLocation)
if ($chk.IconLocation) {
    $icoFile = ($chk.IconLocation -split ',')[0]
    Write-Output ("  iconExists=" + (Test-Path $icoFile))
}
