# 从根目录 icon.png 生成 assets\icon.ico（256x256，PNG-based ICO，Windows Vista+ 支持）。
# 用途：桌面快捷方式图标、任务栏图标、以及导出 exe 的程序图标。
# 重新生成：pwsh -File tools\make_icon.ps1

$ErrorActionPreference = 'Stop'
$projectDir = Split-Path $PSScriptRoot -Parent
Set-Location $projectDir
New-Item -ItemType Directory -Force -Path assets | Out-Null

$srcPng = Join-Path $projectDir 'icon.png'
if (-not (Test-Path $srcPng)) {
    throw "缺少图标源文件: $srcPng"
}

Add-Type -AssemblyName System.Drawing

$srcImg = [System.Drawing.Image]::FromFile($srcPng)
$bmp = New-Object System.Drawing.Bitmap(256, 256, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.Clear([System.Drawing.Color]::Transparent)
$g.DrawImage($srcImg, 0, 0, 256, 256)
$g.Dispose()
$srcImg.Dispose()

$ms = New-Object System.IO.MemoryStream
$bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
$png = $ms.ToArray()
$bmp.Dispose()
$ms.Dispose()

$out = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($out)
$bw.Write([UInt16]0)               # reserved
$bw.Write([UInt16]1)               # type = icon
$bw.Write([UInt16]1)               # count
$bw.Write([Byte]0)                 # width (0 = 256)
$bw.Write([Byte]0)                 # height (0 = 256)
$bw.Write([Byte]0)                 # palette
$bw.Write([Byte]0)                 # reserved
$bw.Write([UInt16]1)               # planes
$bw.Write([UInt16]32)              # bpp
$bw.Write([UInt32]$png.Length)     # data size
$bw.Write([UInt32]22)              # data offset = 6 + 16
$bw.Write($png)
$bw.Flush()

$icoPath = Join-Path $projectDir (Join-Path 'assets' 'icon.ico')
[System.IO.File]::WriteAllBytes($icoPath, $out.ToArray())
$bw.Dispose()
$out.Dispose()

Write-Output ("ICO_WRITTEN=" + $icoPath + " bytes=" + (Get-Item $icoPath).Length)
