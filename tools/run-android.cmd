@echo off
setlocal
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"
subst U: "%PROJECT_ROOT%" >nul 2>&1
if not exist "U:\flutter_app\pubspec.yaml" (
  echo Could not map this project to drive U:. Check whether U: is already in use.
  exit /b 1
)
set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.21.9-hotspot"
set "PATH=%JAVA_HOME%\bin;%PATH%"
if not exist "%JAVA_HOME%\bin\java.exe" (
  echo Java 17 was not found at %JAVA_HOME%.
  exit /b 1
)
if not exist U:\.tmp mkdir U:\.tmp
set "TEMP=U:\.tmp"
set "TMP=U:\.tmp"
pushd U:\flutter_app
call flutter pub get
if errorlevel 1 (
  popd
  exit /b 1
)
call flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000
set "RUN_EXIT=%ERRORLEVEL%"
popd
exit /b %RUN_EXIT%
