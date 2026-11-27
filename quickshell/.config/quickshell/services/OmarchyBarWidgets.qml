pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "OmarchyBarWidgets.js" as Lib

// Omarchy's bar widgets (the plugins with kind "bar-widget"), for the
// Settings › Bar page.
//
// Omarchy publishes every plugin it knows in `omarchy plugin catalog` (JSON,
// first-party and user ones). The ones that draw on a bar are the
// `bar-widget` kind: clock, tray, weather, media… Each entry is
//   { id, name, description, category, enabled, onBar, allowMultiple }
// where `enabled` is what Omarchy's shell reports right now and `onBar` is
// whether it sits in shell.json's bar layout.
//
// These widgets belong to Omarchy's bar, not to Orvix's: they show up in
// Settings only while Omarchy's shell runs (it is what draws and toggles
// them), and adding one calls Omarchy's own plugin registry. Nothing here
// edits Omarchy's files.
//
// The parsing rules are in OmarchyBarWidgets.js, tested in node.

Singleton {
    id: root

    // Omarchy installed, with a shell that can answer
    readonly property bool available: OmarchyService.available
    readonly property bool shellRunning: OmarchyService.shellRunning

    // What the catalogue said (the names and categories), what the shell
    // reports (enabled) and what the layout says (onBar); `widgets` is the
    // three folded together
    property var _catalog: []
    property var _enabled: ({})
    property var _onBar: ({})
    // [{ id, name, description, category, enabled, onBar, allowMultiple }]
    readonly property var widgets: Lib.merge(_catalog, _onBar, _enabled)
    property bool loading: false
    property string error: ""
    property bool loaded: false

    // The page keeps the two origins apart: Omarchy's own widgets, then the
    // ones installed from a git repo or written by hand. Each is grouped by
    // Omarchy's own category (Time, Network, Audio…).
    readonly property var omarchyWidgets: widgets.filter(w => w.source !== "community")
    readonly property var communityWidgets: widgets.filter(w => w.source === "community")
    readonly property var omarchyCategories: Lib.groupByCategory(omarchyWidgets)
    readonly property var communityCategories: Lib.groupByCategory(communityWidgets)

    readonly property int addedCount: widgets.filter(w => w.onBar).length
    readonly property int enabledCount: widgets.filter(w => w.enabled).length

    readonly property string shellJsonPath: Quickshell.env("HOME") + "/.config/omarchy/shell.json"

    // Reads the catalogue and the live enabled state. Called when the Bar
    // page opens and when one of the buttons is pressed.
    function refresh(): void {
        if (!available || loading)
            return;
        loading = true;
        catalogProc.running = true;
        enabledProc.running = true;
        layoutFile.reload();
    }

    // Turns one on. `placement` is optional (Omarchy picks the default spot)
    function enable(id: string): void {
        if (!shellRunning) {
            error = I18n.tr("Omarchy's shell isn't running, so its bar can't change");
            return;
        }
        run(["omarchy", "plugin", "enable", id], I18n.tr("Adding %1 to Omarchy's bar", _name(id)));
    }

    function disable(id: string): void {
        if (!shellRunning) {
            error = I18n.tr("Omarchy's shell isn't running, so its bar can't change");
            return;
        }
        run(["omarchy", "plugin", "disable", id], I18n.tr("Removing %1 from Omarchy's bar", _name(id)));
    }

    function toggle(id: string, on: bool): void {
        if (on)
            enable(id);
        else
            disable(id);
    }

    function _name(id: string): string {
        return widgets.find(w => w.id === id)?.name ?? id;
    }

    // One action at a time: the registry answers slowly when it rescans
    property string pendingId: ""
    property bool actionRunning: false

    function run(args: var, label: string): void {
        if (actionProc.running)
            return;
        actionRunning = true;
        lastAction = label;
        actionProc.run(args, {
            label
        });
    }

    property string lastAction: ""
    property string lastOutput: ""

    // shell.json's bar layout, to know what is on the bar
    function _setLayout(text: string): void {
        _onBar = Lib.layoutIds(text);
    }

    FileView {
        id: layoutFile
        path: root.shellJsonPath
        blockLoading: true
        printErrors: false
        watchChanges: true
        onLoaded: root._setLayout(text())
        onFileChanged: root._setLayout(text())
    }

    // Every plugin Omarchy knows
    Process {
        id: catalogProc
        command: ["omarchy", "plugin", "catalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = Lib.parseCatalog(text);
                if (list.length === 0 && text.trim() !== "")
                    root.error = I18n.tr("Unexpected output from omarchy plugin catalog");
                root._catalog = list;
            }
        }
        onExited: code => {
            root.loading = false;
            root.loaded = true;
            if (code !== 0 && root._catalog.length === 0)
                root.error = I18n.tr("omarchy plugin catalog failed");
        }
    }

    // What the running shell reports: only there while it runs
    Process {
        id: enabledProc
        command: root.shellRunning ? ["omarchy-shell", "shell", "listPlugins"] : []
        stdout: StdioCollector {
            onStreamFinished: root._enabled = Lib.parseEnabled(text)
        }
    }

    QueuedProcess {
        id: actionProc
        onExited: code => {
            root.actionRunning = false;
            if (code !== 0)
                root.error = I18n.tr("%1 failed", root.lastAction);
            // The layout and the catalogue moved: read them again
            root.loading = false;
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
