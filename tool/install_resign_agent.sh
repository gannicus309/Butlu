#!/bin/zsh
# Runs tool/resign.sh when you log in to this Mac and every 2 hours after,
# so Butlu is re-signed before it expires. Safe to run again.
#
#   tool/install_resign_agent.sh             install / update
#   tool/install_resign_agent.sh --remove    uninstall

set -eu
REPO="${0:A:h:h}"
LABEL="com.butlu.resign"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
if [[ "${1:-}" == "--remove" ]]; then
  rm -f "$PLIST"
  print "Removed."
  exit 0
fi

chmod +x "$REPO/tool/resign.sh"
mkdir -p "${PLIST:h}"
cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>$REPO/tool/resign.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>StartInterval</key><integer>7200</integer>
  <key>ProcessType</key><string>Background</string>
</dict>
</plist>
EOF
launchctl bootstrap "gui/$(id -u)" "$PLIST"
print "Installed: runs at login and every 2 hours."
print "Log: ~/Library/Application Support/Butlu/resign.log"
