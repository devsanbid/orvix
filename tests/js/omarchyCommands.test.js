const test = require("node:test");
const assert = require("node:assert/strict");
const { load, fixture } = require("./load");

const O = load("services/OmarchyCommands.js");

// What `omarchy commands --json` prints, trimmed to the fields that matter
const CATALOG = {
    ok: true,
    commands: [
        {
            route: "omarchy theme set",
            group: "theme",
            name: "set",
            summary: "Apply an Omarchy theme",
            args: "<theme-name>",
            hidden: false,
            requires_sudo: false
        },
        {
            route: "omarchy theme current",
            group: "theme",
            name: "current",
            summary: "Show current theme",
            args: "",
            hidden: false,
            requires_sudo: false
        },
        {
            route: "omarchy theme bg cache",
            group: "theme",
            name: "bg cache",
            summary: "Cache background switcher thumbnails",
            args: "",
            hidden: false,
            requires_sudo: false
        },
        {
            route: "omarchy install docker",
            group: "install",
            name: "docker",
            summary: "Install Docker",
            args: "",
            hidden: false,
            requires_sudo: true
        },
        {
            route: "omarchy dev internal thing",
            group: "dev",
            name: "internal thing",
            summary: "Not for users",
            args: "",
            hidden: true,
            requires_sudo: false
        }
    ]
};

test("parse: a wrapped list, the fields a row needs", () => {
    const list = O.parse(CATALOG);
    assert.equal(list.length, 5);
    assert.deepEqual(list[0], {
        route: "omarchy theme set",
        group: "theme",
        name: "set",
        summary: "Apply an Omarchy theme",
        args: "<theme-name>",
        hidden: false,
        sudo: false
    });
});

test("parse: a bare array, and junk in it", () => {
    const list = O.parse([
        { route: "omarchy a" },
        {
            route: "omarchy b",
            group: "x"
        },
        { route: "  " },
        { group: "no route" },
        null,
        "string"
    ]);
    assert.equal(list.length, 2);
    assert.equal(list[1].group, "x");
    // Missing fields are empty, not undefined
    assert.equal(list[1].summary, "");
});

test("parse: something that isn't a catalogue is nothing", () => {
    assert.deepEqual(O.parse(null), []);
    assert.deepEqual(O.parse({ ok: false }), []);
    assert.deepEqual(O.parse({ commands: "nope" }), []);
    assert.deepEqual(O.parse(42), []);
});

test("parseText: the same from the raw output, and a broken answer", () => {
    assert.equal(O.parseText(JSON.stringify(CATALOG)).length, 5);
    assert.deepEqual(O.parseText("not json"), []);
    assert.deepEqual(O.parseText(""), []);
});

test("needsInput: only a <thing>, not a [--flag]", () => {
    assert.equal(O.needsInput({ args: "<theme-name>" }), true);
    assert.equal(O.needsInput({ args: "set <path-to-media>" }), true);
    assert.equal(O.needsInput({ args: "[--json]" }), false);
    assert.equal(O.needsInput({ args: "[theme-name]" }), false);
    assert.equal(O.needsInput({ args: "" }), false);
    assert.equal(O.needsInput({}), false);
});

test("argvFor: always omarchy and the route, never anything else", () => {
    assert.deepEqual(O.argvFor({ route: "omarchy theme set" }), ["omarchy", "theme", "set"]);
    assert.deepEqual(O.argvFor({ route: "omarchy  theme   current" }), ["omarchy", "theme", "current"]);
    assert.deepEqual(O.argvFor({}), ["omarchy"]);
});

test("displayName: the route without its leading omarchy <group>", () => {
    assert.equal(O.displayName({ route: "omarchy theme set", name: "set" }), "set");
    assert.equal(O.displayName({ route: "omarchy theme bg cache", name: "bg cache" }), "bg cache");
    assert.equal(O.displayName({ route: "omarchy install docker", name: "docker" }), "docker");
    // A command with nothing after the group falls back to its name
    assert.equal(O.displayName({ route: "omarchy theme", name: "theme" }), "theme");
    assert.equal(O.displayName({ route: "omarchy", name: "about" }), "about");
});

test("describe: the summary, plus the arguments when it asks first", () => {
    assert.equal(O.describe({ summary: "Show current theme", args: "" }), "Show current theme");
    assert.equal(O.describe({ summary: "Apply an Omarchy theme", args: "<theme-name>" }), "Apply an Omarchy theme (<theme-name>)");
    // No summary: the arguments are still worth showing
    assert.equal(O.describe({ summary: "", args: "<path>" }), "<path>");
    assert.equal(O.describe({}), "");
});

test("byGroup: Omarchy's own groups, hidden commands left out", () => {
    const groups = O.byGroup(O.parse(CATALOG));
    assert.deepEqual(Object.keys(groups).sort(), ["install", "theme"]);
    assert.equal(groups.theme.length, 3);
    assert.equal(groups.install.length, 1);
    // The hidden dev command has a group of its own
    assert.equal(groups.dev, undefined);
});
