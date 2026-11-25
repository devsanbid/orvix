pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// The desktop's GTK look and how much Orvix may change it: GTK theme, font
// and light/dark preference, the icon and cursor themes (edited on their own
// pages) and the Qt color scheme the shell writes. Nothing here touches
// Omarchy's files; "Use Omarchy's GTK settings" calls Omarchy's own command.
ColumnLayout {
    id: root

    spacing: Config.spacing * 3

    // Values may have changed in another app or by an Omarchy theme switch
    Component.onCompleted: GtkService.refresh()

    SettingsGroup {
        title: I18n.tr("GTK")
        visible: GtkService.available

        SettingRow {
            label: I18n.tr("Theme")
            description: GtkService.gtkTheme !== "" ? GtkService.gtkTheme : I18n.tr("Not set")

            MenuButton {
                id: themeMenuButton

                onClicked: themeMenu.openAt(themeMenuButton)
            }
        }

        SelectRow {
            label: I18n.tr("Prefer")
            description: I18n.tr("Tells GTK apps whether to use a dark or a light look")
            segmentWidth: Config.fontSizeNormal * 7
            options: [
                {
                    label: I18n.tr("Default"),
                    value: "default"
                },
                {
                    label: I18n.tr("Dark"),
                    value: "prefer-dark"
                },
                {
                    label: I18n.tr("Light"),
                    value: "prefer-light"
                }
            ]
            value: GtkService.colorScheme !== "" ? GtkService.colorScheme : "default"
            onSelected: value => GtkService.setColorScheme(value)
        }

        TextFieldRow {
            label: I18n.tr("Font")
            description: I18n.tr("Name and size, like “CaskaydiaCove Nerd Font 10”")
            text: GtkService.fontName
            placeholder: I18n.tr("Sans 10")
            onSubmitted: value => GtkService.setFontName(value)
        }
    }

    InfoRow {
        visible: !GtkService.available
        label: I18n.tr("GTK settings")
        value: I18n.tr("gsettings was not found, so GTK settings can't be read or changed here")
    }

    SettingsGroup {
        title: I18n.tr("Icons and cursor")

        SettingRow {
            label: I18n.tr("Icon theme")
            description: GtkService.iconTheme !== "" ? GtkService.iconTheme : I18n.tr("Not set")

            ActionButton {
                text: I18n.tr("Change")
                onClicked: SettingsService.currentPage = "icons"
            }
        }

        SettingRow {
            label: I18n.tr("Cursor")
            description: GtkService.cursorTheme !== "" ? I18n.tr("%1, size %2", GtkService.cursorTheme, GtkService.cursorSize) : I18n.tr("Not set")

            ActionButton {
                text: I18n.tr("Change")
                onClicked: SettingsService.currentPage = "cursor"
            }
        }
    }

    SettingsGroup {
        title: I18n.tr("Orvix theme")

        ToggleRow {
            label: I18n.tr("Set the GTK theme")
            description: I18n.tr("Pick adw-gtk3 or adw-gtk3-dark to match the shell's light or dark mode. Turn off to keep the GTK theme you choose above.")
            path: "theme.applyGtkTheme"
            onToggled: ThemeService.applyAppColors()
        }

        ToggleRow {
            label: I18n.tr("Write GTK colors")
            description: I18n.tr("Write the shell palette to ~/.config/gtk-*/colors.css for themes that read it")
            path: "theme.applyGtkColors"
            onToggled: ThemeService.applyAppColors()
        }

        ToggleRow {
            label: I18n.tr("Write the Qt color scheme")
            description: I18n.tr("Save the shell palette for Qt apps in ~/.config/qt6ct and ~/.local/share/color-schemes")
            path: "theme.applyQtColors"
            onToggled: ThemeService.applyAppColors()
        }

        InfoRow {
            label: I18n.tr("Qt")
            value: ThemeService.qtColorSchemePath
        }

        InfoRow {
            label: I18n.tr("Omarchy")
            value: I18n.tr("Omarchy does not manage Qt colors; its GTK settings can be applied below.")
        }

        SettingRow {
            label: I18n.tr("Reapply now")
            description: I18n.tr("Write the current shell palette to GTK and Qt again")

            ActionButton {
                icon: "\u{f0450}"
                text: I18n.tr("Reapply")
                onClicked: ThemeService.applyAppColors()
            }
        }
    }

    SettingsGroup {
        visible: OmarchyService.installed
        title: I18n.tr("Omarchy")

        SettingRow {
            label: I18n.tr("Use Omarchy's GTK settings")
            description: I18n.tr("Apply the current Omarchy theme's light or dark mode and icon theme through Omarchy's own command")
            enabled: !GtkService.actionRunning

            ActionButton {
                text: I18n.tr("Apply")
                enabled: !GtkService.actionRunning
                onClicked: GtkService.useOmarchyDefaults()
            }
        }

        InfoRow {
            visible: GtkService.actionRunning
            label: I18n.tr("Omarchy")
            value: I18n.tr("Applying…")
        }

        InfoRow {
            visible: !GtkService.actionRunning && GtkService.lastError !== ""
            label: I18n.tr("Failed")
            value: GtkService.lastError
        }
    }

    // Installed GTK themes, the current one checked
    ContextMenu {
        id: themeMenu

        items: {
            const names = GtkService.gtkThemes.slice();
            if (GtkService.gtkTheme !== "" && !names.includes(GtkService.gtkTheme))
                names.unshift(GtkService.gtkTheme);
            return names.map(name => ({
                label: name,
                checked: name === GtkService.gtkTheme,
                action: name
            }));
        }

        onTriggered: action => GtkService.setGtkTheme(action)
    }
}
