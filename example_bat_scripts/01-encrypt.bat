@echo off

rem Architecture check ==============================================

set "ARCH=32bit"
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "ARCH=64bit"
if "%PROCESSOR_ARCHITECTURE%"=="IA64" set "ARCH=64bit"
if defined PROCESSOR_ARCHITEW6432 set "ARCH=64bit"

rem Determine script dir ============================================

set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%a in ("%SCRIPT_DIR%") do set "PARENT_DIR=%%~dpa"
set "PARENT_DIR=%PARENT_DIR:~0,-1%"

rem File definitions ================================================

set ISQL=%PARENT_DIR%\%ARCH%\isql.exe

rem Others ==========================================================

set GREEN=Key=Green 0xab,0xd7,0x34,0x63,0xae,0x19,0x52,0x00,0xb8,0x84,0xa3,0x44,0xbd,0x11,0x9f,0x72,0xe0,0x04,0x68,0x4f,0xc4,0x89,0x3b,0x20,0x8d,0x2a,0xa7,0x07,0x32,0x3b,0x5e,0x74,
set "TEMP_SQL=%SCRIPT_DIR%\isql_commands_%RANDOM%.sql"
set USER=SYSDBA
set PASS=masterkey

rem Main program ====================================================

if not exist "%SCRIPT_DIR%\employee.fdb" (
    echo ERROR: %SCRIPT_DIR%\employee.fdb not found! Please, run crypt plugin setup again.
    exit /b 1
)

copy %SCRIPT_DIR%\employee.fdb %SCRIPT_DIR%\emp-crypted.fdb
set EMP=%SCRIPT_DIR%\emp-crypted.fdb


rem Write SQL commands to temporary file
(
echo alter database encrypt with dbcrypt key Green;
echo commit;
echo show database;
echo exit;
) > "%TEMP_SQL%"

echo Executing "isql localhost:%EMP% -i %TEMP_SQL%"
echo SQL alter database encrypt with dbcrypt key Green;
%ISQL% localhost:"%EMP%" -i "%TEMP_SQL%" -user "%USER%" -password "%PASS%"

del "%TEMP_SQL%" 2>nul
