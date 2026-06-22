# Me Time - local deploy script

Write-Host "--- [1/6] Preparing release version... ---" -ForegroundColor Cyan
$pubspecPath = "pubspec.yaml"
$pubContent = Get-Content $pubspecPath -Raw

if ($pubContent -notmatch "version: (\d+\.\d+\.\d+)\+(\d+)") {
    throw "Cannot find Flutter version in pubspec.yaml. Expected format: version: x.y.z+build"
}

$versionName = $Matches[1]
$buildNumber = [int]$Matches[2]

if ($buildNumber -lt 135) {
    $buildNumber = 135
} else {
    $buildNumber += 1
}

$newVersion = "$versionName+$buildNumber"
$pubContent = $pubContent -replace "version: \d+\.\d+\.\d+\+\d+", "version: $newVersion"
$pubContent | Out-File $pubspecPath -Encoding UTF8
Write-Host "Using release version: $newVersion" -ForegroundColor Yellow

Write-Host "--- [2/6] Building Android APK... ---" -ForegroundColor Cyan
C:\flutter\bin\flutter.bat build apk --release --build-name=$versionName --build-number=$buildNumber
if ($LASTEXITCODE -ne 0) { throw "APK build failed." }

Write-Host "--- [3/6] Cleaning and preparing web folder... ---" -ForegroundColor Cyan
if (Test-Path "build/web") { Remove-Item -Recurse -Force "build/web" }

Write-Host "--- [4/6] Building Web... ---" -ForegroundColor Cyan
C:\flutter\bin\flutter.bat build web --release --pwa-strategy=none
if ($LASTEXITCODE -ne 0) { throw "Web build failed." }

Write-Host "--- [5/6] Syncing APK and metadata... ---" -ForegroundColor Cyan
$iconPath = "assets/icon/app_icon.png"
if (Test-Path $iconPath) {
    if (!(Test-Path "build/web/icons")) { New-Item -ItemType Directory "build/web/icons" -Force | Out-Null }
    Copy-Item $iconPath "build/web/icons/Icon-192.png" -Force
    Copy-Item $iconPath "build/web/icons/Icon-512.png" -Force
    Copy-Item $iconPath "build/web/icons/Icon-maskable-192.png" -Force
    Copy-Item $iconPath "build/web/icons/Icon-maskable-512.png" -Force
    Copy-Item $iconPath "build/web/icons/final_logo.png" -Force
    Write-Host "Icons synced to build folder." -ForegroundColor Green
}

$apkPath = "build/app/outputs/flutter-apk/app-release.apk"
$gitHash = git rev-parse --short HEAD
$versionedApkName = "me-time-v$versionName-$buildNumber-$gitHash.apk"

if (!(Test-Path $apkPath)) {
    throw "APK not found: $apkPath"
}

Copy-Item $apkPath "build/web/$versionedApkName" -Force
Copy-Item $apkPath "build/web/app-release.apk" -Force
Write-Host "APK synced as $versionedApkName and app-release.apk" -ForegroundColor Green

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$jsonObj = @{
    version = $versionName
    buildNumber = $buildNumber.ToString()
    url = "https://metimegoalgoal.web.app/$versionedApkName"
    fallbackUrl = "https://metimegoalgoal.web.app/app-release.apk"
    apkFileName = $versionedApkName
    changelog = "v$versionName (Build $buildNumber): Local release build."
    timestamp = $timestamp
}
$versionJson = $jsonObj | ConvertTo-Json
$versionJson | Out-File "build/web/version.json" -Encoding UTF8
Write-Host "version.json generated: v$versionName+$buildNumber" -ForegroundColor Green

Write-Host "--- [6/6] Deploying to Firebase Hosting... ---" -ForegroundColor Cyan
firebase.cmd deploy --only hosting
if ($LASTEXITCODE -ne 0) { throw "Firebase deploy failed." }

Write-Host "--- DONE. Refresh browser with Ctrl+F5. ---" -ForegroundColor Magenta
