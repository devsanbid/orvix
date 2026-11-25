const test = require("node:test");
const assert = require("node:assert/strict");
const { load } = require("./load");

const O = load("services/OmarchyTheme.js");

const TOKYO = `mode = "dark"

accent = "#7aa2f7"
selection = "#292e42"
muted = "#414868"

background = "#1a1b26"
dark_background = "#13141c"
darker_background = "#0e0e14"
lighter_background = "#24283b"

foreground = "#a9b1d6"
dark_foreground = "#565f89"
light_foreground = "#b4bee6"
bright_foreground = "#c0caf5"

red = "#f7768e"
yellow = "#e0af68"
orange = "#eb927b"
green = "#9ece6a"
cyan = "#449dab"
blue = "#7aa2f7"
magenta = "#ad8ee6"
brown = "#75493d"

bright_red = "#ff7a93"
bright_yellow = "#ff9e64"
bright_green = "#b9f27c"
bright_cyan = "#0db9d7"
bright_blue = "#7da6ff"
bright_magenta = "#bb9af7"
`;

test("parseColors reads quoted keys and ignores comments and bare values", () => {
    const c = O.parseColors(`${TOKYO}\n# comment = "nope"\nbare = value\n`);
    assert.equal(c.accent, "#7aa2f7");
    assert.equal(c.background, "#1a1b26");
    assert.equal(c.mode, "dark");
    assert.equal(c.comment, undefined);
    assert.equal(c.bare, undefined);
});

test("Tokyo Night maps onto the Orvix palette", () => {
    const data = O.toThemeData(O.parseColors(TOKYO), "Tokyo Night");
    assert.equal(data.name, "Tokyo Night");
    assert.equal(data.variant, "dark");
    assert.deepEqual(data.palette, {
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
        muted: "#414868",
        greyBlue: "#292e42",
        blueDark: "#0e0e14"
    });
});

test("terminal and Hyprland colors are complete and valid", () => {
    const data = O.toThemeData(O.parseColors(TOKYO));
    const t = data.terminal;
    for (const key of ["background", "foreground", "cursor", "color0", "color15", "color17"])
        assert.match(t[key], /^#[0-9a-f]{6}$/, key);
    assert.equal(t.color4, "#7aa2f7");
    assert.equal(t.color16, "#eb927b");
    assert.match(data.hyprland.activeBorder, /^[0-9a-f]{8}$/);
    assert.equal(data.hyprland.activeBorder, "7aa2f7ff");
    assert.equal(data.hyprland.inactiveBorder, "414868aa");
});

test("a light theme keeps its light background and dark text", () => {
    const light = O.parseColors(`mode = "light"
background = "#fafafa"
foreground = "#343b58"
bright_foreground = "#1a1b26"
accent = "#34548a"
`);
    const data = O.toThemeData(light);
    assert.equal(data.variant, "light");
    assert.equal(data.palette.background, "#fafafa");
    assert.equal(data.palette.text, "#1a1b26");
    assert.equal(data.palette.textReverse, "#fafafa");
});

test("missing colors fall back instead of producing empty values", () => {
    const data = O.toThemeData(O.parseColors("mode = \"dark\"\n"), "Broken");
    assert.deepEqual(data.palette, O.DEFAULT_PALETTE);
    assert.match(data.terminal.background, /^#[0-9a-f]{6}$/);
    assert.equal(data.hyprland.activeBorder, "7aa2f7ff");
});

test("accepts 8-digit colors and bare hex", () => {
    const c = O.parseColors(`background = "#112233ff"\naccent = "#aabbcc"\n`);
    const p = O.palette(c);
    assert.equal(p.background, "#112233");
    assert.equal(p.accent, "#aabbcc");
});

test("prettyName matches Omarchy's theme current output", () => {
    assert.equal(O.prettyName("tokyo-night"), "Tokyo Night");
    assert.equal(O.prettyName("catppuccin-latte"), "Catppuccin Latte");
    assert.equal(O.prettyName("mono"), "Mono");
});
