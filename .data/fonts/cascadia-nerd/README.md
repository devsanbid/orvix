# Bundled fonts

## CaskaydiaCove Nerd Font

Orvix's interface font: **CaskaydiaCove Nerd Font**, a Nerd-Fonts patched build
of Microsoft's **Cascadia Code**.

| File | Face |
| --- | --- |
| `CaskaydiaCoveNerdFont-Regular.ttf` | Regular (the UI's default) |
| `CaskaydiaCoveNerdFont-Bold.ttf` | Bold (window titles, headings) |
| `CaskaydiaCoveNerdFont-Italic.ttf` | Italic |
| `CaskaydiaCoveNerdFont-BoldItalic.ttf` | Bold italic |

The other eight weights (Light, SemiLight, ExtraLight and their italics) are
not bundled: the interface never asks for them, and all twelve together are
34 MB. Install `ttf-cascadia-code-nerd` if you want the whole family — the
installer does exactly that, and then these files are simply not used.

### Licence

**SIL Open Font License 1.1** — see [LICENSE-OFL.txt](LICENSE-OFL.txt), which
travels with the fonts as the licence requires.

Redistribution is permitted by the OFL: condition 2 allows bundling with any
software provided the copyright notice and the licence come with it, which is
what this folder is for. Condition 3 — that a *modified* version may not use
the reserved name "Cascadia Code" — does not apply: these files are
byte-for-byte the ones the Arch package ships, unmodified.

Copyright (c) 2019 - Present, Microsoft Corporation, with Reserved Font Name
Cascadia Code.

### Where they go

`install.sh` copies them to `~/.local/share/fonts/` and refreshes the font
cache, so the interface font is there on a fresh install before anything else
needs it. The Arch package `ttf-cascadia-code-nerd` is installed as well when
the fonts category is picked; the two do not conflict (the local copy wins for
the user, and the family name is the same).

To use it, nothing needs doing: `typography.font` defaults to
`CaskaydiaCove Nerd Font`.

## Quicksand (wallpaper generator only)

`.data/wallpapers/generator/fonts/Quicksand-500.ttf`, used only by the
wallpaper renderer, with `OFL-Quicksand.txt` beside it. Not an interface font.

## Verified

`fc-query` on each bundled file reports the family **`CaskaydiaCove Nerd
Font`** (styles Regular, Bold, Italic, Bold Italic), which is exactly the name
`typography.font` defaults to — so the bundled copy is used without anything
else changing.
