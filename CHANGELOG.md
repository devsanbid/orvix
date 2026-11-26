# Changelog

All notable changes to Orvix are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Orvix has no tagged release yet: everything below is on `main` and is what the
next release will contain. Lyne-Dots' history is kept in git; this file starts
with the rename.

## [Unreleased]

### Added

- **`orvix doctor` and Settings › System › Health.** One set of checks (in
  `.data/orvix-cli/lib/doctor.sh`) for Hyprland and its config, Quickshell, the
  wallpaper daemon, the polkit agent, the clipboard, the theme files and
  matugen, your default apps, the tools behind the shortcuts, the update source
  and Omarchy when it is installed. Each problem shows the command that fixes
  it; nothing is installed or changed. `--json` and `--quiet` for scripts, and
  the exit status is 1 when something failed.
- **Quick actions in the overview.** Launcher, Settings, screenshot, wallpaper,
  lock and power, one click each, under the cards.
- **Keyboard focus in the overview.** The arrows and Tab move a highlight
  through the cards and then the action buttons, in reading order; Enter or
  Space opens the highlighted card's tab or runs the action.
- **The two-shell guard.** Settings › System › Omarchy › *Skip Orvix's bar when
  Omarchy's shell runs* keeps Orvix's shell off at login while Omarchy's is
  running. Off by default. `conf/autostart.lua` now starts
  `scripts/shell-launch.sh`, which applies the guard.
- **Omarchy actions.** Open Omarchy's theme switcher or menu, run its updater in
  a terminal window, and mirror Orvix's accent into Omarchy's current theme as
  a user override (`scripts/omarchy-accent.sh`), each through an `omarchy`
  command. A theme you made or edited yourself is refused and left untouched.
- **Overview layouts.** The dashboard overview comes in **Classic** (calendar
  beside the clock and weather, player on the right) and **Focus** (clock across
  the top, weather and player below, no calendar). Both stack into one column
  when the panel is narrow, the panel itself fits small screens, and the layout
  switches from the button beside the tabs, Settings › Dashboard › Layout or
  <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>O</kbd>.
- **Settings › Appearance › GTK & Qt.** GTK theme (menu of the installed themes),
  font, light/dark preference, links to the Icons and Cursor pages, and the Qt
  color-scheme path. Three switches decide whether the shell theme sets the GTK
  theme, writes GTK colors and writes the Qt color scheme; "Use Omarchy's GTK
  settings" runs Omarchy's own `omarchy-theme-set-gnome`.
- **Omarchy integration.** Settings › System › Omarchy (shown only when Omarchy
  is installed): version, current theme, whether `omarchy-shell` is running and
  how many shell plugins are installed (read-only, from the plugin folders).
  Theme sources now include Omarchy, with a live watcher on its current theme.
  Nothing under `/usr/share/omarchy` is written, and neither shell is stopped
  automatically.
- **Installer options.** `--yes`/`-y` takes the defaults and skips the questions;
  `--no-omarchy` hides Omarchy detection; the review screen explains what
  happens to Hyprland when Omarchy is installed. `--help` lists every option.
- **Documentation.** `INSTALL.md`, `UNINSTALL.md`, `CHANGELOG.md` and a rewritten
  `README.md`, plus the Omarchy plan and its supported setups.
- **Tests.** JavaScript tests for the Omarchy color mapping, and a lint baseline
  that fails on new QML warnings.

### Changed

- The theme wallpapers are `orvix-<theme>-contour.jpg` now, and the theme files
  name them; migration `052-unlink-lyne` renames the copies already in
  `~/.local/wallpapers`.

- **The project is now Orvix.** Internal rename across the shell, CLI, services,
  environment variables, settings state, Neovim colorscheme, assets, installer,
  migrations and docs. The repository can live anywhere; `~/.orvix` is the
  default.
- **Coexistence with Omarchy.** Orvix keeps its own Hyprland config and bar. The
  supported setups and the remaining gaps (an optional autostart guard, more
  Omarchy actions in Settings) are tracked in `TODO_OMARCHY_INTEGRATION.md`.
- Tab labels in the dashboard elide instead of overflowing on narrow screens.
- `theme.applyGtkTheme`, `theme.applyGtkColors` and `theme.applyQtColors` default
  to on, so existing installs keep the old behavior until the user turns a part
  off.

### Fixed

- ThemeService no longer runs the GTK theme switch twice when it writes colors
  from a palette, and each GTK/Qt apply step can be turned off independently.
- A pre-existing i18n false positive in `ThemeService.qml` (a string that only
  looked translatable) no longer fails the translation check.

### Removed

- **The last Lyne names.** Migration `052-unlink-lyne` removes the
  `~/.local/bin/lyne` command, the `~/.lyne-dots` link, `conf/legacy.lua` (and
  its `lyne_*` Lua globals), the `lyne-editor` desktop entry, and the old
  `~/.cache/lyne`, `~/.local/share/lyne` and `Lyne.colors` files once their
  Orvix replacements exist. Generated `~/.config/hypr/local/*.lua` that still
  called `lyne_*` is rewritten to `orvix_*`.

### Kept for compatibility

- `lyne-sddm` keeps its package name (the login-screen theme is built and
  installed under it), and `LYNE_SDDM_REF` still selects its build. It is a
  third-party project, not part of Orvix.
- Historic migration file names are unchanged: a migration's name is its
  identity in `migrations-done`.

### Not done

- No release tag or package has been published from this tree.
- No Omarchy Shell marketplace plugin. The official marketplace accepts
  `omarchy-shell` plugins only; Orvix is a separate shell.
