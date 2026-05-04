#!/usr/bin/env bash

# @raycast.schemaVersion 1
# @raycast.title Check Logi Options+
# @raycast.description Print on or off for Only Switch based on the Logi Options+ user agent/application state.
# @raycast.mode compact
# @raycast.packageName Logi Options+
# @version 1.1.3-raycast-onlyswitch
# Project source: https://github.com/maxDNA/logi-options-switch

set -euo pipefail

USER_ID="$(/usr/bin/id -u)"
USER_DOMAIN="gui/${USER_ID}"
USER_SERVICE="${USER_DOMAIN}/com.logi.cp-dev-mgr"

agent_is_running() {
  /bin/launchctl print "$USER_SERVICE" 2>/dev/null | /usr/bin/grep -Fq 'state = running'
}

logi_app_is_registered() {
  /bin/launchctl print "$USER_DOMAIN" 2>/dev/null | /usr/bin/grep -Fq 'application.com.logi.optionsplus'
}

if agent_is_running || logi_app_is_registered; then
  printf 'on\n'
else
  printf 'off\n'
fi
