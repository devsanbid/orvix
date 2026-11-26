# Uninstalling Orvix

Orvix is dotfiles plus packages: links into your home folder, packages on the
system, and a few state and cache files. Removing it is done in that order, and
the first steps can be done on their own if you only want to drop part of it.

Read the whole page once before deleting anything. The backups are the only copy
of the files Orvix replaced, so keep `~/.orvix-backup/` until you are sure.

## 1. Bring your own files back

`orvix unlink <package>` removes a package's links and restores the newest copy
of each file from `~/.orvix-backup/`.

```bash
orvix link status              # what is linked, and each package's category
orvix unlink kitty zsh tmux    # one or more optional packages
```

- `hyprland`, `quickshell` and `local` cannot be unlinked this way: the running
  shell needs them. Remove their links by hand in step 2, from a TTY or another
  session.
- `orvix unlink` only touches files the package linked. Your own files in
  `~/.config/hypr/local/`, your themes and your wallpapers are not linked from the
  repository and stay where they are.
- If a backup is missing, the link is removed and the original file is not
  recreated; look in `~/.orvix-backup/<date>/` for the copy you want.

## 2. Remove the links

From a session that is **not** running Orvix's Quickshell (a TTY works), remove
the remaining links. GNU Stow can do it per package:

```bash
cd ~/.orvix
stow --delete --target="$HOME" hyprland quickshell local
```

Or delete the links by hand. They are symlinks into `~/.orvix`, so this finds
them without touching your real files:

```bash
find ~/.config ~/.local ~/.zshrc ~/.tmux.conf ~/.config/kitty ~/.config/nvim \
  -maxdepth 3 -type l -lname "$HOME/.orvix/*" -print
```

Check the list before removing anything, then repeat the same command with
`-delete`. `~/.local/bin/orvix` is a link too; remove it with the rest. (The
old `~/.local/bin/lyne` shim is gone since migration `052-unlink-lyne`.)

If you log in through the Orvix Hyprland config, switch the session back to your
previous config (or to Omarchy's) before removing `~/.config/hypr`, otherwise the
next login has no window manager.

## 3. Remove the state and cache (optional)

These are not needed once the links are gone:

| Path | What it is |
| --- | --- |
| `~/.config/quickshell/state.json` | Your Settings values |
| `~/.local/share/quickshell/` | Defaults and the shell's own data |
| `~/.local/share/orvix/` | The migration marker and Orvix's managed-file backup |
| `~/.cache/orvix/` | Installer and update logs, the Neovim and Zen palette files |
| `~/.local/state/orvix/` | Runtime state, when present |
| `~/.local/share/color-schemes/Orvix.colors` | The generated KDE/Qt color scheme |
| `~/.config/gtk-3.0/colors.css`, `~/.config/gtk-4.0/colors.css` | Colors written by the theme |
| `~/.config/qt6ct/` | Qt colors written by the theme |
| `~/.orvix-backup/` | **Your files from before the install** — keep until you are sure |
| `~/.orvix` | The repository itself |

Keep `~/.config/hypr/local/` if you move to another Hyprland config: it holds the
per-machine files Settings wrote for you.

## 4. Remove the packages (optional)

The installer does not track a package list for removal, and removing Hyprland or
the GPU driver can leave the machine without a desktop. If you want the space
back, remove the categories you added, carefully, one at a time:

```bash
sudo pacman -Rns quickshell kitty     # only if nothing else needs them
```

Do **not** remove `hyprland`, the portals or the GPU driver until you have another
session that works. `pacman -Rns` also removes dependencies that nothing else
needs; read the list before confirming.

The login screen (`lyne-sddm`) is a package too:

```bash
orvix sddm status        # before removing the CLI
sudo pacman -Rns lyne-sddm
```

Switch SDDM back to your previous display manager (or another one) before
removing it, so the machine still boots to a login screen.

## 5. If Omarchy is installed

Nothing to undo: Orvix never writes under `/usr/share/omarchy` and never edits an
Omarchy theme or plugin. If you used Orvix's Hyprland config for the session,
select Omarchy's config (or its session entry) again at login. Omarchy's own
settings and theme state were left as they were, and Settings › Appearance › GTK
& Qt can hand the GTK theme back with "Use Omarchy's GTK settings" while Orvix is
still installed.

## After removing

- Log out and back in, or reboot, so the session and the shell start from the
  files that are actually there.
- Check `~/.config` and `~/.local` for leftovers: a broken symlink shows up as a
  file that cannot be opened.
- `~/.orvix-backup/` can be deleted once your own files are back in place and you
  have checked them. Nothing else reads it.
