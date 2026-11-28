pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import qs.config
import "ThemeGenerator.js" as ThemeGenerator

Singleton {
    id: root

    // Helper function to shorten the service call
    function getState(path, fallback) {
        return StateService.get(path, fallback);
    }

    function setState(path, value) {
        StateService.set(path, value);
    }

    // ========================================================================
    // PROPERTIES
    // ========================================================================

    readonly property string themesDir: Quickshell.env("HOME") + "/.local/themes"
    readonly property string kittyThemePath: Quickshell.env("HOME") + "/.config/kitty/current-theme.conf"
    // Not Quickshell.shellDir: it is empty while a singleton is built
    readonly property string kittyApplyScript: Quickshell.env("HOME") + "/.config/quickshell/scripts/kitty-apply.sh"
    readonly property string ghosttyThemePath: Quickshell.env("HOME") + "/.config/ghostty/current-theme.conf"
    readonly property string ghosttyApplyScript: Quickshell.env("HOME") + "/.config/quickshell/scripts/ghostty-apply.sh"

    // Read by the Neovim "orvix" colorscheme (nvim/.config/nvim/lua/orvix/)
    readonly property string nvimPalettePath: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/orvix/nvim.json"
    readonly property string wallpaperDir: Quickshell.env("HOME") + "/.local/wallpapers"

    // GTK/Qt paths
    readonly property string gtkColorsPath3: Quickshell.env("HOME") + "/.config/gtk-3.0/colors.css"
    readonly property string gtkColorsPath4: Quickshell.env("HOME") + "/.config/gtk-4.0/colors.css"
    readonly property string qtColorSchemePath: Quickshell.env("HOME") + "/.local/share/color-schemes/Orvix.colors"
    readonly property string matugenConfigPath: Paths.dots + "/.data/matugen/config.toml"
    readonly property string matugenCachePath: Quickshell.env("HOME") + "/.cache/matugen"

    property string currentThemeName: getState("theme.name", "tokyonight")
    property string themeMode: getState("theme.mode", "preset") // "preset" | "auto" | "omarchy"
    // The mode picked in Settings: the theme list shows its themes
    property string colorScheme: getState("theme.scheme", "dark") // "dark" | "light"
    readonly property bool isAutoMode: themeMode === "auto"
    // Orvix follows the active Omarchy theme (read-only; Omarchy owns it)
    readonly property bool isOmarchyMode: themeMode === "omarchy"
    readonly property bool omarchyAvailable: OmarchyService.available
    // Variant of the preset on screen. GTK and Qt follow it, not
    // colorScheme: picking Light on a theme without a light version keeps
    // it until a light theme is chosen
    property string appliedVariant: "dark"
    readonly property string appliedScheme: isAutoMode ? colorScheme : appliedVariant
    readonly property bool isDarkMode: appliedScheme === "dark"
    // The current preset has no version for the picked mode
    readonly property string schemeHint: {
        if (isOmarchyMode)
            return "";
        if (isAutoMode || appliedVariant === colorScheme)
            return "";
        const name = themePreviews[currentThemeName]?.name ?? currentThemeName;
        return colorScheme === "dark" ? I18n.tr("%1 has no dark version: pick a dark theme", name) : I18n.tr("%1 has no light version: pick a light theme", name);
    }
    readonly property string gtkThemeName: isDarkMode ? "adw-gtk3-dark" : "adw-gtk3"
    // Whether Orvix may change the desktop's GTK/Qt look. On by default, as
    // before; Settings › Appearance › GTK & Qt can turn each part off
    readonly property bool applyGtkTheme: getState("theme.applyGtkTheme", true)
    readonly property bool applyGtkColors: getState("theme.applyGtkColors", true)
    readonly property bool applyQtColors: getState("theme.applyQtColors", true)
    property var availableThemes: []

    // Themes filtered by current color scheme (dark shows dark, light shows light)
    readonly property var displayThemes: {
        var result = [];
        var themes = availableThemes;
        var previews = themePreviews;
        var scheme = colorScheme;
        for (var i = 0; i < themes.length; i++) {
            var name = themes[i];
            var preview = previews[name];
            var variant = (preview && preview.variant) ? preview.variant : "dark";
            if (variant === scheme)
                result.push(name);
        }
        // If no themes match (e.g. no light presets yet), show all
        if (result.length === 0)
            return themes;
        return result;
    }

    // Preview data: { "themeName": { name, palette: { background, accent, ... } } }
    property var themePreviews: ({})

    // Omarchy's themes, for the grid while the Omarchy source is picked:
    // [{ id, name, palette, accent, variant, current }]. Read from each
    // theme's colors.toml through OmarchyService, so it needs no shell and
    // nothing is written to the theme. Empty when Omarchy isn't there.
    readonly property var omarchyThemes: {
        if (!omarchyAvailable)
            return [];
        const current = OmarchyService.themeId;
        return (OmarchyService.themes ?? []).map(t => {
            const colors = OmarchyService.colorsOf(t.id);
            return {
                id: t.id,
                name: t.name,
                // A few colors for the tile: the theme's own background and
                // accent, so the swatch reads like that theme
                palette: {
                    background: colors.background || "#1a1b26",
                    accent: colors.accent || colors.blue || "#7aa2f7",
                    text: colors.foreground || "#c0caf5"
                },
                variant: colors.mode === "light" ? "light" : "dark",
                current: t.id === current
            };
        });
    }

    // The palette is the single source of truth for all colors
    // Config.qml reads from here. It starts with the last applied one (see
    // lastPalette); these are the colors of a first start
    property var palette: ({
            "background": "#1a1b26",
            "surface0": "#24283b",
            "surface1": "#292e42",
            "surface2": "#414868",
            "surface3": "#565f89",
            "text": "#c0caf5",
            "textReverse": "#1a1b26",
            "subtext": "#a9b1d6",
            "subtextReverse": "#565f89",
            "accent": "#7aa2f7",
            "success": "#9ece6a",
            "warning": "#e0af68",
            "error": "#f7768e",
            "muted": "#545c7e",
            "greyBlue": "#283457",
            "blueDark": "#16161e"
        })

    // Helper for Config.qml to read palette with fallback
    function color(key, fallback) {
        return palette[key] ?? fallback;
    }

    // ========================================================================
    // INITIALIZATION
    // ========================================================================

    // The Neovim file holds the last applied palette: read before the first
    // frame, so a shell starting with another theme doesn't show the colors
    // above until the theme's file is read
    FileView {
        id: lastPalette
        path: root.nvimPalettePath
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        try {
            const last = JSON.parse(lastPalette.text()).palette;
            if (last?.background)
                palette = last;
        } catch (e) {}
        lastPalette.path = "";
        listThemes();
    }

    // Load theme when state is ready
    Connections {
        target: StateService
        function onStateLoaded(keys) {
            // Writes to other keys (brightness, bar...) leave the theme be; in
            // auto mode the wallpaper drives it
            if (!keys.includes("theme") && !(root.isAutoMode && keys.includes("wallpaper")))
                return;
            root.themeMode = root.getState("theme.mode", "preset");
            root.colorScheme = root.getState("theme.scheme", "dark");
            // currentThemeName changes when the theme is applied, so a new
            // name from outside (orvix theme set) counts as another theme
            const name = root.getState("theme.name", "tokyonight");
            if (root.isOmarchyMode) {
                root.applyOmarchyTheme(true);
            } else if (root.isAutoMode) {
                const wallpaper = root.getState("wallpaper.current", "");
                if (wallpaper) {
                    root.runMatugen(wallpaper);
                } else {
                    // Fallback to preset if no wallpaper
                    root.applyTheme(name, true);
                }
            } else {
                // Reloading the current preset keeps the user's opacity
                // and wallpaper
                root.applyTheme(name, true);
            }
        }
    }

    // ========================================================================
    // PUBLIC API
    // ========================================================================

    // restoring: re-applying the saved preset (startup, state reload) must
    // not replace the opacity or the wallpaper the user picked; only
    // switching presets does
    function applyTheme(themeName, restoring = false) {
        console.log("[Theme] Loading theme:", themeName);
        loadThemeProc.run(["cat", themesDir + "/" + themeName + ".json"], {
            themeName,
            restoring
        });
    }

    function setPresetMode(themeName) {
        console.log("[Theme] Switching to preset mode:", themeName);
        themeMode = "preset";
        setState("theme.mode", "preset");
        applyTheme(themeName);
    }

    function setAutoMode() {
        console.log("[Theme] Switching to auto (Material You) mode");
        themeMode = "auto";
        setState("theme.mode", "auto");
        const wallpaper = getState("wallpaper.current", "");
        if (wallpaper) {
            runMatugen(wallpaper);
        } else {
            // No wallpaper to sample: keep what we have, applied everywhere,
            // rather than the previous mode's terminal and editor colours
            applyPaletteEverywhere(palette);
        }
    }

    // Re-applies the given palette to every app that takes one. Used when
    // matugen cannot run (a missing wallpaper, a broken image): the shell's
    // own colours are already this palette, and the apps have to catch up
    // with it instead of keeping another theme's.
    function applyPaletteEverywhere(pal) {
        if (!pal)
            return;
        console.log("[Theme] Applying the current palette without matugen");
        _applyHyprland(_hyprlandFromPalette(pal));
        _applyKitty(_terminalFromPalette(pal));
        _applyGhostty(_terminalFromPalette(pal));
        _applyNeovim(pal, _terminalFromPalette(pal));
        ZenService.applyPalette(pal);
        _applyGtkFromPalette(pal);
        _applyGtkThemeSwitch();
        _applyQtFromPalette(pal);
    }

    // A palette -> the terminal block _applyKitty expects. Matugen supplies
    // its own; this is the fallback, so a terminal is never left on another
    // theme's colours.
    //
    // Only the keys every palette has are used (accent, background, surface0-3,
    // text, subtext, success, warning, error, muted): matugen's palette and the
    // presets carry the same set, and inventing magenta/cyan/orange would put
    // `undefined` in the file.
    function _terminalFromPalette(pal) {
        const bg = pal.background || "#1a1b26";
        const fg = pal.text || "#c0caf5";
        const dim = pal.subtext || fg;
        const accent = pal.accent || "#7aa2f7";
        const red = pal.error || "#f7768e";
        const green = pal.success || "#9ece6a";
        const yellow = pal.warning || "#e0af68";
        const muted = pal.muted || pal.surface3 || dim;
        const surface1 = pal.surface1 || pal.surface0 || bg;
        const surface2 = pal.surface2 || surface1;
        const surface3 = pal.surface3 || surface2;
        return {
            background: bg,
            foreground: fg,
            selectionBackground: surface2,
            selectionForeground: fg,
            urlColor: accent,
            cursor: accent,
            cursorTextColor: bg,
            activeTabBackground: surface1,
            activeTabForeground: fg,
            inactiveTabBackground: bg,
            inactiveTabForeground: dim,
            activeBorderColor: accent,
            inactiveBorderColor: surface2,
            // Normal, then bright: the eight ANSI colours each. There are no
            // distinct blue/magenta/cyan in this palette, so they step through
            // it rather than being invented.
            color0: surface1,
            color1: red,
            color2: green,
            color3: yellow,
            color4: accent,
            color5: pal.muted || accent,
            color6: pal.greyBlue || accent,
            color7: dim,
            color8: surface3,
            color9: red,
            color10: green,
            color11: yellow,
            color12: accent,
            color13: pal.muted || accent,
            color14: pal.greyBlue || accent,
            color15: fg,
            color16: pal.blueDark || yellow,
            color17: muted
        };
    }

    // A palette -> Hyprland border colours, for the same fallback
    function _hyprlandFromPalette(pal) {
        return {
            activeBorder: pal.accent || "#7aa2f7",
            inactiveBorder: pal.surface2 || pal.surface1 || "#292e42"
        };
    }

    // Applies the current palette to GTK and Qt again (after the user turns
    // one of the switches on, or changes the GTK theme by hand)
    function applyAppColors() {
        _applyGtkFromPalette(palette);
        _applyGtkThemeSwitch();
        _applyQtFromPalette(palette);
    }

    // Follow the active Omarchy theme. The palette, Kitty, Ghostty, Neovim,
    // GTK, Qt and Hyprland borders come from Omarchy's colors.toml; the
    // wallpaper and opacity stay the user's (Omarchy has its own wallpaper
    // handling).
    function setOmarchyMode() {
        if (!OmarchyService.available) {
            console.log("[Theme] Omarchy theme not available");
            return;
        }
        console.log("[Theme] Switching to Omarchy theme mode");
        themeMode = "omarchy";
        setState("theme.mode", "omarchy");
        applyOmarchyTheme();
    }

    function applyOmarchyTheme(restoring = false) {
        const data = OmarchyService.themeData;
        if (!data) {
            // Omarchy was removed while selected: keep the last palette and
            // let the user pick another mode in Settings
            console.log("[Theme] Omarchy theme unavailable");
            return;
        }
        root.palette = data.palette;
        root.appliedVariant = data.variant;
        _applyHyprland(data.hyprland);
        _applyKitty(data.terminal);
        // Omarchy writes ghostty.conf itself: clear Orvix's file so that
        // include is the one Ghostty shows, and it stays live even when
        // Orvix isn't running
        _applyGhostty(data.terminal, true);
        _applyNeovim(data.palette, data.terminal);
        ZenService.applyPalette(data.palette);
        _applyGtkFromPalette(data.palette);
        _applyGtkThemeSwitch();
        _applyQtFromPalette(data.palette);
        console.log("[Theme] Omarchy theme applied:", data.name || "Omarchy");
    }

    // Omarchy rewrote its theme: follow it live while selected
    Connections {
        target: OmarchyService

        function onThemeChanged() {
            if (root.isOmarchyMode)
                root.applyOmarchyTheme(true);
        }
    }

    function setColorScheme(scheme: string) {
        console.log("[Theme] Switching color scheme to:", scheme);
        colorScheme = scheme;
        setState("theme.scheme", scheme);

        if (isAutoMode) {
            _applyGtkThemeSwitch();
            const wallpaper = getState("wallpaper.current", "");
            if (wallpaper)
                runMatugen(wallpaper);
            return;
        }
        // The current preset's version for that mode, if it has one;
        // otherwise it stays (schemeHint) until a theme of that mode is picked
        const pair = pairFor(currentThemeName, scheme);
        if (pair && pair !== currentThemeName)
            applyTheme(pair);
    }

    // The theme for `scheme` that goes with `name`: itself, the pair it
    // names, or the theme that names it (dark themes don't name their light
    // version; the light ones name their dark one). "" when there's none
    function pairFor(name: string, scheme: string): string {
        const previews = themePreviews;
        const variant = t => previews[t]?.variant ?? "dark";
        const preview = previews[name];
        if (!preview)
            return "";
        if (variant(name) === scheme)
            return name;
        const named = scheme === "light" ? preview.lightPair : preview.darkPair;
        if (named && previews[named])
            return named;
        return availableThemes.find(t => variant(t) === scheme && (scheme === "light" ? previews[t].darkPair : previews[t].lightPair) === name) ?? "";
    }

    // A video wallpaper gives its colors through its poster
    // (wallpaper-poster.sh prints an image's own path)
    function runMatugen(wallpaperPath: string) {
        console.log("[Theme] Running matugen on:", wallpaperPath);
        matugenProc.run(["sh", "-c", "still=$(\"$1\" \"$2\") || exit 1; shift 2; exec matugen image \"$still\" \"$@\"", "sh", WallpaperService.posterScript, wallpaperPath, "-m", colorScheme, "-c", matugenConfigPath, "--prefer", "saturation"]);
    }

    function listThemes() {
        listThemesProc.run(listThemesProc.command);
    }

    function loadPreviews() {
        previewProc.run(previewProc.command);
    }

    // Writes ~/.local/themes/<slug>.json (atomically) and refreshes the list;
    // apply switches to it once written. wallpaperFrom: an image copied first
    // to ~/.local/wallpapers/<data.wallpaper>. Emits themeSaved or
    // themeSaveFailed
    function saveTheme(slug: string, data, apply: bool, wallpaperFrom = "") {
        const path = themesDir + "/" + slug + ".json";
        const wallpaperTo = wallpaperFrom !== "" && data.wallpaper ? wallpaperDir + "/" + data.wallpaper : "";
        saveThemeComponent.createObject(root, {
            slug: slug,
            apply: apply,
            command: ["sh", "-c", "if [ -n \"$3\" ]; then mkdir -p \"$(dirname \"$4\")\" && { [ \"$3\" -ef \"$4\" ] || cp -f \"$3\" \"$4\"; } || exit 1; fi; " + "mkdir -p \"$(dirname \"$2\")\" && printf '%s\\n' \"$1\" > \"$2.tmp\" && mv \"$2.tmp\" \"$2\"", "sh", JSON.stringify(data, null, 2), path, wallpaperFrom, wallpaperTo]
        });
    }

    // Removes a custom theme and its wallpaper folder. The theme in use can't
    // be deleted (switch first)
    function deleteTheme(slug: string) {
        const preview = themePreviews[slug];
        if (!preview || !preview.custom || slug === currentThemeName)
            return;
        deleteThemeProc.run(["sh", "-c", "rm -f -- \"$1\" && rm -rf -- \"$2\"", "sh", themesDir + "/" + slug + ".json", wallpaperDir + "/themes/" + slug]);
    }

    signal themeSaved(string slug)
    signal themeSaveFailed(string slug)

    // ========================================================================
    // INTERNAL
    // ========================================================================

    function _applyThemeData(themeName, data, restoring) {
        // 1. Update palette (triggers Config.qml rebinding)
        if (data.palette) {
            root.palette = data.palette;
        }

        // 2. Update opacity in StateService (user preference, not theme-owned)
        if (!restoring && data.opacity && data.opacity.background !== undefined) {
            setState("opacity.background", data.opacity.background);
        }

        // 3. Save theme name. Another theme chosen (not the saved one
        // reloaded) brings the list's mode along with its variant
        const variant = data.variant || "dark";
        if (themeName !== currentThemeName && variant !== colorScheme) {
            colorScheme = variant;
            setState("theme.scheme", variant);
        }
        appliedVariant = variant;
        currentThemeName = themeName;
        setState("theme.name", themeName);

        // 4. Apply to Hyprland
        _applyHyprland(data.hyprland);

        // 5. Apply to Kitty
        _applyKitty(data.terminal);

        // 5b. Apply to Ghostty
        _applyGhostty(data.terminal);

        // 6. Apply to Neovim
        _applyNeovim(data.palette, data.terminal);

        // 7. Zen Browser (profiles where it's on in Settings)
        ZenService.applyPalette(data.palette);

        // 8. Apply theme wallpaper
        if (!restoring)
            _applyWallpaper(data.wallpaper);

        // 9. Apply GTK/Qt colors from palette
        _applyGtkFromPalette(data.palette);
        _applyGtkThemeSwitch();
        _applyQtFromPalette(data.palette);

        console.log("[Theme] Theme applied:", data.name || themeName);
    }

    // Last colors sent to Hyprland; they only live in memory (hyprctl eval),
    // so they are sent again whenever Hyprland reloads its config
    property var _hyprColors: null
    // Border fade in progress, like the shell's (Config.themeTransition): the
    // colors it started from and when (ms)
    property var _hyprFadeFrom: null
    property real _hyprFadeStart: 0
    property int _hyprFadeDuration: 0
    readonly property var _hyprKeys: ["activeBorder", "inactiveBorder", "shadowColor"]

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded" && root._hyprColors)
                root._applyHyprland(root._hyprColors, false);
        }
    }

    // "rrggbbaa" (Hyprland) <-> QML color
    function _hyprToColor(hex: string): color {
        return Qt.color("#" + hex.substr(6, 2) + hex.substr(0, 6));
    }

    function _hyprHex(rgba): string {
        return rgba.map(v => {
            const n = Math.round(Math.min(1, Math.max(0, v)) * 255);
            return (n < 16 ? "0" : "") + n.toString(16);
        }).join("");
    }

    // Colors Hyprland shows now: mid-fade, the point the fade has reached
    function _hyprShown() {
        if (!_hyprFadeFrom || !_hyprColors)
            return _hyprColors;
        const t = (Date.now() - _hyprFadeStart) / _hyprFadeDuration;
        if (t >= 1)
            return _hyprColors;
        const shown = {};
        for (const key of _hyprKeys) {
            if (_hyprColors[key] && _hyprFadeFrom[key])
                shown[key] = _hyprHex(ThemeGenerator.mixOklab(ThemeGenerator.colorToOklab(_hyprToColor(_hyprFadeFrom[key])), ThemeGenerator.colorToOklab(_hyprToColor(_hyprColors[key])), _ease(t)));
            else
                shown[key] = _hyprColors[key];
        }
        return shown;
    }

    // Easing.InOutQuad, as the shell's fade
    function _ease(t: real): real {
        return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
    }

    function _hyprLua(colors): string {
        const parts = [];
        const col = [];
        if (colors.activeBorder)
            col.push("active_border = \"rgba(" + colors.activeBorder + ")\"");
        if (colors.inactiveBorder)
            col.push("inactive_border = \"rgba(" + colors.inactiveBorder + ")\"");
        if (col.length > 0)
            parts.push("general = { col = { " + col.join(", ") + " } }");
        if (colors.shadowColor)
            parts.push("decoration = { shadow = { color = \"rgba(" + colors.shadowColor + ")\" } }");
        return "{ " + parts.join(", ") + " }";
    }

    // animate: fade from the colors shown now (theme switches); the first
    // colors since the shell started and config reloads apply at once. The
    // fade runs inside Hyprland (an hl.timer stepping through precomputed
    // colors), so it costs one hyprctl call
    function _applyHyprland(hyprColors, animate = true) {
        if (!hyprColors || !_hyprKeys.some(k => hyprColors[k]))
            return;
        const from = _hyprShown();
        const same = from && _hyprKeys.every(k => String(from[k] ?? "").toLowerCase() === String(hyprColors[k] ?? "").toLowerCase());
        // Re-applying the current theme (state reloads) mustn't cut a fade
        if (animate && same)
            return;
        _hyprColors = hyprColors;

        const steps = [];
        if (animate && from && Config.themeTransition) {
            _hyprFadeFrom = from;
            _hyprFadeStart = Date.now();
            _hyprFadeDuration = Config.themeTransitionDuration;
            const count = Math.max(1, Math.round(_hyprFadeDuration / 30));
            for (let i = 1; i <= count; i++) {
                const step = {};
                for (const key of _hyprKeys) {
                    if (hyprColors[key] && from[key])
                        step[key] = _hyprHex(ThemeGenerator.mixOklab(ThemeGenerator.colorToOklab(_hyprToColor(from[key])), ThemeGenerator.colorToOklab(_hyprToColor(hyprColors[key])), _ease(i / count)));
                    else
                        step[key] = hyprColors[key];
                }
                steps.push(_hyprLua(step));
            }
        } else {
            _hyprFadeFrom = null;
        }

        let lua = "if orvix_border_fade then orvix_border_fade:set_enabled(false); orvix_border_fade = nil end ";
        if (steps.length > 1) {
            lua += "local steps = { " + steps.join(", ") + " } local i = 0 " + "orvix_border_fade = hl.timer(function() i = i + 1 hl.config(steps[i]) " + "if i >= #steps and orvix_border_fade then orvix_border_fade:set_enabled(false); orvix_border_fade = nil end end, " + "{ timeout = " + Math.round(_hyprFadeDuration / steps.length) + ", type = \"repeat\" })";
        } else {
            lua += "hl.config(" + _hyprLua(hyprColors) + ")";
        }
        Quickshell.execDetached(["hyprctl", "eval", lua]);
    }

    function _applyKitty(terminal) {
        if (!terminal)
            return;

        const lines = ["# vim:ft=kitty", "# Auto-generated by ThemeService - Do not edit manually", "", "background " + terminal.background, "foreground " + terminal.foreground, "selection_background " + terminal.selectionBackground, "selection_foreground " + terminal.selectionForeground, "url_color " + terminal.urlColor, "cursor " + terminal.cursor, "cursor_text_color " + terminal.cursorTextColor, "", "# Tabs", "active_tab_background " + terminal.activeTabBackground, "active_tab_foreground " + terminal.activeTabForeground, "inactive_tab_background " + terminal.inactiveTabBackground, "inactive_tab_foreground " + terminal.inactiveTabForeground, "", "# Windows", "active_border_color " + terminal.activeBorderColor, "inactive_border_color " + terminal.inactiveBorderColor, "", "# Normal", "color0 " + terminal.color0, "color1 " + terminal.color1, "color2 " + terminal.color2, "color3 " + terminal.color3, "color4 " + terminal.color4, "color5 " + terminal.color5, "color6 " + terminal.color6, "color7 " + terminal.color7, "", "# Bright", "color8  " + terminal.color8, "color9  " + terminal.color9, "color10 " + terminal.color10, "color11 " + terminal.color11, "color12 " + terminal.color12, "color13 " + terminal.color13, "color14 " + terminal.color14, "color15 " + terminal.color15, "", "# Extended", "color16 " + terminal.color16, "color17 " + terminal.color17, ""];

        const content = lines.join("\n");

        // Written to a temporary file and handed to kitty-apply.sh, which
        // copies it into place and pushes the colours into every running
        // kitty through its remote-control socket. SIGUSR1 is not used: this
        // kitty build does not install a handler for it, so it changed the
        // file and left the open windows as they were.
        kittyProc.run(["bash", "-c", "tmp=$(mktemp) && cat > \"$tmp\" << 'THEME_EOF'\n" + content + "THEME_EOF\n" + "bash " + shellEscape(kittyApplyScript) + " \"$tmp\"; rc=$?; rm -f \"$tmp\"; exit $rc"]);
    }

    // Ghostty takes its colours as `key = value` and `palette = N=#...`.
    // In Omarchy mode omarchy=true: Omarchy writes its own ghostty.conf,
    // which Ghostty includes before Orvix's file, so removing Orvix's file
    // lets that theme show (and keep following Omarchy on its own).
    function _applyGhostty(terminal, omarchy = false) {
        if (!terminal)
            return;

        if (omarchy) {
            ghosttyProc.run(["bash", shellEscape(ghosttyApplyScript), "--clear"]);
            return;
        }

        const lines = ["# Auto-generated by ThemeService - Do not edit manually", "", "background = " + terminal.background, "foreground = " + terminal.foreground, "cursor-color = " + terminal.cursor, "cursor-text = " + terminal.cursorTextColor, "selection-background = " + terminal.selectionBackground, "selection-foreground = " + terminal.selectionForeground, ""];
        for (let i = 0; i <= 15; i++)
            lines.push("palette = " + i + "=" + terminal["color" + i]);
        const content = lines.join("\n");

        ghosttyProc.run(["bash", "-c", "tmp=$(mktemp) && cat > \"$tmp\" << 'THEME_EOF'\n" + content + "\nTHEME_EOF\n" + "bash " + shellEscape(ghosttyApplyScript) + " \"$tmp\"; rc=$?; rm -f \"$tmp\"; exit $rc"]);
    }


    // Writes the theme for the "orvix" colorscheme and reloads it in every
    // running Neovim using it, through its server socket (a config of the
    // user's own may not have it)
    function _applyNeovim(pal, terminal) {
        if (!pal || !terminal)
            return;
        const content = JSON.stringify({
            palette: pal,
            terminal: terminal
        }, null, 2);
        const path = shellEscape(nvimPalettePath);
        const tmp = shellEscape(nvimPalettePath + ".tmp");

        nvimProc.run(["bash", "-c", "mkdir -p \"$(dirname " + path + ")\" && cat > " + tmp + " << 'THEME_EOF'\n" + content + "\nTHEME_EOF\n" + "mv " + tmp + " " + path + " && " + "for sock in /run/user/$(id -u)/nvim.*.0; do " + "  [ -S \"$sock\" ] && nvim --server \"$sock\" --remote-send '<Cmd>if get(g:, \"colors_name\", \"\") ==# \"orvix\" | colorscheme orvix | endif<CR>' 2>/dev/null & " + "done; wait"]);
    }

    function _applyWallpaper(wallpaperFile) {
        if (!wallpaperFile || !WallpaperService.dynamicWallpaper)
            return;
        WallpaperService.setWallpaper(wallpaperDir + "/" + wallpaperFile);
    }

    function _applyGtkThemeSwitch() {
        // Settings › GTK & Qt can leave the desktop's GTK theme alone
        if (!applyGtkTheme)
            return;
        const theme = gtkThemeName;
        const scheme = isDarkMode ? "prefer-dark" : "prefer-light";
        // The icon theme's variant follows isDarkMode in IconService
        gtkThemeSwitchProc.run(["bash", "-c", "gsettings set org.gnome.desktop.interface gtk-theme " + shellEscape(theme) + " 2>/dev/null; " + "gsettings set org.gnome.desktop.interface color-scheme " + shellEscape(scheme) + " 2>/dev/null; true"]);
    }

    function _applyGtkFromPalette(pal) {
        if (!pal || !applyGtkColors)
            return;

        var lines = [];
        lines.push("/* Auto-generated by ThemeService - Do not edit manually */");
        lines.push("");
        lines.push("@define-color accent_bg_color " + pal.accent + ";");
        lines.push("@define-color accent_color " + pal.accent + ";");
        lines.push("@define-color accent_fg_color " + pal.textReverse + ";");
        lines.push("");
        lines.push("@define-color window_bg_color " + pal.background + ";");
        lines.push("@define-color window_fg_color " + pal.text + ";");
        lines.push("");
        lines.push("@define-color view_bg_color " + pal.background + ";");
        lines.push("@define-color view_fg_color " + pal.text + ";");
        lines.push("");
        lines.push("@define-color headerbar_bg_color " + pal.surface0 + ";");
        lines.push("@define-color headerbar_fg_color " + pal.subtext + ";");
        lines.push("");
        lines.push("@define-color card_bg_color " + pal.surface0 + ";");
        lines.push("@define-color card_fg_color " + pal.text + ";");
        lines.push("");
        lines.push("@define-color popover_bg_color " + pal.surface0 + ";");
        lines.push("@define-color popover_fg_color " + pal.text + ";");
        lines.push("");
        lines.push("@define-color dialog_bg_color " + pal.surface1 + ";");
        lines.push("@define-color dialog_fg_color " + pal.text + ";");
        lines.push("");
        lines.push("@define-color sidebar_bg_color " + pal.surface1 + ";");
        lines.push("@define-color sidebar_fg_color " + pal.subtext + ";");
        lines.push("");
        lines.push("@define-color destructive_bg_color " + pal.error + ";");
        lines.push("@define-color destructive_fg_color " + pal.textReverse + ";");
        lines.push("@define-color destructive_color " + pal.error + ";");
        lines.push("");
        lines.push("@define-color error_bg_color " + pal.error + ";");
        lines.push("@define-color error_fg_color " + pal.textReverse + ";");
        lines.push("@define-color error_color " + pal.error + ";");
        lines.push("");
        lines.push("@define-color success_bg_color " + pal.success + ";");
        lines.push("@define-color success_fg_color " + pal.textReverse + ";");
        lines.push("@define-color success_color " + pal.success + ";");
        lines.push("");
        lines.push("@define-color warning_bg_color " + pal.warning + ";");
        lines.push("@define-color warning_fg_color " + pal.textReverse + ";");
        lines.push("@define-color warning_color " + pal.warning + ";");
        lines.push("");

        const content = lines.join("\n");

        // The folders don't exist without the theming package's stow
        gtkProc.run(["bash", "-c", "mkdir -p \"$(dirname " + shellEscape(gtkColorsPath3) + ")\" \"$(dirname " + shellEscape(gtkColorsPath4) + ")\" && " + "cat > " + shellEscape(gtkColorsPath3) + " << 'GTK_EOF'\n" + content + "GTK_EOF\n" + "cp " + shellEscape(gtkColorsPath3) + " " + shellEscape(gtkColorsPath4)]);
    }

    function _applyQtFromPalette(pal) {
        if (!pal || !applyQtColors)
            return;

        const bg = hexToRgb(pal.background);
        const s0 = hexToRgb(pal.surface0);
        const s1 = hexToRgb(pal.surface1);
        const fg = hexToRgb(pal.text);
        const ac = hexToRgb(pal.accent);
        const fgR = hexToRgb(pal.textReverse);
        const sub = hexToRgb(pal.subtext);
        const err = hexToRgb(pal.error);
        const warn = hexToRgb(pal.warning);
        const succ = hexToRgb(pal.success);
        const muted = hexToRgb(pal.muted);

        var lines = [];
        lines.push("[ColorEffects:Disabled]");
        lines.push("Color=56,56,56");
        lines.push("ColorAmount=0");
        lines.push("ColorEffect=0");
        lines.push("ContrastAmount=0.65");
        lines.push("ContrastEffect=1");
        lines.push("IntensityAmount=0.1");
        lines.push("IntensityEffect=2");
        lines.push("");
        lines.push("[ColorEffects:Inactive]");
        lines.push("ChangeSelectionColor=true");
        lines.push("Color=112,111,110");
        lines.push("ColorAmount=0.025");
        lines.push("ColorEffect=2");
        lines.push("ContrastAmount=0.1");
        lines.push("ContrastEffect=2");
        lines.push("Enable=false");
        lines.push("IntensityAmount=0");
        lines.push("IntensityEffect=0");
        lines.push("");

        // Helper: generate a color group
        var groups = ["Button", "Header", "Selection", "Tooltip", "View", "Window"];
        for (var i = 0; i < groups.length; i++) {
            var group = groups[i];
            var bgColor = s0;
            var fgColor = fg;

            if (group === "View")
                bgColor = bg;
            if (group === "Header")
                bgColor = s1;
            if (group === "Window")
                bgColor = s0;
            if (group === "Tooltip")
                bgColor = s0;
            if (group === "Selection") {
                bgColor = ac;
                fgColor = fgR;
            }

            // On the accent background of a selection the accent itself
            // (links, active items) wouldn't show: text color there
            const selection = group === "Selection";

            lines.push("[Colors:" + group + "]");
            lines.push("BackgroundAlternate=" + (selection ? ac : s1));
            lines.push("BackgroundNormal=" + bgColor);
            lines.push("DecorationFocus=" + ac);
            lines.push("DecorationHover=" + ac);
            lines.push("ForegroundActive=" + (selection ? fgR : ac));
            lines.push("ForegroundInactive=" + (selection ? fgR : muted));
            lines.push("ForegroundLink=" + (selection ? fgR : ac));
            lines.push("ForegroundNegative=" + err);
            lines.push("ForegroundNeutral=" + warn);
            lines.push("ForegroundNormal=" + fgColor);
            lines.push("ForegroundPositive=" + succ);
            lines.push("ForegroundVisited=" + (selection ? fgR : sub));
            lines.push("");
        }

        // Sets KColorScheme fills from Breeze when they are missing
        var extra = [{
            name: "Complementary",
            bgColor: s1,
            fgColor: fg
        }, {
            name: "Header][Inactive",
            bgColor: s1,
            fgColor: fg
        }];
        for (var e = 0; e < extra.length; e++) {
            lines.push("[Colors:" + extra[e].name + "]");
            lines.push("BackgroundAlternate=" + s0);
            lines.push("BackgroundNormal=" + extra[e].bgColor);
            lines.push("DecorationFocus=" + ac);
            lines.push("DecorationHover=" + ac);
            lines.push("ForegroundActive=" + ac);
            lines.push("ForegroundInactive=" + muted);
            lines.push("ForegroundLink=" + ac);
            lines.push("ForegroundNegative=" + err);
            lines.push("ForegroundNeutral=" + warn);
            lines.push("ForegroundNormal=" + extra[e].fgColor);
            lines.push("ForegroundPositive=" + succ);
            lines.push("ForegroundVisited=" + sub);
            lines.push("");
        }

        lines.push("[General]");
        lines.push("ColorScheme=Orvix");
        lines.push("Name=Orvix");
        lines.push("shadeSortColumn=true");
        lines.push("");
        lines.push("[KDE]");
        lines.push("contrast=4");
        lines.push("");
        lines.push("[WM]");
        lines.push("activeBackground=" + s0);
        lines.push("activeBlend=" + bg);
        lines.push("activeForeground=" + fg);
        lines.push("inactiveBackground=" + bg);
        lines.push("inactiveBlend=" + bg);
        lines.push("inactiveForeground=" + muted);
        lines.push("");

        const content = lines.join("\n");
        // qt6ct/qt5ct format. Official qt6ct cannot read the KDE file above.
        const qtct = ThemeGenerator.qtctScheme(pal);
        const home = Quickshell.env("HOME");
        const qtct6 = home + "/.config/qt6ct/colors/Orvix.conf";
        const qtct5 = home + "/.config/qt5ct/colors/Orvix.conf";
        const conf6 = home + "/.config/qt6ct/qt6ct.conf";
        const conf5 = home + "/.config/qt5ct/qt5ct.conf";
        // KDE apps choose a scheme by name; writing Orvix.colors alone leaves
        // them on BreezeLight. Select it for KDE apps as well.
        const applyKdeScheme = "if command -v plasma-apply-colorscheme >/dev/null 2>&1; then plasma-apply-colorscheme Orvix; elif command -v kwriteconfig6 >/dev/null 2>&1; then kwriteconfig6 --file kdeglobals --group General --key ColorScheme Orvix; fi";

        // qt6ct-kde (the theming package) understands Orvix.colors and tells
        // KDE apps to use it. Plain qt6ct only understands Orvix.conf, and
        // leaves every Qt window on the light palette when pointed at .colors.
        function pointAt(conf, scheme) {
            return "if [ -f " + shellEscape(conf) + " ]; then " + "if grep -q '^color_scheme_path=' " + shellEscape(conf) + "; then sed -i " + shellEscape("s|^color_scheme_path=.*|color_scheme_path=" + scheme + "|") + " " + shellEscape(conf) + "; " + "else sed -i " + shellEscape("/^\\[Appearance\\]/a color_scheme_path=" + scheme) + " " + shellEscape(conf) + "; fi; " + "if grep -q '^custom_palette=' " + shellEscape(conf) + "; then sed -i 's|^custom_palette=.*|custom_palette=true|' " + shellEscape(conf) + "; fi; " + "touch " + shellEscape(conf) + "; fi"; // i18n-ignore
        }

        qtProc.run(["bash", "-c", "mkdir -p " + shellEscape(home + "/.local/share/color-schemes") + " " + shellEscape(home + "/.config/qt6ct/colors") + " " + shellEscape(home + "/.config/qt5ct/colors") + " && " + "cat > " + shellEscape(qtColorSchemePath) + " << 'QT_EOF'\n" + content + "QT_EOF\n" + "cat > " + shellEscape(qtct6) + " << 'QTCT_EOF'\n" + qtct + "QTCT_EOF\n" + "cp " + shellEscape(qtct6) + " " + shellEscape(qtct5) + " && " + "if ldd /usr/lib/libqt6ct-common.so 2>/dev/null | grep -q KF6ColorScheme; then " + pointAt(conf6, "~/.local/share/color-schemes/Orvix.colors") + "; " + "else " + pointAt(conf6, "~/.config/qt6ct/colors/Orvix.conf") + "; fi; " + pointAt(conf5, "~/.config/qt5ct/colors/Orvix.conf") + " && " + applyKdeScheme]);
    }

    function hexToRgb(hex: string): string {
        if (!hex || hex.length < 7)
            return "0,0,0";
        var r = parseInt(hex.substring(1, 3), 16);
        var g = parseInt(hex.substring(3, 5), 16);
        var b = parseInt(hex.substring(5, 7), 16);
        return r + "," + g + "," + b;
    }

    function _loadAndApplyHyprlandColors() {
        loadHyprColorsProc.run(["cat", matugenCachePath + "/hyprland-colors.json"]);
    }

    function shellEscape(str) {
        return "'" + str.replace(/'/g, "'\\''") + "'";
    }

    // ========================================================================
    // PROCESSES
    // ========================================================================

    QueuedProcess {
        id: loadThemeProc
        property string _buffer: ""
        onStarted: _buffer = ""

        stdout: SplitParser {
            onRead: data => loadThemeProc._buffer += data + "\n"
        }

        stderr: SplitParser {
            onRead: data => console.error("[Theme] " + data)
        }

        onExited: exitCode => {
            // Another theme was asked for meanwhile: only that one is applied
            if (superseded)
                return;
            if (exitCode === 0) {
                try {
                    const data = JSON.parse(_buffer.trim());
                    root._applyThemeData(request.themeName, data, request.restoring);
                } catch (e) {
                    console.error("[Theme] Failed to parse theme:", e);
                }
            } else {
                console.error("[Theme] Theme file not found:", request.themeName);
            }
        }
    }

    QueuedProcess {
        id: listThemesProc
        onStarted: _collected = []
        command: ["bash", "-c", "ls -1 '" + root.themesDir + "'/*.json 2>/dev/null | sed 's|.*/||;s|\\.json$||' | sort"]
        property var _collected: []

        stdout: SplitParser {
            onRead: data => {
                const name = data.trim();
                if (name)
                    listThemesProc._collected.push(name);
            }
        }

        onExited: {
            root.availableThemes = listThemesProc._collected;
            console.log("[Theme] Available themes:", root.availableThemes.join(", "));
            root.loadPreviews();
        }
    }

    // Load all theme JSONs to extract preview palettes
    QueuedProcess {
        id: previewProc
        onStarted: _buffer = ""
        command: ["bash", "-c", "for f in '" + root.themesDir + "'/*.json; do echo \"---THEME_NAME:$(basename \"$f\" .json)---\"; cat \"$f\"; echo '---THEME_SEP---'; done"]
        property string _buffer: ""

        stdout: SplitParser {
            onRead: data => previewProc._buffer += data + "\n"
        }

        onExited: exitCode => {
            if (exitCode !== 0)
                return;

            const chunks = _buffer.split("---THEME_SEP---");
            var previews = {};

            for (var i = 0; i < chunks.length; i++) {
                var chunk = chunks[i].trim();
                if (!chunk)
                    continue;

                // Extract theme name from the header line
                var nameMatch = chunk.indexOf("---THEME_NAME:");
                if (nameMatch === -1)
                    continue;
                var nameEnd = chunk.indexOf("---", nameMatch + 14);
                if (nameEnd === -1)
                    continue;
                var themeName = chunk.substring(nameMatch + 14, nameEnd).trim();
                var jsonStr = chunk.substring(nameEnd + 3).trim();

                try {
                    var data = JSON.parse(jsonStr);
                    previews[themeName] = {
                        name: data.name || themeName,
                        palette: data.palette || {},
                        terminal: data.terminal || {},
                        custom: data.custom === true,
                        seed: data.seed || null,
                        wallpaper: data.wallpaper || "",
                        variant: data.variant || "dark",
                        lightPair: data.lightPair || "",
                        darkPair: data.darkPair || ""
                    };
                } catch (e) {
                    console.error("[Theme] Preview parse error for " + themeName + ":", e);
                }
            }

            root.themePreviews = previews;
            console.log("[Theme] Loaded previews for", Object.keys(previews).length, "themes");
        }
    }

    Component {
        id: saveThemeComponent

        Process {
            id: saveProc

            property string slug
            property bool apply

            running: true
            stderr: SplitParser {
                onRead: data => console.error("[Theme:Save] " + data)
            }
            onExited: exitCode => {
                if (exitCode === 0) {
                    console.log("[Theme] Saved theme:", slug);
                    root.listThemes();
                    // Edits to the theme in use keep the user's opacity and
                    // wallpaper
                    if (apply && slug === root.currentThemeName && !root.isAutoMode)
                        root.applyTheme(slug, true);
                    else if (apply)
                        root.setPresetMode(slug);
                    root.themeSaved(slug);
                } else {
                    root.themeSaveFailed(slug);
                }
                destroy();
            }
        }
    }

    QueuedProcess {
        id: deleteThemeProc
        onExited: exitCode => {
            if (exitCode === 0)
                console.log("[Theme] Theme deleted");
            root.listThemes();
        }
    }

    QueuedProcess {
        id: nvimProc
        stderr: SplitParser {
            onRead: data => console.error("[Theme:Neovim] " + data)
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                return;
            console.log("[Theme] Neovim theme updated");
            // The login screen copies the palette from the same file
            SddmService.paletteWritten();
        }
    }

    QueuedProcess {
        id: kittyProc
        stderr: SplitParser {
            onRead: data => console.error("[Theme:Kitty] " + data)
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("[Theme] Kitty theme updated");
            } else {
                // The file may still be written; say what stopped it rather
                // than leaving the terminal silently on another theme
                console.error("[Theme] Kitty theme not applied (exit " + exitCode + ")");
            }
        }
    }

    QueuedProcess {
        id: ghosttyProc
        stderr: SplitParser {
            onRead: data => console.error("[Theme:Ghostty] " + data)
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                console.log("[Theme] Ghostty theme updated");
            } else {
                console.error("[Theme] Ghostty theme not applied (exit " + exitCode + ")");
            }
        }
    }

    // GTK colors.css writer (preset mode)
    QueuedProcess {
        id: gtkProc
        stderr: SplitParser {
            onRead: data => console.error("[Theme:GTK] " + data)
        }
        onExited: exitCode => {
            if (exitCode === 0)
                console.log("[Theme] GTK colors updated");
        }
    }

    // GTK theme switcher (gsettings)
    QueuedProcess {
        id: gtkThemeSwitchProc
        stderr: SplitParser {
            onRead: data => console.error("[Theme:GtkSwitch] " + data)
        }
        onExited: exitCode => {
            if (exitCode === 0)
                console.log("[Theme] GTK theme switched to:", root.gtkThemeName);
        }
    }

    // Qt .colors writer (preset mode)
    QueuedProcess {
        id: qtProc
        stderr: SplitParser {
            onRead: data => console.error("[Theme:Qt] " + data)
        }
        onExited: exitCode => {
            if (exitCode === 0)
                console.log("[Theme] Qt color scheme updated");
        }
    }

    // Matugen process (auto mode)
    QueuedProcess {
        id: matugenProc
        onStarted: _buffer = ""
        property string _buffer: ""

        stdout: SplitParser {
            onRead: data => matugenProc._buffer += data + "\n"
        }

        stderr: SplitParser {
            onRead: data => console.log("[Theme:Matugen] " + data)
        }

        onExited: exitCode => {
            // A newer wallpaper is queued: its palette is the one to load
            if (superseded)
                return;
            if (exitCode === 0) {
                console.log("[Theme] Matugen finished, loading palette...");
                // Matugen has written its outputs (palette, terminal and hyprland colors)
                // Now load the QuickShell palette JSON
                loadMatugenPaletteProc.run(["cat", root.matugenCachePath + "/quickshell-palette.json"]);
            } else {
                console.error("[Theme] Matugen failed with exit code:", exitCode);
                // Nothing was written for this wallpaper, so kitty, Neovim,
                // GTK and Qt would keep the last mode's colours — switching
                // from Omarchy back to Material You left the terminal on
                // Omarchy's background forever.
                //
                // The palette in memory is no use here: while Omarchy's mode
                // was on, it held Omarchy's colours. Material You's own last
                // palette is still in matugen's cache, so read that and apply
                // it; only if there is none does what is in memory stand.
                loadMatugenPaletteProc.run(["cat", root.matugenCachePath + "/quickshell-palette.json"]);
            }
        }
    }

    // Load matugen-generated palette JSON
    QueuedProcess {
        id: loadMatugenPaletteProc
        onStarted: _buffer = ""
        property string _buffer: ""

        stdout: SplitParser {
            onRead: data => loadMatugenPaletteProc._buffer += data + "\n"
        }

        stderr: SplitParser {
            onRead: data => console.error("[Theme:MatugenPalette] " + data)
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    const pal = JSON.parse(_buffer.trim());
                    root.palette = pal;
                    console.log("[Theme] Auto palette applied");

                    // Load and apply hyprland colors
                    root._loadAndApplyHyprlandColors();

                    // GTK and Qt from the palette, like a preset; kitty and
                    // Neovim from the terminal colors loaded next
                    root._applyGtkFromPalette(pal);
                    root._applyGtkThemeSwitch();
                    root._applyQtFromPalette(pal);
                    loadMatugenTerminalProc.run(["cat", root.matugenCachePath + "/terminal-colors.json"]);

                    ZenService.applyPalette(pal);
                } catch (e) {
                    console.error("[Theme] Failed to parse matugen palette:", e);
                    // No cached palette either: apply the preset the user last
                    // chose, so every app still agrees with the shell
                    root.applyPaletteEverywhere(root.palette);
                }
            }
        }
    }

    // Load the matugen terminal colors for kitty and Neovim
    QueuedProcess {
        id: loadMatugenTerminalProc
        onStarted: _buffer = ""
        property string _buffer: ""

        stdout: SplitParser {
            onRead: data => loadMatugenTerminalProc._buffer += data + "\n"
        }

        stderr: SplitParser {
            onRead: data => console.error("[Theme:MatugenTerminal] " + data)
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    const terminal = JSON.parse(_buffer.trim());
                    root._applyKitty(terminal);
                    root._applyGhostty(terminal);
                    root._applyNeovim(root.palette, terminal);
                } catch (e) {
                    console.error("[Theme] Failed to parse matugen terminal colors:", e);
                }
            }
        }
    }

    // Load hyprland colors from matugen output
    QueuedProcess {
        id: loadHyprColorsProc
        onStarted: _buffer = ""
        property string _buffer: ""

        stdout: SplitParser {
            onRead: data => loadHyprColorsProc._buffer += data + "\n"
        }

        stderr: SplitParser {
            onRead: data => console.error("[Theme:HyprColors] " + data)
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                try {
                    const colors = JSON.parse(_buffer.trim());
                    root._applyHyprland(colors);
                } catch (e) {
                    console.error("[Theme] Failed to parse hyprland colors:", e);
                }
            }
        }
    }

    // The theme mode and what each app was last given, so a round trip can be
    // checked without opening Settings and reading the kitty file by eye.
    // "mode<TAB>kitty-background<TAB>theme-name"
    IpcHandler {
        target: "theme"

        function mode(): string {
            return String(root.themeMode);
        }

        // Switches modes exactly the way the Settings › Theme selector does:
        // these are the same functions its onSelected calls.
        function set(mode: string): string {
            if (mode === "auto") {
                root.setAutoMode();
            } else if (mode === "omarchy") {
                if (!root.omarchyAvailable)
                    return "Omarchy is not available"; // i18n-ignore: an IPC answer, not UI text
                root.setOmarchyMode();
            } else {
                root.setPresetMode(root.currentThemeName);
            }
            return "ok: " + mode;
        }

        // What the shell thinks it is showing, for a script to compare with
        // what kitty actually has
        function palette(): string {
            return [root.themeMode, root.palette.background ?? "", root.palette.accent ?? "", root.currentThemeName ?? ""].join("\t");
        }

        function reapply(): string {
            root.applyPaletteEverywhere(root.palette);
            return "ok";
        }
    }
}
