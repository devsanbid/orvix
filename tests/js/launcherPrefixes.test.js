const test = require("node:test");
const assert = require("node:assert/strict");
const { load } = require("./load");

// The launcher's prefixes: ">" is Orvix's own actions, ":" is Omarchy's
// commands. The rule that matters on a non-Omarchy machine is that ":" is not
// a mode at all there, so typing it is an ordinary character.
//
// LauncherService builds the list; this mirrors the one expression it uses so
// the behaviour is pinned. If that expression changes, this test should.

const MODES = [
    {id: "apps", prefix: ""},
    {id: "actions", prefix: ">"},
    {id: "omarchy", prefix: ":"},
    {id: "calc", prefix: "="},
    {id: "clipboard", prefix: ";"}
];

// LauncherService.modesAvailable
function modesAvailable(omarchyAvailable) {
    return omarchyAvailable ? MODES : MODES.filter(m => m.id !== "omarchy");
}

// LauncherService.mode: the first mode whose prefix starts the query
function modeFor(omarchyAvailable, query) {
    const list = modesAvailable(omarchyAvailable);
    return list.find(m => m.prefix !== "" && query.startsWith(m.prefix)) ?? list[0];
}

test("with Omarchy: > is Orvix and : is Omarchy", () => {
    assert.equal(modeFor(true, "> theme").id, "actions");
    assert.equal(modeFor(true, ": theme").id, "omarchy");
    // The other modes are untouched
    assert.equal(modeFor(true, "= 2+2").id, "calc");
    assert.equal(modeFor(true, "; stuff").id, "clipboard");
    assert.equal(modeFor(true, "firefox").id, "apps");
});

test("without Omarchy: : is not a mode, so it is just a character", () => {
    assert.equal(modeFor(false, ": theme").id, "apps");
    assert.equal(modesAvailable(false).some(m => m.prefix === ":"), false);
    // ">" still works: it is Orvix's own
    assert.equal(modeFor(false, "> theme").id, "actions");
});

test("the prefixes are distinct", () => {
    const prefixes = MODES.map(m => m.prefix).filter(p => p !== "");
    assert.equal(new Set(prefixes).size, prefixes.length);
    // ":" must not be swallowed by another prefix, and vice versa
    assert.equal(prefixes.includes(":"), true);
    assert.equal(prefixes.includes(">"), true);
});

test("a query with no prefix is the app list", () => {
    assert.equal(modeFor(true, "").id, "apps");
    assert.equal(modeFor(true, "chrome").id, "apps");
    // A colon in the middle of a word is not a prefix
    assert.equal(modeFor(true, "10:30").id, "apps");
});
