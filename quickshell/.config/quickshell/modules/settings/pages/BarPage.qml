pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// The bar, in tabs. The page used to be one column of ten groups and a few
// hundred rows of settings — a long scroll where the thing you wanted was
// rarely on screen. It is the same controls, split by what they are about:
//
//   Style      template, position, height, margin
//   Widgets    the launcher button and the workspaces
//   Center     clock or buttons, and what the buttons lead to
//   Tray       the system tray and its items
//   Quick      the notification bell and Quick Settings
//   Plugins    Omarchy's bar widgets and the ones installed on top
//   Behaviour  whether there is a bar at all, and auto hide
//
// "The bar is off" is handled first and on its own: with `bar.show` false the
// other tabs would all be settings for something that isn't drawn, so the
// page says so and offers to bring it back. The tab is remembered in
// state.json (`bar.settingsTab`), so the page comes back where it was.
ColumnLayout {
    id: page

    spacing: Config.spacing * 3

    readonly property var tabs: [
        {
            id: "style",
            label: I18n.tr("Style"),
            icon: "\u{f03d8}"
        },
        {
            id: "widgets",
            label: I18n.tr("Widgets"),
            icon: "\u{f04f0}"
        },
        {
            id: "center",
            label: I18n.tr("Center"),
            icon: "\u{f0954}"
        },
        {
            id: "tray",
            label: I18n.tr("Tray"),
            icon: "\u{f0c9e}"
        },
        {
            id: "quick",
            label: I18n.tr("Quick"),
            icon: "\u{f0493}"
        },
        {
            id: "plugins",
            label: I18n.tr("Plugins"),
            icon: "\u{f0fe7}",
            // Nothing to configure without Omarchy: the tab hides rather
            // than showing an empty page
            visible: OmarchyBarWidgets.available
        },
        {
            id: "behavior",
            label: I18n.tr("Behavior"),
            icon: "\u{f0493}"
        }
    ].filter(t => t.visible !== false)

    readonly property int tabIndex: Math.max(0, tabs.findIndex(t => t.id === tabId))

    property string tabId: StateService.get("bar.settingsTab", "style")

    // A remembered tab that no longer exists (Omarchy removed) lands on Style
    Component.onCompleted: {
        if (!tabs.some(t => t.id === tabId))
            tabId = "style";
    }

    function selectTab(id: string): void {
        tabId = id;
        StateService.set("bar.settingsTab", id);
    }

    // ===================== THE BAR IS OFF =====================
    // Its own state, not a tab: a setting for a bar that isn't drawn would be
    // misleading, and this is where someone turns it back on
    SettingsGroup {
        visible: !Config.barVisible
        title: I18n.tr("The bar is off")

        InfoRow {
            label: I18n.tr("Bar")
            value: I18n.tr("Orvix isn't drawing a bar. The screens have the space back.")
        }

        SettingRow {
            label: I18n.tr("Show the bar")
            description: I18n.tr("Draw it again and come back to these settings")

            ActionButton {
                icon: "\u{f012c}"
                text: I18n.tr("Turn on")
                onClicked: StateService.set("bar.show", true)
            }
        }
    }

    // ===================== TABS =====================
    SettingsGroup {
        visible: Config.barVisible
        title: ""

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: tabBar.implicitHeight

            QsTabBar {
                id: tabBar

                anchors.fill: parent
                tabs: page.tabs
                currentIndex: page.tabIndex
                onSelected: index => page.selectTab(page.tabs[index].id)
            }
        }
    }

    // Wrapped in an Item: a Loader is not an Item, so Layout attached
    // properties on it have nowhere to go
    Item {
        visible: Config.barVisible
        Layout.fillWidth: true
        Layout.preferredHeight: tabLoader.implicitHeight

        Loader {
            id: tabLoader

            width: parent.width
            sourceComponent: {
                switch (page.tabId) {
                case "widgets":
                    return widgetsTab;
                case "center":
                    return centerTab;
                case "tray":
                    return trayTab;
                case "quick":
                    return quickTab;
                case "plugins":
                    return pluginsTab;
                case "behavior":
                    return behaviorTab;
                default:
                    return styleTab;
                }
            }
        }
    }

    Component {
        id: styleTab
        BarTabStyle {}
    }

    Component {
        id: widgetsTab
        BarTabWidgets {}
    }

    Component {
        id: centerTab
        BarTabCenter {}
    }

    Component {
        id: trayTab
        BarTabTray {}
    }

    Component {
        id: quickTab
        BarTabQuick {}
    }

    Component {
        id: pluginsTab
        BarTabPlugins {}
    }

    Component {
        id: behaviorTab
        BarTabBehavior {}
    }
}
