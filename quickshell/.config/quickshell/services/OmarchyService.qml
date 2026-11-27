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
    // Omarchy exports OMARCHY_PATH (its own lag is the reason a dev checkout
    // can be linked in place of the packaged one); /usr/share/omarchy is only
    // the fallback. Reading it here means a checkout, or a distro that puts it
    // elsewhere, works without Orvix knowing the path.
    readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"
    readonly property string versionPath: omarchyPath + "/version"
    readonly property string themesDir: omarchyPath + "/themes"
    readonly property string userThemesDir: home + "/.config/omarchy/themes"
    readonly property string systemPluginsDir: omarchyPath + "/shell/plugins"
    readonly property string userPluginsDir: home + "/.config/omarchy/plugins"

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
    readonly property int pluginCount: plugins.length

    // [{ id, name, current }] from the system and user theme folders
    property var themes: []
    // id -> parsed colors.toml, read with the list (no extra process per theme)
    property var _themeColors: ({})

    // A theme's colors, by id: {} while the list hasn't been read or the
    // theme's colors.toml is missing
    function colorsOf(id: string): var {
        return _themeColors[id] ?? {};
    }
    // [{ id, name, source }] — read from the plugin folders, not from the
    // running Omarchy shell, so it works while only Orvix runs. Informational:
    // Orvix does not load these plugins
    property var plugins: []
    property bool shellRunning: false

    // Settings › System › Omarchy: skip Orvix's shell at login while Omarchy's
    // runs (hypr/conf/autostart.lua starts scripts/shell-launch.sh, which
    // reads this). Off by default: the warning stays, nothing is stopped
    readonly property bool skipShellWithOmarchy: StateService.get("omarchy.skipShellWithOmarchy", false)

    function setSkipShellWithOmarchy(value: bool): void {
        StateService.set("omarchy.skipShellWithOmarchy", value);
    }

    // Keep Omarchy's bar (and dock) hidden so its shell can run behind Orvix
    // with plugins alive. The flag Omarchy itself reads lives in
    // ~/.local/state/omarchy/toggles/bar-off; `orvix omarchy` sets it, and
    // the post-update/post-boot hooks re-apply it.
    readonly property bool hideOmarchyBar: StateService.get("omarchy.hideOmarchyBar", false)
    // What the bar is doing now, read from Omarchy's own flag
    readonly property string barFlagPath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/toggles/bar-off"
    property bool omarchyBarHidden: false

    function setHideOmarchyBar(value: bool): void {
        StateService.set("omarchy.hideOmarchyBar", value);
        run([Paths.dots + "/local/.local/bin/orvix", "omarchy", value ? "on" : "off"], value ? I18n.tr("Hiding Omarchy's bar") : I18n.tr("Showing Omarchy's bar"));
    }

    // Installs the hooks that keep it hidden across `omarchy update` and login
    function installOmarchyHooks(): bool {
        return run([Paths.dots + "/local/.local/bin/orvix", "omarchy", "hooks", "install"], I18n.tr("Installing Omarchy's hooks"));
    }

    // The flag is created and removed rather than edited, so a process that
    // tests for the file is simpler and more reliable than a FileView on a
    // path that may not exist
    function refreshBarFlag(): void {
        if (!barFlagProc.running)
            barFlagProc.running = true;
    }

    Process {
        id: barFlagProc
        command: ["test", "-f", root.barFlagPath]
        onExited: code => root.omarchyBarHidden = code === 0
    }

    // Set by scripts/shell-launch.sh when it skipped Orvix's shell at login
    readonly property string skippedMarker: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/orvix-shell-skipped"
    property bool shellSkipped: false

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
        if (!pluginsProc.running)
            pluginsProc.running = true;
        root.refreshBarFlag();
        // The theme folder may have been replaced since the last read
        colorsFile.reload();
    }

    function _setColors(): void {
        const text = colorsFile.text();
        if (text !== root.colorsText) {
            root.colorsText = text;
            root.themeChanged();
        }
    }

    // `omarchy theme set` replaces the whole theme folder, so colors.toml is a
    // new inode: FileView's watch is still on the old one and won't fire
    // again. Re-pointing the FileView (reload) reads the new file and starts
    // watching it. Bar.qml watches a directory for the same reason.
    function _reloadColors(): void {
        colorsFile.reload();
        // A theme that only changed its name keeps the same colors; the list
        // and the name file are cheap to read again
        if (!themesProc.running)
            themesProc.running = true;
        nameFile.reload();
    }

    // Applies one of the themes listed above, by its folder id. Anything else
    // is refused: the list is the allowlist.
    function applyTheme(id: string): bool {
        if (!themes.some(t => t.id === id))
            return false;
        return run(["omarchy", "theme", "set", id], I18n.tr("Applying %1", OmarchyTheme.prettyName(id)));
    }

    function refreshConfig(): bool {
        // `omarchy refresh config` needs a config path: without one it only
        // prints its usage. The shell's own config is the closest to "the
        // config Orvix replaced", and Omarchy backs up what it finds there
        return run(["omarchy", "refresh", "config", "hypr"], I18n.tr("Refreshing Omarchy config"));
    }

    // Opens Omarchy's own theme picker (`omarchy theme switcher`, the
    // omarchy-theme-switcher window). It needs the Omarchy shell running
    function openThemeSwitcher(): bool {
        return run(["omarchy", "theme", "switcher"], I18n.tr("Opening Omarchy's theme switcher"));
    }

    // Omarchy's menu (omarchy.menu plugin, through omarchy-shell)
    function openMenu(): bool {
        return run(["omarchy", "menu"], I18n.tr("Opening Omarchy's menu"));
    }

    // The other direction, only when asked: Orvix's accent goes into the
    // active Omarchy theme through Omarchy's own command (scripts/
    // omarchy-accent.sh explains how; nothing Omarchy owns is edited)
    function applyAccent(color: string): bool {
        return run([Quickshell.env("HOME") + "/.config/quickshell/scripts/omarchy-accent.sh", String(color)], I18n.tr("Applying Orvix's accent to Omarchy"));
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
        actionProc.run(args, {
            label
        });
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
            // In place, so this is the reliable "the theme changed" signal:
            // re-read colors.toml through a fresh FileView, since the folder
            // (and the file's inode) were replaced under it
            root._reloadColors();
        }
    }

    Process {
        id: themesProc
        // id, then the theme's colors.toml base64'd on one line: a theme
        // missing from a later pass must not leave stale colors behind, and
        // base64 keeps the TOML's newlines out of this line format
        command: ["sh", "-c", `
            for d in "$1"/*/ "$2"/*/; do
                [ -f "$d/colors.toml" ] || continue
                printf '%s\t' "$(basename "$d")"
                base64 -w0 <"$d/colors.toml" 2>/dev/null || printf ''
                printf '\n'
            done | sort -u -t'	' -k1,1
        `, "sh", root.themesDir, root.userThemesDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const current = root.themeId;
                const colors = {};
                const list = text.split("\n").map(s => s.trim()).filter(s => s !== "").map(line => {
                    const tab = line.indexOf("\t");
                    const id = (tab >= 0 ? line.slice(0, tab) : line).trim();
                    const b64 = tab >= 0 ? line.slice(tab + 1) : "";
                    if (b64 !== "") {
                        try {
                            colors[id] = OmarchyTheme.parseColors(Qt.atob(b64));
                        } catch (e) {
                            colors[id] = {};
                        }
                    }
                    return id;
                }).filter(id => id !== "");
                root._themeColors = colors;
                root.themes = list.map(id => ({
                    id,
                    name: OmarchyTheme.prettyName(id),
                    current: id === current
                }));
            }
        }
    }

    Process {
        id: pluginsProc
        command: ["sh", "-c", `
            for base in "$1" "$2"; do
                [ -d "$base" ] || continue
                if [ "$base" = "$1" ]; then source=omarchy; else source=user; fi
                for dir in "$base"/*/; do
                    [ -f "$dir/manifest.json" ] || continue
                    id=$(basename "$dir")
                    name=$(jq -r '.name // empty' "$dir/manifest.json" 2>/dev/null || true)
                    [ -n "$name" ] || name=$id
                    printf '%s\t%s\t%s\n' "$id" "$source" "$name"
                done
            done
        `, "sh", root.systemPluginsDir, root.userPluginsDir]
        stdout: StdioCollector {
            onStreamFinished: {
                root.plugins = text.split("\n").map(line => line.trim()).filter(line => line !== "").map(line => {
                    const parts = line.split("\t");
                    return {
                        id: parts[0],
                        source: parts[1],
                        name: parts[2] || parts[0]
                    };
                });
            }
        }
    }

    Process {
        id: shellProc
        // omarchy-shell runs as `quickshell -p /usr/share/omarchy/shell`
        // Any Omarchy shell, wherever its config lives: the pattern matches
        // the folder name, not one hardcoded path
        command: ["sh", "-c", "pgrep -af 'quickshell.*(/omarchy/shell|omarchy-shell)' >/dev/null 2>&1"]
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
