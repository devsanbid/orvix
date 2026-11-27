pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"

// Bar template, position, height and margin.
ColumnLayout {
    id: page

    spacing: Config.spacing * 3

    SettingsGroup {
        title: I18n.tr("Style")

        // Label repeated here for the Settings search (it reads the page source)
        BarTemplatePicker {
            label: I18n.tr("Template")
        }

        ToggleRow {
            label: I18n.tr("Attach to the bar")
            description: Config.barIslands || Config.barFloating ? I18n.tr("Popups grow out of the screen edge with rounded joins (the bar has no continuous edge in its current style): Quick Settings, the dashboard and the launcher (dropdown, sidebar and spotlight next to the bar)") : I18n.tr("Popups grow out of the bar with rounded joins: Quick Settings, the dashboard and the launcher (dropdown, sidebar and spotlight next to the bar)")
            path: "bar.attachPopups"
        }
    }

    SettingsGroup {
        title: I18n.tr("Layout")

        SelectRow {
            label: I18n.tr("Position")
            description: I18n.tr("Screen edge the bar sits on")
            path: "bar.position"
            options: [
                {
                    label: I18n.tr("Top"),
                    icon: "\u{f1513}",
                    value: "top"
                },
                {
                    label: I18n.tr("Bottom"),
                    icon: "\u{f10a9}",
                    value: "bottom"
                }
            ]
        }

        SliderRow {
            label: I18n.tr("Height")
            description: I18n.tr("Height of the bar; the islands and buttons follow it")
            path: "bar.height"
            from: 24
            to: 48
            format: v => v + "px"
        }

        SliderRow {
            label: I18n.tr("Margin")
            description: I18n.tr("Gap between the floating bar and the screen edges")
            path: "bar.margin"
            enabled: Config.barFloating
            from: 0
            to: 24
            format: v => v + "px"
        }
    }

}
