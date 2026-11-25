# Changelog

All notable changes to Orvix are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Orvix has no tagged release yet: everything below is on `main` and is what the
next release will contain. Lyne-Dots' history is kept in git; this file starts
with the rename.

## [Unreleased]

### Added

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

### Kept for compatibility

- `~/.local/bin/lyne` forwards to `orvix` for one release.
- `conf/legacy.lua` maps old `lyne_*` Lua globals for one release.
- `lyne-sddm` keeps its package name (the login-screen theme is built and
  installed under it), and `LYNE_SDDM_REF` still selects its build.
- Historic migration file names and the `lyne-*-contour.jpg` wallpaper assets are
  unchanged, so existing installs and theme files keep working.

### Not done

- No release tag, remote or package has been published from this tree.
- No Omarchy Shell marketplace plugin. The official marketplace accepts
  `omarchy-shell` plugins only; Orvix is a separate shell.
