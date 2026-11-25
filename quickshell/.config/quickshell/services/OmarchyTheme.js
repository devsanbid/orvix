.pragma library

// Maps an Omarchy theme (colors.toml) onto the palette the Orvix shell uses.
// Pure functions: no Qt, no files. OmarchyService reads the files and passes
// the parsed colors here; tests/js/omarchyTheme.test.js covers the mapping.
//
// Omarchy keys (colors.toml): mode, accent, selection, muted, background,
// dark_background, darker_background, lighter_background, foreground,
// dark_foreground, light_foreground, bright_foreground, red, yellow, orange,
// green, cyan, blue, magenta, brown, bright_*.

var DEFAULT_PALETTE = {
    background: "#1a1b26",
    surface0: "#24283b",
    surface1: "#292e42",
    surface2: "#414868",
    surface3: "#565f89",
    text: "#c0caf5",
    textReverse: "#1a1b26",
    subtext: "#a9b1d6",
    subtextReverse: "#565f89",
    accent: "#7aa2f7",
    success: "#9ece6a",
    warning: "#e0af68",
    error: "#f7768e",
    muted: "#545c7e",
    greyBlue: "#283457",
    blueDark: "#16161e"
};

function _hex(value, fallback) {
    if (typeof value !== "string")
        return fallback;
    var v = value.trim();
    if (/^#[0-9a-fA-F]{6}$/.test(v))
        return v.toLowerCase();
    if (/^[0-9a-fA-F]{6}$/.test(v))
        return "#" + v.toLowerCase();
    // #rrggbbaa: the shell's palette is #rrggbb
    if (/^#[0-9a-fA-F]{8}$/.test(v))
        return v.slice(0, 7).toLowerCase();
    return fallback;
}

function _bare(value, fallback) {
    return _hex(value, fallback).slice(1);
}

// Only `key = "value"` lines; comments and bare values are ignored on
// purpose, so a malformed theme falls back instead of producing bad colors.
function parseColors(text) {
    var out = {};
    if (!text)
        return out;
    var lines = String(text).split(/\r?\n/);
    for (var i = 0; i < lines.length; i++) {
        var m = lines[i].match(/^\s*([A-Za-z0-9_]+)\s*=\s*"([^"]*)"\s*(?:#.*)?$/);
        if (m)
            out[m[1]] = m[2];
    }
    return out;
}

function variant(colors) {
    return colors && colors.mode === "light" ? "light" : "dark";
}

function palette(colors) {
    var c = colors || {};
    return {
        background: _hex(c.background, DEFAULT_PALETTE.background),
        surface0: _hex(c.lighter_background, DEFAULT_PALETTE.surface0),
        surface1: _hex(c.selection, DEFAULT_PALETTE.surface1),
        surface2: _hex(c.muted, DEFAULT_PALETTE.surface2),
        surface3: _hex(c.dark_foreground, DEFAULT_PALETTE.surface3),
        text: _hex(c.bright_foreground, _hex(c.foreground, DEFAULT_PALETTE.text)),
        textReverse: _hex(c.background, DEFAULT_PALETTE.textReverse),
        subtext: _hex(c.foreground, DEFAULT_PALETTE.subtext),
        subtextReverse: _hex(c.dark_foreground, DEFAULT_PALETTE.subtextReverse),
        accent: _hex(c.accent, DEFAULT_PALETTE.accent),
        success: _hex(c.green, DEFAULT_PALETTE.success),
        warning: _hex(c.yellow, DEFAULT_PALETTE.warning),
        error: _hex(c.red, DEFAULT_PALETTE.error),
        muted: _hex(c.muted, DEFAULT_PALETTE.muted),
        greyBlue: _hex(c.selection, DEFAULT_PALETTE.greyBlue),
        blueDark: _hex(c.darker_background, DEFAULT_PALETTE.blueDark)
    };
}

function terminal(colors) {
    var c = colors || {};
    var p = palette(c);
    return {
        background: p.background,
        foreground: _hex(c.foreground, p.text),
        selectionBackground: _hex(c.selection, p.surface1),
        selectionForeground: _hex(c.bright_foreground, p.text),
        urlColor: _hex(c.cyan, p.accent),
        cursor: p.accent,
        cursorTextColor: p.background,
        activeTabBackground: p.accent,
        activeTabForeground: p.background,
        inactiveTabBackground: _hex(c.lighter_background, p.surface0),
        inactiveTabForeground: _hex(c.dark_foreground, p.subtextReverse),
        activeBorderColor: p.accent,
        inactiveBorderColor: _hex(c.selection, p.surface1),
        color0: _hex(c.dark_background, p.blueDark),
        color1: _hex(c.red, p.error),
        color2: _hex(c.green, p.success),
        color3: _hex(c.yellow, p.warning),
        color4: _hex(c.blue, p.accent),
        color5: _hex(c.magenta, "#bb9af7"),
        color6: _hex(c.cyan, "#7dcfff"),
        color7: _hex(c.foreground, p.subtext),
        color8: _hex(c.muted, p.muted),
        color9: _hex(c.bright_red, _hex(c.red, p.error)),
        color10: _hex(c.bright_green, _hex(c.green, p.success)),
        color11: _hex(c.bright_yellow, _hex(c.yellow, p.warning)),
        color12: _hex(c.bright_blue, _hex(c.blue, p.accent)),
        color13: _hex(c.bright_magenta, _hex(c.magenta, "#bb9af7")),
        color14: _hex(c.bright_cyan, _hex(c.cyan, "#7dcfff")),
        color15: _hex(c.bright_foreground, p.text),
        color16: _hex(c.orange, "#ff9e64"),
        color17: _hex(c.brown, "#db4b4b")
    };
}

function hyprland(colors) {
    var c = colors || {};
    var p = palette(c);
    return {
        activeBorder: _bare(p.accent, "7aa2f7") + "ff",
        inactiveBorder: _bare(p.muted, "545c7e") + "aa",
        shadowColor: _bare(p.blueDark, "16161e") + "ee"
    };
}

// { name, variant, palette, terminal, hyprland } in the shape ThemeService
// applies for a preset theme. `name` is the display name.
function toThemeData(colors, name) {
    return {
        name: name || "Omarchy",
        variant: variant(colors),
        palette: palette(colors),
        terminal: terminal(colors),
        hyprland: hyprland(colors)
    };
}

// "tokyo-night" -> "Tokyo Night" (the way `omarchy theme current` prints it)
function prettyName(slug) {
    return String(slug || "")
        .replace(/[-_]+/g, " ")
        .replace(/\b[a-z]/g, function (c) { return c.toUpperCase(); });
}
