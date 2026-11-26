# Installing Orvix

Orvix is a Hyprland desktop and a Quickshell shell for Arch Linux. The installer
sets up the packages, links the dotfiles into your home folder and creates the
per-machine Hyprland files. It asks everything first, then runs on its own.

Read [UNINSTALL.md](UNINSTALL.md) before you start if you want to know how to get
your old configuration back.

## Before you start

- **Arch Linux**, or a close derivative with `pacman`. The installer stops with a
  clear message on anything else; there is no partial install on another distro.
- **A normal user with `sudo`.** The installer refuses to run as root: the files
  belong in your home folder and `makepkg` refuses root anyway.
- **An internet connection.** The full install downloads a few GB of packages.
- **A backup of your important files**, as with any new desktop. The installer
  backs up every file it replaces, but it cannot back up what it never touches.
- **Free space:** several GB for packages, more if you keep several kernels or a
  large NVIDIA driver.
- **Optional:** an existing Omarchy install. Orvix detects it, mentions it in the
  review screen and never writes under `/usr/share/omarchy`. See
  [Omarchy](#omarchy) below.

## Getting the code

There is no published remote for this copy of Orvix yet. Clone it where you want
it, by default `~/.orvix`:

```bash
git clone <your-orvix-remote> ~/.orvix
cd ~/.orvix
```

The folder does not have to be `~/.orvix`: the `orvix` command, the session and
the shell follow where the repository really is. `~/.orvix` is only the default
the installer suggests in its messages.

If the repository is hosted on GitHub with the included Pages workflow,
`bootstrap.sh` is available as a one-line installer:

```bash
curl -fsSL https://<your-user>.github.io/orvix/install \
  | ORVIX_BOOTSTRAP_REPO=https://github.com/<your-user>/orvix.git bash
```

`bootstrap.sh` clones into `~/.orvix`, checks out the newest release tag when one
exists (otherwise the tip of `main`), and runs that tree's `install.sh`.
Arguments go to the installer: `| bash -s -- --dry-run`. It refuses to run when
`~/.orvix` already exists; update that install with `orvix update` instead.

## Running the installer

```bash
./install.sh
```

The questions, in order:

1. **Packages.** Pick categories. The shell's own files are always linked; the
   optional categories decide which programs and configs come along.

   | Category | Programs and configs |
   | --- | --- |
   | `core` | Hyprland, UWSM, portals, the base system pieces |
   | `terminal` | kitty, Zsh, tmux, fastfetch and their configs |
   | `editor` | Neovim and its tools |
   | `apps` | Dolphin, Zen Browser, Spotify, Chromium (WhatsApp) |
   | `utils` | Clipboard, audio, Bluetooth |
   | `fonts` | Nerd Fonts and icons |
   | `quickshell` | Quickshell itself |
   | `theming` | GTK, Qt and KDE theming, plus their configs |
   | `nvidia` | The NVIDIA driver (also offered by the Graphics question) |

   Leave a category out and your existing config for it stays as it is.
2. **Graphics.** The GPUs found, and for NVIDIA the driver (open or 580xx,
   optionally 32-bit) and its environment.
3. **Login screen** (only when SDDM is the display manager): install
   `lyne-sddm`, a login screen in the same style as the lock screen. It is built
   from GitHub with `makepkg`; switching display managers is left to you.
4. **Reboot** after the install, with a countdown any key cancels. It never
   happens after a failed install.
5. **Review.** The packages to link, the GPUs, the login screen, the reboot, and
   every file of yours that will be moved to the backup. Nothing has been
   installed at this point.

After the review, sudo asks for the password once (it is kept alive), and the
install runs with a progress bar and the latest output.

### Non-interactive and preview runs

| Option | What it does |
| --- | --- |
| `--dry-run` | Changes nothing: a throwaway HOME and stand-ins for `sudo`, `pacman -S`, `yay`, `stow`, `systemctl`. `ORVIX_DRY_HOME=dir` reuses one throwaway HOME |
| `--yes`, `-y` | Takes the defaults shown in the questions and skips them (the sudo password is still asked) |
| `--answers FILE` | Reads answers from `id=value` lines: `categories=core terminal ...`, `nvidia=driver\|env\|none`, `multilib=yes`, `gpu_order=igpu\|dgpu\|auto`, `reboot=yes\|no` |
| `--packages NAME` | Installs one category, e.g. `--packages nvidia` to install or fix the driver |
| `--stow-only` | Only links the dotfiles again, for the packages linked before |
| `--setup-only` | Only creates the per-machine Hyprland files |
| `--no-omarchy` | Does not detect or mention Omarchy (nothing is written to it either way) |
| `--help`, `-h` | Every option, and the package categories |

A typical unattended run:

```bash
./install.sh --dry-run --yes          # see what a default install would do
./install.sh --answers answers.txt    # answers.txt holds the id=value lines
```

The installer needs a terminal when it has questions to ask. With `--answers` or
`--yes` it runs without one, which is what a provisioning script wants.

## What gets changed

- **Packages** are installed with `pacman` and, where needed, `yay`/`makepkg`.
- **Dotfiles** are linked with [GNU Stow](https://www.gnu.org/software/stow/):
  `hyprland/`, `quickshell/` and `local/` always, plus the folders of the
  categories you picked.
- **Existing files in the way** are moved, not deleted, to
  `~/.orvix-backup/<date>/`, keeping their path under your home folder. The
  review screen lists them before anything moves.
- **Per-machine files** (`~/.config/hypr/local/settings.lua`, `monitors.lua`,
  `gpus.lua`) are created from the defaults; they are not tracked by git.
- **The full log** is written to `~/.cache/orvix/install-<date>.log`.
- **Orvix never writes under `/usr/share/omarchy`.** Omarchy's themes, plugins
  and default config are read-only from Orvix's side.

If a step fails, the installer stops that step, keeps going with the others where
it is safe, and prints what failed at the end. The log has the details. Running
`./install.sh` again resumes: it detects what is already linked.

## Omarchy

Orvix works on a plain Arch + Hyprland machine with no Omarchy, and it also works
next to Omarchy:

- **Detected, not touched.** When `/usr/share/omarchy` exists, the review screen
  says so and Settings › System › Omarchy shows the version, current theme,
  whether `omarchy-shell` is running and how many shell plugins are installed.
- **Own Hyprland config.** Orvix links `~/.config/hypr` with its own Lua config.
  Omarchy's Hyprland config, autostart entries and keybinds are not loaded while
  Orvix's session runs. This is the main difference between the two setups, and
  it is a deliberate choice, not something the installer hides.
- **Theme following is opt-in.** Settings › Theme can use Omarchy's current theme
  as the color source. It reads `~/.local/state/omarchy/current/theme`; it never
  rewrites it. Settings › Appearance › GTK & Qt can apply Omarchy's GTK settings
  through Omarchy's own `omarchy-theme-set-gnome`.
- **One bar at a time.** If `omarchy-shell` is running too, you get two bars.
  Settings warns about it; nothing is stopped automatically.
- **Plugins are not shared.** Omarchy's `omarchy-shell` plugins cannot be loaded
  by Orvix. The plugin count is informational only.

The two supported setups are described in
[TODO_OMARCHY_INTEGRATION.md](TODO_OMARCHY_INTEGRATION.md#supported-setups).

## Coming from Lyne-Dots

The project was called Lyne-Dots before Orvix. An existing install is adopted
instead of replaced, and the old names are gone once the chain has run:

- Migration `051-orvix-rename` moves the Neovim palette cache
  (`~/.cache/lyne` → `~/.cache/orvix`), the KDE color scheme
  (`Lyne.colors` → `Orvix.colors`) and, when the repo is at the default
  `~/.lyne-dots`, the repository folder itself (`~/.lyne-dots` → `~/.orvix`).
  The symlinks that pointed into the old folder are repointed.
- Migration `052-unlink-lyne` removes what is left: the `~/.local/bin/lyne`
  command, the `~/.lyne-dots` link, the `lyne-<theme>-contour.jpg` wallpapers
  (renamed to `orvix-*`, and the theme files that name them updated), the old
  caches, the `lyne-editor` desktop entry, and the last `lyne_*` Lua globals in
  `~/.config/hypr/local/*.lua`.
- Custom themes, wallpapers, `state.json` and your files in
  `~/.config/hypr/local/` are not rewritten beyond those names. A theme,
  a wallpaper or a folder you made yourself stays as you made it.
- Kept on purpose: the third-party **`lyne-sddm`** login-screen package and its
  `LYNE_SDDM_REF` build variable. It is a separate project, installed and
  updated under that name.

If you start from a fresh clone on a machine that was never Lyne, none of this
runs.

## When something is missing

```bash
orvix doctor
```

Checks Hyprland and its config, Quickshell, the wallpaper daemon, the polkit
agent, the clipboard, the theme files and matugen, your default apps, the tools
behind the shortcuts (screenshots, OCR, media keys), the update source and, if
it is installed, Omarchy. Nothing is changed: each problem comes with the
command that fixes it. The same checks are in **Settings › System › Health**.

## First login

1. Log out and pick **Hyprland (uwsm)** in your display manager, or run
   `uwsm start hyprland-uwsm.desktop`.
2. Open Settings (<kbd>Super</kbd> + <kbd>I</kbd>) and set up monitors under
   **Hyprland › Monitors**. Each monitor gets its own workspace block.
3. In tmux, press <kbd>prefix</kbd> + <kbd>I</kbd> to install the plugins.
4. On NVIDIA, check the driver after the reboot with `orvix nvidia` and review
   `~/.config/hypr/local/extra_environment.lua`.
5. Everything else is in Settings. The CLI is `orvix <command> --help`.

## Troubleshooting

| Symptom | What to do |
| --- | --- |
| "This script is for Arch Linux only" | The installer checks for `/etc/arch-release`. Use Arch or a derivative that has it |
| The installer says it needs a terminal | Run it from a terminal, use `--answers FILE` or `--yes` |
| A package fails to install | Read the log at `~/.cache/orvix/install-<date>.log`; fix the package and run `./install.sh` again |
| The session does not start | Check `~/.cache/orvix/` logs, then try a TTY: `uwsm start hyprland-uwsm.desktop` and read the output |
| The bar is missing | `orvix reload`, then `qs` in a terminal to see Quickshell's errors |
| Two bars, one of them Omarchy's | Stop `omarchy-shell` in your session, or use setup B from the plan; Orvix never stops it for you |
| Your old config is gone | Look in `~/.orvix-backup/<date>/`; `orvix unlink <package>` restores a package's files |
| Something is not translated | Settings › Profile & Region; partial translations fall back to English |

To remove Orvix and get your files back, follow [UNINSTALL.md](UNINSTALL.md).
