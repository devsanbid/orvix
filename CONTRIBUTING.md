# Contributing to Orvix

Thanks for taking a look. Orvix is a Hyprland desktop for Arch Linux: a
Quickshell shell (bar, launcher, dashboard, notifications, lock screen,
Settings), a Hyprland config in Lua, and a `orvix` CLI that ties them
together.

## Before you start

- **Bugs and ideas:** open an issue. Say what you expected, what happened, and
  what `orvix doctor` prints — it covers the dependencies and the session in
  one go.
- **Big changes:** open an issue first. The shell's structure is deliberate (one
  service per concern, Settings pages generated from a registry), and a short
  discussion saves a rewrite.
- **Security:** please don't open a public issue for a vulnerability; see
  [SECURITY.md](SECURITY.md).

## Setting up

You need Arch Linux (or a close derivative) and a working Orvix or Arch +
Hyprland session. To work on a clone without installing:

```bash
git clone https://github.com/devsanbid/orvix.git ~/.orvix
cd ~/.orvix
./install.sh            # links the configs; --dry-run to look first
```

Reload the shell after a change:

```bash
orvix reload            # or Super + Shift + R
```

## What goes where

| Path | What |
| --- | --- |
| `quickshell/.config/quickshell/services/` | One singleton per concern (theme, state, monitors, MPRIS…). JavaScript helpers in the same folder end in `.js` and are testable in node. |
| `quickshell/.config/quickshell/modules/` | The UI: `bar/`, `launcher/`, `dashboard/`, `settings/` (one `pages/XxxPage.qml` per page), and so on. |
| `hyprland/.config/hypr/conf/` | The Hyprland config, in Lua. `local/` is per-machine and not tracked. |
| `.data/orvix-cli/` | The CLI: `commands/`, `lib/` and `migrations/`. |
| `.install/` | The installer, its package lists and its setup steps. |
| `.data/themes/` | The preset themes (JSON). |

## Rules the code follows

- **Settings first.** A new option goes in `state.json` (with its default in
  `.data/quickshell/defaults.json`) and gets a row in a Settings page, not a
  hand-edited file.
- **Every string goes through `I18n.tr`.** English is the source; add the
  Portuguese in `i18n/pt_BR.json` (see below).
- **External commands are asynchronous and quiet when missing.** Use
  `Quickshell.execDetached`, `Process` or `QueuedProcess`; never block the
  shell, and never assume a binary is installed.
- **Never write Omarchy's files.** Orvix coexists with it: read its state, call
  its commands, and say so in Settings. See
  [TODO_OMARCHY_INTEGRATION.md](TODO_OMARCHY_INTEGRATION.md).
- **Hyprland config stays Lua** and keeps the `orvix_*` global names.
- **Match the code around you**: naming, comments that say *why*, and the
  existing helper components (`Card`, `SettingRow`, `ActionButton`…).

## Tests

```bash
tests/run.sh js      # the shell's JavaScript libraries (node)
tests/run.sh bash    # the CLI, migrations and installer (bats)
tests/run.sh lint    # shellcheck over every script
tests/run.sh qml     # qmllint against tests/qml/lint-baseline.txt
tests/run.sh         # everything, plus the smoke and nvim sections
```

`js`, `bash`, `lint` and `qml` are what CI runs; they need `nodejs`, `bats`
(with `bats-assert` and `bats-support`), `shellcheck` and `qt6-declarative`.
A missing tool fails its section rather than being skipped.

When a lint warning is new, fix it; only add a line to
`tests/qml/lint-baseline.txt` with `tests/qml/lint.sh --update` when you have
looked at it and it is qmllint not knowing Quickshell.

## Translations

Every user-visible string goes through `I18n`:

```bash
node tools/i18n.js extract    # after adding or changing strings
node tools/i18n.js check      # placeholders, plurals, completeness
```

`i18n/README.md` has the details (placeholders, plurals, contexts, the
pseudo-language for finding untranslated text).

## Commits and pull requests

- One logical change per commit. A short subject in the imperative mood
  (`feat(doctor): …`, `fix(bar): …`, `docs: …`), then a body that says what
  changed and why.
- Say what you checked: the test sections you ran, and anything that needed a
  live session.
- Keep user-facing changes in `CHANGELOG.md` under `Unreleased`.
- Don't reformat unrelated code, and don't add a dependency for something the
  shell or a small script already does.

## License

Orvix is GPL-3.0. By contributing you agree your changes are under the same
license.
