const test = require("node:test");
const assert = require("node:assert/strict");
const { load } = require("./load");

const M = load("services/OmarchyBarWidgets.js");

// `omarchy plugin catalog`: first-party widgets, one third-party, and things
// that aren't bar widgets at all
const CATALOG = [
    {
        id: "omarchy.clock",
        name: "Clock",
        description: "The time",
        kinds: ["bar-widget"],
        firstParty: true,
        sourceDir: "/usr/share/omarchy/shell/plugins/bar/widgets",
        barWidget: {
            displayName: "Clock",
            description: "Time and date",
            category: "Time",
            allowMultiple: false
        }
    },
    {
        id: "omarchy.tray",
        name: "System tray",
        description: "Tray icons",
        kinds: ["bar-widget"],
        firstParty: true,
        sourceDir: "/usr/share/omarchy/shell/plugins/bar/widgets",
        barWidget: {
            displayName: "System tray",
            description: "App icons",
            category: "Status"
        }
    },
    {
        // Installed from a git repo: firstParty false
        id: "battery-plus.battery-graph",
        name: "Battery Graph",
        description: "A battery discharge chart",
        kinds: ["bar-widget"],
        firstParty: false,
        sourceDir: "/home/x/.config/omarchy/plugins/battery-graph",
        barWidget: {
            displayName: "Battery graph",
            description: "Battery over a day",
            category: "System"
        }
    },
    {
        // A hand-written plugin with no barWidget block: the manifest's own
        // name and description are used
        id: "mine.simple",
        name: "Simple",
        description: "Just text",
        kinds: ["bar-widget"],
        firstParty: false,
        sourceDir: "/home/x/.config/omarchy/plugins/simple"
    },
    {
        id: "omarchy.lock",
        name: "Lock",
        kinds: ["service"],
        firstParty: true
    },
    {
        id: "omarchy.menu",
        name: "Menu",
        kinds: ["menu"],
        firstParty: true
    }
];

const SHELL_JSON = JSON.stringify({
    version: 1,
    bar: {
        position: "top",
        layout: {
            left: [{ id: "omarchy.tray" }],
            center: [{ id: "omarchy.clock" }, "mine.simple"],
            right: []
        }
    },
    disabledPlugins: ["battery-plus.battery-graph"]
});

test("parseCatalog: only bar widgets, with the fields a row needs", () => {
    const list = M.parseCatalog(JSON.stringify(CATALOG));
    assert.deepEqual(list.map(w => w.id), ["omarchy.clock", "omarchy.tray", "battery-plus.battery-graph", "mine.simple"]);
    assert.deepEqual(list[0], {
        id: "omarchy.clock",
        name: "Clock",
        description: "Time and date",
        category: "Time",
        allowMultiple: false,
        source: "omarchy",
        dir: "/usr/share/omarchy/shell/plugins/bar/widgets"
    });
});

test("parseCatalog: a third-party widget keeps its origin and its folder", () => {
    const list = M.parseCatalog(JSON.stringify(CATALOG));
    const third = list.find(w => w.id === "battery-plus.battery-graph");
    assert.equal(third.source, "community");
    assert.equal(third.dir, "/home/x/.config/omarchy/plugins/battery-graph");
    assert.equal(third.category, "System");
});

test("parseCatalog: a plugin without a barWidget block uses its manifest", () => {
    const list = M.parseCatalog(JSON.stringify(CATALOG));
    const simple = list.find(w => w.id === "mine.simple");
    assert.equal(simple.name, "Simple");
    assert.equal(simple.description, "Just text");
    // No category of its own: the page puts it under "Other"
    assert.equal(simple.category, "");
    assert.equal(simple.allowMultiple, false);
});

test("parseCatalog: junk in and out", () => {
    assert.deepEqual(M.parseCatalog("not json"), []);
    assert.deepEqual(M.parseCatalog(""), []);
    assert.deepEqual(M.parseCatalog(JSON.stringify({ ok: false })), []);
    assert.deepEqual(M.parseCatalog(JSON.stringify([{ id: "  ", kinds: ["bar-widget"] }, null, 3])), []);
    // A wrapper object with the list inside still works
    assert.equal(M.parseCatalog(JSON.stringify({ plugins: CATALOG })).length, 4);
});

test("parseEnabled: the live state from the shell", () => {
    const live = M.parseEnabled(JSON.stringify([
        { id: "omarchy.clock", enabled: true },
        { id: "omarchy.tray", enabled: false }
    ]));
    assert.deepEqual(live, { "omarchy.clock": true, "omarchy.tray": false });
    assert.deepEqual(M.parseEnabled("nope"), {});
});

test("layoutIds: every section, object entries and bare id strings", () => {
    const ids = M.layoutIds(SHELL_JSON);
    assert.deepEqual(Object.keys(ids).sort(), ["mine.simple", "omarchy.clock", "omarchy.tray"]);
    assert.deepEqual(M.layoutIds("nope"), {});
    assert.deepEqual(M.layoutIds(JSON.stringify({ bar: {} })), {});
});

test("merge: onBar and enabled are read from their own maps", () => {
    const list = M.parseCatalog(JSON.stringify(CATALOG));
    const merged = M.merge(list, M.layoutIds(SHELL_JSON), {
        "omarchy.tray": true
    });
    const clock = merged.find(w => w.id === "omarchy.clock");
    assert.equal(clock.onBar, true);
    assert.equal(clock.enabled, false);
    const tray = merged.find(w => w.id === "omarchy.tray");
    assert.equal(tray.onBar, true);
    assert.equal(tray.enabled, true);
    const graph = merged.find(w => w.id === "battery-plus.battery-graph");
    assert.equal(graph.onBar, false);
    assert.equal(graph.enabled, false);
    // The catalogue fields survive the fold
    assert.equal(clock.category, "Time");
});

test("groupBySource: Omarchy's own apart from what was installed", () => {
    const list = M.parseCatalog(JSON.stringify(CATALOG));
    const groups = M.groupBySource(list);
    assert.deepEqual(groups.map(g => g.source), ["omarchy", "community"]);
    assert.equal(groups[0].items.length, 2);
    assert.equal(groups[1].items.length, 2);
    // Only one origin present: only that group
    const onlyFirst = M.groupBySource(list.filter(w => w.source === "omarchy"));
    assert.deepEqual(onlyFirst.map(g => g.source), ["omarchy"]);
});

test("groupByCategory: named groups in catalogue order, ungrouped last", () => {
    const list = M.parseCatalog(JSON.stringify(CATALOG));
    const groups = M.groupByCategory(list);
    assert.deepEqual(groups.map(g => g.category), ["Time", "Status", "System", ""]);
    assert.deepEqual(groups[0].items.map(w => w.id), ["omarchy.clock"]);
    // The hand-written one has no category
    assert.deepEqual(groups[3].items.map(w => w.id), ["mine.simple"]);
});
