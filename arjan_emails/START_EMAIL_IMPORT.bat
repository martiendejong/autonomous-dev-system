@echo off
REM Email Import - Arjan Stroeve
REM Dubbelklik dit bestand om de email import te starten

echo.
echo ================================================================
echo  Email Import - Arjan Stroeve en Gerelateerde Contacten
echo ================================================================
echo.
echo Dit script importeert emails van/naar:
echo   - Arjan Stroeve
echo   - Allan Drenth
echo   - Rinus Huisman / Socranext
echo   - Social Media Hulp
echo   - Eethuys de Steen
echo   - Cassandra project
echo.
echo Van accounts:
echo   - info@martiendejong.nl
echo   - martiendejong2008@gmail.com
echo.
echo Output: C:\scripts\arjan_emails\emails\
echo.
echo ================================================================
echo.
pause

REM Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] Python niet gevonden!
    echo Installeer Python van https://www.python.org/downloads/
    echo.
    pause
    exit /b 1
)

echo [OK] Python gevonden
echo.

REM Run import script
echo Starten email import...
echo Het script zal vragen om wachtwoorden voor beide accounts.
echo.
echo BELANGRIJK:
echo   - Als je 2FA hebt: gebruik App Password
echo   - App Password maken: https://myaccount.google.com/apppasswords
echo   - IMAP moet ingeschakeld zijn in Gmail settings
echo.
pause

cd /d C:\scripts\tools
python import-arjan-emails.py

echo.
echo ================================================================
echo  Import voltooid!
echo ================================================================
echo.
echo Check de resultaten in: C:\scripts\arjan_emails\emails\
echo.
pause

REM Open folder
start explorer "C:\scripts\arjan_emails\emails"
