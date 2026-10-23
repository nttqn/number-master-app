# Renders the two Play Games leaderboard icons (512x512 PNG) into store_assets/.
# Run: powershell -File tool/leaderboard_icons.ps1 -OutDir store_assets
param([string]$OutDir)
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force $OutDir | Out-Null

function C([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }
function Lerp($a, $b, [double]$t) {
  [System.Drawing.Color]::FromArgb(255,
    [int]($a.R + ($b.R - $a.R) * $t), [int]($a.G + ($b.G - $a.G) * $t), [int]($a.B + ($b.B - $a.B) * $t))
}
function NewCanvas([string]$top, [string]$bottom) {
  $bmp = New-Object System.Drawing.Bitmap 512, 512
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.TextRenderingHint = 'AntiAliasGridFit'
  $rect = New-Object System.Drawing.Rectangle 0, 0, 512, 512
  $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, (C $top), (C $bottom), 90
  $g.FillRectangle($bg, $rect)
  return @($bmp, $g)
}
function Poly($g, $color, $pts) {
  $arr = [System.Drawing.PointF[]]($pts | ForEach-Object { New-Object System.Drawing.PointF $_[0], $_[1] })
  $g.FillPolygon((New-Object System.Drawing.SolidBrush $color), $arr)
}
# Pseudo-3D block: front face + lighter top face, like the in-game blocks.
function Block($g, [double]$x, [double]$y, [double]$w, [double]$h, $color, [double]$topH) {
  $white = [System.Drawing.Color]::White
  $black = [System.Drawing.Color]::Black
  Poly $g (Lerp $color $white 0.4) @(@($x, $y), @(($x + $w * 0.06), ($y - $topH)), @(($x + $w * 0.94), ($y - $topH)), @(($x + $w), $y))
  $front = New-Object System.Drawing.RectangleF $x, $y, $w, $h
  $grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush $front, $color, (Lerp $color $black 0.25), 90
  $g.FillRectangle($grad, $front)
}
function OutlinedText($g, [string]$text, [string]$fontName, [float]$size, [float]$cx, [float]$cy, $fill, $stroke, [float]$strokeW) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $family = New-Object System.Drawing.FontFamily $fontName
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
  $path.AddString($text, $family, [int][System.Drawing.FontStyle]::Bold, $size, (New-Object System.Drawing.PointF $cx, $cy), $fmt)
  $pen = New-Object System.Drawing.Pen $stroke, $strokeW
  $pen.LineJoin = 'Round'
  $g.DrawPath($pen, $path)
  $g.FillPath((New-Object System.Drawing.SolidBrush $fill), $path)
}
function Sparkle($g, [float]$cx, [float]$cy, [float]$r, $color) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $pts = @()
  for ($i = 0; $i -lt 8; $i++) {
    $a = [Math]::PI / 4 * $i - [Math]::PI / 2
    $rr = if ($i % 2 -eq 0) { $r } else { $r * 0.28 }
    $pts += , @(($cx + [Math]::Cos($a) * $rr), ($cy + [Math]::Sin($a) * $rr))
  }
  Poly $g $color $pts
}

$font = 'Arial Black'

# ---- Highest Level: rainbow staircase + crown ----
$c = NewCanvas '#3E9BE0' '#BFE6FA'; $bmp = $c[0]; $g = $c[1]
$colors = '#2ED47A', '#3D8BFF', '#B55CFF', '#FF4D6D', '#FFC233'
$stepW = 84; $baseY = 470
for ($i = 0; $i -lt 5; $i++) {
  $h = 70 + $i * 62
  Block $g (46 + $i * $stepW) ($baseY - $h) $stepW $h (C $colors[$i]) 22
}
# Crown on the top step.
$cx = 46 + 4 * $stepW + $stepW / 2; $cy = $baseY - (70 + 4 * 62) - 40
$gold = C '#FFD23F'
Poly $g $gold @(@(($cx - 62), ($cy + 30)), @(($cx - 70), ($cy - 40)), @(($cx - 32), ($cy - 5)), @($cx, ($cy - 58)), @(($cx + 32), ($cy - 5)), @(($cx + 70), ($cy - 40)), @(($cx + 62), ($cy + 30)))
$g.FillRectangle((New-Object System.Drawing.SolidBrush (C '#F0A500')), [float]($cx - 62), [float]($cy + 22), [float]124, [float]18)
foreach ($dx in -70, 0, 70) {
  $dy = if ($dx -eq 0) { -58 } else { -40 }
  $g.FillEllipse((New-Object System.Drawing.SolidBrush (C '#FF4D6D')), [float]($cx + $dx - 11), [float]($cy + $dy - 11), [float]22, [float]22)
}
OutlinedText $g 'LV' $font 150 150 140 ([System.Drawing.Color]::White) (C '#1E3A8A') 18
Sparkle $g 300 70 26 ([System.Drawing.Color]::White)
Sparkle $g 70 300 18 ([System.Drawing.Color]::White)
$bmp.Save((Join-Path $OutDir 'leaderboard_highest_level.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()

# ---- Biggest Number: big gold cube with a number ----
$c = NewCanvas '#7B3FE4' '#FF5CC8'; $bmp = $c[0]; $g = $c[1]
# Soft glow behind the cube.
$glow = New-Object System.Drawing.Drawing2D.GraphicsPath
$glow.AddEllipse(56, 70, 400, 400)
$pg = New-Object System.Drawing.Drawing2D.PathGradientBrush $glow
$pg.CenterColor = [System.Drawing.Color]::FromArgb(150, 255, 230, 120)
$pg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 255, 230, 120))
$g.FillPath($pg, $glow)
$g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(70, 0, 0, 0))), 106, 420, 300, 50)
Block $g 96 175 320 265 (C '#FFB300') 48
$g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(60, 255, 255, 255))), [float]96, [float]175, [float]320, [float]30)
OutlinedText $g '999' $font 120 256 312 ([System.Drawing.Color]::White) (C '#7A4A00') 16
Sparkle $g 90 110 34 (C '#FFF3B0')
Sparkle $g 430 90 26 ([System.Drawing.Color]::White)
Sparkle $g 450 230 18 (C '#FFF3B0')
Sparkle $g 60 260 16 ([System.Drawing.Color]::White)
$bmp.Save((Join-Path $OutDir 'leaderboard_biggest_number.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
'done'
