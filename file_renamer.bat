@echo off
setlocal enabledelayedexpansion
chcp 65001 > nul

:: ===================================================
:: ENVIRONMENT INITIALIZATION & PATH SETUP
:: ===================================================
set "CONFIG_FILE=%~dp0config.cfg"
set "LOG_FILE=%~dp0log.txt"

:: Capture current execution path safely without trailing backslash
set "CURRENT_RUN_DIR=%~dp0"
if "!CURRENT_RUN_DIR:~-1!"=="\" set "CURRENT_RUN_DIR=!CURRENT_RUN_DIR:~0,-1!"

:: Counters for session summary
set /a TOTAL_PROCESSED=0
set /a TOTAL_RENAMED=0
set /a TOTAL_SKIPPED=0
set /a TOTAL_ERRORS=0

:: Ensure log file exists without clearing existing session logs
if not exist "%LOG_FILE%" type nul > "%LOG_FILE%"

:: ===================================================
:: FASE A: AUTO-CREATION & LOADING OF CONFIG.CFG
:: ===================================================
if not exist "%CONFIG_FILE%" (
    (
        echo SOURCE_DIR=!CURRENT_RUN_DIR!
        echo EXTENSIONS=
        echo REMOVE_WORDS=
        echo REPLACE_SPACE=false
        echo ADD_ZERO=true
        echo DRY_RUN=false
    ) > "%CONFIG_FILE%"

    echo [NOTICE] config.cfg was missing and has been created with default values.
    echo [%date% !time!] [NOTICE] config.cfg was automatically generated pointing to execution folder. >> "%LOG_FILE%"
)

:: Set Default Configuration Values
set "SOURCE_DIR=!CURRENT_RUN_DIR!"
set "EXTENSIONS="
set "REMOVE_WORDS="
set "REPLACE_SPACE=false"
set "ADD_ZERO=true"
set "DRY_RUN=false"

:: Parse config.cfg line-by-line safely
for /f "usebackq tokens=1* delims=" %%A in ("%CONFIG_FILE%") do (
    set "LINE=%%A"
    if not "!LINE:~0,1!"==":" if not "!LINE:~0,1!"==";" if not "!LINE:~0,1!"=="#" (
        for /f "tokens=1* delims==" %%B in ("%%A") do (
            set "KEY=%%B"
            set "VALUE=%%C"
            :: Trim spaces
            for /f "tokens=*" %%D in ("!KEY!") do set "KEY=%%D"
            if defined VALUE (
                for /f "tokens=*" %%D in ("!VALUE!") do set "VALUE=%%D"
            ) else (
                set "VALUE="
            )
            set "!KEY!=!VALUE!"
        )
    )
)

:: Validate SOURCE_DIR existence
if "%SOURCE_DIR%"=="" set "SOURCE_DIR=!CURRENT_RUN_DIR!"
if not exist "%SOURCE_DIR%\" (
    echo [CRITICAL] Specified SOURCE_DIR does not exist: "%SOURCE_DIR%"
    echo [%date% !time!] [CRITICAL] Invalid SOURCE_DIR directory: "%SOURCE_DIR%" >> "%LOG_FILE%"
    pause
    exit /b
)

:: Write Session Header to Log
echo =================================================== >> "%LOG_FILE%"
echo SESSION STARTED ON: %date% AT !time! >> "%LOG_FILE%"
echo =================================================== >> "%LOG_FILE%"

echo Starting batch file renaming process...
echo Source Directory: "%SOURCE_DIR%"
echo ---------------------------------------------------

:: Convert EXTENSIONS parameter to lowercase for case-insensitive checks
set "EXT_LIST_LOWER="
if defined EXTENSIONS (
    for %%E in (%EXTENSIONS%) do (
        set "EXT_ITEM=%%E"
        call :LOWERCASE EXT_ITEM
        set "EXT_LIST_LOWER=!EXT_LIST_LOWER! .!EXT_ITEM!"
    )
)

:: Convert REMOVE_WORDS parameter to lowercase
set "REMOVE_WORDS_LOWER="
if defined REMOVE_WORDS (
    set "RAW_WORDS=%REMOVE_WORDS%"
    call :LOWERCASE RAW_WORDS
    set "REMOVE_WORDS_LOWER=!RAW_WORDS!"
)

:: ===================================================
:: FASE B: RECURSIVE FILE SCANNING
:: ===================================================
for /R "%SOURCE_DIR%" %%F in (*) do (
    if exist "%%F" (
        set "FULL_PATH=%%~fF"
        set "FILE_DIR=%%~dpF"
        set "ORIGINAL_NAME=%%~nF"
        set "ORIGINAL_EXT=%%~xF"

        set "PROCESS_THIS_FILE=0"

        if "%EXTENSIONS%"=="" (
            set "PROCESS_THIS_FILE=1"
        ) else (
            set "CURR_EXT=%%~xF"
            if "!CURR_EXT:~0,1!"=="." set "CURR_EXT=!CURR_EXT:~1!"
            call :LOWERCASE CURR_EXT
            
            for %%X in (!EXT_LIST_LOWER!) do (
                if ".!CURR_EXT!"=="%%X" set "PROCESS_THIS_FILE=1"
            )
        )

        if "!PROCESS_THIS_FILE!"=="1" (
            set /a TOTAL_PROCESSED+=1
            call :PROCESS_FILE "%%~fF"
        )
    )
)

:: ===================================================
:: FASE F: FINALIZATION & SUMMARY LOGGING
:: ===================================================
echo ---------------------------------------------------
echo Session finished!
echo Total Files Processed : !TOTAL_PROCESSED!
echo Total Files Renamed   : !TOTAL_RENAMED!
echo Total Files Skipped   : !TOTAL_SKIPPED!
echo Total Errors          : !TOTAL_ERRORS!

echo =================================================== >> "%LOG_FILE%"
echo SESSION SUMMARY: >> "%LOG_FILE%"
echo Total Processed: !TOTAL_PROCESSED! >> "%LOG_FILE%"
echo Total Renamed  : !TOTAL_RENAMED! >> "%LOG_FILE%"
echo Total Skipped  : !TOTAL_SKIPPED! >> "%LOG_FILE%"
echo Total Errors   : !TOTAL_ERRORS! >> "%LOG_FILE%"
echo SESSION FINISHED AT: !time! >> "%LOG_FILE%"
echo =================================================== >> "%LOG_FILE%"

pause
exit /b


:: ===================================================
:: SUBROUTINE: PROCESS SINGLE FILE (FASE C, D, E)
:: ===================================================
:PROCESS_FILE
set "FILE_FULL_PATH=%~1"
set "WORKING_DIR=%~dp1"
set "OLD_FILENAME=%~n1"
set "EXT_ORIG=%~x1"

set "NEW_NAME=%OLD_FILENAME%"

:: --- Step C1: Convert name to lowercase ---
call :LOWERCASE NEW_NAME

:: --- Step C2: Remove configured words/phrases ---
if defined REMOVE_WORDS_LOWER (
    :: Parse words separated by comma
    set "WORDS_TEMP=!REMOVE_WORDS_LOWER!"
    :REMOVE_LOOP
    for /f "tokens=1* delims=," %%A in ("!WORDS_TEMP!") do (
        set "WORD_TO_REMOVE=%%A"
        set "WORDS_TEMP=%%B"
        
        :: Trim leading spaces from phrase
        for /f "tokens=*" %%S in ("!WORD_TO_REMOVE!") do set "WORD_TO_REMOVE=%%S"
        
        if defined WORD_TO_REMOVE (
            set "NEW_NAME=!NEW_NAME:%WORD_TO_REMOVE%=!"
        )
        if defined WORDS_TEMP goto :REMOVE_LOOP
    )
)

:: --- Step C3: Add Leading Zero to single digits (1-9) ---
if /i "%ADD_ZERO%"=="true" (
    call :ADD_LEADING_ZEROS NEW_NAME
)

:: --- Step C4: Clean residual spaces (trim & collapse multiple spaces) ---
:COLLAPSE_SPACES
if not "!NEW_NAME:  =!"=="!NEW_NAME!" (
    set "NEW_NAME=!NEW_NAME:  = !"
    goto :COLLAPSE_SPACES
)

:: Trim leading spaces
:TRIM_LEFT
if "!NEW_NAME:~0,1!"==" " (
    set "NEW_NAME=!NEW_NAME:~1!"
    goto :TRIM_LEFT
)

:: Trim trailing spaces
:TRIM_RIGHT
if "!NEW_NAME:~-1!"==" " (
    set "NEW_NAME=!NEW_NAME:~0,-1!"
    goto :TRIM_RIGHT
)

:: --- Step C5: Space replacement with underline ---
if /i "%REPLACE_SPACE%"=="true" (
    set "NEW_NAME=!NEW_NAME: =_!"
    :COLLAPSE_UNDERSCORES
    if not "!NEW_NAME:__=!"=="!NEW_NAME!" (
        set "NEW_NAME=!NEW_NAME:__=_!"
        goto :COLLAPSE_UNDERSCORES
    )
)

:: Reattach original extension
set "FINAL_NEW_FILENAME=!NEW_NAME!!EXT_ORIG!"
set "OLD_FULL_FILENAME=%OLD_FILENAME%%EXT_ORIG%"

:: --- FASE D: Validation and Collision Checking ---
:: Check if unchanged
if "!OLD_FULL_FILENAME!"=="!FINAL_NEW_FILENAME!" (
    echo [SKIPPED/UNCHANGED] "!OLD_FULL_FILENAME!"
    echo [%date% !time!] [SKIPPED/UNCHANGED] "!OLD_FULL_FILENAME!" >> "%LOG_FILE%"
    set /a TOTAL_SKIPPED+=1
    exit /b
)

:: Check target collision
if exist "!WORKING_DIR!!FINAL_NEW_FILENAME!" (
    echo [SKIP/COLLISION] Target already exists: "!FINAL_NEW_FILENAME!"
    echo [%date% !time!] [SKIP/COLLISION] "!OLD_FULL_FILENAME!" -^> "!FINAL_NEW_FILENAME!" >> "%LOG_FILE%"
    set /a TOTAL_SKIPPED+=1
    exit /b
)

:: --- FASE E: Rename Execution / Dry-Run ---
if /i "%DRY_RUN%"=="true" (
    echo [DRY-RUN] "!OLD_FULL_FILENAME!" -^> "!FINAL_NEW_FILENAME!"
    echo [%date% !time!] [DRY-RUN] "!OLD_FULL_FILENAME!" -^> "!FINAL_NEW_FILENAME!" >> "%LOG_FILE%"
    set /a TOTAL_RENAMED+=1
) else (
    ren "!WORKING_DIR!!OLD_FULL_FILENAME!" "!FINAL_NEW_FILENAME!" >nul 2>&1
    if !errorlevel! equ 0 (
        echo [SUCCESS] "!OLD_FULL_FILENAME!" -^> "!FINAL_NEW_FILENAME!"
        echo [%date% !time!] [SUCCESS] "!OLD_FULL_FILENAME!" -^> "!FINAL_NEW_FILENAME!" >> "%LOG_FILE%"
        set /a TOTAL_RENAMED+=1
    ) else (
        echo [ERROR] Failed to rename "!OLD_FULL_FILENAME!"
        echo [%date% !time!] [ERROR] Failed to rename "!OLD_FULL_FILENAME!" >> "%LOG_FILE%"
        set /a TOTAL_ERRORS+=1
    )
)
exit /b


:: ===================================================
:: HELPER FUNCTION: LOWERCASE CONVERSION
:: ===================================================
:LOWERCASE
set "STR=!%1!"
for %%L in (a b c d e f g h i j k l m n o p q r s t u v w x y z) do (
    set "CHAR=%%L"
    for %%U in (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
        if "%%U"=="%%L" set "STR=!STR:%%U=%%L!"
    )
)
set "%1=!STR!"
exit /b


:: ===================================================
:: HELPER FUNCTION: ADD LEADING ZEROS TO DIGITS 1-9
:: ===================================================
:ADD_LEADING_ZEROS
set "TEXT=!%1!"
set "OUT="
set "LEN=0"

:: Calculate string length
set "TMP_STR=!TEXT!"
:LEN_LOOP
if defined TMP_STR (
    set "TMP_STR=!TMP_STR:~1!"
    set /a LEN+=1
    goto :LEN_LOOP
)

set /a LAST_IDX=LEN - 1
set "I=0"

:ZERO_SCAN_LOOP
if !I! geq !LEN! goto :END_ZERO_SCAN

set "CHAR=!TEXT:~%I%,1!"

:: Check if current char is a digit 1-9
set "IS_SINGLE_DIGIT=0"
if "!CHAR!"=="1" set "IS_SINGLE_DIGIT=1"
if "!CHAR!"=="2" set "IS_SINGLE_DIGIT=1"
if "!CHAR!"=="3" set "IS_SINGLE_DIGIT=1"
if "!CHAR!"=="4" set "IS_SINGLE_DIGIT=1"
if "!CHAR!"=="5" set "IS_SINGLE_DIGIT=1"
if "!CHAR!"=="6" set "IS_SINGLE_DIGIT=1"
if "!CHAR!"=="7" set "IS_SINGLE_DIGIT=1"
if "!CHAR!"=="8" set "IS_SINGLE_DIGIT=1"
if "!CHAR!"=="9" set "IS_SINGLE_DIGIT=1"

if "!IS_SINGLE_DIGIT!"=="1" (
    :: Inspect previous char
    set "PREV_IS_DIGIT=0"
    if !I! gtr 0 (
        set /a PREV_I=I - 1
        for %%P in (!PREV_I!) do set "PREV_CHAR=!TEXT:~%%P,1!"
        if "!PREV_CHAR!"=="0" set "PREV_IS_DIGIT=1"
        if "!PREV_CHAR!"=="1" set "PREV_IS_DIGIT=1"
        if "!PREV_CHAR!"=="2" set "PREV_IS_DIGIT=1"
        if "!PREV_CHAR!"=="3" set "PREV_IS_DIGIT=1"
        if "!PREV_CHAR!"=="4" set "PREV_IS_DIGIT=1"
        if "!PREV_CHAR!"=="5" set "PREV_IS_DIGIT=1"
        if "!PREV_CHAR!"=="6" set "PREV_IS_DIGIT=1"
        if "!PREV_CHAR!"=="7" set "PREV_IS_DIGIT=1"
        if "!PREV_CHAR!"=="8" set "PREV_IS_DIGIT=1"
        if "!PREV_CHAR!"=="9" set "PREV_IS_DIGIT=1"
    )

    :: Inspect next char
    set "NEXT_IS_DIGIT=0"
    if !I! lss !LAST_IDX! (
        set /a NEXT_I=I + 1
        for %%N in (!NEXT_I!) do set "NEXT_CHAR=!TEXT:~%%N,1!"
        if "!NEXT_CHAR!"=="0" set "NEXT_IS_DIGIT=1"
        if "!NEXT_CHAR!"=="1" set "NEXT_IS_DIGIT=1"
        if "!NEXT_CHAR!"=="2" set "NEXT_IS_DIGIT=1"
        if "!NEXT_CHAR!"=="3" set "NEXT_IS_DIGIT=1"
        if "!NEXT_CHAR!"=="4" set "NEXT_IS_DIGIT=1"
        if "!NEXT_CHAR!"=="5" set "NEXT_IS_DIGIT=1"
        if "!NEXT_CHAR!"=="6" set "NEXT_IS_DIGIT=1"
        if "!NEXT_CHAR!"=="7" set "NEXT_IS_DIGIT=1"
        if "!NEXT_CHAR!"=="8" set "NEXT_IS_DIGIT=1"
        if "!NEXT_CHAR!"=="9" set "NEXT_IS_DIGIT=1"
    )

    :: Pad with '0' only if isolated single digit
    if "!PREV_IS_DIGIT!"=="0" if "!NEXT_IS_DIGIT!"=="0" (
        set "CHAR=0!CHAR!"
    )
)

set "OUT=!OUT!!CHAR!"
set /a I+=1
goto :ZERO_SCAN_LOOP

:END_ZERO_SCAN
set "%1=!OUT!"
exit /b