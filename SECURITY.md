# Security policy

## Reporting a vulnerability

Please **do not** open a public issue for a security problem.

Use GitHub's private reporting: go to the **Security** tab of
[devsanbid/orvix](https://github.com/devsanbid/orvix) and choose
**Report a vulnerability**. That opens a private advisory only you and the
maintainer can see.

If you can't use that, email the maintainer at the address on their
[GitHub profile](https://github.com/devsanbid).

Please include:

- what the problem is and where it is (file, page, command),
- how to reproduce it,
- what an attacker could do with it,
- the version (`orvix doctor` prints the session; `git -C ~/.orvix log -1` the
  commit).

You'll get an answer within a week. Once a fix is ready it goes out on `main`
and in the next release, and the advisory credits you unless you'd rather not.

## What is in scope

Orvix runs your desktop session, so anything that gives away control of it
counts:

- the installer and `orvix update` (they run as your user and use `sudo`),
- the CLI and its migrations (shell quoting, files written with privileged
  paths, symlinks followed when they shouldn't be),
- the shell's scripts (screenshots, wallpapers, clipboard, the lock screen,
  the Bluetooth and polkit agents),
- Settings pages that write files or run commands,
- the Omarchy integration (`scripts/omarchy-accent.sh`, the two-shell guard).

## What is not

- An app you install that misbehaves.
- Something that needs an attacker to already run code as your user, or root.
- Hyprland, Quickshell or another upstream's own bugs: report them upstream.
  Tell us if Orvix's configuration makes one worse.

## How Orvix already tries to be safe

- No command is built from untrusted text: arguments are passed as lists and
  Omarchy's commands are allowlisted.
- The installer backs up every file it replaces and logs what it did.
- Migrations never delete a file they didn't write, and skip anything that
  doesn't look like theirs.
- Nothing under `/usr/share/omarchy` is ever written.
- The shell's own scripts run without privileges; the few that need root ask
  for it through `sudo`, visibly.
