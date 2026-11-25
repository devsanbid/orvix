pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "OmarchyTheme.js" as OmarchyTheme

// Read-only view of the Omarchy install: version, current theme, its colors
// and whether omarchy-shell is running. Also the two safe actions Settings
// needs: apply an Omarchy theme (through `omarchy theme set`) and refresh
// Omarchy's own config. Nothing here writes Omarchy files directly.
//
// The theme is read from the live state Omarchy keeps:
//   ~/.local/state/omarchy/current/theme/colors.toml
//   ~/.local/state/omarchy/current/theme.name
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: home + "/.local/state/omarchy"
    readonly property string colorsPath: stateDir + "/current/theme/colors.toml"
    readonly property string namePath: stateDir + "/current/theme.name"
    readonly property string versionPath: "/usr/share/omarchy/version"
    readonly property string themesDir: "/usr/share/omarchy/themes"
    readonly property string userThemesDir: home + "/.config/omarchy/themes"

    // Raw file contents (FileView's text() is a function, so these properties
    // are what the bindings below watch)
    property string versionText: ""
    property string colorsText: ""
    property string nameText: ""

    readonly property bool installed: versionText.trim() !== "" || colorsText !== ""
    readonly property bool available: colorsText !== ""
    readonly property string version: versionText.trim()
    readonly property var colors: OmarchyTheme.parseColors(colorsText)
    readonly property string themeId: nameText.trim()
    readonly property string themeName: themeId !== "" ? OmarchyTheme.prettyName(themeId) : ""
    readonly property var themeData: available ? OmarchyTheme.toThemeData(colors, themeName) : null

    // [{ id, name, current }] from the system and user theme folders
    property var themes: []
    property bool shellRunning: false

    // Last action run from Settings
    property bool actionRunning: false
    property string lastAction: ""
    property int lastExit: 0
    property string lastOutput: ""

    signal themeChanged

    function refresh(): void {
        if (!themesProc.running)
            themesProc.running = true;
        if (!shellProc.running)
            shellProc.running = true;
    }

    function _setColors(): void {
        const text = colorsFile.text();
        if (text !== root.colorsText) {
            root.colorsText = text;
            root.themeChanged();
        }
    }

    // Applies one of the themes listed above, by its folder id. Anything else
    // is refused: the list is the allowlist.
    function applyTheme(id: string): bool {
        if (!themes.some(t => t.id === id))
            return false;
        return run(["omarchy", "theme", "set", id], I18n.tr("Applying %1", OmarchyTheme.prettyName(id)));
    }

    function refreshConfig(): bool {
        return run(["omarchy", "refresh", "config"], I18n.tr("Refreshing Omarchy config"));
    }

    // Fixed commands only; the arguments come from this file, never from a
    // text field.
    function run(args: var, label: string): bool {
        if (actionProc.running)
            return false;
        lastAction = label;
        lastOutput = "";
        lastExit = 0;
        actionRunning = true;
        actionProc.run(args, { label });
        return true;
    }

    Component.onCompleted: {
        root._setColors();
        root.refresh();
    }

    FileView {
        id: versionFile
        path: root.versionPath
        blockLoading: true
        printErrors: false
        onLoaded: root.versionText = text()
        onFileChanged: root.versionText = text()
    }

    FileView {
        id: colorsFile
        path: root.colorsPath
        blockLoading: true
        printErrors: false
        watchChanges: true
        onLoaded: root._setColors()
        onFileChanged: root._setColors()
    }

    // theme.name is rewritten in place by omarchy-theme-set, so it survives
    // the theme folder being replaced
    FileView {
        id: nameFile
        path: root.namePath
        blockLoading: true
        printErrors: false
        watchChanges: true
        onLoaded: root.nameText = text()
        onFileChanged: {
            root.nameText = text();
            root._setColors();
        }
    }

    Process {
        id: themesProc
        command: ["sh", "-c", `
            for d in "$1"/*/ "$2"/*/; do
                [ -f "$d/colors.toml" ] && basename "$d"
            done | sort -u
        `, "sh", root.themesDir, root.userThemesDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const current = root.themeId;
                root.themes = text.split("\n").map(s => s.trim()).filter(s => s !== "").map(id => ({
                    id,
                    name: OmarchyTheme.prettyName(id),
                    current: id === current
                }));
            }
        }
    }

    Process {
        id: shellProc
        // omarchy-shell runs as `quickshell -p /usr/share/omarchy/shell`
        command: ["sh", "-c", "pgrep -af 'quickshell.*(/usr/share/omarchy|omarchy)/shell' >/dev/null 2>&1"]
        onExited: code => root.shellRunning = code === 0
    }

    QueuedProcess {
        id: actionProc
        onExited: code => {
            root.actionRunning = false;
            root.lastExit = code;
            // A theme change rewrites the state files; the watchers above
            // pick them up, this makes the list and shell state fresh too
            root.refresh();
        }
        stdout: StdioCollector {
            onStreamFinished: root.lastOutput = text.trim()
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const err = text.trim();
                if (err !== "")
                    root.lastOutput = err;
            }
        }
    }
}
