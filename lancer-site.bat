@echo off
rem Opens the site at http://localhost:8000 (Windows). Double-click to start.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serveur.ps1"
