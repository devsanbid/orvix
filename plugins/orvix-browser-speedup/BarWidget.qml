pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.config
import qs.services

// The bar widget: a small bolt, there only while the background browser is
// running. The point of the plugin is that you don't notice it, so it takes
// no room at all when the browser is stopped, and its setting can hide it
// while leaving the background browser running.
Item {
    id: root

    // Settings › Plugins › this plugin. Read through PluginBridge, which the
    // host sets to this plugin before the widget is created.
    readonly property bool wanted: PluginBridge.setting("showInBar", true)
    readonly property bool active: BrowserSpeedup.running && root.wanted

    // A bar widget is sized by the bar: no room when it has nothing to say
    visible: root.active
    implicitWidth: root.active ? label.implicitWidth + Config.padding * 2 : 0
    implicitHeight: root.active ? Config.barHeight : 0

    HoverHandler {
        id: hover
    }

    Text {
        id: label

        anchors.centerIn: parent
        text: "\u{f0e7}" // bolt
        font.family: Config.font
        font.pixelSize: Config.fontSizeNormal
        color: hover.hovered ? Config.accentColor : Config.subtextColor

        Behavior on color {
            ColorAnimation {
                duration: Config.animDurationShort
            }
        }
    }

    // What it is, on hover. A bar widget has no room for prose.
    QsToolTip {
        text: BrowserSpeedup.browser !== "" ? I18n.tr("%1 is warm: new windows open instantly", BrowserSpeedup.browser) : I18n.tr("The background browser is running")
        shown: hover.hovered
    }
}
