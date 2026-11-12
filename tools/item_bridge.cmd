@echo off
setlocal
title NOVA Item Editor Bridge
python -u "%~dp0item_bridge.py" %*
set "bridge_exit=%errorlevel%"
echo.
echo The item bridge has stopped. If port 34873 is busy, an existing bridge may already be running.
echo You can use Export to repo in the Item Editor while that bridge is running.
pause
exit /b %bridge_exit%
