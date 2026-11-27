# Tạo lại toàn bộ ảnh màn hình mobile (mobile/test/goldens/*.png), 1290x2796 (3x), đủ 3 vai trò + màn công khai.
#   powershell -File mobile/tool/generate_screenshots.ps1
#
# Vì sao chạy trên BẢN SAO của dự án: trong `flutter test` chữ không khai báo fontFamily rơi về font Ahem (toàn ô vuông). Ứng dụng có ~30 nút
# đặt `textStyle: TextStyle(fontSize, fontWeight)` không có fontFamily (trên điện thoại thật chữ vẫn đúng) nên ảnh Landing/Thiết bị bị ô vuông.
# Script thêm fontFamily 'Segoe UI' vào các kiểu chữ đó CHỈ ở bản sao tạm; mã ứng dụng thật không bị sửa.
# Dữ liệu mẫu: mobile/test/fixtures/screenshot_routes.json (ghi bằng mobile/tool/record_screenshot_fixtures.ps1) + làm giàu ở test/screenshot_enrich.dart.
$ErrorActionPreference = 'Stop'
$src = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pk = Join-Path $env:TEMP 'smartfarm_screenshots_pkg'
if (Test-Path $pk) { Remove-Item $pk -Recurse -Force }
New-Item -ItemType Directory $pk, "$pk\test" | Out-Null
foreach ($f in 'pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml') { if (Test-Path "$src\$f") { Copy-Item "$src\$f" $pk } }
Copy-Item "$src\assets" "$pk\assets" -Recurse
Copy-Item "$src\lib" "$pk\lib" -Recurse
Copy-Item "$src\test\fixtures" "$pk\test\fixtures" -Recurse
Copy-Item "$src\test\generate_all_screenshots_test.dart", "$src\test\screenshot_enrich.dart" "$pk\test"

# thêm fontFamily vào kiểu chữ của nút ở bản sao (bỏ qua chỗ đã có fontFamily để không trùng tham số)
$n = 0
Get-ChildItem "$pk\lib" -Recurse -Filter *.dart | ForEach-Object {
  $t = [IO.File]::ReadAllText($_.FullName)
  $new = [regex]::Replace($t, 'textStyle:\s*(?:const\s+)?TextStyle\(', {
    param($m)
    $after = $t.Substring($m.Index + $m.Length, [Math]::Min(220, $t.Length - $m.Index - $m.Length))
    $closeAt = $after.IndexOf('),')
    $scope = if ($closeAt -ge 0) { $after.Substring(0, $closeAt) } else { $after }
    if ($scope -match 'fontFamily') { return $m.Value }
    $script:n++
    return ($m.Value -replace 'const\s+', '') + "fontFamily: 'Segoe UI', "
  })
  if ($new -ne $t) { [IO.File]::WriteAllText($_.FullName, $new, (New-Object Text.UTF8Encoding($false))) }
}
Write-Host "Đã thêm fontFamily ở $n kiểu chữ của nút (bản sao tạm)."

Push-Location $pk
try {
  flutter pub get --offline | Out-Null
  flutter test test/generate_all_screenshots_test.dart --update-goldens
  if ($LASTEXITCODE -ne 0) { throw "Bộ chụp ảnh thất bại (mã $LASTEXITCODE)" }
} finally { Pop-Location }

$dest = Join-Path $src 'test\goldens'
New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item "$pk\test\goldens\*.png" $dest -Force
Write-Host ("Đã ghi {0} ảnh vào {1}" -f (Get-ChildItem "$pk\test\goldens\*.png").Count, $dest)
