pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Health checks for Settings › System › Health, and the same checks `orvix
// doctor` prints. The work is in .data/orvix-cli/lib/doctor.sh (one place for
// both): each check comes back as
//   level <TAB> id <TAB> what <TAB> state <TAB> fix
// with level "ok", "warn" or "fail". Nothing here changes the system; the
// page shows the fix command and the user runs it.
Singleton {
    id: root

    // Run on the page, and from About's "Check the system" link
    property bool running: false
    // [{ id, level, what, state, fix }]
    property var checks: []
    property bool hasRun: false

    readonly property int okCount: checks.filter(c => c.level === "ok").length
    readonly property int warnCount: checks.filter(c => c.level === "warn").length
    readonly property int failCount: checks.filter(c => c.level === "fail").length
    // What the summary says in one line
    readonly property string summary: {
        if (!hasRun)
            return I18n.tr("Not checked yet");
        if (failCount > 0)
            return I18n.tr("%1 failed, %2 warning(s), %3 fine", failCount, warnCount, okCount);
        if (warnCount > 0)
            return I18n.tr("%1 warning(s), %2 fine", warnCount, okCount);
        return I18n.tr("Everything is fine");
    }
    // "ok", "warn" or "fail", for the summary colour
    readonly property string level: failCount > 0 ? "fail" : warnCount > 0 ? "warn" : hasRun ? "ok" : ""

    readonly property string script: Paths.dots + "/.data/orvix-cli/lib/doctor.sh"

    function refresh(): void {
        if (proc.running)
            return;
        running = true;
        proc.running = true;
    }

    // The doctor lib is sourced, then the checks run: same order and wording
    // as `orvix doctor`
    Process {
        id: proc
        command: ["bash", "-c", 'source "$1" && ORVIX_DIR="$2" orvix_doctor_checks', "bash", root.script, Paths.dots]
        stdout: StdioCollector {
            onStreamFinished: {
                root.checks = text.split("\n").map(line => line.trim()).filter(line => line !== "").map(line => {
                    const parts = line.split("\t");
                    return {
                        level: parts[0] ?? "",
                        id: parts[1] ?? "",
                        what: parts[2] ?? "",
                        state: parts[3] ?? "",
                        fix: parts[4] ?? ""
                    };
                });
                root.hasRun = true;
            }
        }
        onExited: code => {
            root.running = false;
            if (code !== 0 && root.checks.length === 0) {
                root.checks = [{
                        level: "fail",
                        id: "doctor",
                        what: I18n.tr("Health checks"),
                        state: I18n.tr("Could not run %1", "doctor.sh"),
                        fix: ""
                    }];
                root.hasRun = true;
            }
        }
    }
}
