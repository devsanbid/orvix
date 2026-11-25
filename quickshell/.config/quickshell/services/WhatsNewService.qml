pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// What's new: the notes of the releases an update brought, from the release
// tags (`orvix update notes`). orvix update's notification opens it through
// `qs ipc call whatsnew open <commit before the update>`; Settings › About
// opens the current release's
Singleton {
    id: root

    property bool visible: false
    property bool loading: false
    // [{version, date, notes}], newest first, only those with notes
    property var releases: []

    // Empty when the repo has no remote: the window hides the link
    readonly property string releasesUrl: Paths.repoUrl !== "" ? Paths.repoUrl + "/releases" : ""

    // since: the commit before the update; "" = the current release alone
    function open(since: string) {
        if (notesProc.running)
            return;
        loading = true;
        releases = [];
        visible = true;
        notesProc.command = ["orvix", "update", "notes", "--json"].concat(since !== "" ? ["--since", since] : []);
        notesProc.running = true;
    }

    function close() {
        visible = false;
    }

    Process {
        id: notesProc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.releases = JSON.parse(text).filter(r => r.notes.trim() !== "");
                } catch (e) {
                    root.releases = [];
                }
                root.loading = false;
            }
        }
    }

    IpcHandler {
        target: "whatsnew"

        function open(since: string): void {
            root.open(since);
        }

        function close(): void {
            root.close();
        }
    }
}
