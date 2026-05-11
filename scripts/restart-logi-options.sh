#!/usr/bin/env bash

# @raycast.schemaVersion 1
# @raycast.title Restart Logi Options+
# @raycast.description Restart the Logi Options+ user agent without opening the app window.
# @raycast.mode compact
# @raycast.packageName Logi Options+
# @version 1.1.4-raycast-onlyswitch
# Project source: https://github.com/maxDNA/logi-options-switch

set -euo pipefail

USER_ID="$(/usr/bin/id -u)"
USER_DOMAIN="gui/${USER_ID}"
USER_SERVICE="${USER_DOMAIN}/com.logi.cp-dev-mgr"
USER_PLIST="/Library/LaunchAgents/com.logi.optionsplus.plist"
warn() {
  printf 'warning: %s\n' "$1" >&2
}

quit_gui() {
  /usr/bin/osascript -e 'tell application "Logi Options+" to quit' >/dev/null 2>&1 || true
  /usr/bin/osascript -e 'tell application "logioptionsplus" to quit' >/dev/null 2>&1 || true
}

kill_user_processes() {
  local process_names=(
    "Logi Options+"
    "logioptionsplus"
    "logioptionsplus Helper"
    "logioptionsplus Helper (GPU)"
    "logioptionsplus Helper (Renderer)"
    "LogiPluginService"
    "LogiPluginServiceExt"
    "LogiPluginServiceNative"
    "logi_crashpad_handler"
  )

  local process_name
  for process_name in "${process_names[@]}"; do
    /usr/bin/pkill -x "$process_name" >/dev/null 2>&1 || true
  done

  local process_patterns=(
    "/Applications/logioptionsplus.app/Contents/"
    "/Applications/Utilities/LogiPluginService.app/Contents/"
    "/Library/Application Support/Logitech.localized/LogiOptionsPlus/logioptionsplus_agent.app/Contents/MacOS/logi_crashpad_handler"
  )

  local process_pattern
  for process_pattern in "${process_patterns[@]}"; do
    /usr/bin/pkill -f "$process_pattern" >/dev/null 2>&1 || true
  done
}

bootstrap_user_agent_if_needed() {
  if /bin/launchctl print "$USER_SERVICE" >/dev/null 2>&1; then
    return 0
  fi

  /bin/launchctl bootstrap "$USER_DOMAIN" "$USER_PLIST" >/dev/null 2>&1 || true
}

restart_user_agent() {
  bootstrap_user_agent_if_needed

  if ! /bin/launchctl kickstart -k "$USER_SERVICE" >/dev/null 2>&1; then
    warn "could not kickstart $USER_SERVICE"
  fi
}

wait_for_user_agent() {
  local attempt
  for attempt in 1 2 3 4 5; do
    if /bin/launchctl print "$USER_SERVICE" >/dev/null 2>&1; then
      return 0
    fi
    /bin/sleep 1
  done

  warn "Logi Options+ user agent was not confirmed after restart"
}

quit_gui
kill_user_processes
restart_user_agent
wait_for_user_agent
printf 'Logi Options+ restarted without opening the app window.\n'
