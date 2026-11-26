pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../calendar/"
import "../../components/"

// Clock, weather, the month, the player, resource usage and quick actions.
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
//
// Keyboard: the dashboard's key handler sends the arrows and Enter here (see
// handleKey). Up, down, left and right move a highlight between the cards in
// reading order, plus the buttons of the action bar; Enter or Space does what
// clicking the highlighted card does (opens its tab), and on an action button
// it runs the action.
GridLayout {
    id: root

    // Shown to the user (the dashboard is open on this tab)
    property bool active: false

    readonly property bool focusMode: DashboardService.overviewLayout === "focus"
    readonly property bool hasPlayer: MprisService.hasPlayer
    // Columns need room; below this the cards stack
    readonly property bool wide: width >= Config.fontSizeNormal * 44

    // The highlight: "" when no card has it (the keys bring it in)
    property string focusedKey: ""

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
        else
            root.focusedKey = "";
    }

    // ==================== KEYBOARD ====================
    // The stops, in reading order. `visible` false ones are skipped, so the
    // highlight never sits on a card that isn't there.
    readonly property var stops: [
        {
            key: "clock",
            visible: true,
            run: () => DashboardService.tab = "weather"
        },
        {
            key: "weather",
            visible: true,
            run: () => DashboardService.tab = "weather"
        },
        {
            key: "calendar",
            visible: !root.focusMode,
            run: () => DashboardService.tab = "overview"
        },
        {
            key: "player",
            visible: root.hasPlayer,
            run: () => DashboardService.tab = "media"
        },
        {
            key: "resources",
            visible: true,
            run: () => DashboardService.tab = "system"
        }
    ].concat(actions.visible ? actions.stops : [])

    readonly property var visibleStops: stops.filter(s => s.visible)

    function _move(delta: int): void {
        const list = visibleStops;
        if (list.length === 0)
            return;
        const at = list.findIndex(s => s.key === root.focusedKey);
        root.focusedKey = at === -1 ? list[delta > 0 ? 0 : list.length - 1].key : list[(at + delta + list.length) % list.length].key;
    }

    function _activate(): void {
        const stop = visibleStops.find(s => s.key === root.focusedKey);
        if (stop)
            stop.run();
    }

    // true when the key was used (the dashboard's handler then accepts it)
    function handleKey(key: int, modifiers: int): bool {
        switch (key) {
        case Qt.Key_Left:
        case Qt.Key_Up:
            root._move(-1);
            return true;
        case Qt.Key_Right:
        case Qt.Key_Down:
            root._move(1);
            return true;
        case Qt.Key_Tab:
            root._move(modifiers & Qt.ShiftModifier ? -1 : 1);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            root._activate();
            return true;
        default:
            return false;
        }
    }

    function _is(key: string): bool {
        return root.active && root.focusedKey === key;
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

        focused: root._is("clock")
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

        focused: root._is("weather")
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

        focused: root._is("calendar")
    }

    PlayerCard {
        Layout.row: !root.wide ? (root.focusMode ? 2 : 3) : root.focusMode ? 1 : 0
        Layout.column: root.wide ? (root.focusMode ? 1 : 2) : 0
        Layout.rowSpan: !root.wide ? 1 : root.focusMode ? 1 : 3
        Layout.columnSpan: 1
        Layout.preferredWidth: root.wide ? (root.focusMode ? 260 : 220) : -1
        Layout.fillWidth: !root.wide
        Layout.fillHeight: root.wide
        visible: root.hasPlayer

        focused: root._is("player")
    }

    ResourcesCard {
        Layout.row: root.wide ? 2 : root.focusMode ? 3 : 4
        Layout.column: 0
        // The player only sits in the second column of row 1 in Focus, so the
        // resource row can always run full width there
        Layout.columnSpan: !root.wide ? 1 : root.focusMode ? 2 : (root.hasPlayer ? 2 : 3)
        Layout.fillWidth: true

        focused: root._is("resources")
    }

    // The things worth one click, and the end of the keyboard ring
    QuickActionsCard {
        id: actions

        Layout.row: root.wide ? 3 : root.focusMode ? 4 : 5
        Layout.column: 0
        Layout.columnSpan: root.wide ? 3 : 1
        Layout.fillWidth: true

        focusedKey: root.focusedKey
        onFocused: key => root.focusedKey = key
    }
}
