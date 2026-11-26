pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

// Rounded surface used by the sections of popups (system monitor, calendar...)
Rectangle {
    id: root

    default property alias content: layout.data
    property alias spacing: layout.spacing
    readonly property int padding: Config.padding * 2

    // The overview's keyboard highlight (OverviewTab): an outline, drawn
    // inside the card so the layout doesn't move
    property bool focused: false

    implicitWidth: layout.implicitWidth + padding * 2
    implicitHeight: layout.implicitHeight + padding * 2
    radius: Config.radiusLarge
    color: Config.cardColor
    border.width: root.focused ? 2 : 0
    border.color: Config.accentColor

    Behavior on border.width {
        enabled: !Config.themeTransitioning
        NumberAnimation {
            duration: Config.animDurationShort
        }
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: Config.spacing
    }
}
