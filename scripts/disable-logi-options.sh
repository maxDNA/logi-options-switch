#!/usr/bin/env bash

# @raycast.schemaVersion 1
# @raycast.title Disable Logi Options+
# @raycast.description Temporarily stop Logi Options+ user processes and user LaunchAgent without administrator privileges.
# @raycast.mode compact
# @raycast.packageName Logi Options+
# @version 1.1.3-raycast-onlyswitch
# Project source: https://github.com/maxDNA/logi-options-switch
#
# Temporary effect: current login session only; Logi Options+ may start again after reboot or login.
# This script does not delete plist files or persistently disable launchd jobs.
# Stops app names: Logi Options+, logioptionsplus.
# Stops LaunchAgent service: gui/<current-user-id>/com.logi.cp-dev-mgr.
# Stops process names/patterns: Logi Options+, logioptionsplus, logioptionsplus_agent, logioptionsplus Helper*, LogiPluginService*, logi_crashpad_handler, and Logi Options+ app/plugin bundle paths.

set -euo pipefail

USER_ID="$(/usr/bin/id -u)"
USER_DOMAIN="gui/${USER_ID}"
USER_SERVICE="${USER_DOMAIN}/com.logi.cp-dev-mgr"

quit_gui() {
  /usr/bin/osascript -e 'tell application "Logi Options+" to quit' >/dev/null 2>&1 || true
  /usr/bin/osascript -e 'tell application "logioptionsplus" to quit' >/dev/null 2>&1 || true
}

stop_user_agent() {
  /bin/launchctl bootout "$USER_SERVICE" >/dev/null 2>&1 || true
}

kill_user_processes() {
  local process_names=(
    "Logi Options+"
    "logioptionsplus"
    "logioptionsplus_agent"
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
    "/Library/Application Support/Logitech.localized/LogiOptionsPlus/logioptionsplus_agent.app/Contents/MacOS/logioptionsplus_agent"
    "/Library/Application Support/Logitech.localized/LogiOptionsPlus/logioptionsplus_agent.app/Contents/MacOS/logi_crashpad_handler"
  )

  local process_pattern
  for process_pattern in "${process_patterns[@]}"; do
    /usr/bin/pkill -f "$process_pattern" >/dev/null 2>&1 || true
  done
}

quit_gui
stop_user_agent
kill_user_processes
printf 'Logi Options+ disabled without administrator privileges.\n'
