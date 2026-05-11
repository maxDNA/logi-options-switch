#!/usr/bin/env bash

# @raycast.schemaVersion 1
# @raycast.title Enable Logi Options+
# @raycast.description Start the Logi Options+ user LaunchAgent without opening the app window.
# @raycast.mode compact
# @raycast.packageName Logi Options+
# @version 1.1.4-raycast-onlyswitch
# Project source: https://github.com/maxDNA/logi-options-switch

set -euo pipefail

USER_ID="$(/usr/bin/id -u)"
USER_DOMAIN="gui/${USER_ID}"
USER_SERVICE="${USER_DOMAIN}/com.logi.cp-dev-mgr"
USER_PLIST="/Library/LaunchAgents/com.logi.optionsplus.plist"
start_user_agent() {
  /bin/launchctl bootstrap "$USER_DOMAIN" "$USER_PLIST" >/dev/null 2>&1 || true
  /bin/launchctl kickstart -k "$USER_SERVICE" >/dev/null 2>&1 || true
}

start_user_agent
printf 'Logi Options+ enabled without opening the app window.\n'
