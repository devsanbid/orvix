pragma ComponentBehavior: Bound
import QtQuick

// Loads one plugin's QML and keeps a broken plugin from taking the shell down.
//
// A plugin is third-party code: it can throw while being created, it can
// reference something that isn't there, and it can be written for a newer
// Orvix. All of that has to be a message in Settings › Plugins and a hole in
// the bar where the widget would be — never "the whole shell fails to load".
//
// The QML is loaded through a Component built from the file's URL, created by
// a Loader. Qt reports a failed creation on the Loader, which is where it is
// caught: the Loader goes inactive and `failed` says why.
Item {
    id: root

    // The plugin object from PluginService (id, dir, entryPoints, …)
    required property var plugin
    // "barWidget", "panel", "settings" — the key in entryPoints
    property string kind: "barWidget"
    // Extra width the host needs to report (the bar reads the child's)
    property bool reportSize: false

    readonly property string entry: plugin?.entryPoints?.[kind] ?? ""
    // The plugin isn't loaded, and why. "" while it is fine.
    property string failure: ""
    readonly property bool loaded: loader.status === Loader.Ready && failure === ""

    visible: loaded
    // The linter knows `item` only as a QObject; a plugin's root is an Item
    // and has these at runtime. The Loader's own size is the honest fallback.
    implicitWidth: loaded ? loader.implicitWidth : 0
    implicitHeight: loaded ? loader.implicitHeight : 0

    // The plugin's settings are read through PluginBridge, which needs to know
    // which plugin it is building for. It is set before the QML is created,
    // and cleared once it is: the item keeps working because QML resolves the
    // settings it read at creation, not by asking again later.
    function _create(): void {
        if (entry === "") {
            failure = I18n.tr("no %1 entry point in its manifest", kind);
            return;
        }
        const source = plugin.dir + "/" + entry;
        PluginBridge._enter(plugin);
        failure = "";
        loader.setSource(source);
        PluginBridge._leave();
    }

    Component.onCompleted: _create()

    onPluginChanged: _create()

    Loader {
        id: loader

        anchors.fill: parent
        asynchronous: false

        onStatusChanged: {
            if (status === Loader.Error) {
                root.failure = I18n.tr("%1 failed to load (see the shell log)", root.plugin?.name ?? "plugin");
                console.warn("[Plugin]", root.plugin?.id, "failed to load", root.entry);
            } else if (status === Loader.Ready) {
                root.failure = "";
            }
        }
    }
}
