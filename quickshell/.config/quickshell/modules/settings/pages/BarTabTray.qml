pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// System tray: style, the items, and the ones that are missing.
ColumnLayout {
    id: page

    spacing: Config.spacing * 3

    SettingsGroup {
        title: I18n.tr("Tray")

        TemplatePicker {
            label: I18n.tr("Style")
            description: ({
                    "row": I18n.tr("Every icon always in the bar"),
                    "overflow": I18n.tr("One button in the bar; the icons open in a grid under it"),
                    "pinned": I18n.tr("The items switched on below stay in the bar; the rest wait behind a button")
                })[Config.barTrayStyle] ?? I18n.tr("The icons slide out of a button in the bar")
            path: "bar.tray.style"
            options: [
                {
                    label: I18n.tr("Row"),
                    value: "row"
                },
                {
                    label: I18n.tr("Drawer"),
                    value: "drawer"
                },
                {
                    label: I18n.tr("Overflow"),
                    value: "overflow"
                },
                {
                    label: I18n.tr("Pinned"),
                    value: "pinned"
                }
            ]
            thumbHeight: Config.fontSizeIconLarge * 4
            preview: Component {
                TrayStylePreview {}
            }
        }

        ToggleRow {
            label: I18n.tr("Tooltips")
            description: I18n.tr("The item's name on hover. Middle click and the mouse wheel go to the app")
            path: "bar.tray.tooltips"
        }

        ToggleRow {
            label: I18n.tr("Monochrome icons")
            description: I18n.tr("Tint the icons with the text color, like the rest of the bar")
            path: "bar.tray.monochrome"
        }

        ToggleRow {
            label: I18n.tr("Attention badge")
            description: I18n.tr("A pulsing dot on items asking for attention, and on the button hiding them")
            path: "bar.tray.attention"
        }

        // Running items in bar order: move, hide, and pin (pinned style)
        Repeater {
            model: TrayService.items

            SettingRow {
                id: trayRow

                required property var modelData
                required property int index

                readonly property string itemId: modelData.id
                readonly property bool hidden: TrayService.isHidden(itemId)
                readonly property bool pinned: TrayService.isPinned(itemId)
                readonly property bool pinnedStyle: Config.barTrayStyle === "pinned"
                readonly property int buttonSize: Config.fontSizeIconSmall + Config.padding * 2

                label: TrayService.itemName(modelData)
                description: hidden ? I18n.tr("Hidden from the bar") : !pinnedStyle ? "" : pinned ? I18n.tr("Pinned to the bar") : I18n.tr("Behind the button")

                leading: TrayIconBox {
                    source: TrayService.getIconSource(trayRow.modelData.icon)
                    color: trayRow.controlColor
                    opacity: trayRow.hidden ? 0.4 : 1
                }

                // md-arrow_up / md-arrow_down
                ActionButton {
                    icon: "\u{f005d}"
                    size: trayRow.buttonSize
                    baseColor: trayRow.controlColor
                    opacity: trayRow.index > 0 ? 1 : 0.3
                    onClicked: TrayService.move(trayRow.itemId, -1)
                }

                ActionButton {
                    icon: "\u{f0045}"
                    size: trayRow.buttonSize
                    baseColor: trayRow.controlColor
                    opacity: trayRow.index < TrayService.items.length - 1 ? 1 : 0.3
                    onClicked: TrayService.move(trayRow.itemId, 1)
                }

                // md-eye / md-eye_off
                ActionButton {
                    icon: trayRow.hidden ? "\u{f0208}" : "\u{f0209}"
                    text: trayRow.hidden ? I18n.tr("Show") : I18n.tr("Hide")
                    size: trayRow.buttonSize
                    baseColor: trayRow.controlColor
                    onClicked: TrayService.setHidden(trayRow.itemId, !trayRow.hidden)
                }

                QsSwitch {
                    visible: trayRow.pinnedStyle
                    enabled: !trayRow.hidden
                    opacity: enabled ? 1 : 0.4
                    checked: trayRow.pinned
                    onToggled: {
                        TrayService.setPinned(trayRow.itemId, checked);
                        checked = Qt.binding(() => trayRow.pinned);
                    }
                }
            }
        }

        // Pinned or hidden items that aren't running right now
        Repeater {
            model: TrayService.missingIds

            SettingRow {
                id: missingRow

                required property string modelData

                label: modelData
                description: TrayService.isHidden(modelData) ? I18n.tr("Hidden, not running") : I18n.tr("Pinned, not running")

                leading: TrayIconBox {
                    source: ""
                    color: missingRow.controlColor
                }

                // md-close
                ActionButton {
                    icon: "\u{f0156}"
                    text: I18n.tr("Forget")
                    size: Config.fontSizeIconSmall + Config.padding * 2
                    baseColor: missingRow.controlColor
                    onClicked: TrayService.forget(missingRow.modelData)
                }
            }
        }
    }

    // Tray item icon in a rounded box, like the launcher's app rows
    component TrayIconBox: Rectangle {
        id: iconBox

        property string source

        implicitWidth: Config.fontSizeIconLarge + Config.padding * 2
        implicitHeight: implicitWidth
        radius: Config.radiusLarge

        Image {
            id: icon
            anchors.centerIn: parent
            width: Config.fontSizeIconLarge
            height: width
            source: iconBox.source
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectFit
            visible: status === Image.Ready
        }

        // Missing or broken icon
        Image {
            anchors.centerIn: parent
            width: Config.fontSizeIconLarge
            height: width
            source: IconService.url("application-x-executable", "")
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectFit
            visible: icon.status !== Image.Ready
        }
    }
}
