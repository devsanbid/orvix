pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../calendar/"
import "../../components/"

// Clock, weather, the month, the player and resource usage.
//
// Two layouts, switched from the button beside the tabs, Settings › Dashboard
// or Ctrl+Shift+O:
//   Classic  the month calendar beside the clock and weather, player on the
//            right
//   Focus    the clock across the top, weather and player below it, no
//            calendar: the few things worth seeing at a glance
//
// When the dashboard is too narrow for columns (a small screen) both layouts
// stack into one column. GPU and disk usage are only sampled while active.
GridLayout {
    id: root

    // Shown to the user (the dashboard is open on this tab)
    property bool active: false

    readonly property bool focusMode: DashboardService.overviewLayout === "focus"
    readonly property bool hasPlayer: MprisService.hasPlayer
    // Columns need room; below this the cards stack
    readonly property bool wide: width >= Config.fontSizeNormal * 44

    // Back to the current month, without the slide animation
    function reset() {
        monthCard.displayMonth = TimeService.today.getMonth();
        monthCard.displayYear = TimeService.today.getFullYear();
        monthCard.selectedDate = TimeService.today;
    }

    // GPU and disk usage are only sampled while someone watches
    Watcher {
        service: SystemMonitorService
        active: root.active
    }
    onActiveChanged: {
        if (active)
            WeatherService.refresh(false);
    }

    rowSpacing: Config.spacing
    columnSpacing: Config.spacing

    ClockCard {
        Layout.row: 0
        Layout.column: 0
        // In Focus the time spans the whole width, so it reads first
        Layout.columnSpan: root.focusMode && root.wide ? 2 : 1
        Layout.preferredWidth: root.wide && !root.focusMode ? 250 : -1
        Layout.fillWidth: true
    }

    WeatherNowCard {
        Layout.row: 1
        Layout.column: 0
        Layout.columnSpan: root.focusMode && root.wide && !root.hasPlayer ? 2 : 1
        Layout.preferredWidth: root.wide && !root.focusMode ? 250 : -1
        Layout.fillWidth: true
        // Beside the month/player it fills the column; stacked it keeps its
        // own height
        Layout.fillHeight: root.wide
    }

    MonthCard {
        id: monthCard

        // Focus leaves the calendar out on purpose
        visible: !root.focusMode
        Layout.row: root.wide ? 0 : 2
        Layout.column: root.wide ? 1 : 0
        Layout.rowSpan: root.wide ? 2 : 1
        Layout.fillWidth: true
        Layout.fillHeight: root.wide
    }

    PlayerCard {
        Layout.row: !root.wide ? (root.focusMode ? 2 : 3) : root.focusMode ? 1 : 0
        Layout.column: root.wide ? (root.focusMode ? 1 : 2) : 0
        Layout.rowSpan: !root.wide ? 1 : root.focusMode ? 1 : 3
        Layout.columnSpan: 1
        Layout.preferredWidth: root.wide ? (root.focusMode ? 260 : 220) : -1
        Layout.fillWidth: !root.wide
        Layout.fillHeight: root.wide
    }

    ResourcesCard {
        Layout.row: root.wide ? 2 : root.focusMode ? 3 : 4
        Layout.column: 0
        // The player only sits in the second column of row 1 in Focus, so the
        // resource row can always run full width there
        Layout.columnSpan: !root.wide ? 1 : root.focusMode ? 2 : (root.hasPlayer ? 2 : 3)
        Layout.fillWidth: true
    }
}
