pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// What a plugin's QML may use: its own settings, and its own folder.
//
// A plugin is loaded through PluginHost (see services/PluginHost.qml), which
// gives each plugin a `Plugin` object here before its QML is created. This
// singleton is the one indirection that makes that possible without the
// plugin prompting for it in every file.
//
// Deliberately small: a plugin reads and writes its own settings and can find
// its own files. It is given nothing else — no arbitrary state keys, no store
// access — so one plugin cannot rewrite another's settings or the shell's.
Singleton {
    id: root

    // Set by PluginHost while it builds a plugin's item
    property var _current: null

    readonly property string id: _current?.id ?? ""
    readonly property string dir: _current?.dir ?? ""
    readonly property var manifest: _current ?? ({})

    // A path inside the plugin's own folder. A request that would leave it is
    // refused and gives "" — the manifest is validated at install, but a
    // plugin's own code can ask for anything.
    function path(relative: string): string {
        const rel = String(relative ?? "");
        if (rel === "" || rel.startsWith("/") || rel.includes(".."))
            return "";
        return root.dir + "/" + rel;
    }

    function setting(key: string, fallback) {
        return root.id === "" ? fallback : PluginService.setting(root.id, key, fallback);
    }

    function set(key: string, value): void {
        if (root.id !== "")
            PluginService.setSetting(root.id, key, value);
    }

    // For PluginHost: which plugin the next items belong to
    function _enter(plugin): void {
        _current = plugin;
    }

    function _leave(): void {
        _current = null;
    }
}
