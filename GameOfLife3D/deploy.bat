@echo off
REM GameOfLife3D Deployment Script for Windows

echo GameOfLife3D Deployment Script
echo ================================

REM Configuration
set SERVER=hybridmachine.com
set REMOTE_PATH=hybridmachine.com/

REM Always build
echo Building project...
call npm run build
if errorlevel 1 (
    echo Build failed. Please fix errors and try again.
    pause
    exit /b 1
)

REM Create deployment directory
echo Preparing deployment files...
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
echo Uploading files to %SERVER%...
cd deploy_temp
scp -r * %SERVER%:%REMOTE_PATH%
if errorlevel 1 (
    echo Upload failed. Please check your connection and credentials.
    cd ..
    pause
    exit /b 1
)
cd ..

echo.
echo Setting permissions on remote server...
ssh %SERVER% "chmod -R 755 %REMOTE_PATH%"
if errorlevel 1 (
    echo Failed to set permissions. You may need to do this manually.
)

REM Cleanup
rmdir /s /q deploy_temp
echo Cleaned up temporary files

echo.
echo Deployment complete!
pause