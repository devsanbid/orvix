<div align="center">

<img src=".data/assets/logo/hicolor/512x512/apps/orvix.png" alt="Orvix" width="112">

# Orvix

**A Hyprland desktop for Arch Linux, with a Quickshell shell you set up from its own Settings app.**<br>
One theme follows the bar, terminal, editor, GTK/Qt apps, Hyprland and Zen Browser.

<sub>Formerly Lyne-Dots · built to live alongside [Omarchy](#omarchy) without fighting it</sub>

[Install](INSTALL.md) · [Uninstall](UNINSTALL.md) · [Changelog](CHANGELOG.md) · [Omarchy plan](TODO_OMARCHY_INTEGRATION.md) · [License](LICENSE)

</div>

## What is Orvix?

Orvix is a complete desktop for Arch Linux: Hyprland for the windows, Quickshell for
the bar, launcher, dashboard, notifications, lock screen and settings, plus a CLI
that ties it all together. Almost everything is changed from the Settings app;
nothing important needs a config file.

It started as a local rework of **Lyne-Dots** and keeps its design language;
the rename to Orvix is carried through the whole tree. If you have an older Lyne
install, the migrations and the `lyne` command shim move it over; see
[INSTALL.md](INSTALL.md#coming-from-lyne-dots).

## Highlights

<table>
<tr>
<td width="33%" valign="top">

**A Settings app for everything**<br>
More than 30 pages: appearance, bar, launcher, dashboard, lock screen, monitors, GPUs, workspaces, keybinds, autostart, GTK & Qt. Searchable, applied live.

</td>
<td width="33%" valign="top">

**Themes that reach every app**<br>
13 presets, Material You from the wallpaper, or the theme Omarchy is already using. Switching fades the shell and Hyprland's borders and recolors kitty, Neovim, GTK/Qt and Zen Browser.

</td>
<td width="33%" valign="top">

**An overview two ways**<br>
**Classic** keeps the month beside the clock; **Focus** puts the clock across the top and leaves the calendar out. Both fit a small screen, and both switch with one key.

</td>
</tr>
<tr>
<td valign="top">

**GTK & Qt, without guessing**<br>
Read and set the GTK theme, font and light/dark preference, list the installed themes, and choose how much of the shell theme reaches GTK and Qt apps.

</td>
<td valign="top">

**A shell with templates**<br>
Bar, launcher, Quick Settings, OSD, lock screen and power menu each come in several styles, previewed in Settings before you pick one.

</td>
<td valign="top">

**A guided installer and a CLI**<br>
Every question first, then an unattended install with a progress bar. `--dry-run`, `--yes` and `--answers` for scripts. `orvix update` pulls, syncs your settings and runs migrations.

</td>
</tr>
</table>

> [!NOTE]
> The screenshots that used to live here were hosted on the upstream project's
> `media` branch, which this repository does not have. Open Settings and the
> dashboard to see the current look.

## Documentation

| Document | What is in it |
| --- | --- |
| [INSTALL.md](INSTALL.md) | Requirements, the installer and its options, Omarchy coexistence, first login, troubleshooting |
| [UNINSTALL.md](UNINSTALL.md) | Removing Orvix, restoring your old files, what is left behind |
| [CHANGELOG.md](CHANGELOG.md) | What changed, release by release |
| [TODO_OMARCHY_INTEGRATION.md](TODO_OMARCHY_INTEGRATION.md) | The Omarchy plan and what is done, in progress or blocked |
| [.install/README.md](.install/README.md) | How the installer is put together |
| [LICENSE](LICENSE) | GPL-3.0, with the Lyne-Dots origin |

## Install

**Requirements:** Arch Linux (or a close derivative), a user with `sudo`, and an
internet connection. About 4 GB of packages for the full install.

There is no published remote for this copy of Orvix yet, so install from a clone:

```bash
git clone <your-orvix-remote> ~/.orvix
cd ~/.orvix
./install.sh
```

`bootstrap.sh` is the one-line installer for a hosted copy. Point it at a
repository with `ORVIX_BOOTSTRAP_REPO`:

```bash
curl -fsSL https://<your-user>.github.io/orvix/install | ORVIX_BOOTSTRAP_REPO=https://github.com/<your-user>/orvix.git bash
```

The installer asks everything first, then installs without further questions
after the sudo password:

1. **Packages:** pick categories (core, terminal, editor, apps, utils, fonts,
   quickshell, theming). The shell's own files (Hyprland, Quickshell,
   `~/.local/`) are always linked; **terminal** also links the kitty, Zsh, tmux
   and fastfetch configs, **editor** the Neovim one and **theming** the GTK, Qt
   and KDE ones. Leave a category out and your configs for it stay as they are.
2. **Graphics:** the GPUs it found; for NVIDIA, the driver (open or 580xx,
   optionally 32-bit) and its environment. Which GPU renders stays automatic
   (Settings › Graphics changes it).
3. **Reboot** when done, then a review screen with the packages to link and
   every file of yours that will be replaced.

Files it replaces go to `~/.orvix-backup/<date>/`; the full log is in
`~/.cache/orvix/install-<date>.log`. Changed your mind later? `orvix link nvim`
links a package (your files to the backup first) and `orvix unlink nvim` brings
yours back.

<details>
<summary><b>Installer options</b></summary>

| Option | What it does |
| --- | --- |
| `--help`, `-h` | Show every option and the package categories |
| `--dry-run` | Change nothing: a throwaway HOME and stand-ins for sudo, pacman, yay... (`ORVIX_DRY_HOME=dir` reuses one) |
| `--yes`, `-y` | Take the defaults and skip the questions (the sudo password is still asked) |
| `--answers FILE` | Unattended: answers as `id=value` lines (`categories=`, `nvidia=`, `gpu_order=`, `reboot=`) |
| `--packages NAME` | Install one category (`--packages nvidia` installs or fixes the driver) |
| `--stow-only` | Only link the dotfiles again: the packages linked before (`orvix link` adds others) |
| `--setup-only` | Only create the local Hyprland files |
| `--no-omarchy` | Don't detect or mention Omarchy (nothing is written to it either way) |

More in [INSTALL.md](INSTALL.md).

</details>

## Omarchy

Orvix is a desktop of its own, not an Omarchy plugin, and it is designed to be a
good guest on a machine that also has [Omarchy](https://omarchy.org) installed.

- **Shown in Settings, never hidden.** When `/usr/share/omarchy` exists, Settings ›
  System › Omarchy shows the version, the current theme, whether `omarchy-shell`
  is running and how many shell plugins are installed.
- **Themes both ways, one direction at a time.** Orvix can follow Omarchy's
  current theme (colors, light/dark, borders) through its own palette, or leave
  it alone. Changing a theme from Orvix does not edit Omarchy's files.
- **GTK, through Omarchy's own command.** "Use Omarchy's GTK settings" runs
  `omarchy-theme-set-gnome`; Orvix never writes under `/usr/share/omarchy`.
- **No quiet takeovers.** Installing Orvix replaces `~/.config/hypr` with its own
  Hyprland config, so Omarchy's autostart entries and keybinds do not run while
  Orvix's do. The installer says so, Settings warns when both shells are running,
  and neither shell is ever stopped automatically.
- **Plugins are not loaded.** Omarchy's `omarchy-shell` plugins are not Orvix
  plugins; the count is informational.

The two supported setups, and the remaining work, are in
[TODO_OMARCHY_INTEGRATION.md](TODO_OMARCHY_INTEGRATION.md#supported-setups).

## Update

```bash
orvix update
```

Updates the dotfiles, adds new settings to your `state.json` without touching the
ones you changed, runs pending migrations (new packages, moved files) and reloads
Quickshell. Settings › System › About shows when an update is available and runs
it for you.

Two channels, picked in Settings › System › About or with `orvix update channel`:

- **Stable** (default): the newest release tag.
- **Latest**: every change as soon as it lands on `main`.

Switching back to Stable never goes back in time: you stay where you are until
the next release.

> [!NOTE]
> Changes you made inside `~/.orvix` are listed first, and you choose to stash
> them (`git stash pop` brings them back), discard them or cancel. Keep personal
> changes in `~/.config/hypr/local/` or in Settings, which are not tracked.

## Reference

<details>
<summary><b>orvix CLI</b></summary>

`orvix` is installed to `~/.local/bin`. Run `orvix <command> --help` for
subcommands.

| Command | Description |
| --- | --- |
| `orvix theme` | Show the theme; `list`, `set <name>`, `auto` (Material You), `scheme dark\|light` |
| `orvix update` | Update to the channel's version, sync `state.json`, run migrations, reload Quickshell; `status`, `channel stable\|latest` |
| `orvix reload` | Restart Quickshell |
| `orvix state` | Edit `state.json`; `sync`, `rebuild` |
| `orvix migrate` | `list`, `run`, `done` for migrations |
| `orvix link` | Each dotfiles package, linked or not; `orvix link <package>` links one the install left out |
| `orvix unlink` | Removes a package's links and brings back your files from the backup |
| `orvix monitors` | Monitor rules from Settings; revert a trial or reset them |
| `orvix workspaces` | Each monitor's workspace blocks |
| `orvix keyboard` | Layouts, options and per-keyboard layouts |
| `orvix autostart` | What starts at login |
| `orvix gpu` | GPUs found; `order`, `links` |
| `orvix nvidia` | NVIDIA driver status; `install` installs or fixes it |
| `orvix cursor`, `orvix icons` | Cursor and icon themes |
| `orvix zen` | Zen Browser profiles that follow the theme |
| `orvix whatsapp` | Open WhatsApp Web (the app of the WhatsApp special) |
| `orvix welcome` | Open the welcome screen again |
| `orvix git` | Run git in the dotfiles repository |
| `orvix help` | Every command, with a one-line summary |

</details>

<details>
<summary><b>Keybindings</b></summary>

Every bind below can be changed or turned off in Settings › Hyprland › Keybinds,
where you can also add your own. Prefer the arrow keys over H / J / K / L? Pick
Arrows (or Both) under Navigation keys there. <kbd>Super</kbd> + left / right
drag moves / resizes windows.

<!-- keybinds:start -->

**Apps**

| Keys | Action |
| --- | --- |
| <kbd>Super</kbd> + <kbd>Enter</kbd> | Terminal |
| <kbd>Super</kbd> + <kbd>D</kbd> | File manager |
| <kbd>Super</kbd> + <kbd>Z</kbd> | Browser |

**Windows**

| Keys | Action |
| --- | --- |
| <kbd>Super</kbd> + <kbd>Q</kbd> | Close window |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>Space</kbd> | Toggle floating |
| <kbd>Super</kbd> + <kbd>F</kbd> | Fullscreen |
| <kbd>Super</kbd> + <kbd>Tab</kbd> | Split / swap with main / column width |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>Tab</kbd> | Previous column width (scrolling) |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>Tab</kbd> | Next window layout |
| <kbd>Super</kbd> + <kbd>,</kbd> | Swap column left (scrolling) |
| <kbd>Super</kbd> + <kbd>.</kbd> | Swap column right (scrolling) |
| <kbd>Super</kbd> + <kbd>[</kbd> | Join / leave previous column (scrolling) |
| <kbd>Super</kbd> + <kbd>]</kbd> | Join / leave next column (scrolling) |
| <kbd>Super</kbd> + <kbd>C</kbd> | Center column (scrolling) |
| <kbd>Super</kbd> + <kbd>R</kbd> | Fit visible columns (scrolling) |
| <kbd>Super</kbd> + <kbd>H / L / K / J</kbd> | Focus left / right / up / down |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>H / L / K / J</kbd> | Move window left / right / up / down |
| <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>H</kbd> | Shrink width |
| <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>L</kbd> | Grow width |
| <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>K</kbd> | Shrink height |
| <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>J</kbd> | Grow height |

**Workspaces**

| Keys | Action |
| --- | --- |
| <kbd>Super</kbd> + <kbd>1–0</kbd> | Go to workspace 1–10 |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>1–0</kbd> | Move window to workspace 1–10 |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>L</kbd> | Next workspace |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>H</kbd> | Previous workspace |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>L</kbd> | Move window to next workspace |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>H</kbd> | Move window to previous workspace |

**Media**

| Keys | Action |
| --- | --- |
| <kbd>Volume Up</kbd> | Volume up |
| <kbd>Volume Down</kbd> | Volume down |
| <kbd>Mute</kbd> | Mute |
| <kbd>Mic Mute</kbd> | Mute microphone |
| <kbd>Brightness Up</kbd> | Brightness up |
| <kbd>Brightness Down</kbd> | Brightness down |
| <kbd>Next</kbd> | Next track |
| <kbd>Pause</kbd> or <kbd>Play</kbd> | Play / pause |
| <kbd>Previous</kbd> | Previous track |

**Shell**

| Keys | Action |
| --- | --- |
| <kbd>Super</kbd> + <kbd>=</kbd> | Zoom in |
| <kbd>Super</kbd> + <kbd>-</kbd> | Zoom out |
| <kbd>Super (tap)</kbd> | App launcher |
| <kbd>Super</kbd> + <kbd>V</kbd> | Clipboard history |
| <kbd>Print</kbd> | Screenshot |
| <kbd>Super</kbd> + <kbd>End</kbd> | Power menu |
| <kbd>Super</kbd> + <kbd>Esc</kbd> | Lock screen |
| <kbd>Super</kbd> + <kbd>B</kbd> | Wallpaper picker |
| <kbd>Super</kbd> + <kbd>I</kbd> | Settings |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>R</kbd> | Reload Quickshell |

**Keyboard**

| Keys | Action |
| --- | --- |
| <kbd>Super</kbd> + <kbd>Space</kbd> | Next keyboard layout |

**Special workspaces**

| Keys | Action |
| --- | --- |
| <kbd>Super</kbd> + <kbd>W</kbd> | Toggle WhatsApp |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | Move window to WhatsApp |
| <kbd>Super</kbd> + <kbd>M</kbd> | Toggle Music |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>M</kbd> | Move window to Music |

<!-- keybinds:end -->

</details>

<details>
<summary><b>Repository layout</b></summary>

Each top-level folder is a [GNU Stow](https://www.gnu.org/software/stow/) package
linked into `$HOME`: `quickshell/`, `hyprland/` and `local/` always, the others
with their installer category (`orvix link` shows which are linked). The repo
doesn't have to stay at `~/.orvix`: the `orvix` command, the session and the
shell follow where it really is.

| Folder | Contents |
| --- | --- |
| `quickshell/` | The shell: bar, launcher, dashboard, notifications, OSD, lock, power, screenshots, Settings |
| `hyprland/` | Hyprland config in Lua (`conf/`), plus `local/` for per-machine files |
| `kitty/`, `zsh/`, `tmux/`, `nvim/` | Terminal, shell (Oh My Zsh + Powerlevel10k), multiplexer, editor |
| `theming/`, `kde/` | GTK 3/4, Qt 5/6 and KDE color settings |
| `fastfetch/` | System info |
| `local/` | Scripts, the `orvix` command, themes and wallpapers (`~/.local/`) |
| `.install/` | Installer libraries, package lists and setup |
| `.data/` | Default themes, wallpapers and their generator, state defaults, CLI commands and migrations |

</details>

<details>
<summary><b>Customization</b></summary>

- **Settings first.** Almost everything is in Settings (<kbd>Super</kbd> +
  <kbd>I</kbd>). Its values live in `~/.config/quickshell/state.json`;
  `orvix state` opens it.
- **Language**: English or Português (Brasil), in Settings › Profile & Region
  (Automatic follows your system). Dates and numbers follow it.
- **Machine-specific Hyprland files** live in `~/.config/hypr/local/` (not
  tracked). Settings writes `settings.lua`, `monitors.lua` and `gpus.lua` there;
  any other `.lua` file you add is loaded too.
- **Themes** are JSON files in `~/.local/themes/`. Create one in Settings › Theme ›
  New theme, or copy a file from `.data/themes/`.
- **Wallpapers** live in `~/.local/wallpapers/`, with each theme's in
  `themes/<theme>/`.
  `.data/wallpapers/generator/generate.py --theme-file <json>` renders the contour
  wallpaper for any palette.
- **GTK & Qt**: Settings › Appearance › GTK & Qt. Three switches decide whether
  the shell theme sets the GTK theme, writes GTK colors and writes the Qt color
  scheme; the rest of the page is yours to set by hand.

</details>

<details>
<summary><b>Languages and translations</b></summary>

The shell speaks English and Português (Brasil). Every string goes through an
`I18n` singleton with one JSON file per language in
`quickshell/.config/quickshell/i18n/`, so a new language needs no code:

```sh
node tools/i18n.js add de "Deutsch"   # creates i18n/de.json, every value empty
node tools/i18n.js extract            # after translating: refresh the language list
node tools/i18n.js check              # placeholders, plural forms, files up to date
```

Partial translations work (untranslated strings show in English).
[i18n/README.md](quickshell/.config/quickshell/i18n/README.md) has the rules
(placeholders, plurals, contexts, date formats), how to try a language live and
the pseudo-language for finding untranslated or cut text.

</details>

## Tests

```bash
tests/run.sh js      # the shell's JavaScript libraries (node)
tests/run.sh qml     # qmllint against tests/qml/lint-baseline.txt
tests/run.sh bash    # the CLI, migrations and installer (bats)
tests/run.sh lint    # shellcheck over every script
tests/run.sh         # everything, including the smoke test in a nested Hyprland
```

The `bash`, `lint` and `smoke` sections need `bats`, `shellcheck`, `tmux` and a
running Hyprland session; a missing tool fails the section rather than being
skipped silently.

## Credits

- **Lyne-Dots**, by [caioax](https://github.com/caioax), which this project comes
  from and whose GPL-3.0 license it keeps
- [Caelestia shell](https://github.com/caelestia-dots/shell): inspiration for many
  of the shell's panels and its Settings
- [HyprQuickFrame](https://github.com/Ronin-CK/HyprQuickFrame): the screenshot
  tool's starting point
- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell):
  inspiration for the installer's TUI layout and its questions before installing
- [Omarchy](https://omarchy.org): the desktop Orvix is built to coexist with
- [Quickshell](https://quickshell.org), [Hyprland](https://hypr.land),
  [matugen](https://github.com/InioX/matugen),
  [awww](https://codeberg.org/LGFae/awww),
  [cliphist](https://github.com/sentriz/cliphist),
  [cava](https://github.com/karlstav/cava),
  [tesseract](https://github.com/tesseract-ocr/tesseract)
- Weather from [Open-Meteo](https://open-meteo.com); lyrics from
  [LRCLIB](https://lrclib.net) and NetEase

## License

[GPL-3.0](LICENSE). Orvix is a modified version of Lyne-Dots by caioax and
contributors; the changes keep the same license.
