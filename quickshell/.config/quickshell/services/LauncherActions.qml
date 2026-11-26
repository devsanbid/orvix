pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Shell actions for the launcher's ">" mode. Each item is
// { id, name, comment, glyph, keywords, run, confirm? }; `confirm` asks for a
// second Enter. Toggles name the state they switch to
Singleton {
    id: root

    // Destructive ones count down in the power menu (PowerService.request)
    readonly property var power: PowerService.availableActions.map(a => ({
                id: a.id,
                name: a.name,
                comment: a.comment,
                glyph: a.glyph,
                keywords: a.keywords,
                run: () => PowerService.request(a.id)
            })).concat([
            {
                id: "power-menu",
                name: I18n.tr("Power menu"),
                comment: I18n.tr("Lock, suspend, log out, reboot or shut down"),
                glyph: "\u{f0426}",
                keywords: ["session"],
                run: () => PowerService.show()
            }
        ])

    readonly property var tools: [
        {
            id: "screenshot",
            name: I18n.tr("Take a screenshot"),
            comment: I18n.tr("Select a region, a window or the screen"),
            glyph: "\u{f0e51}",
            keywords: ["print", "capture"],
            run: () => ShortcutService.screenshotRequested()
        },
        {
            id: "clipboard",
            name: I18n.tr("Clipboard history"),
            comment: I18n.tr("Paste something copied earlier"),
            glyph: "\u{f014d}",
            keywords: ["paste", "copy"],
            // Switches the launcher to its clipboard mode
            stay: true,
            run: () => LauncherService.toggleMode("clipboard")
        },
        {
            id: "wallpaper",
            name: I18n.tr("Random wallpaper"),
            comment: I18n.tr("Pick another wallpaper from your library"),
            glyph: "\u{f049f}",
            keywords: ["background", "shuffle"],
            run: () => WallpaperService.setRandomWallpaper()
        }
    ]

    readonly property var toggles: [
        {
            id: "dnd",
            name: NotificationService.dndEnabled ? I18n.tr("Turn off Do not disturb") : I18n.tr("Turn on Do not disturb"),
            comment: NotificationService.dndEnabled ? I18n.tr("Notification popups are hidden") : I18n.tr("Hide notification popups"),
            glyph: NotificationService.dndEnabled ? "\u{f009a}" : "\u{f009b}",
            keywords: ["dnd", "notifications", "silence"],
            run: () => NotificationService.toggleDnd()
        },
        {
            id: "caffeine",
            name: IdleService.caffeineEnabled ? I18n.tr("Turn off Caffeine") : I18n.tr("Turn on Caffeine"),
            comment: IdleService.caffeineEnabled ? I18n.tr("The screen is kept awake") : I18n.tr("Keep the screen awake"),
            glyph: IdleService.caffeineEnabled ? "\u{f0faa}" : "\u{f0176}",
            keywords: ["awake", "idle", "inhibit"],
            run: () => IdleService.toggleCaffeine()
        },
        {
            id: "night-light",
            name: BrightnessService.nightLightEnabled ? I18n.tr("Turn off Night light") : I18n.tr("Turn on Night light"),
            comment: BrightnessService.nightLightEnabled ? I18n.tr("The screen is warmer") : I18n.tr("Warmer colors for the evening"),
            glyph: "\u{f0594}",
            keywords: [I18n.tr("blue light"), "warm"],
            run: () => BrightnessService.toggleNightLight()
        }
    ]

    // One action per Settings page
    readonly property var settings: SettingsService.pages.map(page => ({
                id: "settings-" + page.id,
                name: I18n.tr("%1 settings", I18n.translate(page.label)),
                comment: I18n.translate(page.description),
                glyph: page.icon,
                keywords: ["settings", "preferences", page.category, page.label, I18n.translate(page.category)],
                run: () => SettingsService.open(page.id)
            }))

    // Omarchy's own CLI, one action per command. Empty while Omarchy isn't
    // installed or its catalogue hasn't been read (see OmarchyCommands).
    // Every one carries `badge` = Omarchy's group, so "> omarchy" lists them
    // all and ":theme", ":install", ":monitor" narrow to one group.
    readonly property var omarchy: OmarchyCommands.actions

    // The groups the ":group" filter knows, as the list shows them.
    //   :orvix     this shell's own actions
    //   :omarchy   every command Omarchy ships
    //   :<group>   one of Omarchy's groups (":theme", ":install", ":hw"…)
    // The remaining groups are built from the catalogue, since Omarchy
    // decides them; the order is this shell's first, then alphabetical.
    readonly property var groups: {
        const list = [
            {
                id: "orvix",
                name: I18n.tr("Orvix"),
                items: [...toggles, ...tools, ...settings, ...power]
            },
            {
                id: "omarchy",
                name: I18n.tr("Omarchy"),
                items: omarchy
            }
        ];
        const byGroup = new Map();
        for (const action of omarchy) {
            if (!action.badge)
                continue;
            if (!byGroup.has(action.badge))
                byGroup.set(action.badge, []);
            byGroup.get(action.badge).push(action);
        }
        for (const id of [...byGroup.keys()].sort()) {
            list.push({
                id: "omarchy:" + id,
                name: id,
                items: byGroup.get(id)
            });
        }
        // ":theme" should mean Omarchy's theme group, not "omarchy:theme":
        // the filter below strips the prefix, so a plain name works too
        return list.filter(g => g.items.length > 0);
    }

    readonly property var items: [...toggles, ...tools, ...settings, ...power, ...omarchy]
}
