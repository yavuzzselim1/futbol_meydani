$ErrorActionPreference = "Stop"

$manifest = Join-Path $PSScriptRoot "android\app\src\main\AndroidManifest.xml"

if (-not (Test-Path $manifest)) {
    throw "AndroidManifest.xml bulunamadi. Bu dosyayi futbol_meydani proje ana klasorune kopyalayip tekrar calistir."
}

$content = [System.IO.File]::ReadAllText($manifest)
$appName = "Futbol Meydan" + [char]0x0131
$updated = [System.Text.RegularExpressions.Regex]::Replace(
    $content,
    'android:label="[^"]*"',
    ('android:label="' + $appName + '"')
)

if ($updated -notmatch 'android.permission.INTERNET') {
    $updated = $updated -replace '<manifest([^>]*)>', ('<manifest$1>' + [Environment]::NewLine + '    <uses-permission android:name="android.permission.INTERNET" />')
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($manifest, $updated, $utf8)

Write-Host "Uygulama adi: Futbol Meydani olarak ayarlandi." -ForegroundColor Green
Write-Host "Adaptive Android simgeleri olusturuluyor..." -ForegroundColor Cyan

dart run flutter_launcher_icons
dart run flutter_native_splash:create

Write-Host "Android adi, simgesi, internet izni ve acilis ekrani hazir." -ForegroundColor Green
