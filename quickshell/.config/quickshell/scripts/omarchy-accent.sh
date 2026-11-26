# omarchy-accent.sh - Ask Omarchy to use Orvix's accent color
#
# Orvix's theme mode can follow Omarchy's theme (read-only). The other
# direction exists too, but only when the user asks: Settings › System ›
# Omarchy › "Use Orvix's accent in Omarchy" runs this with the accent of the
# Orvix palette.
#
# How, without touching anything Omarchy owns:
#   * Omarchy reads the official theme from /usr/share/omarchy/themes and
#     overlays ~/.config/omarchy/themes/<name>/ on top of it; that user folder
#     is the documented place for a user's changes to a theme
#   * this writes only colors.toml there, with the current palette and the new
#     accent, and only when the folder is missing or holds a file Orvix wrote
#     (the marker line). A theme the user made or edited is refused, untouched
#   * then it runs `omarchy theme set <name>`, Omarchy's own command, which
#     does the actual switch
#
# Nothing under /usr/share/omarchy is written, and no Omarchy file is edited
# in place.
#
# Usage: omarchy-accent.sh <#rrggbb>
# Exit:  0 done, 1 refused or failed, 2 usage

set -u

MARKER="# Written by Orvix (Settings › System › Omarchy)"

usage() { echo "Usage: omarchy-accent.sh <#rrggbb>" >&2; }

accent="${1:-}"
if [[ ! "$accent" =~ ^#[0-9a-fA-F]{6}$ ]]; then
    usage
    exit 2
fi

HOME_DIR="${HOME:-}"
STATE="$HOME_DIR/.local/state/omarchy"
COLORS="$STATE/current/theme/colors.toml"
NAME_FILE="$STATE/current/theme.name"
THEMES="$HOME_DIR/.config/omarchy/themes"

if [[ ! -f "$COLORS" || ! -f "$NAME_FILE" ]]; then
    echo "Omarchy has no current theme: pick one in Omarchy first." >&2
    exit 1
fi

theme="$(tr -d '[:space:]' <"$NAME_FILE")"
if [[ -z "$theme" || "$theme" == */* || "$theme" == .* ]]; then
    echo "Omarchy's current theme name is not usable: '$theme'" >&2
    exit 1
fi
if ! command -v omarchy >/dev/null 2>&1; then
    echo "The omarchy command isn't installed" >&2
    exit 1
fi

target="$THEMES/$theme"
target_file="$target/colors.toml"

# A theme folder that isn't ours: leave it alone
if [[ -e "$target" && ! -d "$target" ]]; then
    echo "$target exists and isn't a theme folder: left as it is." >&2
    exit 1
fi
if [[ -f "$target_file" ]] && ! head -n 1 "$target_file" | grep -qxF "$MARKER"; then
    echo "$target_file is not Orvix's: left as it is. Edit it yourself to change the accent." >&2
    exit 1
fi
if [[ -d "$target" ]] && [[ -n "$(find "$target" -mindepth 1 -maxdepth 1 ! -name colors.toml -print -quit 2>/dev/null)" ]]; then
    echo "$target holds files Orvix didn't write: left as it is." >&2
    exit 1
fi

# The current palette with the accent replaced (or added, when the theme has
# no accent line)
new_colors="$({
    printf '%s\n' "$MARKER"
    if grep -qiE '^[[:space:]]*accent[[:space:]]*=' "$COLORS"; then
        sed -E "s|^[[:space:]]*accent[[:space:]]*=.*$|accent = \"$accent\"|I" "$COLORS"
    else
        cat "$COLORS" && printf 'accent = "%s"\n' "$accent"
    fi
})"

mkdir -p "$target" || exit 1
printf '%s\n' "$new_colors" >"$target_file" || exit 1

# Omarchy's own command does the switch (it overlays the user folder itself)
if ! omarchy theme set "$theme"; then
    echo "omarchy theme set $theme failed" >&2
    exit 1
fi

echo "Omarchy's $theme now uses the accent $accent"
