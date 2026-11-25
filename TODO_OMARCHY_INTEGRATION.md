# Orvix × Omarchy Integration Plan

> Working name: **Orvix** (renamed from Lyne-Dots). This file tracks the work to
> make Orvix a first-class companion to Omarchy instead of a parallel desktop.
>
> Status legend: `[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked
> Priority: **P0** correctness/safety · **P1** core experience · **P2** polish

## Ground rules

- Never overwrite an Omarchy theme, plugin, or `/usr/share/omarchy` file.
- Read Omarchy state; write only through Omarchy's own commands, and only when
  the user asks for it.
- Orvix must keep working on a plain Arch + Hyprland install with no Omarchy.
- Every external command is asynchronous, argument-escaped, and fails quietly
  when a binary is missing.
- Existing user appearance (wallpaper, fonts, icons, cursor, terminal, GTK/Qt)
  is preserved unless the user changes it.

## Compatibility model (decided)

| Area | Omarchy owns | Orvix does | Rule |
| --- | --- | --- | --- |
| Theme colors | `~/.local/state/omarchy/current/theme/colors.toml` | Optional **Omarchy theme source** | Read-only sync; never rewrite Omarchy files |
| Shell | `omarchy-shell` (Quickshell plugin host) | `quickshell` running Orvix | One bar at a time; detect and warn on conflict |
| Hyprland | `/usr/share/omarchy/default/hypr/*` + `~/.config/hypr/{hyprland,bindings,monitors}.lua` | Orvix `hypr/conf/*` | Orvix keeps its own config; document the swap |
| Plugins | `~/.config/omarchy/plugins` | — | Not plugin-compatible; no marketplace claim |
| CLI | `omarchy …` | `orvix …` | Orvix wraps selected `omarchy` commands in Settings |

## Phase 0 — Baseline & safety

- [x] Inspect Orvix tree, entry point, services, installer, tests.
- [x] Inspect installed Omarchy (version, commands, theme internals, plugin API).
- [x] Confirm official marketplace only accepts `omarchy-shell` plugins → **skip**.
- [ ] `git init`, baseline commit of the untouched tree.
- [ ] Add `orvix doctor` / Settings health checks for missing dependencies.
- [ ] Confirm `install.sh` refuses to run on a non-Arch system with a clear message.

## Phase 1 — Rename Lyne-Dots → Orvix (full internal rename)

Chosen by the user: **full internal rename**, with a one-release compatibility
shim so a live install does not break mid-session.

- [ ] CLI `lyne` → `orvix`; `~/.local/bin/lyne` becomes a deprecated shim.
- [ ] Env vars `LYNE_*` → `ORVIX_*` (keep `LYNE_*` reads as fallback for one release).
- [ ] Repo dir `~/.lyne-dots` → `~/.orvix` via `orvix migrate`; keep
      `~/.lyne-dots` as a symlink to the new path.
- [ ] State keys, runtime JSON filenames (`lyne-keybinds.json`,
      `lyne-autostart.json`, …) → `orvix-*`, with fallback reads.
- [ ] QML/JS identifiers, theme IDs (`Lyne.colors` → `Orvix.colors`), Neovim
      colorscheme, generated files.
- [ ] Wallpapers, assets, docs, About page, repo URLs, install URL.
- [ ] Migration test: run on a copy of the current tree, verify symlinks and
      `state.json` survive.
- [ ] Keep `lyne` CLI working for one release; print a deprecation notice.

## Phase 2 — Omarchy detection & coexistence (P0)

- [ ] `OmarchyService.qml`: detect `/usr/share/omarchy`, `omarchy` binary,
      version, current theme, whether `omarchy-shell` is running, plugin count.
- [ ] `orvix doctor` / Settings banner when both shells would run.
- [ ] Autostart guard: if `omarchy-shell` is running, do not start Orvix's bar
      and notification overlay (configurable, default = warn only).
- [ ] Document the two supported setups:
      1. **Orvix as the desktop** (Orvix Hyprland config + Orvix shell).
      2. **Omarchy as the desktop** (Omarchy Hyprland config + Omarchy shell;
         Orvix available on demand).
- [ ] Never kill `omarchy-shell` automatically.

## Phase 3 — Theme bridge (P1)

- [ ] `OmarchyThemeService.qml`: read `colors.toml`, map to Orvix palette
      (`background`, `foreground`, `accent`, `color0..15`).
- [ ] Theme source selector in Settings › Theme:
      `Orvix presets` · `Omarchy theme` · `Wallpaper (matugen)`.
- [ ] Watch `~/.local/state/omarchy/current/theme` and live-update the palette.
- [ ] Optional: mirror Orvix accent back to Omarchy **only** through
      `omarchy theme set` when the user explicitly picks "Apply to Omarchy".
- [ ] Respect light/dark from Omarchy (`mode`).
- [ ] Test with Tokyo Night, Catppuccin, Gruvbox, and a light theme.

## Phase 4 — Settings: beginner-friendly Omarchy page (P1)

- [ ] New `Settings › System › Omarchy` page (only shown when detected).
- [ ] Status card: version, current theme, shell running, plugins, last update.
- [ ] Actions, each with a plain-language explanation and confirmation:
      - [ ] Open theme picker (`omarchy theme switcher`).
      - [ ] Refresh config (`omarchy refresh config`).
      - [ ] Update system (`omarchy update`) — link to Omarchy docs, no silent run.
      - [ ] Open Omarchy menu (`omarchy menu`).
      - [ ] List plugins (`omarchy plugin list`) read-only.
- [ ] Inline help text for every action; never auto-run a destructive command.
- [ ] Add search keywords so the page is findable.

## Phase 5 — Overview redesign (P1)

Current overview: clock + weather | month | player + resources (three columns).

- [ ] New layout focused on "what do I need right now":
      - [ ] Top: date/time, active workspace, focused window.
      - [ ] Left: today's agenda (calendar + next event).
      - [ ] Center: window/workspace switcher preview (Hyprland toplevels).
      - [ ] Right: now playing + system health (CPU/GPU/RAM/disk/network).
      - [ ] Bottom: quick actions (launcher, terminal, files, settings, lock).
- [ ] Responsive: stack to two columns under a width threshold, one column on
      small screens.
- [ ] Keyboard-first: arrows move selection, Enter focuses, Esc closes.
- [ ] Keep the existing tabs (Media, System, Weather) untouched.
- [ ] Setting to switch between **Classic** and **Focus** overview.
- [ ] Performance: no polling while closed; reuse existing watchers.

## Phase 6 — GTK/Qt customization (P2)

- [ ] Settings › Appearance › GTK/Qt page:
      - [ ] GTK theme, icon theme, cursor, font, color scheme.
      - [ ] Qt style + color scheme, with a note that Omarchy may own these.
      - [ ] "Reset to Omarchy defaults" button (reads Omarchy, does not guess).
- [ ] Apply paths use `gsettings` / `qt6ct` / `kdeglobals` already present in
      `ThemeService`, wrapped in the existing async helpers.
- [ ] Live preview without restart where possible.

## Phase 7 — Installer & docs

- [ ] Friendlier `install.sh`: shorter first screen, plain-language categories,
      `--help`, `--dry-run`, `--yes`, `--no-omarchy`, resumable steps.
- [ ] `INSTALL.md` (beginner walkthrough, screenshots placeholders).
- [ ] `UNINSTALL.md` (safe unlink, restore Omarchy, keep user data).
- [ ] `CHANGELOG.md` (Keep a Changelog format).
- [ ] Rewrite `README.md` (what it is, Orvix vs Omarchy, features, install).
- [ ] Rewrite `LICENSE` attribution (keep upstream MIT text, add Orvix notice).
- [ ] Document that Orvix is **not** an Omarchy shell plugin.

## Phase 8 — Testing & release

- [ ] `bats` suite still passes after rename.
- [ ] Add tests: rename migration, Omarchy detection, theme mapping, installer
      flags.
- [ ] QML syntax check (`qmllint`/`qmlformat` where available).
- [ ] Manual smoke test on the live session (bar, dashboard, settings).
- [ ] Commit in logical chunks; no secrets, no generated artifacts.
- [ ] Final report: commits, branch, remote/push, release, marketplace, blockers.

## Known blockers / decisions

- **Git remote:** repo is not initialized and has no remote. Commits are local
  until the user provides a remote.
- **Marketplace:** skipped by user decision; `plugins.omarchy.org` is for
  `omarchy-shell` plugins only.
- **Live directory move:** `~/.lyne-dots` → `~/.orvix` is staged behind
  `orvix migrate`; the old path stays as a symlink.
