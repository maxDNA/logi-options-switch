#!/usr/bin/env bash

# Installer for Raycast and Only Switch compatible scripts to temporarily disable, enable, and restart Logi Options+ on macOS.
# @version 1.3.6
# Project source: https://github.com/maxDNA/logi-options-switch

set -euo pipefail

EVOLUTION_NAME="Logi Options+"
RESTART_EVOLUTION_NAME="Restart Logi Options+"
DEFAULT_INSTALL_DIR="$HOME/Documents/Scripts"
DEFAULT_INSTALL_DIR_LABEL="~/Documents/Scripts"
ONLYSWITCH_BUNDLE_ID="jacklandrin.OnlySwitch"
DB_PATH="$HOME/Library/Group Containers/B22726TNGH.OnlySwitch.shared/onlyswitch.sqlite"
PREFS_PATH="$HOME/Library/Preferences/jacklandrin.OnlySwitch.plist"
ENABLE_FILE_NAME="enable-logi-options.sh"
DISABLE_FILE_NAME="disable-logi-options.sh"
CHECK_FILE_NAME="check-logi-options.sh"
RESTART_FILE_NAME="restart-logi-options.sh"
SCRIPT_VERSION="1.1.3-raycast-onlyswitch"
RESTART_ONLYSWITCH=1
OPEN_INSTALL_DIR=1
INSTALL_DIR=""
USE_DEFAULT_DIR=0

usage() {
  cat <<'USAGE'
Usage: install-logi-options-switch.sh [--default] [--install-dir PATH] [--no-restart] [--no-open-folder] [--help]

Installs Raycast-compatible Logi Options+ scripts into the selected
directory and imports/updates a "Logi Options+" Evolution switch and a
"Restart Logi Options+" Evolution button.
Without path options, the installer asks whether to use the default
directory or choose a custom folder. The default directory is created
if it does not exist.

Options:
  --default           Install directly to $HOME/Documents/Scripts without prompting.
  --install-dir PATH  Install scripts directly into PATH.
  --no-restart        Do not reopen Only Switch after database import.
  --no-open-folder    Do not open the install directory in Finder after installation.
  --help              Show this help.
USAGE
}

die() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

info() {
  printf '%s\n' "$1"
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --default)
        USE_DEFAULT_DIR=1
        ;;
      --install-dir)
        [[ "$#" -ge 2 ]] || die "--install-dir requires a path"
        INSTALL_DIR="$2"
        shift
        ;;
      --no-restart)
        RESTART_ONLYSWITCH=0
        ;;
      --no-open-folder)
        OPEN_INSTALL_DIR=0
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
    shift
  done
}

choose_install_dir() {
  if [[ -n "$INSTALL_DIR" ]]; then
    return
  fi

  if [[ "$USE_DEFAULT_DIR" -eq 1 ]]; then
    INSTALL_DIR="$DEFAULT_INSTALL_DIR"
    return
  fi

  local choice
  if ! choice="$(/usr/bin/osascript - "$DEFAULT_INSTALL_DIR_LABEL" <<'APPLESCRIPT' 2>/dev/null
on run argv
  set defaultPathLabel to item 1 of argv
  set promptText to "Install Logi Options+ scripts to the default script directory?" & return & return & defaultPathLabel & return & return & "The folder will be created if it does not exist. Add this folder to Raycast Script Commands if Raycast has not already indexed it."
  set dialogResult to display dialog promptText buttons {"Cancel", "Choose Folder", "Use Default"} default button "Use Default" cancel button "Cancel" with title "Logi Options+ Installer"
  button returned of dialogResult
end run
APPLESCRIPT
)"; then
    die "install directory prompt was cancelled or unavailable; use --default or --install-dir PATH"
  fi

  if [[ "$choice" == "Use Default" ]]; then
    INSTALL_DIR="$DEFAULT_INSTALL_DIR"
    return
  fi

  [[ "$choice" == "Choose Folder" ]] || die "unexpected install directory choice: $choice"

  local chosen_dir
  if chosen_dir="$(/usr/bin/osascript <<'APPLESCRIPT' 2>/dev/null
set defaultLocation to (path to library folder from user domain)
set chosenFolder to choose folder with prompt "Choose the Raycast script directory for Logi Options+ scripts:" default location defaultLocation
POSIX path of chosenFolder
APPLESCRIPT
)"; then
    INSTALL_DIR="${chosen_dir%/}"
  else
    die "folder selection was cancelled; installation aborted"
  fi
}

detect_version() {
  local path="$1"
  local version
  version="$(/usr/bin/awk '/^# @version / {print $3; exit}' "$path" 2>/dev/null || true)"
  if [[ -n "$version" ]]; then
    printf '%s\n' "$version"
  else
    printf 'unknown\n'
  fi
}

backup_target_script() {
  local path="$1"
  [[ -e "$path" ]] || return 0

  local filename version backup_dir timestamp
  filename="$(/usr/bin/basename "$path")"
  version="$(detect_version "$path")"
  backup_dir="$(/usr/bin/dirname "$path")/bak"
  timestamp="$(/bin/date +%Y%m%d-%H%M%S)"
  /bin/mkdir -p "$backup_dir"
  /bin/cp -p "$path" "$backup_dir/$filename.v$version.bak-$timestamp.sh" \
    || die "failed to back up existing script: $path"
  info "Backed up existing script: bak/$filename.v$version.bak-$timestamp.sh"
}

install_script_file() {
  local path="$1"
  backup_target_script "$path"
  /bin/chmod 755 "$path"
  info "Installed script: $path"
}

install_scripts() {
  /bin/mkdir -p "$INSTALL_DIR"

  local enable_path="$INSTALL_DIR/$ENABLE_FILE_NAME"
  local disable_path="$INSTALL_DIR/$DISABLE_FILE_NAME"
  local check_path="$INSTALL_DIR/$CHECK_FILE_NAME"

  backup_target_script "$enable_path"
  /bin/cat >"$enable_path" <<'ENABLE_SCRIPT'
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
ENABLE_SCRIPT
  /bin/chmod 755 "$enable_path"
  info "Installed script: $enable_path"

  backup_target_script "$disable_path"
  /bin/cat >"$disable_path" <<'DISABLE_SCRIPT'
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
DISABLE_SCRIPT
  /bin/chmod 755 "$disable_path"
  info "Installed script: $disable_path"

  backup_target_script "$check_path"
  /bin/cat >"$check_path" <<'CHECK_SCRIPT'
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
CHECK_SCRIPT
  /bin/chmod 755 "$check_path"
  info "Installed script: $check_path"

  printf '%s\n%s\n%s\n' "$enable_path" "$disable_path" "$check_path"
}

install_restart_script() {
  /bin/mkdir -p "$INSTALL_DIR"

  local restart_path="$INSTALL_DIR/$RESTART_FILE_NAME"
  backup_target_script "$restart_path"
  /bin/cat >"$restart_path" <<'RESTART_SCRIPT'
#!/usr/bin/env bash

# @raycast.schemaVersion 1
# @raycast.title Restart Logi Options+
# @raycast.description Restart the Logi Options+ user agent and reopen the app without administrator privileges.
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

open_logi_options() {
  if [[ -d "$APP_PATH" ]]; then
    /usr/bin/open "$APP_PATH" >/dev/null 2>&1 || true
  else
    /usr/bin/open -a "Logi Options+" >/dev/null 2>&1 || true
  fi
}

quit_gui
kill_user_processes
restart_user_agent
wait_for_user_agent
open_logi_options
printf 'Logi Options+ restarted.\n'
RESTART_SCRIPT
  /bin/chmod 755 "$restart_path"
  info "Installed script: $restart_path"
  printf '%s\n' "$restart_path"
}

quit_onlyswitch() {
  /usr/bin/osascript -e "tell application id \"$ONLYSWITCH_BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
  /bin/sleep 1
}

restart_onlyswitch() {
  if [[ "$RESTART_ONLYSWITCH" -eq 1 ]]; then
    /usr/bin/open -b "$ONLYSWITCH_BUNDLE_ID" >/dev/null 2>&1 || true
  fi
}

open_install_dir() {
  if [[ "$OPEN_INSTALL_DIR" -eq 1 ]]; then
    /usr/bin/open "$INSTALL_DIR" >/dev/null 2>&1 || true
  fi
}

verify_db_schema() {
  [[ -f "$DB_PATH" ]] || die "Only Switch database not found: $DB_PATH"

  sqlite3 "$DB_PATH" "select 1 from sqlite_master where type='table' and name='ZEVOLUTIONCOMMANDENTITY';" | /usr/bin/grep -qx '1' \
    || die "Only Switch database schema is incompatible; scripts may already be installed, but Evolution import was not completed (missing ZEVOLUTIONCOMMANDENTITY table)"

  sqlite3 "$DB_PATH" "select 1 from sqlite_master where type='table' and name='Z_PRIMARYKEY';" | /usr/bin/grep -qx '1' \
    || die "Only Switch database schema is incompatible; scripts may already be installed, but Evolution import was not completed (missing Z_PRIMARYKEY table)"

  local required_columns=(
    Z_PK Z_ENT Z_OPT ZTIMESTAMP ZICONNAME ZITEMTYPE ZNAME
    ZSINGLECOMMAND ZSINGLECOMMANDTYPE
    ZSTATUSCOMMAND ZSTATUSCOMMANDTYPE ZTRUECONDITION
    ZTURNOFFCOMMAND ZTURNOFFCOMMANDTYPE ZTURNONCOMMAND ZTURNONCOMMANDTYPE ZID
  )

  local column
  for column in "${required_columns[@]}"; do
    sqlite3 "$DB_PATH" "pragma table_info(ZEVOLUTIONCOMMANDENTITY);" | /usr/bin/awk -F'|' '{print $2}' | /usr/bin/grep -qx "$column" \
      || die "Only Switch database schema is incompatible; scripts may already be installed, but Evolution import was not completed (missing ZEVOLUTIONCOMMANDENTITY column: $column)"
  done

  sqlite3 "$DB_PATH" "select 1 from Z_PRIMARYKEY where Z_NAME='EvolutionCommandEntity';" | /usr/bin/grep -qx '1' \
    || die "Only Switch database schema is incompatible; scripts may already be installed, but Evolution import was not completed (missing EvolutionCommandEntity row in Z_PRIMARYKEY)"
}

print_scripts_only_success() {
  cat <<EOF
Installation complete.
Raycast-compatible scripts installed to:
  $INSTALL_DIR

Only Switch Evolution controls were not imported.
No Only Switch database was found at:
  $DB_PATH

Only Switch can be downloaded and installed from:
  https://onlyswitch.click/

After installing and opening Only Switch once, rerun this installer to add the Evolution controls.
EOF
}

print_full_success() {
  cat <<EOF
Installation complete.
Raycast-compatible scripts installed to:
  $INSTALL_DIR

Only Switch Evolution controls imported or updated:
  - $EVOLUTION_NAME
  - $RESTART_EVOLUTION_NAME

Keep the install folder in place because Raycast Script Commands and Only Switch Evolution controls use these same script files.
EOF
}

backup_database() {
  local timestamp="$1"
  local db_dir
  db_dir="$(/usr/bin/dirname "$DB_PATH")"

  /bin/cp -p "$DB_PATH" "$db_dir/onlyswitch.sqlite.bak-$timestamp" \
    || die "failed to back up onlyswitch.sqlite"

  if [[ -f "$DB_PATH-wal" ]]; then
    /bin/cp -p "$DB_PATH-wal" "$db_dir/onlyswitch.sqlite-wal.bak-$timestamp" \
      || die "failed to back up onlyswitch.sqlite-wal"
  fi

  if [[ -f "$DB_PATH-shm" ]]; then
    /bin/cp -p "$DB_PATH-shm" "$db_dir/onlyswitch.sqlite-shm.bak-$timestamp" \
      || die "failed to back up onlyswitch.sqlite-shm"
  fi

  info "Database backup timestamp: $timestamp"
}

backup_preferences() {
  local timestamp="$1"

  if [[ -f "$PREFS_PATH" ]]; then
    local prefs_backup="$PREFS_PATH.bak-$timestamp"
    /bin/cp -p "$PREFS_PATH" "$prefs_backup" \
      || die "failed to back up jacklandrin.OnlySwitch.plist"
    info "Preferences backup: jacklandrin.OnlySwitch.plist.bak-$timestamp"
  fi
}

apple_timestamp() {
  local unix_now apple_epoch
  unix_now="$(/bin/date +%s)"
  apple_epoch="$(sqlite3 "$DB_PATH" "select strftime('%s','2001-01-01');")"
  printf '%s\n' "$((unix_now - apple_epoch))"
}

uuid_hex() {
  /usr/bin/uuidgen | /usr/bin/tr -d '-' | /usr/bin/tr '[:lower:]' '[:upper:]'
}

uuid_from_hex() {
  local hex="$1"
  printf '%s-%s-%s-%s-%s\n' \
    "${hex:0:8}" "${hex:8:4}" "${hex:12:4}" "${hex:16:4}" "${hex:20:12}"
}

sql_quote() {
  printf "%s" "$1" | /usr/bin/sed "s/'/''/g"
}

shell_quote() {
  printf "'"
  printf "%s" "$1" | /usr/bin/sed "s/'/'\\\\''/g"
  printf "'"
}

upsert_switch_evolution() {
  local enable_path="$1"
  local disable_path="$2"
  local check_path="$3"
  local now timestamp existing_uuid uuid on_command off_command status_command
  now="$(apple_timestamp)"
  timestamp="$(/bin/date +%Y%m%d-%H%M%S)"
  existing_uuid="$(sqlite3 "$DB_PATH" "select hex(ZID) from ZEVOLUTIONCOMMANDENTITY where ZNAME='$(sql_quote "$EVOLUTION_NAME")' limit 1;")"
  if [[ -n "$existing_uuid" ]]; then
    uuid="$existing_uuid"
  else
    uuid="$(uuid_hex)"
  fi
  on_command="/bin/bash $(shell_quote "$enable_path")"
  off_command="/bin/bash $(shell_quote "$disable_path")"
  status_command="/bin/bash $(shell_quote "$check_path")"

  local q_name q_type q_status q_status_type q_true q_on q_off q_cmd_type
  q_name="$(sql_quote "$EVOLUTION_NAME")"
  q_type="$(sql_quote "Switch")"
  q_status="$(sql_quote "$status_command")"
  q_status_type="$(sql_quote "shell")"
  q_true="$(sql_quote "on")"
  q_on="$(sql_quote "$on_command")"
  q_off="$(sql_quote "$off_command")"
  q_cmd_type="$(sql_quote "shell")"

  sqlite3 "$DB_PATH" <<SQL
BEGIN IMMEDIATE TRANSACTION;

UPDATE ZEVOLUTIONCOMMANDENTITY
SET
  Z_OPT = Z_OPT + 1,
  ZTIMESTAMP = $now,
  ZICONNAME = NULL,
  ZITEMTYPE = '$q_type',
  ZSTATUSCOMMAND = '$q_status',
  ZSTATUSCOMMANDTYPE = '$q_status_type',
  ZTRUECONDITION = '$q_true',
  ZTURNONCOMMAND = '$q_on',
  ZTURNONCOMMANDTYPE = '$q_cmd_type',
  ZTURNOFFCOMMAND = '$q_off',
  ZTURNOFFCOMMANDTYPE = '$q_cmd_type',
  ZSINGLECOMMAND = NULL,
  ZSINGLECOMMANDTYPE = NULL
WHERE ZNAME = '$q_name';

INSERT INTO ZEVOLUTIONCOMMANDENTITY (
  Z_PK, Z_ENT, Z_OPT, ZTIMESTAMP, ZICONNAME, ZITEMTYPE, ZNAME,
  ZSINGLECOMMAND, ZSINGLECOMMANDTYPE,
  ZSTATUSCOMMAND, ZSTATUSCOMMANDTYPE, ZTRUECONDITION,
  ZTURNOFFCOMMAND, ZTURNOFFCOMMANDTYPE,
  ZTURNONCOMMAND, ZTURNONCOMMANDTYPE, ZID
)
SELECT
  (SELECT Z_MAX + 1 FROM Z_PRIMARYKEY WHERE Z_NAME = 'EvolutionCommandEntity'),
  (SELECT Z_ENT FROM Z_PRIMARYKEY WHERE Z_NAME = 'EvolutionCommandEntity'),
  1,
  $now,
  NULL,
  '$q_type',
  '$q_name',
  NULL,
  NULL,
  '$q_status',
  '$q_status_type',
  '$q_true',
  '$q_off',
  '$q_cmd_type',
  '$q_on',
  '$q_cmd_type',
  X'$uuid'
WHERE changes() = 0;

UPDATE Z_PRIMARYKEY
SET Z_MAX = (SELECT max(Z_PK) FROM ZEVOLUTIONCOMMANDENTITY)
WHERE Z_NAME = 'EvolutionCommandEntity';

COMMIT;
SQL

  info "Imported or updated Evolution: $EVOLUTION_NAME"
  info "Turn on: $on_command"
  info "Turn off: $off_command"
  info "Check status: $status_command"
  info "True condition: on"
  info "Install timestamp: $timestamp"
  uuid_from_hex "$uuid"
}

upsert_restart_evolution() {
  local restart_path="$1"
  local now timestamp existing_uuid uuid single_command
  now="$(apple_timestamp)"
  timestamp="$(/bin/date +%Y%m%d-%H%M%S)"
  existing_uuid="$(sqlite3 "$DB_PATH" "select hex(ZID) from ZEVOLUTIONCOMMANDENTITY where ZNAME='$(sql_quote "$RESTART_EVOLUTION_NAME")' limit 1;")"
  if [[ -n "$existing_uuid" ]]; then
    uuid="$existing_uuid"
  else
    uuid="$(uuid_hex)"
  fi
  single_command="/bin/bash $(shell_quote "$restart_path")"

  local q_name q_type q_single q_cmd_type q_empty
  q_name="$(sql_quote "$RESTART_EVOLUTION_NAME")"
  q_type="$(sql_quote "Button")"
  q_single="$(sql_quote "$single_command")"
  q_cmd_type="$(sql_quote "shell")"
  q_empty="$(sql_quote "")"

  sqlite3 "$DB_PATH" <<SQL
BEGIN IMMEDIATE TRANSACTION;

UPDATE ZEVOLUTIONCOMMANDENTITY
SET
  Z_OPT = Z_OPT + 1,
  ZTIMESTAMP = $now,
  ZICONNAME = NULL,
  ZITEMTYPE = '$q_type',
  ZSINGLECOMMAND = '$q_single',
  ZSINGLECOMMANDTYPE = '$q_cmd_type',
  ZSTATUSCOMMAND = '$q_empty',
  ZSTATUSCOMMANDTYPE = '$q_cmd_type',
  ZTRUECONDITION = '$q_empty',
  ZTURNONCOMMAND = '$q_empty',
  ZTURNONCOMMANDTYPE = '$q_cmd_type',
  ZTURNOFFCOMMAND = '$q_empty',
  ZTURNOFFCOMMANDTYPE = '$q_cmd_type'
WHERE ZNAME = '$q_name';

INSERT INTO ZEVOLUTIONCOMMANDENTITY (
  Z_PK, Z_ENT, Z_OPT, ZTIMESTAMP, ZICONNAME, ZITEMTYPE, ZNAME,
  ZSINGLECOMMAND, ZSINGLECOMMANDTYPE,
  ZSTATUSCOMMAND, ZSTATUSCOMMANDTYPE, ZTRUECONDITION,
  ZTURNOFFCOMMAND, ZTURNOFFCOMMANDTYPE,
  ZTURNONCOMMAND, ZTURNONCOMMANDTYPE, ZID
)
SELECT
  (SELECT Z_MAX + 1 FROM Z_PRIMARYKEY WHERE Z_NAME = 'EvolutionCommandEntity'),
  (SELECT Z_ENT FROM Z_PRIMARYKEY WHERE Z_NAME = 'EvolutionCommandEntity'),
  1,
  $now,
  NULL,
  '$q_type',
  '$q_name',
  '$q_single',
  '$q_cmd_type',
  '$q_empty',
  '$q_cmd_type',
  '$q_empty',
  '$q_empty',
  '$q_cmd_type',
  '$q_empty',
  '$q_cmd_type',
  X'$uuid'
WHERE changes() = 0;

UPDATE Z_PRIMARYKEY
SET Z_MAX = (SELECT max(Z_PK) FROM ZEVOLUTIONCOMMANDENTITY)
WHERE Z_NAME = 'EvolutionCommandEntity';

COMMIT;
SQL

  info "Imported or updated Evolution button: $RESTART_EVOLUTION_NAME"
  info "Button command: $single_command"
  info "Install timestamp: $timestamp"
  uuid_from_hex "$uuid"
}

ensure_visible_evolution_id() {
  local evolution_id="$1"

  if [[ ! -f "$PREFS_PATH" ]]; then
    /usr/bin/defaults write "$ONLYSWITCH_BUNDLE_ID" evolutionIDsKey -array "$evolution_id"
    return
  fi

  if ! /usr/libexec/PlistBuddy -c "Print :evolutionIDsKey" "$PREFS_PATH" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Add :evolutionIDsKey array" "$PREFS_PATH"
  fi

  if /usr/libexec/PlistBuddy -c "Print :evolutionIDsKey" "$PREFS_PATH" 2>/dev/null | /usr/bin/grep -Fq "$evolution_id"; then
    return
  fi

  /usr/libexec/PlistBuddy -c "Add :evolutionIDsKey: string $evolution_id" "$PREFS_PATH"
}

main() {
  parse_args "$@"
  choose_install_dir

  info "Install directory: $INSTALL_DIR"
  local script_paths enable_path disable_path check_path restart_path
  script_paths="$(install_scripts)"
  enable_path="$(printf '%s\n' "$script_paths" | /usr/bin/tail -n 3 | /usr/bin/sed -n '1p')"
  disable_path="$(printf '%s\n' "$script_paths" | /usr/bin/tail -n 3 | /usr/bin/sed -n '2p')"
  check_path="$(printf '%s\n' "$script_paths" | /usr/bin/tail -n 3 | /usr/bin/sed -n '3p')"
  restart_path="$(install_restart_script | /usr/bin/tail -n 1)"

  if [[ ! -f "$DB_PATH" ]]; then
    open_install_dir
    print_scripts_only_success
    return 0
  fi

  verify_db_schema
  quit_onlyswitch

  local backup_timestamp
  backup_timestamp="$(/bin/date +%Y%m%d-%H%M%S)"
  backup_database "$backup_timestamp"
  backup_preferences "$backup_timestamp"

  local switch_evolution_id restart_evolution_id
  switch_evolution_id="$(upsert_switch_evolution "$enable_path" "$disable_path" "$check_path" | /usr/bin/tail -n 1)"
  restart_evolution_id="$(upsert_restart_evolution "$restart_path" | /usr/bin/tail -n 1)"
  ensure_visible_evolution_id "$switch_evolution_id"
  ensure_visible_evolution_id "$restart_evolution_id"
  info "Visible Switch Evolution ID: $switch_evolution_id"
  info "Visible Restart Evolution ID: $restart_evolution_id"

  restart_onlyswitch
  open_install_dir
  print_full_success
}

main "$@"
