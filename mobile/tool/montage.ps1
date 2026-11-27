param([string]$dir, [string]$names, [string]$out)
Add-Type -AssemblyName System.Drawing
$w = 360; $h = 780
$bmp = New-Object System.Drawing.Bitmap ($w * $names.Count), $h
$g = [System.Drawing.Graphics]::FromImage($bmp); $g.InterpolationMode = 'HighQualityBicubic'
$i = 0
$list = $names -split ","; $bmp.Dispose(); $bmp = New-Object System.Drawing.Bitmap ($w * $list.Count), $h; $g = [System.Drawing.Graphics]::FromImage($bmp); $g.InterpolationMode = "HighQualityBicubic"; foreach ($n in $list) { $im = [System.Drawing.Image]::FromFile((Join-Path $dir $n)); $g.DrawImage($im, $i * $w, 0, $w, $h); $im.Dispose(); $i++ }
$g.Dispose(); $bmp.Save($out); $bmp.Dispose()
