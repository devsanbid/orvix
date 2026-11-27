pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.config
import qs.services

// This plugin's settings, shown in Settings › Plugins › Browser startup
// speedup.
//
// A plugin cannot import the shell's own rows (they live in a folder, not a
// module), so this is plain QtQuick built to look like them: a card per
// group, a title, and a row with a label, a description and a control. The
// colours and sizes come from qs.config, which a plugin can read, so it
// follows the theme without copying it.
ColumnLayout {
    id: page

    spacing: Config.spacing * 3

    // One titled card of rows, like the shell's SettingsGroup
    component Card: Rectangle {
        id: card

        default property alias content: column.data
        property string title

        Layout.fillWidth: true
        implicitHeight: column.implicitHeight + Config.padding * 4
        radius: Config.radiusLarge
        color: Config.cardColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Config.padding * 2
            spacing: Config.spacing

            Text {
                Layout.fillWidth: true
                visible: card.title !== ""
                text: card.title.toUpperCase()
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold: true
                font.letterSpacing: 1
                color: Config.accentColor
            }

            ColumnLayout {
                id: column

                Layout.fillWidth: true
                spacing: Config.spacing
            }
        }
    }

    // A label, a description and whatever control the row needs
    component Row: Rectangle {
        id: row

        default property alias control: controlSlot.data
        property string label
        property string description

        Layout.fillWidth: true
        implicitHeight: Math.max(textColumn.implicitHeight, controlSlot.implicitHeight) + Config.padding * 2
        radius: Config.radius
        color: Config.surface1Color

        ColumnLayout {
            id: textColumn

            anchors.left: parent.left
            anchors.right: controlSlot.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Config.padding
            anchors.rightMargin: Config.spacing
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: row.label
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                color: Config.textColor
            }

            Text {
                Layout.fillWidth: true
                visible: row.description !== ""
                text: row.description
                wrapMode: Text.WordWrap
                font.family: Config.font
                font.pixelSize: Config.fontSizeSmall
                color: Config.subtextColor
            }
        }

        RowLayout {
            id: controlSlot

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: Config.padding
            spacing: Config.spacing
        }
    }

    // A button that looks like the shell's ActionButton
    component Button: Rectangle {
        id: button

        property string text
        property bool enabled: true

        signal clicked

        implicitWidth: caption.implicitWidth + Config.padding * 3
        implicitHeight: Config.fontSizeNormal + Config.padding * 2
        radius: Config.radius
        color: !button.enabled ? Config.surface1Color : hover.hovered ? Config.surface2Color : Config.surface1Color
        opacity: button.enabled ? 1 : 0.4

        HoverHandler {
            id: hover
        }

        Text {
            id: caption

            anchors.centerIn: parent
            text: button.text
            font.family: Config.font
            font.pixelSize: Config.fontSizeSmall
            font.bold: true
            color: Config.textColor
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: button.enabled
            onClicked: button.clicked()
        }
    }

    Card {
        title: I18n.tr("Background browser")

        Row {
            label: I18n.tr("Status")
            description: BrowserSpeedup.running ? I18n.tr("%1 open", BrowserSpeedup.windows) : I18n.tr("Windows you open start the browser from scratch")

            Text {
                text: BrowserSpeedup.running ? I18n.tr("Running%1", BrowserSpeedup.browser !== "" ? " (" + BrowserSpeedup.browser + ")" : "") : I18n.tr("Stopped")
                font.family: Config.font
                font.pixelSize: Config.fontSizeNormal
                color: BrowserSpeedup.running ? Config.successColor : Config.subtextColor
            }
        }

        Row {
            label: I18n.tr("Start now")
            description: I18n.tr("Runs your default browser with no window, so the next one opens at once")

            Button {
                text: BrowserSpeedup.running ? I18n.tr("Restart") : I18n.tr("Start")
                onClicked: BrowserSpeedup.running ? BrowserSpeedup.restartIfChanged() : BrowserSpeedup.startService()
            }
        }

        Row {
            label: I18n.tr("Stop")
            description: I18n.tr("Stops the background browser; windows you have open keep running")

            Button {
                text: I18n.tr("Stop")
                enabled: BrowserSpeedup.running
                onClicked: BrowserSpeedup.stopService()
            }
        }

        Row {
            visible: BrowserSpeedup.note !== ""
            label: I18n.tr("Problem")
            description: BrowserSpeedup.note
        }
    }

    Card {
        title: I18n.tr("The bar")

        Row {
            label: I18n.tr("Show an icon while it runs")
            description: I18n.tr("A small bolt in the bar; off, the browser keeps running with nothing on screen")

            CheckBox {
                checked: PluginBridge.setting("showInBar", true)
                onToggled: PluginBridge.set("showInBar", checked)
            }
        }
    }

    Card {
        title: I18n.tr("About this plugin")

        Row {
            label: I18n.tr("Browsers")
            description: I18n.tr("Chromium, Chrome, Brave, Edge and Vivaldi. Firefox, Zen and Flatpak browsers have no keep-alive switch, so this does nothing for them.")
        }

        Row {
            label: I18n.tr("Memory")
            description: I18n.tr("The browser stays in memory (about 0.5–0.8 GB) with its extensions running")
        }
    }
}
