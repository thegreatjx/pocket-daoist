# 生成 assetsicon.ico（256x256，PNG-based ICO，Windows Vista+ 支持）。
# 用途：桌面快捷方式图标、任务栏图标、以及未来导出 exe 的程序图标。
# 重新生成：pwsh -File toolsmake_icon.ps1

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType Directory -Force -Path assets | Out-Null

Add-Type -AssemblyName System.Drawing

$bmp = New-Object System.Drawing.Bitmap(256, 256)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

# 圆角深蓝底
$rect = New-Object System.Drawing.Rectangle(0, 0, 256, 256)
$cTop = [System.Drawing.Color]::FromArgb(255, 16, 28, 54)
$cBot = [System.Drawing.Color]::FromArgb(255, 10, 18, 38)
$bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $cTop, $cBot, 90.0)
$r = 40
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddArc(0, 0, $r * 2, $r * 2, 180, 90)
$path.AddArc(256 - $r * 2, 0, $r * 2, $r * 2, 270, 90)
$path.AddArc(256 - $r * 2, 256 - $r * 2, $r * 2, $r * 2, 0, 90)
$path.AddArc(0, 256 - $r * 2, $r * 2, $r * 2, 90, 90)
$path.CloseFigure()
$g.FillPath($bgBrush, $path)

# 灵韵光晕
$glow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(50, 120, 200, 235))
$g.FillEllipse($glow, 48, 40, 160, 160)
$glow2 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45, 150, 220, 245))
$g.FillEllipse($glow2, 72, 64, 112, 112)

# 山岳剪影
$mtn = @(
    (New-Object System.Drawing.PointF(18, 214)),
    (New-Object System.Drawing.PointF(72, 138)),
    (New-Object System.Drawing.PointF(104, 176)),
    (New-Object System.Drawing.PointF(136, 124)),
    (New-Object System.Drawing.PointF(168, 168)),
    (New-Object System.Drawing.PointF(196, 132)),
    (New-Object System.Drawing.PointF(238, 214))
)
$mtnBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 22, 35, 61))
$mtnPts = [System.Drawing.PointF[]]$mtn
$g.FillPolygon($mtnBrush, $mtnPts)
$mtnPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 44, 68, 112), 3)
$g.DrawPolygon($mtnPen, $mtnPts)

# 斜向长剑
$st = $g.BeginContainer()
$g.TranslateTransform(128, 122)
$g.RotateTransform(-42)

$bladeRect = New-Object System.Drawing.Rectangle(-14, -96, 28, 150)
$cHi = [System.Drawing.Color]::FromArgb(255, 232, 255, 251)
$cLo = [System.Drawing.Color]::FromArgb(255, 79, 216, 200)
$bladeBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($bladeRect, $cHi, $cLo, 90.0)
$blade = @(
    (New-Object System.Drawing.PointF(0, -100)),
    (New-Object System.Drawing.PointF(13, -72)),
    (New-Object System.Drawing.PointF(13, 42)),
    (New-Object System.Drawing.PointF(0, 58)),
    (New-Object System.Drawing.PointF(-13, 42)),
    (New-Object System.Drawing.PointF(-13, -72))
)
$bladePts = [System.Drawing.PointF[]]$blade
$g.FillPolygon($bladeBrush, $bladePts)

$hiBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(150, 255, 255, 255))
$hiPoly = @(
    (New-Object System.Drawing.PointF(0, -100)),
    (New-Object System.Drawing.PointF(6, -74)),
    (New-Object System.Drawing.PointF(6, 44)),
    (New-Object System.Drawing.PointF(0, 54))
)
$hiPts = [System.Drawing.PointF[]]$hiPoly
$g.FillPolygon($hiBrush, $hiPts)

# 护手 / 剑柄 / 剑首
$goldBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 224, 180, 74))
$g.FillRectangle($goldBrush, -40, 46, 80, 15)
$gripBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 122, 82, 48))
$g.FillRectangle($gripBrush, -9, 61, 18, 40)
$g.FillEllipse($goldBrush, -11, 98, 22, 22)

$g.EndContainer($st)
$g.Dispose()

# PNG 编码后包装为 ICO
$ms = New-Object System.IO.MemoryStream
$bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
$png = $ms.ToArray()
$bmp.Dispose()

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

$icoPath = Join-Path (Split-Path $PSScriptRoot -Parent) (Join-Path 'assets' 'icon.ico')
[System.IO.File]::WriteAllBytes($icoPath, $out.ToArray())
$bw.Dispose()
$out.Dispose()

Write-Output ("ICO_WRITTEN=" + $icoPath + " bytes=" + (Get-Item $icoPath).Length)
