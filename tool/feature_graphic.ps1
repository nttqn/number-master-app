# Renders Google Play's 1024x500 feature graphic and the 512x512 store icon
# into store/. Run after tool/store_shots.js (it uses two phone shots):
#   powershell -ExecutionPolicy Bypass -File tool/feature_graphic.ps1
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot -Parent
$store = Join-Path $root 'store'

function RoundedPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $p.AddArc($x, $y, 2 * $r, 2 * $r, 180, 90)
  $p.AddArc($x + $w - 2 * $r, $y, 2 * $r, 2 * $r, 270, 90)
  $p.AddArc($x + $w - 2 * $r, $y + $h - 2 * $r, 2 * $r, 2 * $r, 0, 90)
  $p.AddArc($x, $y + $h - 2 * $r, 2 * $r, 2 * $r, 90, 90)
  $p.CloseFigure()
  return $p
}

# A phone screenshot in a rounded white frame, rotated by $angle degrees
# around its center.
function Phone($g, [string]$file, [float]$cx, [float]$cy, [float]$h, [float]$angle) {
  $img = [System.Drawing.Image]::FromFile($file)
  $w = $h * $img.Width / $img.Height
  $state = $g.Save()
  $g.TranslateTransform($cx, $cy)
  $g.RotateTransform($angle)
  $shadow = RoundedPath (-$w / 2 - 4) (-$h / 2 + 6) ($w + 8) ($h + 8) 26
  $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(70, 0, 30, 80))), $shadow)
  $frame = RoundedPath (-$w / 2 - 7) (-$h / 2 - 7) ($w + 14) ($h + 14) 28
  $g.FillPath([System.Drawing.Brushes]::White, $frame)
  $clip = RoundedPath (-$w / 2) (-$h / 2) $w $h 22
  $g.SetClip($clip)
  $g.DrawImage($img, (-$w / 2), (-$h / 2), $w, $h)
  $g.ResetClip()
  $g.Restore($state)
  $img.Dispose()
}

$bmp = New-Object System.Drawing.Bitmap 1024, 500
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.InterpolationMode = 'HighQualityBicubic'

# Sky background: the game's own bg.png, cover-cropped.
$bg = [System.Drawing.Image]::FromFile((Join-Path $root 'assets\images\bg.png'))
$srcH = $bg.Width * 500 / 1024
$dst = New-Object System.Drawing.RectangleF 0, 0, 1024, 500
$src = New-Object System.Drawing.RectangleF 0, (($bg.Height - $srcH) * 0.25), $bg.Width, $srcH
$g.DrawImage($bg, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
$bg.Dispose()

# Two gameplay phones on the right.
Phone $g (Join-Path $store 'phone\06-bonus-stairs.png') 885 268 430 7
Phone $g (Join-Path $store 'phone\05-break-the-walls.png') 715 262 440 -5

# Title logo on the left.
$logo = [System.Drawing.Image]::FromFile((Join-Path $root 'assets\images\number-master-title.png'))
$lw = 480; $lh = $lw * $logo.Height / $logo.Width
$g.DrawImage($logo, 40, (215 - $lh / 2), $lw, $lh)
$logo.Dispose()

# Tagline pill under the logo.
$font = New-Object System.Drawing.Font 'Arial Black', 19
$text = 'Run. Merge. Break through!'
$size = $g.MeasureString($text, $font)
$px = 280 - $size.Width / 2; $py = 418
$pill = RoundedPath ($px - 18) ($py - 6) ($size.Width + 36) ($size.Height + 12) 26
$pillRect = New-Object System.Drawing.RectangleF ($px - 18), $py, ($size.Width + 36), $size.Height
$warmA = [System.Drawing.ColorTranslator]::FromHtml('#FFD23F')
$warmB = [System.Drawing.ColorTranslator]::FromHtml('#FF5F1F')
$pillBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $pillRect, $warmA, $warmB, ([float]0)
$g.FillPath($pillBrush, $pill)
$g.DrawString($text, $font, [System.Drawing.Brushes]::White, $px, $py)

$bmp.Save((Join-Path $store 'feature-graphic.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()

# 512x512 store icon from the launcher icon source.
$src = [System.Drawing.Image]::FromFile((Join-Path $root 'assets\icon\icon.png'))
$icon = New-Object System.Drawing.Bitmap 512, 512
$ig = [System.Drawing.Graphics]::FromImage($icon)
$ig.InterpolationMode = 'HighQualityBicubic'
$ig.DrawImage($src, 0, 0, 512, 512)
$icon.Save((Join-Path $store 'icon-512.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$ig.Dispose(); $icon.Dispose(); $src.Dispose()
'done'
