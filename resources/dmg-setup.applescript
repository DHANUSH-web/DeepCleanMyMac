on run argv
  set imageName to item 1 of argv
  tell application "Finder"
    try
      close (every window whose name is imageName)
    end try
    tell disk imageName
      open
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set bounds of container window to {400, 120, 1120, 570}
      set viewOptions to icon view options of container window
      set arrangement of viewOptions to not arranged
      set icon size of viewOptions to 128
      set background picture of viewOptions to file ".background:background.png"
      set position of item "DeepCleanMyMac.app" of container window to {195, 215}
      set position of item "Applications" of container window to {520, 215}
      delay 2
      close
    end tell
  end tell
  do shell script "/usr/bin/SetFile -a C " & quoted form of ("/Volumes/" & imageName)
end run
