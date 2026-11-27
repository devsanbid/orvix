pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// Launcher button and workspaces: the left end of the bar.
ColumnLayout {
    id: page

    spacing: Config.spacing * 3

    // What a right or middle click on the launcher button can do
    readonly property var launcherClickOptions: [
        {
            label: I18n.tr("Nothing"),
            value: "none"
        },
        {
            label: I18n.tr("Actions"),
            value: "actions"
        },
        {
            label: I18n.tr("Clipboard"),
            value: "clipboard"
        },
        {
            label: I18n.tr("Settings"),
            value: "settings"
        },
        {
            label: I18n.tr("Power"),
            value: "power"
        }
    ]


    SettingsGroup {
        title: I18n.tr("Launcher button")

        TemplatePicker {
            label: I18n.tr("Style")
            description: ({
                    "pill": I18n.tr("The logo on a soft accent pill that is always there"),
                    "compact": I18n.tr("A round button, the same size as the bar's other icons")
                })[Config.barLauncherStyle] ?? I18n.tr("Just the logo; a pill the size of the logo shows on hover")
            path: "bar.launcher.style"
            options: [
                {
                    label: I18n.tr("Logo"),
                    value: "logo"
                },
                {
                    label: I18n.tr("Pill"),
                    value: "pill"
                },
                {
                    label: I18n.tr("Compact"),
                    value: "compact"
                }
            ]
            preview: Component {
                LauncherButtonPreview {}
            }
        }

        SelectRow {
            label: I18n.tr("Icon")
            description: I18n.tr("The orvix logo, or your distro's logo from the Nerd Font")
            path: "bar.launcher.icon"
            options: [
                {
                    label: "orvix",
                    value: "orvix"
                },
                {
                    label: I18n.tr("Distro"),
                    icon: "\u{f31a}",
                    value: "distro"
                }
            ]
        }

        ToggleRow {
            label: I18n.tr("Animate")
            description: I18n.tr("The dot bounces on hover and rides the line when the launcher opens; the logo draws itself when the shell starts")
            path: "bar.launcher.animate"
        }

        SelectRow {
            label: I18n.tr("Right click")
            description: I18n.tr("Actions and Clipboard open that launcher mode")
            path: "bar.launcher.rightClick"
            options: page.launcherClickOptions
        }

        SelectRow {
            label: I18n.tr("Middle click")
            description: I18n.tr("Same choices as the right click")
            path: "bar.launcher.middleClick"
            options: page.launcherClickOptions
        }
    }

    SettingsGroup {
        title: I18n.tr("Workspaces")

        TemplatePicker {
            label: I18n.tr("Style")
            description: ({
                    "numbers": I18n.tr("Numbers of the workspaces in use, dots for the empty ones"),
                    "dots": I18n.tr("Filled dots for workspaces in use, rings for empty ones; the active one is a bar"),
                    "groups": I18n.tr("Numbers where neighbouring workspaces in use share one background"),
                    "icons": I18n.tr("Icons of the apps open on each workspace, numbers for the empty ones")
                })[Config.barWorkspaceStyle] ?? I18n.tr("A pill per workspace, solid when it has windows")
            path: "bar.workspaces.style"
            options: [
                {
                    label: I18n.tr("Pills"),
                    value: "pills"
                },
                {
                    label: I18n.tr("Numbers"),
                    value: "numbers"
                },
                {
                    label: I18n.tr("Dots"),
                    value: "dots"
                },
                {
                    label: I18n.tr("Groups"),
                    value: "groups"
                },
                {
                    label: I18n.tr("Icons"),
                    value: "icons"
                }
            ]
            preview: Component {
                WorkspaceStylePreview {}
            }
        }

        StepperRow {
            label: I18n.tr("Shown")
            description: I18n.tr("Workspaces in view at once; the strip scrolls to reach the others")
            path: "bar.workspaces.count"
            from: 3
            to: 15
            enabled: !Config.barWorkspaceHideEmpty
        }

        ToggleRow {
            label: I18n.tr("Hide empty")
            description: I18n.tr("Only workspaces with windows, plus the active one")
            path: "bar.workspaces.hideEmpty"
        }

        ToggleRow {
            label: I18n.tr("Scroll to switch")
            description: I18n.tr("The mouse wheel over the workspaces moves to the next or previous one, like the keys (Hyprland › Workspaces)")
            path: "bar.workspaces.scroll"
        }
    }

}
