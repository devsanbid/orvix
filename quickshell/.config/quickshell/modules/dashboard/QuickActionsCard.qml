pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// The few things worth one click from the overview: the launcher, Settings,
// a screenshot, the wallpaper picker, the lock screen and the power menu.
//
// Each button is one stop of the overview's keyboard ring (OverviewTab): its
// key is "action:<id>", Enter runs it, and the arrows move through them in
// order. A click gives a button the highlight too, so the mouse and the keys
// never disagree about where it is.
Rectangle {
    id: root

    // The overview's highlight, and where a click on a button moves it
    property string focusedKey: ""
    signal focused(string key)

    readonly property var actions: models
    readonly property var models: [
        {
            id: "launcher",
            icon: "\u{f0a1a}",
            label: I18n.tr("Apps"),
            run: () => LauncherService.toggle()
        },
        {
            id: "settings",
            icon: "\u{f0493}",
            label: I18n.tr("Settings"),
            run: () => SettingsService.toggle()
        },
        {
            id: "screenshot",
            icon: "\u{f0516}",
            label: I18n.tr("Screenshot"),
            run: () => {
                DashboardService.close();
                ShortcutService.requestScreenshotAfter(Config.animDurationShort);
            }
        },
        {
            id: "wallpaper",
            icon: "\u{f0727}",
            label: I18n.tr("Wallpaper"),
            run: () => WallpaperPickerService.toggle()
        },
        {
            id: "lock",
            icon: "\u{f023}",
            label: I18n.tr("Lock"),
            run: () => LockService.lock()
        },
        {
            id: "power",
            icon: "\u{f0425}",
            label: I18n.tr("Power"),
            run: () => PowerService.toggle()
        }
    ]

    // [{ key, visible, run }] for the overview's ring
    readonly property var stops: models.map(a => ({
            key: "action:" + a.id,
            visible: true,
            run: a.run
        }))

    implicitHeight: row.implicitHeight + Config.padding * 3
    radius: Config.radiusLarge
    color: Config.cardColor

    RowLayout {
        id: row

        anchors.fill: parent
        anchors.margins: Config.padding * 1.5
        spacing: Config.spacing

        Repeater {
            model: root.models

            Rectangle {
                id: button

                required property var modelData

                readonly property bool focused: root.focusedKey === "action:" + button.modelData.id

                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitWidth: Config.fontSizeNormal * 5
                implicitHeight: column.implicitHeight + Config.padding * 2
                radius: Config.radius
                color: mouse.containsMouse || button.focused ? Config.surface2Color : Config.surface1Color

                Behavior on color {
                    enabled: !Config.themeTransitioning
                    ColorAnimation {
                        duration: Config.animDurationShort
                    }
                }

                ColumnLayout {
                    id: column

                    anchors.centerIn: parent
                    spacing: Config.padding / 2

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: button.modelData.icon
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIcon
                        color: Config.accentColor
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: button.modelData.label
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeSmall
                        color: Config.textColor
                    }
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.focused("action:" + button.modelData.id);
                        button.modelData.run();
                    }
                }
            }
        }
    }
}
