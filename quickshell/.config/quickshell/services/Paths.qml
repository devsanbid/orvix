pragma Singleton

import Quickshell

// Where the orvix repo is: ORVIX_DIR (uwsm/env sets it from where the
// dotfiles really are), else ~/.orvix. The scripts find it from their
// own path instead
Singleton {
    readonly property string dots: Quickshell.env("ORVIX_DIR") || Quickshell.env("HOME") + "/.orvix"
}
