@echo off
 :: db admin user and password
 set dbUser=user
 set dbPassword=pass
 
 :: IceWarp installation dir
 set iwMainDir="C:\Program Files\IceWarp"
 
 :: backup retention temp dir
 set rtDir="C:\Program Files\IceWarp\backup\temp"
 
 :: how many older backups do we keep
 set rtDays=3
 
 :: directory where to store the backups
 set backupDir="C:\Program Files\IceWarp\backup\dbdump"
 
 :: MySQL data dir
 set mysqlDataDir="C:\Program Files\MariaDB 10.2\data"
 
 :: full path to mysqldump.exe binary
 set mysqldump="C:\Program Files\MariaDB 10.2\bin\mysqldump.exe"
 
 :: full path to 7z.exe binary
 set zip="C:\Program Files\7-Zip\7z.exe"

 if not exist %backupDir% mkdir %backupDir%
 if not exist %rtDir% mkdir %rtDir%

 :: get date ( on windows in cs lang, change delim from / to ., ie.: for /F "tokens=2-4 delims=. )
 for /F "tokens=2-4 delims=/ " %%i in ('date /t') do (
      set yy=%%i
      set mon=%%j
      set dd=%%k
 )

 :: get time 
 for /F "tokens=5-8 delims=:. " %%i in ('echo.^| time ^| find "current" ') do (
      set hh=%%i
      set min=%%j
 )

 echo dirName=%yy%%mon%%dd%_%hh%%min%
 set dirName=%yy%%mon%%dd%_%hh%%min%
 
 :: switch to the "data" folder
 pushd %mysqlDataDir%

 :: iterate over the folder structure in the "data" folder to get the databases
 for /d %%f in (*) do (

 if not exist %backupDir%\%dirName%\ (
      mkdir %backupDir%\%dirName%
 )

 %mysqldump% --host="localhost" --user=%dbUser% --password=%dbPassword% --single-transaction --add-drop-table --databases %%f > %backupDir%\%dirName%\%%f.sql

 %zip% a -tgzip %backupDir%\%dirName%\%%f.sql.gz %backupDir%\%dirName%\%%f.sql
 del %backupDir%\%dirName%\%%f.sql
 )
 popd

 :: backup server settings
 %iwMainDir%\tool.exe export account "*@*" u_backup > %backupDir%\%dirName%\acc_u_backup.csv
 %iwMainDir%\tool.exe export domain "*" d_backup > %backupDir%\%dirName%\dom_d_backup.csv
 %zip% a -r %backupDir%\%dirName%\cfg.7z %iwMainDir%\config
 %zip% a -r %backupDir%\%dirName%\cal.7z %iwMainDir%\calendar

 :: remove backups older than 3 days
 ROBOCOPY %backupDir% %rtDir% /mov /minage:%rtDays%
 del "%rtDir%" /q
