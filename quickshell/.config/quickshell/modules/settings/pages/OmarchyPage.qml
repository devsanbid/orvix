pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// Omarchy integration, shown only when Omarchy is installed. Read-only
// status, the live theme bridge and the two safe actions Orvix offers:
// apply an Omarchy theme and refresh Omarchy's config. Nothing here writes
// Omarchy's files directly; the commands do.
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
            label: I18n.tr("Refresh Omarchy config")
            description: I18n.tr("Reloads Omarchy's generated configuration (omarchy refresh config)")
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
