pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Qt's scale factor: read from, and written to, the session's environment
// file by scripts/qt-scale.sh. A Qt app reads QT_SCALE_FACTOR at start, so
// this is the one appearance setting that cannot apply to a window already
// open — the page says so.
//
// Three scales exist on this desktop and they are different things, which is
// why the page does not offer one "scaling" slider:
//
//   GTK text scale   org.gnome.desktop.interface text-scaling-factor; GTK
//                    apps multiply their fonts by it (GtkService owns it).
//   Qt scale factor  QT_SCALE_FACTOR, this service.
//   Orvix's own      typography.sizeNormal: the shell's text, unrelated to
//                    the other two.
Singleton {
    id: root

    // Not Quickshell.shellDir: a singleton is built before that resolves, and
    // a command built from it came out empty (the file then loaded nothing
    // and said nothing about it).
    readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/scripts/qt-scale.sh"

    // What the next login will use, from the environment file
    property real savedScale: 1.0
    // What this session started with; filled at completion, from the
    // environment the shell itself is running with
    property real runningScale: 1.0
    property bool _read: false
    // `_read` is what lets the page tell "1.0" from "not looked yet"
    readonly property bool available: _read
    property string error: ""

    // A change applies to apps started from now on and to the next login; a
    // window already open keeps the scale it started with
    readonly property bool needsRestart: Math.abs(root.savedScale - root.runningScale) > 0.001

    readonly property bool busy: readProc.running || writeProc.running

    function refresh(): void {
        if (!readProc.running)
            readProc.running = true;
    }

    function setScale(value: real): void {
        const v = Math.round(Math.min(2.5, Math.max(1.0, value)) * 20) / 20;
        // Last one wins: dragging a slider asks for a dozen values
        if (writeProc.running) {
            writeProc.pending = v;
            return;
        }
        writeProc.command = ["bash", root.script, "set", String(v)];
        writeProc.scale = v;
        writeProc.running = true;
    }

    Process {
        id: readProc
        command: ["bash", root.script, "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(text.trim());
                root.savedScale = isNaN(v) ? 1.0 : v;
                root._read = true;
            }
        }
        onExited: code => {
            if (code !== 0) {
                root._read = true;
                root.error = I18n.tr("couldn't read the Qt scale");
            }
        }
    }

    Process {
        id: writeProc
        property real scale: 1.0
        property real pending: 0

        onExited: code => {
            if (code !== 0) {
                root.error = I18n.tr("couldn't save the Qt scale");
            } else {
                root.savedScale = scale;
                root.error = "";
            }
            if (pending > 0) {
                const next = pending;
                pending = 0;
                root.setScale(next);
            }
        }
    }

    Component.onCompleted: {
        // The running value, from the session's own environment. Read here
        // rather than in a property initialiser, where Quickshell.env may not
        // be ready yet.
        const v = parseFloat(Quickshell.env("QT_SCALE_FACTOR") ?? "");
        runningScale = isNaN(v) ? 1.0 : v;
        savedScale = runningScale;
        refresh();
    }
}
