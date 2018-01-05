echo "Updating Plugin"
set "dest=C:\Users\%username%\AppData\Roaming\SketchUp\SketchUp 2017\SketchUp\Plugins"
ROBOCOPY "\\sbs\Shared Docs\Software Installs\Sketchup\DT Takeoff Tools v3\Plugins" "%dest%" /XF *.ink /E /IS
echo "Update Plugin Completed"
echo "Updating Materials"
set "dest=C:\Users\%username%\AppData\Roaming\SketchUp\SketchUp 2017\SketchUp\Materials"
ROBOCOPY "\\sbs\Shared Docs\Software Installs\Sketchup\DT Takeoff Tools v3\Materials" "%dest%" /XF *.ink /E /IS 
echo "Update Materials Completed"
pause
