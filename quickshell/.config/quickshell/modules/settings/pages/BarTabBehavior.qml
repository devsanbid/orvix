pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// Auto hide and the rest of the bar's behaviour.
ColumnLayout {
    id: page

    spacing: Config.spacing * 3

    SettingsGroup {
        title: I18n.tr("Behavior")

        // The bar at all. Off, its window isn't created: the screens get the
        // space back, popups dock to the edge, and this row stays reachable
        // to turn it on again (Settings opens without a bar).
        ToggleRow {
            label: I18n.tr("Show the bar")
            description: Config.barVisible ? I18n.tr("Off hides the bar completely; the screens get its space back and this page keeps working") : I18n.tr("The bar is off. Turn it on here, or with: orvix bar on")
            path: "bar.show"
        }

        ToggleRow {
            label: I18n.tr("Auto hide")
            description: I18n.tr("Hide the bar until the pointer reaches its edge of the screen")
            path: "bar.autoHide"
            enabled: Config.barVisible
        }
    }
}
