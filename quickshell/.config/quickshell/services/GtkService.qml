pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// The desktop's GTK settings, read and written through gsettings: theme, icon
// theme, cursor theme and size, font and light/dark preference. Lists the
// installed themes so Settings can offer them.
//
// These are the values GTK apps use; the shell's own look lives in
// ThemeService. Orvix only changes them here, or when the user leaves
// "Apply to GTK" on in the Theme page.
Singleton {
    id: root

    readonly property string schema: "org.gnome.desktop.interface"

    property string gtkTheme: ""
    property string iconTheme: ""
    property string cursorTheme: ""
    property int cursorSize: 24
    property string fontName: ""
    property string colorScheme: ""

    property var gtkThemes: []

    // gsettings is missing (a very small install): the page shows a note
    property bool available: true
    property bool actionRunning: false
    property string lastError: ""

    function refresh(): void {
        if (!valuesProc.running)
            valuesProc.running = true;
        if (!themesProc.running)
            themesProc.running = true;
    }

    function setGtkTheme(value: string): void {
        _set("gtk-theme", value);
    }

    function setFontName(value: string): void {
        if (value.trim() !== "")
            _set("font-name", value.trim());
    }

    function setColorScheme(value: string): void {
        if (value === "prefer-dark" || value === "prefer-light" || value === "default")
            _set("color-scheme", value);
    }

    // Omarchy's own command for this: applies the current theme's mode and
    // icon theme (Adwaita/Adwaita-dark + the theme's icons), without guessing
    function useOmarchyDefaults(): bool {
        return _run(["omarchy-theme-set-gnome"], "omarchy");
    }

    function _set(key: string, value: string): void {
        _run(["gsettings", "set", root.schema, key, value], key);
    }

    function _run(args: var, request: string): bool {
        if (actionProc.running)
            return false;
        lastError = "";
        actionRunning = true;
        actionProc.run(args, request);
        return true;
    }

    Component.onCompleted: refresh()

    Process {
        id: valuesProc
        command: ["sh", "-c", `
            command -v gsettings >/dev/null 2>&1 || { echo "__missing__"; exit 0; }
            for key in gtk-theme icon-theme cursor-theme cursor-size font-name color-scheme; do
                value=$(gsettings get org.gnome.desktop.interface "$key" 2>/dev/null) || value=""
                printf '%s\t%s\n' "$key" "$value"
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "__missing__") {
                    root.available = false;
                    return;
                }
                root.available = true;
                const values = {};
                text.split("\n").forEach(line => {
                    const cut = line.indexOf("\t");
                    if (cut < 0)
                        return;
                    let value = line.slice(cut + 1).trim();
                    if (value.startsWith("'") && value.endsWith("'"))
                        value = value.slice(1, -1);
                    values[line.slice(0, cut)] = value;
                });
                root.gtkTheme = values["gtk-theme"] ?? "";
                root.iconTheme = values["icon-theme"] ?? "";
                root.cursorTheme = values["cursor-theme"] ?? "";
                root.fontName = values["font-name"] ?? "";
                root.colorScheme = values["color-scheme"] ?? "";
                const size = parseInt(values["cursor-size"], 10);
                if (!isNaN(size))
                    root.cursorSize = size;
            }
        }
    }

    Process {
        id: themesProc
        command: ["sh", "-c", `
            for base in "$HOME/.themes" "$HOME/.local/share/themes" /usr/share/themes; do
                [ -d "$base" ] || continue
                for dir in "$base"/*/; do
                    [ -f "$dir/gtk-3.0/gtk.css" ] || [ -f "$dir/gtk-4.0/gtk.css" ] || continue
                    basename "$dir"
                done
            done | sort -u
        `]
        stdout: StdioCollector {
            onStreamFinished: root.gtkThemes = text.split("\n").map(s => s.trim()).filter(s => s !== "")
        }
    }

    QueuedProcess {
        id: actionProc
        onExited: code => {
            root.actionRunning = false;
            if (code !== 0)
                root.lastError = I18n.tr("The command failed. Check that gsettings and a desktop session are available.");
            root.refresh();
        }
    }
}
