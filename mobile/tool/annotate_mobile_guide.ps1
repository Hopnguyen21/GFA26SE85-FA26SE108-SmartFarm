# Khoanh vùng bước thao tác (1, 2, 3...) lên ảnh mobile cho "Hướng dẫn sử dụng cho người dùng cuối".
#   powershell -File mobile/tool/annotate_mobile_guide.ps1
# Ảnh gốc: mobile/test/goldens (1290x2796). Ảnh ra: docs/huong-dan-nguoi-dung/img/*.png
# Toạ độ viết theo ảnh xem ở độ rộng 1188 px, tự nhân 1290/1188.
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$src = Join-Path $root 'mobile\test\goldens'
$out = Join-Path $root 'docs\huong-dan-nguoi-dung\img'
New-Item -ItemType Directory -Force $out | Out-Null
$k = 1290.0 / 1188.0

# file ảnh -> khung: @(số, x, y, rộng, cao)
$plan = [ordered]@{
  '00_02_login.png' = @(@(1, 100, 1000, 985, 370), @(2, 98, 1640, 992, 146), @(3, 100, 1950, 985, 315))
  '01_01_owner_home.png' = @(@(1, 610, 1195, 530, 215), @(2, 610, 1950, 530, 250))
  '01_25_owner_cf1_progress.png' = @(@(1, 46, 200, 1096, 225), @(2, 46, 1832, 1096, 310))
  '01_24_owner_deployment_send.png' = @(@(1, 86, 1650, 1016, 250), @(2, 46, 2420, 1096, 135))
  '01_23_owner_deployment_requests.png' = @(@(1, 46, 200, 1096, 295), @(2, 1085, 40, 80, 80))
  '03_01_tech_work.png' = @(@(1, 68, 553, 1052, 102), @(2, 32, 1172, 1126, 756))
  '01_21_owner_device_health.png' = @(@(1, 46, 200, 1096, 305), @(2, 46, 1026, 1096, 365))
  '01_09_owner_zone_detail.png' = @(@(1, 0, 395, 1188, 100), @(2, 46, 808, 1096, 800))
  '01_14_owner_monitoring_history.png' = @(@(1, 46, 200, 1096, 120), @(2, 46, 373, 990, 95), @(3, 46, 1552, 1096, 345))
  '01_10_owner_zone_alert_center.png' = @(@(1, 78, 1860, 380, 130), @(2, 476, 1860, 324, 130))
  '01_20_owner_schedules_automation.png' = @(@(1, 46, 715, 1096, 535), @(2, 935, 780, 155, 95), @(3, 776, 2360, 385, 195))
  '01_13_owner_actuator_history.png' = @(@(1, 46, 200, 1096, 165), @(2, 46, 962, 1096, 167))
  '01_05_owner_ai_assistant.png' = @(@(1, 40, 180, 870, 250), @(2, 192, 1082, 915, 1040), @(3, 28, 2330, 990, 115))
  'E02_login_wrong_password.png' = @(@(1, 102, 818, 983, 170), @(2, 103, 1342, 983, 132), @(3, 98, 1745, 992, 145))
  'E04_cf1_server_error.png' = @(@(1, 60, 1230, 1050, 120), @(2, 482, 1365, 224, 132))
  'E05_cf2_alerts_empty.png' = @(@(1, 46, 200, 1096, 180), @(2, 46, 420, 1096, 410))
  'E06_cf2_history_offline.png' = @(@(1, 150, 810, 870, 70), @(2, 456, 910, 276, 120))
  'E08_cf3_devices_offline.png' = @(@(1, 60, 1330, 1060, 70), @(2, 480, 1425, 230, 60))
  'E09_cf4_ai_server_error.png' = @(@(1, 38, 175, 870, 185), @(2, 28, 2330, 990, 115))
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
    $d = 74; $bx = [Math]::Max(4, $x - 14); $by = [Math]::Max(4, $y - $d / 2)
    $g.FillEllipse($fill, $bx, $by, $d, $d)
    $sf = New-Object System.Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
    $g.DrawString([string]$b[0], $font, $white, (New-Object System.Drawing.RectangleF $bx, $by, $d, $d), $sf)
  }
  $g.Dispose()
  $bmp.Save((Join-Path $out $name), [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Host "Đã khoanh: $name"
}
