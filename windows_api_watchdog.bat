"C:\Program Files (x86)\IceWarp\tool.exe" get system C_System_MySQLDefaultCharset > temp.txt
set /p RESULT=<temp.txt
echo %RESULT%
"C:\Program Files\Zabbix Agent\zabbix_sender.exe" -z "185.119.216.161" -s "icewarp.brano.cz" -k IWAPIMySQLCharset -o "%RESULT%"
@setlocal enableextensions enabledelayedexpansion
@echo off
ECHO.%RESULT%| FIND /I "latin1">Nul && ( 
  Echo.Found "latin1", OK
) || (
  Echo.Did not find "latin1", FAIL
  "C:\Program Files (x86)\IceWarp\tool.exe" set system C_System_MySQLDefaultCharset latin1
  net stop IceWarpCalendar
  timeout /t 10 /nobreak > NUL
  net start IceWarpCalendar
)
endlocal
