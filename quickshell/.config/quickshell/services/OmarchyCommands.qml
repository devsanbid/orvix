pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "OmarchyCommands.js" as Lib

// Omarchy's own commands, as launcher actions for the ">" mode.
//
// Omarchy publishes its whole CLI in `omarchy commands --json --all` (each
// command: route, group, name, summary, args, hidden, requires_sudo). This
// reads that list, keeps it in the cache (~/.cache/orvix/omarchy-commands.json,
// so a shell restart doesn't pay for it again) and turns each visible command
// into an action LauncherActions shows next to the shell's own.
//
// The parsing, naming and argv rules are in OmarchyCommands.js, tested in
// tests/js/omarchyCommands.test.js.
//
// A command is only ever started as `omarchy <route>` with no extra text:
// anything that needs an argument (`omarchy font set <font>`) opens in a
// terminal where Omarchy asks for it. When Omarchy isn't installed, or its
// catalogue can't be read, the mode keeps working with the shell's own
// actions and nothing else.

Singleton {
    id: root

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/orvix"
    readonly property string cachePath: cacheDir + "/omarchy-commands.json"

    // Installed and readable: the same test OmarchyService uses
    readonly property bool available: OmarchyService.installed
    // Where the omarchy command is; "" until checked
    property string binary: ""
    readonly property bool ready: binary !== ""

    // [{ route, group, name, summary, args, hidden, sudo }]
    property var commands: []
    property bool loading: false
    // Set when the read failed, for the empty state
    property string error: ""

    // The actions, for LauncherActions.items. Empty until the catalogue has
    // been read once.
    readonly property var actions: root.ready ? commands.filter(c => !c.hidden).map(c => _action(c)) : []

    function _action(c: var): var {
        const needsInput = Lib.needsInput(c)
        return {
            id: "omarchy:" + c.route,
            name: Lib.displayName(c),
            comment: needsInput ? I18n.tr("%1 — asks in a terminal (%2)", c.summary, c.args) : c.summary,
            glyph: root._glyph(c.group),
            keywords: ["omarchy", c.group, c.name, c.route].concat((c.args || "").split(/[\s|<>[\]—-]+/).filter(w => w !== "")),
            // Shown beside the row: which part of Omarchy it drives
            badge: c.group,
            // Fixed argv, from Omarchy's catalogue: nothing typed in the
            // launcher can turn into another command
            terminal: needsInput,
            run: () => root._run(c, needsInput)
        }
    }

    // A rough icon per group; groups are Omarchy's, the fallback is generic
    function _glyph(group: string): string {
        const glyphs = {
            agent: "\u{f167a}",
            audio: "\u{f057e}",
            bar: "\u{f0e09}",
            battery: "\u{f0079}",
            bluetooth: "\u{f00af}",
            boot: "\u{f0e07}",
            branding: "\u{f0e09}",
            brightness: "\u{f0599}",
            capture: "\u{f0e51}",
            channel: "\u{f0e6f}",
            chromium: "\u{f0e6f}",
            clipboard: "\u{f014d}",
            debug: "\u{f188}",
            default: "\u{f0139}",
            dev: "\u{f121}",
            dictation: "\u{f0bc3}",
            disk: "\u{f02ca}",
            display: "\u{f0379}",
            dock: "\u{f0f1a}",
            file: "\u{f0f6d}",
            font: "\u{f031}",
            games: "\u{f1354}",
            hook: "\u{f0c1}",
            hw: "\u{f0b5b}",
            hyprland: "\u{f0607}",
            hibernation: "\u{f023e}",
            input: "\u{f11c4}",
            install: "\u{f019}",
            kernel: "\u{f02a1}",
            keyboard: "\u{f030c}",
            language: "\u{f05ca}",
            launch: "\u{f0379}",
            locale: "\u{f05ca}",
            menu: "\u{f035c}",
            migrate: "\u{f14a3}",
            monitor: "\u{f0379}",
            network: "\u{f0337}",
            notification: "\u{f009a}",
            nvim: "\u{f0bc3}",
            pkg: "\u{f02ca}",
            plymouth: "\u{f0c9c}",
            power: "\u{f0425}",
            powerprofiles: "\u{f04c5}",
            refresh: "\u{f0450}",
            reinstall: "\u{f021}",
            remove: "\u{f056}",
            restart: "\u{f01da}",
            screensaver: "\u{f02a6}",
            security: "\u{f048d}",
            setup: "\u{f0bc9}",
            share: "\u{f0c1e}",
            shell: "\u{f02a6}",
            snapshot: "\u{f0e2e}",
            state: "\u{f02ca}",
            system: "\u{f009}",
            tailscale: "\u{f052a}",
            theme: "\u{f03d8}",
            toggle: "\u{f04f0}",
            transcode: "\u{f0e2f}",
            tui: "\u{f120}",
            update: "\u{f01da}",
            upgrade: "\u{f01da}",
            upload: "\u{f093}",
            version: "\u{f02a4}",
            weather: "\u{f0594}",
            webapp: "\u{f08e5}",
            windows: "\u{f05c7}"
        };
        return glyphs[group] ?? "\u{f0e09}";
    }

    function _run(c: var, needsInput: bool): void {
        const argv = Lib.argvFor(c);
        if (!needsInput) {
            Quickshell.execDetached(argv);
            return;
        }
        // The terminal asks Omarchy's own questions and waits for the answer
        Quickshell.execDetached(AppsService.terminalArgv(argv));
    }

    // Reads the catalogue once. Called when the launcher's Actions mode
    // opens: the cache answers at once, and the command refreshes it in the
    // background, so a command Omarchy added or removed shows up next time.
    function load(): void {
        if (!available || loading)
            return;
        loading = true;
        if (binary !== "")
            _readCache();
        else
            probe.running = true;
    }

    function _readCache(): void {
        cacheFile.reload();
        refresh.running = true;
    }

    function _setCatalog(text: string): void {
        const list = Lib.parseText(text);
        if (list.length === 0) {
            error = I18n.tr("Unexpected output from omarchy commands");
            return;
        }
        commands = list;
        error = "";
    }

    // The omarchy command, if it is installed
    Process {
        id: probe
        command: ["sh", "-c", "command -v omarchy 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path === "") {
                    root.loading = false;
                    return;
                }
                root.binary = path;
                root._readCache();
            }
        }
    }

    // The last catalogue, from disk
    FileView {
        id: cacheFile
        path: root.cachePath
        blockLoading: true
        printErrors: false
        onLoaded: root._setCatalog(text())
    }

    Process {
        id: refresh
        command: root.binary !== "" ? [root.binary, "commands", "--json", "--all"] : []
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text;
                if (out.trim() === "")
                    return;
                root._setCatalog(out);
                writeTimer.cacheText = out;
                writeTimer.restart();
            }
        }
        onExited: code => {
            root.loading = false;
            if (code !== 0 && root.commands.length === 0)
                root.error = I18n.tr("omarchy commands failed");
        }
    }

    // Writes the catalogue to the cache once the list has been drawn
    FileView {
        id: cacheWriter
        path: root.cachePath
        atomicWrites: true
        printErrors: false
    }

    Timer {
        id: writeTimer
        property string cacheText: ""
        interval: 400
        onTriggered: {
            if (cacheText === "")
                return;
            cacheWriter.setText(cacheText);
            cacheText = "";
        }
    }
}
