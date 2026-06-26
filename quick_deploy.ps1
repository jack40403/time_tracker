# Me Time - local deploy script

Set-Location $PSScriptRoot

Write-Host "--- [1/6] Preparing release version... ---" -ForegroundColor Cyan
$pubspecPath = "pubspec.yaml"
$keyPropertiesPath = "android/key.properties"
$releaseKeystorePath = "android/app/upload-keystore.jks"

if (!(Test-Path $keyPropertiesPath)) {
    throw "Missing android/key.properties. Refusing to build a release APK with the debug signing key."
}

if (!(Test-Path $releaseKeystorePath)) {
    throw "Missing release keystore: $releaseKeystorePath"
}

$localPropertiesPath = "android/local.properties"
if (Test-Path $localPropertiesPath) {
    $localProperties = Get-Content $localPropertiesPath
    $sdkDirLine = $localProperties | Where-Object { $_ -match '^sdk\.dir=' } | Select-Object -First 1
    if ($sdkDirLine) {
        $sdkDir = ($sdkDirLine -replace '^sdk\.dir=', '') -replace '\\\\', '\'
        $env:ANDROID_HOME = $sdkDir
        $env:ANDROID_SDK_ROOT = $sdkDir
        Write-Host "Using Android SDK: $sdkDir" -ForegroundColor Green
    }
}

$pubContent = Get-Content $pubspecPath -Raw

if ($pubContent -notmatch "version: (\d+\.\d+\.\d+)\+(\d+)") {
    throw "Cannot find Flutter version in pubspec.yaml. Expected format: version: x.y.z+build"
}

$versionName = $Matches[1]
$buildNumber = [int64]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())

Write-Host "Using release version: $versionName+$buildNumber" -ForegroundColor Yellow

Write-Host "--- [2/6] Building Android APK... ---" -ForegroundColor Cyan
flutter build apk --release --build-name=$versionName --build-number=$buildNumber
if ($LASTEXITCODE -ne 0) { throw "APK build failed." }

Write-Host "--- [3/6] Cleaning and preparing web folder... ---" -ForegroundColor Cyan
if (Test-Path "build/web") { Remove-Item -Recurse -Force "build/web" }

Write-Host "--- [4/6] Building Web... ---" -ForegroundColor Cyan
flutter build web --release --pwa-strategy=none
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
cmd.exe /c "npx firebase-tools deploy --only hosting"
if ($LASTEXITCODE -ne 0) { throw "Firebase deploy failed." }

Write-Host "--- DONE. Refresh browser with Ctrl+F5. ---" -ForegroundColor Magenta
