@echo off
rem ============================================================
rem  Jiyu - push to GitHub and trigger cloud IPA build
rem  Double-click to run.
rem  BEFORE running: create an EMPTY repo on GitHub:
rem    https://github.com/new  ->  name: jiyu  ->  do NOT add README
rem  If you named it differently, edit the "set REPO=" line below.
rem ============================================================
setlocal
cd /d "%~dp0"

set USER=laa200x-arch
set REPO=jiyu
set REMOTE=https://github.com/%USER%/%REPO%.git

echo.
echo [1/4] Adding remote: %REMOTE%
git remote remove origin 2>nul
git remote add origin %REMOTE%

echo [2/4] Switching branch to main
git branch -M main

echo [3/4] Pushing... (a GitHub login window may pop up - please sign in)
git push -u origin main
if errorlevel 1 goto :failed

echo [4/4] DONE!
echo.
echo Push OK. The cloud build has started automatically.
echo Open this page to watch / trigger it manually:
echo   https://github.com/%USER%/%REPO%/actions
echo.
echo When the build finishes (5-10 min), download "Jiyu-unsigned.ipa"
echo from the Artifacts section of the run page.
echo.
pause
exit /b 0

:failed
echo.
echo ============================================================
echo  PUSH FAILED - common causes:
echo   1. The repo does not exist yet:
echo        https://github.com/new  ->  name: %REPO%
echo      (do NOT check "Add a README file")
echo      then run this file again.
echo   2. You named the repo differently: edit "set REPO=" above.
echo   3. GitHub login window was cancelled: run again.
echo   4. Repo already has a README (created by GitHub): run
echo        git pull origin main --allow-unrelated-histories
echo      then run this file again.
echo ============================================================
echo.
pause
exit /b 1
