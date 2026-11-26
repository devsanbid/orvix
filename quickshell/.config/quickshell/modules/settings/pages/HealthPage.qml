pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../rows/"
import "../../../components/"

// Settings › System › Health: the same checks as `orvix doctor`, grouped by
// what they are about, problems first. Nothing is changed or installed here;
// a problem shows the command that fixes it, to run in a terminal.
ColumnLayout {
    id: root

    spacing: Config.spacing * 3

    // What each group is about, in the order of lib/doctor.sh
    readonly property var groups: [
        {
            title: I18n.noop("Desktop"),
            ids: ["hyprland", "hyprland-config", "quickshell", "wallpaper-daemon", "polkit", "clipboard", "jq"]
        },
        {
            title: I18n.noop("Theme"),
            ids: ["themes", "matugen", "theme-files", "theme-source"]
        },
        {
            title: I18n.noop("Apps and tools"),
            ids: ["terminal", "file-manager", "browser", "screenshot", "region", "ocr", "media", "notify"]
        },
        {
            title: I18n.noop("Updates"),
            ids: ["git", "git-changes"]
        },
        {
            title: I18n.noop("Omarchy"),
            ids: ["omarchy", "omarchy-shell"]
        }
    ]

    function checksOf(ids: var): var {
        return HealthService.checks.filter(c => ids.includes(c.id));
    }

    // The checks of a group, problems first
    function sorted(ids: var): var {
        const rank = l => l === "fail" ? 0 : l === "warn" ? 1 : 2;
        return checksOf(ids).slice().sort((a, b) => rank(a.level) - rank(b.level));
    }

    function colorOf(level: string): color {
        if (level === "fail")
            return Config.errorColor;
        if (level === "warn")
            return Config.warningColor;
        return Config.successColor;
    }

    function iconOf(level: string): string {
        if (level === "fail")
            return "\u{f0159}"; // circle-cross
        if (level === "warn")
            return "\u{f0026}"; // alert
        return "\u{f058}"; // check
    }

    Component.onCompleted: {
        HealthService.refresh();
        OmarchyService.refresh();
    }

    // ================= SUMMARY =================
    SettingsGroup {
        title: I18n.tr("Health")

        SettingRow {
            label: I18n.tr("Checks")
            description: HealthService.hasRun ? HealthService.summary : I18n.tr("Hyprland, Quickshell, the theme, your apps and the tools behind the shortcuts")

            ActionButton {
                icon: "\u{f0450}"
                text: HealthService.running ? I18n.tr("Checking…") : I18n.tr("Check again")
                enabled: !HealthService.running
                onClicked: HealthService.refresh()
            }
        }

        InfoRow {
            visible: HealthService.failCount > 0
            label: I18n.tr("What to do")
            value: I18n.tr("Run the commands shown below in a terminal. Nothing is installed or changed from here.")
        }
    }

    // ================= GROUPS =================
    Repeater {
        model: root.groups

        SettingsGroup {
            id: group

            required property var modelData

            readonly property var items: root.sorted(group.modelData.ids)

            visible: group.items.length > 0
            title: I18n.translate(group.modelData.title)

            Repeater {
                model: group.items

                SettingRow {
                    id: checkRow

                    required property var modelData

                    label: checkRow.modelData.what
                    // A failure shows the command; a warning, its hint
                    description: checkRow.modelData.level === "ok" || checkRow.modelData.fix === "" ? checkRow.modelData.state : checkRow.modelData.state + " — " + checkRow.modelData.fix
                    descriptionColor: checkRow.modelData.level === "ok" ? Config.subtextColor : root.colorOf(checkRow.modelData.level)

                    Text {
                        text: root.iconOf(checkRow.modelData.level)
                        font.family: Config.font
                        font.pixelSize: Config.fontSizeIconSmall
                        color: root.colorOf(checkRow.modelData.level)
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }
    }

    // Before the first run finishes
    SettingsGroup {
        visible: !HealthService.hasRun
        title: I18n.tr("Checking")

        InfoRow {
            label: I18n.tr("Status")
            value: HealthService.running ? I18n.tr("Running the checks…") : I18n.tr("Not checked yet")
        }
    }
}
