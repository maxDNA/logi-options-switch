#!/usr/bin/env bash

# @raycast.schemaVersion 1
# @raycast.title Enable Logi Options+
# @raycast.description Start Logi Options+ and restore its user LaunchAgent without administrator privileges.
# @raycast.mode compact
# @raycast.packageName Logi Options+
# @version 1.1.3-raycast-onlyswitch
# Project source: https://github.com/maxDNA/logi-options-switch

set -euo pipefail

USER_ID="$(/usr/bin/id -u)"
USER_DOMAIN="gui/${USER_ID}"
USER_SERVICE="${USER_DOMAIN}/com.logi.cp-dev-mgr"
USER_PLIST="/Library/LaunchAgents/com.logi.optionsplus.plist"
APP_PATH="/Applications/logioptionsplus.app"

start_user_agent() {
  /bin/launchctl bootstrap "$USER_DOMAIN" "$USER_PLIST" >/dev/null 2>&1 || true
  /bin/launchctl kickstart -k "$USER_SERVICE" >/dev/null 2>&1 || true
}

open_logi_options() {
  if [[ -d "$APP_PATH" ]]; then
    /usr/bin/open "$APP_PATH" >/dev/null 2>&1 || true
  else
    /usr/bin/open -a "Logi Options+" >/dev/null 2>&1 || true
  fi
}

start_user_agent
open_logi_options
printf 'Logi Options+ enabled without administrator privileges.\n'
