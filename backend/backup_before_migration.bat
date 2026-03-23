@echo off
REM ===========================================
REM Backup Database Script - Pre teacher_id migration
REM Chay tu thu muc backend\
REM ===========================================

set "PG_BIN=C:\Program Files\PostgreSQL\17\bin"
set DB_NAME=vedura_db
set DB_USER=vedura
set DB_HOST=localhost
set BACKUP_DIR=backups
set TIMESTAMP=%date:~-4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set BACKUP_FILE=%BACKUP_DIR%\backup_before_teacher_id_migration_%TIMESTAMP%

echo ============================================
echo Backup Database - Pre-Migration
echo ============================================
echo Database: %DB_NAME%
echo Timestamp: %TIMESTAMP%
echo Backup Dir: %BACKUP_FILE%
echo ============================================

REM Create backup directory
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

REM Full database backup
echo [1/3] Dang chay full backup...
"%PG_BIN%\pg_dump" -h %DB_HOST% -U %DB_USER% -d %DB_NAME% -F c -f "%BACKUP_FILE%_full.dump"

if %errorlevel% neq 0 (
    echo [ERROR] Backup that bai! Kiem tra lai ket noi database.
    exit /b 1
)

REM Schema only backup
echo [2/3] Dang backup schema...
"%PG_BIN%\pg_dump" -h %DB_HOST% -U %DB_USER% -d %DB_NAME% -F p -f "%BACKUP_FILE%_schema.sql"

if %errorlevel% neq 0 (
    echo [ERROR] Schema backup that bai!
    exit /b 1
)

REM Data backup - courses table (quan trong nhat)
echo [3/3] Dang backup courses table...
"%PG_BIN%\pg_dump" -h %DB_HOST% -U %DB_USER% -d %DB_NAME% -t courses -F c -f "%BACKUP_FILE%_courses.dump"

if %errorlevel% neq 0 (
    echo [ERROR] Courses backup that bai!
    exit /b 1
)

echo ============================================
echo Backup hoan tat!
echo.
echo Cac file backup:
echo   - %BACKUP_FILE%_full.dump
echo   - %BACKUP_FILE%_schema.sql
echo   - %BACKUP_FILE%_courses.dump
echo.
echo Tien hanh chay migration:
echo   docker compose exec api alembic upgrade head
echo ============================================
pause
