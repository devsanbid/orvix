pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// Omarchy's bar widgets and the ones installed on top.
ColumnLayout {
    id: page

    spacing: Config.spacing * 3

    // Read Omarchy's catalogue when this tab is built (it used to run from the
    // page, which no longer builds the widgets until the tab is opened)
    Component.onCompleted: OmarchyBarWidgets.refresh()

    SettingsGroup {
        visible: OmarchyBarWidgets.available
        title: I18n.tr("Omarchy's bar widgets")

        InfoRow {
            label: I18n.tr("Available")
            value: OmarchyBarWidgets.shellRunning ? I18n.tr("%1 from Omarchy, %2 installed, %3 on Omarchy's bar", OmarchyBarWidgets.omarchyWidgets.length, OmarchyBarWidgets.communityWidgets.length, OmarchyBarWidgets.addedCount) : I18n.tr("%1 from Omarchy, %2 installed", OmarchyBarWidgets.omarchyWidgets.length, OmarchyBarWidgets.communityWidgets.length)
        }

        InfoRow {
            visible: OmarchyBarWidgets.available && !OmarchyBarWidgets.shellRunning
            label: I18n.tr("Where they show")
            value: I18n.tr("They draw on Omarchy's bar, not Orvix's. Start Omarchy's shell to switch them, and hide its bar in Settings › System › Omarchy if you only want its plugins.")
        }

        SettingRow {
            visible: OmarchyBarWidgets.available
            label: I18n.tr("Refresh")
            description: I18n.tr("Read Omarchy's catalogue and what is on its bar again")
            enabled: !OmarchyBarWidgets.loading

            ActionButton {
                icon: "\u{f0450}"
                text: OmarchyBarWidgets.loading ? I18n.tr("Reading…") : I18n.tr("Refresh")
                enabled: !OmarchyBarWidgets.loading
                onClicked: OmarchyBarWidgets.refresh()
            }
        }

        InfoRow {
            visible: OmarchyBarWidgets.error !== ""
            label: I18n.tr("Problem")
            value: OmarchyBarWidgets.error
        }
    }

    // Omarchy's own, by category
    Repeater {
        model: OmarchyBarWidgets.omarchyCategories

        SettingsGroup {
            id: omarchyCategory

            required property var modelData

            visible: OmarchyBarWidgets.available && omarchyCategory.modelData.items.length > 0
            // The first one says where these come from; the rest just name
            // their category
            title: (omarchyCategory.modelData.category !== "" ? omarchyCategory.modelData.category : I18n.tr("Other")) + " · " + I18n.tr("Omarchy")

            Repeater {
                model: omarchyCategory.modelData.items
                delegate: WidgetRow {}
            }
        }
    }

    // Installed on top of Omarchy: git plugins and hand-written ones
    SettingsGroup {
        visible: OmarchyBarWidgets.available && OmarchyBarWidgets.communityWidgets.length === 0
        title: I18n.tr("Installed widgets")

        InfoRow {
            label: I18n.tr("None yet")
            value: I18n.tr("Add one with omarchy plugin add <git-url>, or drop a folder in ~/.config/omarchy/plugins. It shows here, next to Omarchy's own.")
        }
    }

    Repeater {
        model: OmarchyBarWidgets.communityCategories

        SettingsGroup {
            id: communityCategory

            required property var modelData

            visible: OmarchyBarWidgets.available
            title: (communityCategory.modelData.category !== "" ? communityCategory.modelData.category : I18n.tr("Other")) + " · " + I18n.tr("Installed")

            Repeater {
                model: communityCategory.modelData.items
                delegate: WidgetRow {}
            }
        }
    }

    // One Omarchy bar widget: its name and description, and the switch that
    // adds it to or removes it from Omarchy's bar
    component WidgetRow: SettingRow {
        id: widgetRow

        required property var modelData

        label: widgetRow.modelData.name
        description: widgetRow.modelData.description
        enabled: OmarchyBarWidgets.shellRunning && !OmarchyBarWidgets.actionRunning

        QsSwitch {
            checked: widgetRow.modelData.enabled
            onToggled: {
                OmarchyBarWidgets.toggle(widgetRow.modelData.id, checked);
                // Clicking breaks the binding; the catalogue is the source of
                // truth and comes back after the action
                checked = Qt.binding(() => widgetRow.modelData.enabled);
            }
        }
    }
}
