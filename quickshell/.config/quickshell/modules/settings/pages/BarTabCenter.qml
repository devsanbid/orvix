pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"

// The center: clock or buttons, and what they show.
ColumnLayout {
    id: page

    spacing: Config.spacing * 3

    SettingsGroup {
        title: I18n.tr("Center")

        SelectRow {
            label: I18n.tr("Style")
            description: Config.barCenterClock ? I18n.tr("The clock alone, with cava faintly behind it while something plays; hover shows the track") : I18n.tr("The clock plus the buttons below, each opening its dashboard tab")
            path: "bar.centerStyle"
            options: [
                {
                    label: I18n.tr("Buttons"),
                    icon: "\u{f056e}",
                    value: "buttons"
                },
                {
                    label: I18n.tr("Clock"),
                    icon: "\u{f0954}",
                    value: "clock"
                }
            ]
        }

        ToggleRow {
            label: I18n.tr("Media")
            description: I18n.tr("Cover and spectrum of what's playing, title on hover; opens the dashboard's Media tab")
            path: "bar.showMedia"
            enabled: !Config.barCenterClock && DashboardService.hasTab("media")
        }

        ToggleRow {
            label: I18n.tr("System")
            description: I18n.tr("CPU usage graph; opens the dashboard's System tab")
            path: "bar.showSystem"
            enabled: !Config.barCenterClock && DashboardService.hasTab("system")
        }

        ToggleRow {
            label: I18n.tr("Weather")
            description: I18n.tr("Its own button for the Weather tab; off, the clock shows the weather")
            path: "bar.showWeather"
            enabled: !Config.barCenterClock && DashboardService.hasTab("weather")
        }

        SelectRow {
            label: I18n.tr("Keyboard layout")
            description: I18n.tr("The layout in use: click to pick one, scroll to switch. Auto shows it with two or more layouts")
            path: "bar.keyboardLayout"
            options: [
                {
                    label: I18n.tr("Auto"),
                    value: "auto"
                },
                {
                    label: I18n.tr("Always"),
                    value: "always"
                },
                {
                    label: I18n.tr("Never"),
                    value: "never"
                }
            ]
        }
    }

}
