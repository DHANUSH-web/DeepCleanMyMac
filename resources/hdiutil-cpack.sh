#!/bin/sh
# CPack mounts the RW image with `hdiutil attach`. Without -nobrowse, Finder
# opens a default window before the setup script can style it.
if [ "$1" = "attach" ]; then
  shift
  exec /usr/bin/hdiutil attach -nobrowse "$@"
fi
exec /usr/bin/hdiutil "$@"
