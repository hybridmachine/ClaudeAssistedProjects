@echo off
REM GameOfLife3D Deployment Script for Windows
REM For DreamHost VPS deployment

echo 🚀 GameOfLife3D Deployment Script
echo ================================

REM Configuration - UPDATE THESE VALUES
set SERVER=vps66522.dreamhostps.com
set USER=wd65c02
set REMOTE_PATH=/home/wd65c02

REM Check if build exists
if not exist "dist" (
    echo ⚠️  No dist folder found. Building project...
    call npm run build
    if errorlevel 1 (
        echo ❌ Build failed. Please fix errors and try again.
        pause
        exit /b 1
    )
)

REM Create deployment directory
echo 📦 Preparing deployment files...
if exist deploy_temp rmdir /s /q deploy_temp
mkdir deploy_temp

REM Copy essential files
copy index.html deploy_temp\
copy styles.css deploy_temp\
xcopy /e /i dist deploy_temp\dist
mkdir deploy_temp\node_modules\three\build
copy node_modules\three\build\three.module.js deploy_temp\node_modules\three\build\

REM Create .htaccess file
echo # Enable ES6 modules > deploy_temp\.htaccess
echo AddType application/javascript .js >> deploy_temp\.htaccess
echo AddType application/javascript .mjs >> deploy_temp\.htaccess
echo. >> deploy_temp\.htaccess
echo # Enable compression >> deploy_temp\.htaccess
echo ^<IfModule mod_deflate.c^> >> deploy_temp\.htaccess
echo     AddOutputFilterByType DEFLATE text/html text/css application/javascript >> deploy_temp\.htaccess
echo ^</IfModule^> >> deploy_temp\.htaccess

echo.
echo 🌐 Files prepared for upload to %SERVER%
echo.
echo MANUAL UPLOAD REQUIRED:
echo 1. Use your preferred SFTP client (FileZilla, WinSCP, etc.)
echo 2. Connect to %SERVER% with your credentials
echo 3. Upload all contents of 'deploy_temp' folder to your domain directory
echo 4. Make sure to preserve the folder structure
echo.
echo Alternative: Use scp command if you have it installed:
echo scp -r deploy_temp/* %USER%@%SERVER%:%REMOTE_PATH%
echo.

REM Keep window open
echo Press any key to cleanup temporary files and exit...
pause > nul

REM Cleanup
rmdir /s /q deploy_temp
echo 🧹 Cleaned up temporary files

echo.
echo 🎉 Deployment preparation complete!
echo Remember to update the USER and REMOTE_PATH variables in this script
pause