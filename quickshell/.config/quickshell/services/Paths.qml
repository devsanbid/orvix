pragma Singleton

import Quickshell
import Quickshell.Io

// Where the orvix repo is: ORVIX_DIR (uwsm/env sets it from where the
// dotfiles really are), else ~/.orvix. The scripts find it from their
// own path instead
Singleton {
    id: root

    readonly property string dots: Quickshell.env("ORVIX_DIR") || Quickshell.env("HOME") + "/.orvix"

    // The web page of the repository, read from its git remote (the docs and
    // Settings link there). Empty when there is no remote, or it is not a web
    // URL: the links that need it are hidden
    property string repoUrl: ""

    // git@github.com:user/repo.git, ssh://git@host/user/repo and
    // https://host/user/repo.git all become https://host/user/repo
    function _webUrl(remote: string): string {
        let url = String(remote || "").trim();
        if (url === "")
            return "";
        const scp = url.match(/^[^@/]+@([^:/]+):(.+)$/);
        if (scp)
            url = "https://" + scp[1] + "/" + scp[2];
        else if (url.startsWith("ssh://"))
            url = "https://" + url.slice(6).replace(/^[^@/]*@/, "");
        if (url.endsWith(".git"))
            url = url.slice(0, -4);
        url = url.replace(/\/+$/, "");
        return /^https?:\/\//.test(url) ? url : "";
    }

    Process {
        id: remoteProc
        running: true
        command: ["git", "-C", root.dots, "config", "--get", "remote.origin.url"]
        stdout: StdioCollector {
            onStreamFinished: root.repoUrl = root._webUrl(text)
        }
    }
}

