@echo off
set "PATH=%PATH%;C:\shorebird-stable\bin;C:\flutter\bin"
powershell -ExecutionPolicy Bypass -File C:\shorebird-stable\bin\shorebird.ps1 patch android --release-version 1.0.0+2 --force --description "Account isolation fix"
