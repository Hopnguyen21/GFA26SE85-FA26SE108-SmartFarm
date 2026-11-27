# Khoanh vùng thao tác (số 1, 2, 3) lên ảnh chụp màn hình mobile để làm tài liệu hướng dẫn cho Hội đồng.
#   powershell -File mobile/tool/annotate_guide.ps1
# Ảnh gốc: mobile/test/goldens (1290x2796). Ảnh đã khoanh: docs/huong-dan-demo/*.png
# Toạ độ viết theo ảnh xem ở độ rộng 1188 px, tự nhân 1290/1188 cho ảnh gốc.
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$src = Join-Path $root 'mobile\test\goldens'
$out = Join-Path $root 'docs\huong-dan-demo'
New-Item -ItemType Directory -Force $out | Out-Null
$k = 1290.0 / 1188.0

# file ảnh -> danh sách khung: @(số, x, y, rộng, cao)
$plan = [ordered]@{
  '00_02_login.png' = @(@(1, 100, 1000, 985, 370), @(2, 98, 1640, 992, 146), @(3, 100, 1950, 985, 315))
  '01_10_owner_zone_alert_center.png' = @(@(1, 78, 1165, 380, 112), @(2, 476, 1165, 324, 112))
  '03_01_tech_work.png' = @(@(1, 68, 553, 1052, 102), @(2, 32, 1172, 1126, 756))
}

foreach ($name in $plan.Keys) {
  $img = [System.Drawing.Image]::FromFile((Join-Path $src $name))
  $bmp = New-Object System.Drawing.Bitmap $img.Width, $img.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAlias'
  $g.DrawImage($img, 0, 0, $img.Width, $img.Height)
  $img.Dispose()
  $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 235, 30, 30)), 9
  $fill = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 235, 30, 30))
  $white = [System.Drawing.Brushes]::White
  $font = New-Object System.Drawing.Font 'Segoe UI', 40, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
  foreach ($b in $plan[$name]) {
    $x = [int]($b[1] * $k); $y = [int]($b[2] * $k); $w = [int]($b[3] * $k); $h = [int]($b[4] * $k)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = 36
    $path.AddArc($x, $y, $r, $r, 180, 90); $path.AddArc($x + $w - $r, $y, $r, $r, 270, 90)
    $path.AddArc($x + $w - $r, $y + $h - $r, $r, $r, 0, 90); $path.AddArc($x, $y + $h - $r, $r, $r, 90, 90)
    $path.CloseFigure()
    $g.DrawPath($pen, $path)
    # huy hiệu số ở góc trên trái của khung
    $d = 74; $bx = $x - 14; $by = $y - $d / 2
    if ($by -lt 4) { $by = 4 }
    $g.FillEllipse($fill, $bx, $by, $d, $d)
    $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
    $g.DrawString([string]$b[0], $font, $white, (New-Object System.Drawing.RectangleF $bx, $by, $d, $d), $sf)
  }
  $g.Dispose()
  $bmp.Save((Join-Path $out $name), [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Host "Đã khoanh: $name"
}
