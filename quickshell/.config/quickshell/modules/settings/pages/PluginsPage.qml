pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// Settings › Plugins: the Orvix store, and Omarchy's plugins when Omarchy is
// installed.
//
// Two origins, kept apart because they are different things:
//
//   Orvix   ~/.config/orvix/plugins, installed with `orvix plugin install`,
//           loaded by Orvix itself. This works on any Arch install.
//   Omarchy Omarchy's own shell plugins, which only mean anything while its
//           shell runs. Shown here so there is one place to look, but they are
//           toggled through Omarchy's registry, never by Orvix.
//
// Each plugin shows what the manifest declares — name, description, author,
// version, installed state, enabled state, kinds, permissions — and the
// Official/Third-party label. Official is the account, not the URL: see
// docs/PLUGIN_SPEC.md.
ColumnLayout {
    id: page

    spacing: Config.spacing * 3

    // Which plugins are shown: "all", "on", "off"
    property string filter: "all"

    readonly property var shown: {
        if (filter === "on")
            return PluginService.enabled;
        if (filter === "off")
            return PluginService.disabled;
        return PluginService.plugins;
    }

    Component.onCompleted: {
        PluginService.refresh();
        if (OmarchyBarWidgets.available)
            OmarchyBarWidgets.refresh();
    }

    // ===================== ORVIX =====================
    SettingsGroup {
        title: I18n.tr("Orvix plugins")

        InfoRow {
            label: I18n.tr("Installed")
            value: PluginService.count === 0 ? I18n.tr("None yet") : I18n.tr("%1 installed, %2 enabled", PluginService.count, PluginService.enabled.length)
        }

        SelectRow {
            label: I18n.tr("Show")
            description: I18n.tr("Which plugins this list shows")
            segmentWidth: Config.fontSizeNormal * 6
            options: [
                {
                    label: I18n.tr("All"),
                    value: "all"
                },
                {
                    label: I18n.tr("Enabled"),
                    value: "on"
                },
                {
                    label: I18n.tr("Disabled"),
                    value: "off"
                }
            ]
            value: page.filter
            onSelected: value => page.filter = value
        }

        SettingRow {
            label: I18n.tr("Refresh")
            description: I18n.tr("Read the plugin folder and its state again")

            ActionButton {
                icon: "\u{f0450}"
                text: I18n.tr("Refresh")
                onClicked: PluginService.refresh()
            }
        }

        InfoRow {
            visible: PluginService.error !== ""
            label: I18n.tr("Problem")
            value: PluginService.error
        }

        // Nothing installed: how to get one
        InfoRow {
            visible: PluginService.count === 0
            label: I18n.tr("Install one")
            value: I18n.tr("Run: orvix plugin install github:devsanbid/orvix — the Official plugins live in that repository's plugins/ folder")
        }
    }

    // One row per plugin. A Repeater with a Loader would be heavier than the
    // store ever gets; a ColumnLayout of rows is what Settings uses.
    Repeater {
        model: page.shown

        SettingsGroup {
            id: pluginGroup

            required property var modelData

            Layout.fillWidth: true
            title: ""

            SettingRow {
                id: pluginRow

                label: pluginGroup.modelData.name
                description: pluginGroup.modelData.description
                // Room for the badge, the version and the switch
                resettable: false

                QsSwitch {
                    checked: pluginGroup.modelData.enabled
                    onToggled: {
                        PluginService.setPluginState(pluginGroup.modelData.id, "enabled", checked);
                        checked = Qt.binding(() => pluginGroup.modelData.enabled);
                    }
                }
            }

            InfoRow {
                label: I18n.tr("Source")
                value: pluginGroup.modelData.official ? I18n.tr("Official (%1)", pluginGroup.modelData.author) : I18n.tr("Third-party (%1)", pluginGroup.modelData.author !== "" ? pluginGroup.modelData.author : I18n.tr("author not declared"))
            }

            InfoRow {
                label: I18n.tr("Version")
                value: pluginGroup.modelData.version + (pluginGroup.modelData.license !== "" ? " · " + pluginGroup.modelData.license : "")
            }

            InfoRow {
                label: I18n.tr("Kinds")
                value: pluginGroup.modelData.kinds.join(", ")
            }

            InfoRow {
                visible: pluginGroup.modelData.permissions.length > 0
                label: I18n.tr("Permissions")
                value: pluginGroup.modelData.permissions.join(", ")
            }

            InfoRow {
                visible: pluginGroup.modelData.homepage !== ""
                label: I18n.tr("Repository")
                value: pluginGroup.modelData.homepage
            }
        }
    }

    // ===================== OMARCHY =====================
    // Only where Omarchy is: on a plain Arch install this whole group is
    // absent, not empty.
    SettingsGroup {
        visible: OmarchyBarWidgets.available
        title: I18n.tr("Omarchy's plugins")

        InfoRow {
            label: I18n.tr("Where they live")
            value: I18n.tr("Omarchy's own shell plugins, shown here so there is one place to look. They are toggled through Omarchy's registry, and only mean anything while its shell runs.")
        }

        SettingRow {
            label: I18n.tr("Bar widgets")
            description: OmarchyBarWidgets.shellRunning ? I18n.tr("%1 from Omarchy, %2 on its bar", OmarchyBarWidgets.omarchyWidgets.length, OmarchyBarWidgets.addedCount) : I18n.tr("Omarchy's shell isn't running, so they can't be switched")

            ActionButton {
                icon: "\u{f0450}"
                text: I18n.tr("Open the bar tab")
                onClicked: {
                    StateService.set("bar.settingsTab", "plugins");
                    SettingsService.open("bar");
                }
            }
        }

        InfoRow {
            label: I18n.tr("Everything else")
            value: I18n.tr("Omarchy's panels, services and overlays are managed in Omarchy itself (omarchy plugin list): Orvix does not load them.")
        }
    }
}
