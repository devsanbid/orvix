pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "PluginStore.js" as Lib

// The Orvix plugin system: what is installed, what is enabled, and each
// plugin's settings.
//
// The format and rules are docs/PLUGIN_SPEC.md, and .data/orvix-cli/lib/
// plugin.sh is the validator the CLI uses. This reads the same two places and
// deliberately does no validation of its own: a plugin only reaches the store
// through `orvix plugin install`, which has already checked it.
//
//   ~/.config/orvix/plugins/<id>/manifest.json   the plugins
//   ~/.local/state/orvix/plugins.json            enabled, and user settings
//
// A plugin's QML is loaded by PluginHost.qml; this service is only the data.
Singleton {
    id: root

    readonly property string storeDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/orvix/plugins"
    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/orvix/plugins.json"

    // Every installed plugin, one object each. Rebuilt when the store or the
    // state changes on disk.
    property var plugins: []
    property bool loading: false
    property string error: ""

    readonly property var enabled: plugins.filter(p => p.enabled)
    readonly property var disabled: plugins.filter(p => !p.enabled)
    readonly property int count: plugins.length

    // The ones the bar can show, in the user's order
    readonly property var barPlugins: plugins.filter(p => p.enabled && p.kinds.includes("bar-widget"))

    function byId(id: string): var {
        return plugins.find(p => p.id === id) ?? null;
    }

    // A plugin's setting, with the manifest's default behind it
    function setting(id: string, key: string, fallback) {
        const p = byId(id);
        const stored = p?.settings?.[key];
        if (stored !== undefined)
            return stored;
        const declared = p?.defaults?.[key];
        return declared !== undefined ? declared : fallback;
    }

    function setSetting(id: string, key: string, value): void {
        setPluginState(id, "settings", Object.assign({}, byId(id)?.settings ?? {}, {
            [key]: value
        }));
    }

    // Merges a key into a plugin's record in plugins.json, and reloads
    function setPluginState(id: string, key: string, value): void {
        stateWriter.setValue(id, key, value);
    }

    function refresh(): void {
        if (!listProc.running)
            listProc.running = true;
        stateFile.reload();
    }

    // The state file's text -> { enabled, settings } per plugin id
    property var stored: ({})
    function _setStored(text: string): void {
        stored = Lib.parseState(text);
        _rebuild();
    }

    // The store's listing -> the plugins (the state is merged in after)
    property var found: []
    function _setFound(list: var): void {
        found = list;
        _rebuild();
    }

    function _rebuild(): void {
        plugins = found.map(p => {
            const s = stored[p.id] ?? {};
            return Object.assign({}, p, {
                enabled: s.enabled === true,
                settings: s.settings ?? {},
                // Declared defaults, so the page can show what a reset means
                defaults: p.defaults ?? {}
            });
        });
    }

    // Every folder with a manifest, read as one JSON array by jq
    Process {
        id: listProc
        command: ["sh", "-c", `
            dir="$1"
            [ -d "$dir" ] || { echo '[]'; exit 0; }
            for d in "$dir"/*/; do
                [ -f "$d/manifest.json" ] || continue
                printf '%s\\t' "$d"
                base64 -w0 <"$d/manifest.json" 2>/dev/null || printf ''
                printf '\\n'
            done
        `, "sh", root.storeDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const trimmed = line.trim();
                    if (trimmed === "")
                        continue;
                    const tab = trimmed.indexOf("\t");
                    if (tab < 0)
                        continue;
                    const dir = trimmed.slice(0, tab);
                    try {
                        const m = JSON.parse(Qt.atob(trimmed.slice(tab + 1)));
                        list.push({
                            id: String(m.id ?? ""),
                            name: String(m.name ?? m.id ?? ""),
                            version: String(m.version ?? ""),
                            description: String(m.description ?? ""),
                            author: String(m.author ?? ""),
                            license: String(m.license ?? ""),
                            homepage: String(m.homepage ?? m.repository ?? ""),
                            repository: String(m.repository ?? ""),
                            kinds: Array.isArray(m.kinds) ? m.kinds : [],
                            entryPoints: m.entryPoints ?? ({}),
                            barWidget: m.barWidget ?? ({}),
                            permissions: Array.isArray(m.permissions) ? m.permissions : [],
                            requires: m.requires ?? ({}),
                            defaults: m.settings ?? ({}),
                            dir: dir,
                            // Official is the account, not the URL, as the CLI
                            // decides it; this only labels it
                            official: Lib.isOfficial(String(m.author ?? ""), String(m.repository ?? m.homepage ?? ""))
                        });
                    } catch (e) {
                        console.warn("[Plugin] could not read a manifest in", dir, e);
                    }
                }
                root._setFound(list);
            }
        }
        onExited: code => {
            root.loading = false;
            if (code !== 0)
                root.error = I18n.tr("couldn't read the plugin store");
        }
    }

    FileView {
        id: stateFile
        path: root.statePath
        blockLoading: true
        printErrors: false
        watchChanges: true
        onLoaded: root._setStored(text())
        onFileChanged: root._setStored(text())
        onLoadFailed: root._setStored("")
    }

    // Writes one key of one plugin, then refreshes (the file is watched, but
    // writing it here is the only way to be sure the change landed)
    Process {
        id: stateWriter
        property string id: ""
        property string key: ""
        property var value: null
        property string current: ""

        function setValue(id: string, key: string, value): void {
            if (running)
                return;
            this.id = id;
            this.key = key;
            this.value = value;
            current = stateFile.text() || '{"plugins":{}}';
            command = ["sh", "-c", 'printf "%s" "$1" | jq --arg id "$2" --arg k "$3" --argjson v "$4" \'.plugins[$id] = ((.plugins[$id] // {}) | .[$k] = $v)\' > "$5"', "sh", current, id, key, JSON.stringify(value), root.statePath];
            running = true;
        }

        onExited: code => {
            if (code !== 0)
                root.error = I18n.tr("couldn't save the plugin's state");
            root.refresh();
        }
    }

    Component.onCompleted: refresh()

    // Read by scripts and tests: the store as one line a plugin, so what the
    // shell sees can be checked without opening Settings
    //   id<TAB>name<TAB>version<TAB>source<TAB>enabled<TAB>kinds
    IpcHandler {
        target: "plugins"

        function list(): string {
            return root.plugins.map(p => [p.id, p.name, p.version, p.official ? "official" : "third-party", p.enabled ? "enabled" : "disabled", p.kinds.join(",")].join("\t")).join("\n");
        }

        function count(): string {
            return String(root.count);
        }

        // Enables or disables through the same file the CLI writes
        function setEnabled(id: string, on: string): string {
            if (!root.byId(id))
                return "not installed: " + id; // i18n-ignore
            root.setPluginState(id, "enabled", on === "true");
            return "ok";
        }

        function reload(): string {
            root.refresh();
            return "ok";
        }
    }
}
