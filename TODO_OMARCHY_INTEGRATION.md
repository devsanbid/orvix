# Orvix × Omarchy Integration Plan

> Working name: **Orvix** (formerly Lyne-Dots). This file tracks the work to
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
- [x] `git init`, baseline commit of the untouched tree (`ee18f0f`).
- [ ] Add `orvix doctor` / Settings health checks for missing dependencies.
- [x] `install.sh` checks `/etc/arch-release` and exits with a clear message
      (static check; not run on a non-Arch machine).

## Phase 1 — Rename Lyne-Dots → Orvix (full internal rename)

Chosen by the user: **full internal rename**, with a one-release compatibility
shim so a live install does not break mid-session.

- [x] CLI `lyne` → `orvix`; `~/.local/bin/lyne` is now a deprecated shim.
- [x] Env vars `LYNE_*` → `ORVIX_*` (legacy `LYNE_*` reads kept for one release).
- [x] Repo dir `~/.lyne-dots` → `~/.orvix`; `~/.lyne-dots` stays a symlink.
- [x] State keys and runtime JSON filenames (`lyne-keybinds.json`,
      `lyne-autostart.json`, …) → `orvix-*`, with fallback reads.
- [x] QML/JS identifiers, theme IDs (`Lyne.colors` → `Orvix.colors`), Neovim
      colorscheme, generated files.
- [x] Wallpapers, assets, docs, About page, install URL.
- [x] Migration (`orvix migrate`) run on the live tree; symlinks, `state.json`
      and generated files carried over (migrations 050/051).
- [x] Keep the `lyne` CLI and `lyne_*` Lua globals working for one release,
      with a deprecation notice.

Compatibility exceptions kept on purpose: the third-party `lyne-sddm`
theme/package and `LYNE_SDDM_REF`, historical migration filenames, and the
`lyne-*-contour.jpg` wallpaper asset names.

## Phase 2 — Omarchy detection & coexistence (P0)

- [x] `OmarchyService.qml`: detects `/usr/share/omarchy`, the version, the
      current theme, whether `omarchy-shell` is running, and counts the
      shell plugins (read from the plugin folders, no shell needed).
- [x] Settings warns when both shells are running (warn only; nothing is
      stopped automatically).
- [ ] Autostart guard: an optional switch to skip Orvix's bar when
      `omarchy-shell` is running (default stays warn only).
- [ ] Document the two supported setups:
      1. **Orvix as the desktop** (Orvix Hyprland config + Orvix shell).
      2. **Omarchy as the desktop** (Omarchy Hyprland config + Omarchy shell;
         Orvix available on demand).
- [x] Never kill `omarchy-shell` automatically.

## Phase 3 — Theme bridge (P1)

- [x] `OmarchyTheme.js` + `OmarchyService`: read `colors.toml` and map it onto
      the Orvix palette, terminal colors and Hyprland borders.
- [x] Theme source selector in Settings › Theme:
      `Theme` · `Material You` · `Omarchy`.
- [x] Watch `~/.local/state/omarchy/current/theme` and live-update the palette.
- [ ] Optional: mirror the Orvix accent back to Omarchy **only** through
      `omarchy theme set` when the user explicitly asks.
- [x] Respect light/dark from Omarchy (`mode`).
- [~] Tested with Tokyo Night and a synthetic light theme in node tests;
      Catppuccin/Gruvbox and a live switch are still manual checks.

## Phase 4 — Settings: beginner-friendly Omarchy page (P1)

- [x] New `Settings › System › Omarchy` page (only shown when detected).
- [x] Status card: version, current theme, shell running, plugin count.
- [x] Actions, each with a plain-language explanation:
      - [x] Apply a theme from the list (`omarchy theme set <id>`, allowlisted
            to installed themes).
      - [x] Refresh config (`omarchy refresh config`).
      - [ ] Open theme switcher (`omarchy theme switcher`).
      - [ ] Update system (`omarchy update`) — link to Omarchy docs, no silent run.
      - [ ] Open Omarchy menu (`omarchy menu`).
      - [~] List plugins: count only (Omarchy's own list needs `omarchy-shell`
            running); read-only.
- [x] Inline help text for every action; never auto-run a destructive command.
- [x] Search keywords come from the page labels and description.

## Phase 5 — Overview redesign (P1)

Current overview: clock + weather | month | player + resources (three columns).

Shipped in this pass:

- [x] **Focus** layout: the clock across the top, weather and the player below,
      no calendar (fewer things at a glance); **Classic** keeps the month.
- [x] Responsive: both layouts stack into one column on narrow screens, and
      the dashboard panel itself shrinks to fit a small screen.
- [x] Switch from the button beside the tabs, `Settings › Dashboard › Layout`,
      or `Ctrl+Shift+O`.
- [x] Keep the existing tabs (Media, System, Weather) untouched.
- [x] Performance: no polling while closed; the existing watchers are reused.
- [ ] Remaining ideas, not done: an agenda row with the next event, a
      Hyprland workspace/window preview, quick actions in the overview.
- [ ] Keyboard roving focus between cards (arrows + Enter); only tab and
      layout shortcuts exist today.

## Phase 6 — GTK/Qt customization (P2)

- [x] Settings › Appearance › GTK & Qt page:
      - [x] GTK theme (menu of installed themes), font, light/dark preference.
      - [x] Icon and cursor themes linked to their existing pages.
      - [x] Qt color scheme path, with a note that Omarchy does not manage it.
      - [x] "Use Omarchy's GTK settings" (`omarchy-theme-set-gnome`), no guessing.
- [x] Apply paths use `gsettings` and the existing `ThemeService` writers,
      wrapped in the existing async helpers. Every value is an argument, not
      shell text.
- [x] Per-part switches in the same page (`theme.applyGtkTheme`,
      `theme.applyGtkColors`, `theme.applyQtColors`) so the shell theme can
      stop overriding the desktop's GTK/Qt look.
- [x] Live: `gsettings` applies at once; no restart.

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
- **Live directory move:** `~/.orvix` → `~/.orvix` is staged behind
  `orvix migrate`; the old path stays as a symlink.
