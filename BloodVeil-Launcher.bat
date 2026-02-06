@echo off
title BloodVeil Launcher
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0BloodVeil-Launcher.ps1"
if errorlevel 1 pause
exit
