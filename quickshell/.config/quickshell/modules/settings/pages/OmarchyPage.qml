pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// Omarchy integration, shown only when Omarchy is installed. Read-only
// status, the live theme bridge and the actions Orvix offers, each through
// one of Omarchy's own commands: apply a theme, open its switcher or menu,
// update it, mirror Orvix's accent, and the login guard for the two shells.
// Nothing here writes Omarchy's files directly, and no Omarchy command runs
// without the user asking.
ColumnLayout {
    id: root

    spacing: Config.spacing * 3

    // ================= STATUS =================
    SettingsGroup {
        title: I18n.tr("Omarchy")

        InfoRow {
            label: I18n.tr("Version")
            value: OmarchyService.version !== "" ? OmarchyService.version : I18n.tr("Not detected")
        }

        InfoRow {
            label: I18n.tr("Current theme")
            value: OmarchyService.themeName !== "" ? OmarchyService.themeName : I18n.tr("None selected")
        }

        InfoRow {
            label: I18n.tr("Omarchy shell")
            value: OmarchyService.shellRunning ? I18n.tr("Running") : I18n.tr("Not running")
        }

        InfoRow {
            label: I18n.tr("Shell plugins")
            value: I18n.tr("%1 installed, not used by Orvix", OmarchyService.pluginCount)
        }

        SettingRow {
            label: I18n.tr("Refresh")
            description: I18n.tr("Read the version, theme and shell state again")

            ActionButton {
                icon: "\u{f0450}"
                text: I18n.tr("Refresh")
                onClicked: OmarchyService.refresh()
            }
        }
    }

    // Two shells on one desktop: the warning is honest, nothing is stopped
    // automatically.
    SettingsGroup {
        visible: OmarchyService.shellRunning
        title: I18n.tr("Two shells are running")

        InfoRow {
            label: I18n.tr("Overlap")
            value: I18n.tr("Omarchy's bar and panels overlap Orvix's. Keep one of them.")
        }

        ToggleRow {
            label: I18n.tr("Skip Orvix's bar at login")
            description: I18n.tr("While Omarchy's shell is running at login, Orvix's bar stays off. It applies at the next login; nothing is stopped now.")
            checked: OmarchyService.skipShellWithOmarchy
            onToggled: value => OmarchyService.setSkipShellWithOmarchy(value)
        }
    }

    SettingsGroup {
        visible: !OmarchyService.shellRunning
        title: I18n.tr("At login")

        ToggleRow {
            label: I18n.tr("Skip Orvix's bar when Omarchy's shell runs")
            description: I18n.tr("One bar at login instead of two. Off by default: Orvix's bar starts, and this page warns if Omarchy's does too.")
            checked: OmarchyService.skipShellWithOmarchy
            onToggled: value => OmarchyService.setSkipShellWithOmarchy(value)
        }
    }

    // ================= COLORS =================
    SettingsGroup {
        title: I18n.tr("Colors")

        ToggleRow {
            label: I18n.tr("Follow the Omarchy theme")
            description: OmarchyService.available ? I18n.tr("Use the active Omarchy theme's colors in Orvix, GTK, Qt, Kitty and Neovim. Your wallpaper and opacity stay yours.") : I18n.tr("Pick a theme in Omarchy first")
            checked: ThemeService.isOmarchyMode
            enabled: OmarchyService.available
            onToggled: value => {
                if (value)
                    ThemeService.setOmarchyMode();
                else
                    ThemeService.setPresetMode(ThemeService.currentThemeName);
            }
        }

        InfoRow {
            visible: !OmarchyService.available
            label: I18n.tr("Theme colors")
            value: I18n.tr("Not found at ~/.local/state/omarchy/current/theme/colors.toml")
        }

        // One direction at a time: Omarchy owns its theme, Orvix asks it to
        // switch. The accent of the Orvix palette goes over only on request,
        // through Omarchy's own command
        SettingRow {
            label: I18n.tr("Use Orvix's accent in Omarchy")
            description: OmarchyService.available ? I18n.tr("Writes Orvix's accent color into Omarchy's current theme as a user override, then asks Omarchy to reapply it. A theme you made or edited yourself is left alone.") : I18n.tr("Pick a theme in Omarchy first")
            enabled: OmarchyService.available && !OmarchyService.actionRunning

            ActionButton {
                icon: "\u{f0c9e}"
                text: I18n.tr("Apply")
                enabled: OmarchyService.available && !OmarchyService.actionRunning
                onClicked: OmarchyService.applyAccent(ThemeService.palette.accent)
            }
        }
    }

    // ================= THEME LIST =================
    SettingsGroup {
        title: I18n.tr("Themes")

        Repeater {
            model: OmarchyService.themes

            SettingRow {
                id: themeRow

                required property var modelData

                label: modelData.name
                description: modelData.current ? I18n.tr("Active in Omarchy") : ""

                ActionButton {
                    text: themeRow.modelData.current ? I18n.tr("Current") : I18n.tr("Apply")
                    enabled: !themeRow.modelData.current && !OmarchyService.actionRunning
                    onClicked: OmarchyService.applyTheme(themeRow.modelData.id)
                }
            }
        }

        InfoRow {
            visible: OmarchyService.themes.length === 0
            label: I18n.tr("Themes")
            value: I18n.tr("No themes found in /usr/share/omarchy/themes")
        }
    }

    // ================= ACTIONS =================
    SettingsGroup {
        title: I18n.tr("Actions")

        SettingRow {
            label: I18n.tr("Open Omarchy's theme switcher")
            description: I18n.tr("Omarchy's own theme picker, with previews (omarchy theme switcher). Needs Omarchy's shell running.")
            enabled: !OmarchyService.actionRunning && OmarchyService.shellRunning

            ActionButton {
                icon: "\u{f03d8}"
                text: I18n.tr("Open")
                enabled: !OmarchyService.actionRunning && OmarchyService.shellRunning
                onClicked: OmarchyService.openThemeSwitcher()
            }
        }

        SettingRow {
            label: I18n.tr("Open Omarchy's menu")
            description: I18n.tr("Omarchy's main menu, the one its Super key opens (omarchy menu). Needs Omarchy's shell running.")
            enabled: !OmarchyService.actionRunning && OmarchyService.shellRunning

            ActionButton {
                icon: "\u{f035c}"
                text: I18n.tr("Open")
                enabled: !OmarchyService.actionRunning && OmarchyService.shellRunning
                onClicked: OmarchyService.openMenu()
            }
        }

        SettingRow {
            label: I18n.tr("Update Omarchy")
            description: I18n.tr("Updates Omarchy and the system packages (omarchy update). It asks for your password and what to do, so it runs in a terminal window; nothing runs silently.")

            ActionButton {
                icon: "\u{f01da}"
                text: I18n.tr("Open")
                onClicked: Quickshell.execDetached(["kitty", "--hold", "--", "omarchy", "update"])
            }
        }

        SettingRow {
            label: I18n.tr("Refresh Omarchy's Hyprland config")
            description: I18n.tr("Copies Omarchy's own Hyprland config over ~/.config/hypr, backing up yours first (omarchy refresh config hypr). Orvix's config is replaced, so use it only to return to Omarchy's desktop.")
            enabled: !OmarchyService.actionRunning

            ActionButton {
                icon: "\u{f0450}"
                text: I18n.tr("Refresh")
                enabled: !OmarchyService.actionRunning
                onClicked: OmarchyService.refreshConfig()
            }
        }

        InfoRow {
            visible: OmarchyService.actionRunning
            label: OmarchyService.lastAction
            value: I18n.tr("Working…")
        }

        InfoRow {
            visible: !OmarchyService.actionRunning && OmarchyService.lastOutput !== ""
            label: OmarchyService.lastExit === 0 ? I18n.tr("Done") : I18n.tr("Failed")
            value: OmarchyService.lastOutput
        }
    }
}
