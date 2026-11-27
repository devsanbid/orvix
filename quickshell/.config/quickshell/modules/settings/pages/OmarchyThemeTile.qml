pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// One Omarchy theme, as a swatch: its own background, accent and text, the
// name, and a tick on the one Omarchy is using. Clicking applies it through
// Omarchy's own command (`omarchy theme set`), which is why this is a
// separate tile from ThemeTile: a preset is a file Orvix owns, an Omarchy
// theme belongs to Omarchy and changing it is a request to Omarchy.
Rectangle {
    id: root

    required property var modelData
    // The theme the grid is previewing
    property bool selected: false

    readonly property var pal: root.modelData.palette ?? ({})
    readonly property bool current: root.modelData.current === true
    readonly property bool applied: OmarchyService.actionRunning && OmarchyService.lastAction !== "" && root.selected

    signal activated

    implicitHeight: body.implicitHeight + Config.padding * 3
    radius: Config.radiusLarge
    color: Config.cardColor
    border.width: root.selected ? 2 : 1
    border.color: root.selected ? Config.accentColor : Qt.alpha(Config.subtextColor, 0.18)

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    ColumnLayout {
        id: body

        anchors.fill: parent
        anchors.margins: Config.padding * 1.5
        spacing: Config.padding

        // The theme's own colors: background block, a strip of accent and text
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Config.fontSizeIconLarge * 2.4
            radius: Config.radius
            color: root.pal.theme_background || root.pal.background || "#1a1b26"
            border.width: 1
            border.color: Qt.alpha(Config.subtextColor, 0.2)

            RowLayout {
                anchors.fill: parent
                anchors.margins: Config.padding
                spacing: Config.padding / 2

                Rectangle {
                    Layout.preferredWidth: Config.fontSizeIconLarge
                    Layout.fillHeight: true
                    radius: Config.radius
                    color: root.pal.accent || "#7aa2f7"
                }

                Rectangle {
                    Layout.preferredWidth: Config.fontSizeIconLarge * 0.6
                    Layout.fillHeight: true
                    radius: Config.radius
                    color: root.pal.success || root.pal.green || "#9ece6a"
                }

                Rectangle {
                    Layout.preferredWidth: Config.fontSizeIconLarge * 0.6
                    Layout.fillHeight: true
                    radius: Config.radius
                    color: root.pal.warning || root.pal.yellow || "#e0af68"
                }

                Item {
                    Layout.fillWidth: true
                }

                // Text on the theme's background, so it reads as the theme does
                Text {
                    text: "Aa" // i18n-ignore: a sample, not prose
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    font.bold: true
                    color: root.pal.foreground || "#c0caf5"
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Config.padding / 2

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: root.modelData.name
                    elide: Text.ElideRight
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeNormal
                    font.bold: root.selected
                    color: Config.textColor
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.current || root.applied
                    text: root.applied ? I18n.tr("Applying…") : I18n.tr("In use in Omarchy")
                    elide: Text.ElideRight
                    font.family: Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.accentColor
                }
            }

            Text {
                visible: root.current
                text: "\u{f012c}"
                font.family: Config.font
                font.pixelSize: Config.fontSizeIconSmall
                color: Config.accentColor
            }
        }
    }
}
