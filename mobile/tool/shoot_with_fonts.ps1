# Chụp ảnh màn hình mobile trên BẢN SAO tạm của mã nguồn, trong đó mọi TextStyle chưa khai báo font được gắn 'Segoe UI'.
# Lý do: trong `flutter test`, chữ không có fontFamily rơi về font mặc định của bộ test (Ahem) nên hiện thành ô vuông
# (nút dùng styleFrom(textStyle: TextStyle(...)), RichText...). Trên máy thật các chỗ này dùng font hệ thống nên không lỗi.
# Mã nguồn thật KHÔNG bị sửa; ảnh được chép ngược về mobile/test/goldens/.
#   powershell -File mobile\tool\shoot_with_fonts.ps1            # chụp toàn bộ
#   powershell -File mobile\tool\shoot_with_fonts.ps1 "GIS Map"  # chỉ test có tên chứa chuỗi này
param([string]$Name = '')
$ErrorActionPreference = 'Stop'
$src = Resolve-Path (Join-Path $PSScriptRoot '..')
$tmp = Join-Path $env:TEMP 'smartfarm_mobile_shot'
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
New-Item -ItemType Directory $tmp | Out-Null
foreach ($d in 'lib', 'test', 'assets') { Copy-Item (Join-Path $src $d) (Join-Path $tmp $d) -Recurse }
foreach ($f in 'pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml') { Copy-Item (Join-Path $src $f) $tmp }

# Gắn fontFamily cho mọi `TextStyle(` trong lib, trừ các TextStyle đã có fontFamily (monospace...) để khỏi trùng tham số.
Get-ChildItem (Join-Path $tmp 'lib') -Recurse -Filter *.dart | ForEach-Object {
  $t = [IO.File]::ReadAllText($_.FullName)
  $out = New-Object System.Text.StringBuilder
  $i = 0
  while ($true) {
    $m = [regex]::Match($t.Substring($i), '(?<![A-Za-z_])TextStyle\(')
    if (-not $m.Success) { [void]$out.Append($t.Substring($i)); break }
    $start = $i + $m.Index + $m.Length
    # tìm dấu ngoặc đóng tương ứng để biết trong TextStyle này đã có fontFamily chưa
    $depth = 1; $j = $start
    while ($j -lt $t.Length -and $depth -gt 0) { $c = $t[$j]; if ($c -eq '(') { $depth++ } elseif ($c -eq ')') { $depth-- }; $j++ }
    $body = $t.Substring($start, [Math]::Max(0, $j - $start))
    [void]$out.Append($t.Substring($i, $start - $i))
    if ($body -notmatch 'fontFamily\s*:') { [void]$out.Append("fontFamily: 'Segoe UI', ") }
    $i = $start
  }
  [IO.File]::WriteAllText($_.FullName, $out.ToString())
}

Push-Location $tmp
try {
  flutter pub get --offline | Out-Null
  $args2 = @('test', 'test/generate_all_screenshots_test.dart', '--update-goldens')
  if ($Name) { $args2 += @('--plain-name', $Name) }
  & flutter @args2 2>&1 | Select-String -Pattern '^\d+:\d+ \+\d+.*(All|Some)|\[E\]|Error:' | Select-Object -Last 8
} finally { Pop-Location }

Get-ChildItem (Join-Path $tmp 'test\goldens') -Filter *.png | ForEach-Object { Copy-Item $_.FullName (Join-Path $src 'test\goldens') -Force }
Write-Host 'Xong: ảnh đã chép về mobile/test/goldens/'
