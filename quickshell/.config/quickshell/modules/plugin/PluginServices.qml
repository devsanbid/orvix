pragma ComponentBehavior: Bound
import QtQuick
import qs.services

// Loads every enabled plugin of kind "service" once, with the shell.
//
// A service plugin (this plugin keeps a browser warm, that one watches a
// folder) has nothing to draw: it exists to hold a singleton, a Process or a
// Timer while the session runs. So it is built here and kept alive by the
// shell rather than by a bar or a page.
//
// Each one is behind its own Loader (PluginHost), so a plugin that throws
// while loading is reported in Settings › Plugins and the rest of the shell —
// and the other plugins — keep running.
Item {
    id: root

    visible: false
    // A service plugin normally has no size; this keeps a misbehaving one
    // from claiming any
    implicitWidth: 0
    implicitHeight: 0

    readonly property var services: PluginService.plugins.filter(p => p.enabled && p.kinds.includes("service"))

    Repeater {
        model: root.services

        PluginHost {
            required property var modelData

            plugin: modelData
            kind: "service"
            // Not visible, but it must still be created: a Loader in a hidden
            // Item is built, one in an inactive Item is not
            visible: false
            width: 0
            height: 0
        }
    }
}
