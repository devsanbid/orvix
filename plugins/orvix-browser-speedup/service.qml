pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Browser startup speedup: keeps a Chromium-based browser running with no
// windows, so a new window or link opens in the process that is already warm.
// The Linux counterpart of Edge's Startup Boost, which Linux builds don't
// have.
//
// Omarchy has a plugin that does this (AgentRBY/omarchy-speedup-browser-
// startup, MIT). This is the Orvix one: same mechanism, Orvix's plugin
// format, Orvix's own state. bin/speedup-browser-startup.sh holds the logic
// (which browser, the systemd unit, the restart-on-upgrade check); this only
// starts it, stops it, and reports what it says.
//
// It does nothing when the default browser isn't one of the Chromium ones
// that has a keep-alive switch: Firefox, Zen and Flatpak browsers are not
// supported, and pretending otherwise would be a lie in the UI.
Item {
    id: root

    // The plugin's own folder holds the script. Read once, at creation:
    // PluginBridge only names the plugin being built, and the host clears it
    // as soon as the QML exists, so a binding would go blank.
    readonly property string script: String(PluginBridge.dir) + "/bin/speedup-browser-startup.sh"

    // "running", "stopped" or "" until the first read
    property string state: ""
    // The browser it is keeping warm, from `status`
    property string browser: ""
    property int windows: 0
    property bool available: true
    // Why it isn't running when it should be (no supported browser)
    property string note: ""

    readonly property bool running: state === "running"

    function refresh(): void {
        if (!statusProc.running)
            statusProc.running = true;
    }

    function startService(): void {
        if (!runProc.running)
            runProc.run([script, "start"], { arg: "start" });
    }

    function stopService(): void {
        if (!runProc.running)
            runProc.run([script, "stop"], { arg: "stop" });
    }

    function restartIfChanged(): void {
        if (!runProc.running)
            runProc.run([script, "restart-if-changed"], { arg: "check" });
    }

    // The first line is "running (chromium)" or "stopped"; the second, if
    // there is one, is "windows: N"
    function _parse(text: string): void {
        const lines = text.trim().split("\n").map(l => l.trim()).filter(l => l !== "");
        if (lines.length === 0) {
            root.state = "";
            return;
        }
        const head = lines[0];
        const m = head.match(/^(running|stopped)(?:\s+\(([^)]+)\))?/);
        root.state = m ? m[1] : "";
        root.browser = m && m[2] ? m[2] : "";
        const w = lines.find(l => l.startsWith("windows:"));
        root.windows = w ? parseInt(w.slice(8).trim(), 10) || 0 : 0;
    }

    Component.onCompleted: {
        refresh();
        // Start warm with the shell when the user enabled it: that is the
        // whole point, and a service kind loads with the shell
        startService();
    }

    // The update check: a browser upgraded on disk, or a new default browser,
    // restarts the warm process — but only while it owns no windows
    Timer {
        interval: 60000
        running: root.running
        repeat: true
        triggeredOnStart: false
        onTriggered: root.restartIfChanged()
    }

    Process {
        id: statusProc
        command: ["bash", root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
    }

    // A plain Process with its own "one at a time" guard: QueuedProcess is one
    // of the shell's own types, and a plugin cannot import those
    Process {
        id: runProc
        property string arg: ""
        property var pending: null

        function run(args: var, opts): void {
            if (running) {
                pending = {
                    args: args,
                    opts: opts
                };
                return;
            }
            command = args;
            arg = opts?.arg ?? "";
            running = true;
        }

        onExited: code => {
            // Either way, ask what the state is now rather than assume
            root.refresh();
            if (code !== 0)
                root.note = I18n.tr("%1 didn't work; see orvix plugin info browser-speedup", root.arg);
            // Something asked while this ran
            if (pending) {
                const next = pending;
                pending = null;
                run(next.args, next.opts);
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                if (out !== "")
                    console.log("[speedup]", out);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                if (out !== "")
                    console.warn("[speedup]", out);
            }
        }
    }
}
