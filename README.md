# Logi Options+ Switch

**[Raycast](https://www.raycast.com/)** and [**OnlySwitch**](https://onlyswitch.click/) compatible scripts to temporarily disable, enable, and restart Logi Options+ on macOS.

## When to use

Use this project when:

- Your Logitech mouse configuration stops working because the Logi Options+ app or service becomes unresponsive.
- Logi Options+ conflicts with another app or a Mac game, and you want a quick way to temporarily stop and re-enable it.

## What It Does

This project provides a single installer and individual scripts:

```text
install-logi-options-switch.sh
```

The installer creates **Raycast**-compatible scripts for:

- `Disable Logi Options+` - temporarily stops Logi Options+ by quitting the app, booting out the current user LaunchAgent, and stopping user-level Logi Options+ helper processes.
- `Enable Logi Options+` - re-enables Logi Options+ without opening the app window
- `Restart Logi Options+` - restarts the Logi Options+ user agent without opening the app window

It also creates two **Only Switch** Evolution controls:

- `Logi Options+` switch - a simple toggle for temporarily stopping or re-enabling Logi Options+
- `Restart Logi Options+` button - a one-click button to restart the Logi Options+ user agent without opening the app window

## Installation

Download `install-logi-options-switch.sh`, then double-click it to run the installer.

If double-clicking does not work, run it from Terminal:

```bash
chmod +x install-logi-options-switch.sh
./install-logi-options-switch.sh
```

The default install folder is:

```text
~/Documents/Scripts
```

The installer writes these same scripts into the selected folder:

```text
enable-logi-options.sh
disable-logi-options.sh
restart-logi-options.sh
check-logi-options.sh
```

`check-logi-options.sh` is used by **Only Switch** to keep the switch status updated.

> **Important:** **Raycast** Script Commands and **Only Switch** Evolution controls share the same installed script files in this project. **Only Switch** Evolution controls call scripts from the install folder. Please keep that folder and the generated scripts in place after installation.

If **Only Switch** is not installed or has not been opened yet, the installer still installs the Raycast-compatible scripts and skips the Evolution import. Install and open **Only Switch** once, then rerun the installer to add the Evolution controls.

Available options:

```text
--default           Install directly to ~/Documents/Scripts without prompting.
--install-dir PATH  Install scripts directly into PATH.
--no-restart        Do not reopen Only Switch after database import.
--no-open-folder    Do not open the install directory in Finder after installation.
--help              Show help.
```

## How to use

For **Raycast**:

- Add the install folder to **Raycast** Script Commands if **Raycast** has not already indexed it.
- Run `Disable Logi Options+`, `Enable Logi Options+`, or `Restart Logi Options+` commands from **Raycast**.

For **Only Switch**:

- Open **Only Switch** and look for the `Logi Options+` switch and `Restart Logi Options+` button in the **EVOLUTION** section of the dropdown menu. **Only Switch** should show the two Evolution controls like this:

![Only Switch Evolution controls for Logi Options+](assets/only-switch-evolution-controls.png)

- Toggle the `Logi Options+` switch to temporarily stop or re-enable Logi Options+.
- Click the `Restart Logi Options+` button to restart the Logi Options+ user agent with one click.

## Integrations

This project is designed to work with:

- [Raycast Script Commands](https://github.com/raycast/script-commands)
- [OnlySwitch](https://github.com/jacklandrin/OnlySwitch)

If you do not have either app installed, you can still run the shell scripts in the `scripts/` folder directly from Terminal.

## Tested Environment

This project was tested and confirmed working with:

- **macOS Sequoia** 15.7.5
- **Only Switch** 2.5.8
- **Raycast** 1.104.15
- **Logi Options+** 2.3.879545
- **Logi Plugin Service** 6.3.0.2406

## Notes

- This project is not affiliated with **Logi Options+**, **Logitech**, **Raycast**, or **Only Switch**.
- Disable is temporary for the current login session. Logi Options+ may start again after reboot or login.
- Enable and Restart restore or restart the Logi Options+ user LaunchAgent without opening the app window, so they should not interrupt your current workspace.
- **Only Switch** is optional for script installation. It is only required if you want the installer to create Evolution controls automatically.
- Future versions of **Logi Options+**, **Logi Plugin Service**, **Raycast**, or **Only Switch** may change launchd service names, process names, app paths, Script Commands behavior, or Only Switch storage structure. If that happens, some scripts or installer features may need updates.
