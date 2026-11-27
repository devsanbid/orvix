pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"

// Notifications, the Quick Settings button and its indicators.
ColumnLayout {
    id: page

    spacing: Config.spacing * 3

    SettingsGroup {
        title: I18n.tr("Notifications")

        ToggleRow {
            label: I18n.tr("Notifications button")
            description: I18n.tr("A bell after Quick Settings that opens the notification history; the badge counts the conversations you haven't seen yet")
            path: "bar.showNotifications"
        }
    }

    SettingsGroup {
        title: I18n.tr("Quick Settings")

        TemplatePicker {
            label: I18n.tr("Style")
            description: Config.barQsStyle === "minimal" ? I18n.tr("One icon; a dot on it when something needs a glance: low battery, no network, a microphone in use") : I18n.tr("Network, Bluetooth and battery; muted audio and a microphone in use show up only then")
            path: "bar.quickSettings.style"
            options: [
                {
                    label: I18n.tr("Icons"),
                    value: "icons"
                },
                {
                    label: I18n.tr("Pill"),
                    value: "pill"
                },
                {
                    label: I18n.tr("Chips"),
                    value: "chips"
                },
                {
                    label: I18n.tr("Minimal"),
                    value: "minimal"
                }
            ]
            preview: Component {
                QsStylePreview {}
            }
        }

        ToggleRow {
            label: I18n.tr("Battery percentage")
            description: I18n.tr("Next to the battery icon, or inside the pill style's battery capsule (not in the minimal style)")
            path: "bar.quickSettings.batteryPercent"
            enabled: BatteryService.hasBattery && Config.barQsStyle !== "minimal"
        }
    }

    SettingsGroup {
        title: I18n.tr("Quick Settings indicators")

        ToggleRow {
            label: I18n.tr("Network")
            description: I18n.tr("Wi-Fi signal, or ethernet while a cable is connected")
            path: "bar.quickSettings.indicators.network"
        }

        ToggleRow {
            label: I18n.tr("Bluetooth")
            description: I18n.tr("While a device is connected")
            path: "bar.quickSettings.indicators.bluetooth"
        }

        ToggleRow {
            label: I18n.tr("Muted sound")
            description: I18n.tr("While the output is muted")
            path: "bar.quickSettings.indicators.volume"
        }

        ToggleRow {
            label: I18n.tr("Microphone")
            description: I18n.tr("While it's muted or an app is recording")
            path: "bar.quickSettings.indicators.mic"
        }

        ToggleRow {
            label: I18n.tr("Battery")
            description: I18n.tr("Level and charging, on laptops")
            path: "bar.quickSettings.indicators.battery"
        }
    }

    // ===================== OMARCHY'S BAR WIDGETS =====================
    // Orvix draws its own bar, so these belong to Omarchy's bar and only make
    // sense while its shell runs: they are its plugins, and Omarchy's own
    // registry turns them on and off. Shown here because this is where you
    // look when you want something on a bar.
    //
    // Two origins, kept apart: the widgets Omarchy ships, and the ones
    // installed on top of it (`omarchy plugin add <git-url>` or a folder in
    // ~/.config/omarchy/plugins). Each is grouped by Omarchy's own category.
}
