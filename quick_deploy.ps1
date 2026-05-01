# Elite Time Tracker - Pro Deploy Script v3 (Ultra Robust)

Write-Host "--- [1/5] Building Android APK... ---" -ForegroundColor Cyan
C:\flutter\bin\flutter.bat build apk --release

Write-Host "--- [2/5] Cleaning and Preparing Web Folder... ---" -ForegroundColor Cyan
if (Test-Path "build/web") { Remove-Item -Recurse -Force "build/web" }

Write-Host "--- [3/5] Extracting Version and Updating pubspec.yaml... ---" -ForegroundColor Cyan
$pubContent = Get-Content "pubspec.yaml" -Raw
if ($pubContent -match "version: (\d+\.\d+\.\d+)\+(\d+)") {
    $versionName = $Matches[1]
    $buildNumber = [int]$Matches[2] + 1
    $newVersion = "$versionName+$buildNumber"
    $pubContent = $pubContent -replace "version: \d+\.\d+\.\d+\+\d+", "version: $newVersion"
    $pubContent | Out-File "pubspec.yaml" -Encoding UTF8
    Write-Host "New Version: $newVersion" -ForegroundColor Yellow
}

Write-Host "--- [4/5] Building Web... ---" -ForegroundColor Cyan
C:\flutter\bin\flutter.bat build web --release --pwa-strategy=none

Write-Host "--- [5/5] POST-BUILD SYNC (THE FORCE STEP) ---" -ForegroundColor Cyan
# 1. 確保圖示絕對正確 (從 assets 拷貝到 build/web/icons)
$iconPath = "assets/icon/app_icon.png"
if (Test-Path $iconPath) {
    if (!(Test-Path "build/web/icons")) { New-Item -ItemType Directory "build/web/icons" -Force }
    Copy-Item $iconPath "build/web/icons/Icon-192.png" -Force
    Copy-Item $iconPath "build/web/icons/Icon-512.png" -Force
    Copy-Item $iconPath "build/web/icons/Icon-maskable-192.png" -Force
    Copy-Item $iconPath "build/web/icons/Icon-maskable-512.png" -Force
    Copy-Item $iconPath "build/web/icons/final_logo.png" -Force
    Write-Host "✅ Icons synced to build folder." -ForegroundColor Green
}

# 2. 確保 APK 絕對正確
$apkPath = "build/app/outputs/flutter-apk/app-release.apk"
$versionedApkName = "app-v$($versionName.Replace('.', '_'))-$buildNumber.apk"
if (Test-Path $apkPath) {
    Copy-Item $apkPath "build/web/$versionedApkName" -Force
    Copy-Item $apkPath "build/web/app-release.apk" -Force
    Write-Host "?? APK synced as $versionedApkName" -ForegroundColor Green
}

# 3. 生成正確的 version.json (加入時間戳防止快取)
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$jsonObj = @{
  version = $versionName
  buildNumber = $buildNumber.ToString()
  url = "https://metimegoalgoal.web.app/$versionedApkName"
  changelog = "v$versionName (Build $buildNumber): Updated background service and notification behavior."
  timestamp = $timestamp
}
$versionJson = $jsonObj | ConvertTo-Json
[System.IO.File]::WriteAllText("build/web/version.json", $versionJson, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "version.json generated: v$versionName+$buildNumber" -ForegroundColor Green

Write-Host "--- FINISHING: Deploying to Firebase ---" -ForegroundColor Cyan
firebase.cmd deploy --only hosting
Write-Host "--- DONE! Please refresh your browser (Ctrl+F5) ---" -ForegroundColor Magenta
