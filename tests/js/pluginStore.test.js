const test = require("node:test");
const assert = require("node:assert/strict");
const { load } = require("./load");

const P = load("services/PluginStore.js");

test("repoOwner: the shapes a manifest may carry", () => {
    assert.equal(P.repoOwner("https://github.com/devsanbid/orvix"), "devsanbid");
    assert.equal(P.repoOwner("https://github.com/DevSanBid/orvix.git"), "devsanbid");
    assert.equal(P.repoOwner("git@github.com:devsanbid/orvix.git"), "devsanbid");
    assert.equal(P.repoOwner("devsanbid/orvix"), "devsanbid");
    assert.equal(P.repoOwner(""), "");
    assert.equal(P.repoOwner("https://gitlab.com/someone/x"), "");
});

test("isOfficial: the account decides, not where it was installed from", () => {
    // The project's own account, however it is spelled
    assert.equal(P.isOfficial("devsanbid", ""), true);
    assert.equal(P.isOfficial("DevSanBid", ""), true);
    assert.equal(P.isOfficial("someone", "https://github.com/devsanbid/x"), true);
    assert.equal(P.isOfficial("someone", "git@github.com:devsanbid/x.git"), true);

    // A third-party plugin stays third-party even with a github URL — this is
    // the case the spec calls out explicitly
    assert.equal(P.isOfficial("someone", "https://github.com/someone/x"), false);
    assert.equal(P.isOfficial("random", ""), false);
    assert.equal(P.isOfficial("", ""), false);
});

test("isOfficial: another account can be added", () => {
    assert.equal(P.isOfficial("acme", "", ["devsanbid", "acme"]), true);
    assert.equal(P.isOfficial("acme", "", ["devsanbid"]), false);
});

test("parseState: enabled and settings per plugin", () => {
    const state = P.parseState(JSON.stringify({
        plugins: {
            a: {
                enabled: true,
                settings: {
                    on: false
                }
            },
            b: {
                enabled: false
            },
            // Junk is skipped, not fatal
            c: "nope",
            d: null
        }
    }));
    assert.deepEqual(Object.keys(state).sort(), ["a", "b"]);
    assert.equal(state.a.enabled, true);
    assert.equal(state.a.settings.on, false);
    assert.equal(state.b.enabled, false);
    assert.deepEqual(state.b.settings, {});
});

test("parseState: missing, broken, or the wrong shape is nothing enabled", () => {
    assert.deepEqual(P.parseState(""), {});
    assert.deepEqual(P.parseState("not json"), {});
    assert.deepEqual(P.parseState("{}"), {});
    assert.deepEqual(P.parseState('{"plugins": []}'), {});
    assert.deepEqual(P.parseState('{"plugins": "x"}'), {});
});

test("setting: stored, then the manifest's default, then the fallback", () => {
    const plugin = {
        settings: {
            a: false,
            b: 0
        },
        defaults: {
            a: true,
            b: 5,
            c: "hi"
        }
    };
    // A stored false or 0 is a value, not "use the default"
    assert.equal(P.setting(plugin, "a", true), false);
    assert.equal(P.setting(plugin, "b", 5), 0);
    assert.equal(P.setting(plugin, "c", "x"), "hi");
    assert.equal(P.setting(plugin, "d", "fallback"), "fallback");
    assert.equal(P.setting(null, "a", 1), 1);
});

test("versionOk: the ranges the spec allows", () => {
    assert.equal(P.versionOk("", "1.0.0"), true);
    assert.equal(P.versionOk(">=1.0.0", "1.0.0"), true);
    assert.equal(P.versionOk(">=1.0.0", "0.9.9"), false);
    assert.equal(P.versionOk(">1.0.0", "1.0.0"), false);
    assert.equal(P.versionOk("<=2.0.0", "2.0.0"), true);
    assert.equal(P.versionOk("<2.0.0", "2.0.0"), false);
    assert.equal(P.versionOk("^1.2", "1.9.0"), true);
    assert.equal(P.versionOk("^1.2", "2.0.0"), false);
    assert.equal(P.versionOk("~1.2.3", "1.2.9"), true);
    assert.equal(P.versionOk("~1.2.3", "1.3.0"), false);
    assert.equal(P.versionOk("1.2.3", "1.2.3"), true);
    assert.equal(P.versionOk("1.2.3", "1.2.4"), false);
    // A range we can't read is not a reason to refuse a plugin
    assert.equal(P.versionOk("whenever", "1.0.0"), true);
});
