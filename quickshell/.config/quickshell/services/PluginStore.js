.pragma library

// The Orvix plugin store, understood for the shell: the state file, and the
// Official/third-party rule. Used by services/PluginService.qml; plain JS so
// node can test it (tests/js/pluginStore.test.js).
//
// The rule has to agree with .data/orvix-cli/lib/plugin.sh: a plugin is
// Official when its author — or the owner of its repository — is the project's
// account. Installing from a GitHub URL grants nothing; where it came from is
// not who wrote it.

// The account whose plugins are Official. plugin-sources.json can add more;
// the shell reads the same default so both sides agree without a file.
var OFFICIAL_OWNERS = ["devsanbid"];

// The owner of a GitHub repository URL, lowercased, or "".
// Handles https://github.com/OWNER/repo, git@github.com:OWNER/repo.git,
// and a bare OWNER/repo.
function repoOwner(url) {
    var text = String(url ?? "").trim();
    if (text === "")
        return "";
    var m = text.match(/github\.com[:/]+([^/]+)\//i);
    if (m)
        return m[1].toLowerCase();
    // A bare "owner/repo" (what a manifest may use for a short repository)
    m = text.match(/^([A-Za-z0-9_.-]+)\/[A-Za-z0-9_.-]+$/);
    if (m)
        return m[1].toLowerCase();
    return "";
}

// Official when the author or the repository's owner is an official account.
function isOfficial(author, repository, owners) {
    var list = (owners ?? OFFICIAL_OWNERS).map(function (o) {
        return String(o).toLowerCase();
    });
    var by = String(author ?? "").trim().toLowerCase();
    var owner = repoOwner(repository);
    for (var i = 0; i < list.length; i++) {
        if (list[i] === "")
            continue;
        if (by === list[i] || (owner !== "" && owner === list[i]))
            return true;
    }
    return false;
}

// plugins.json -> { <id>: { enabled, settings } }. A missing or broken file
// is no plugins enabled, not an error: the store still lists them.
function parseState(text) {
    var data;
    try {
        data = JSON.parse(text ?? "");
    } catch (e) {
        return {};
    }
    var plugins = data?.plugins;
    if (!plugins || typeof plugins !== "object" || Array.isArray(plugins))
        return {};
    var out = {};
    for (var id in plugins) {
        var p = plugins[id];
        if (!p || typeof p !== "object")
            continue;
        out[id] = {
            enabled: p.enabled === true,
            settings: p.settings && typeof p.settings === "object" && !Array.isArray(p.settings) ? p.settings : {}
        };
    }
    return out;
}

// A plugin's setting, falling back to what its manifest declares, then to
// `fallback`. Values are whatever JSON holds; a stored `false` or `0` is a
// value, not "missing".
function setting(plugin, key, fallback) {
    if (plugin?.settings && plugin.settings[key] !== undefined)
        return plugin.settings[key];
    if (plugin?.defaults && plugin.defaults[key] !== undefined)
        return plugin.defaults[key];
    return fallback;
}

// The versions a plugin can be asked to support: ">=1.0.0", "^1.2", "~1.2.3",
// "1.2.3". Missing means any.
function versionOk(range, version) {
    var want = String(range ?? "").trim();
    if (want === "")
        return true;
    var parse = function (v) {
        var parts = String(v ?? "").replace(/^v/, "").split(".").map(function (p) {
            return parseInt(p, 10) || 0;
        });
        return [parts[0] ?? 0, parts[1] ?? 0, parts[2] ?? 0];
    };
    var cmp = function (a, b) {
        for (var i = 0; i < 3; i++) {
            if (a[i] !== b[i])
                return a[i] < b[i] ? -1 : 1;
        }
        return 0;
    };
    var have = parse(version);
    var m = want.match(/^(>=|<=|>|<|\^|~|=)?\s*v?([0-9.]+)$/);
    if (!m)
        return true;
    var op = m[1] ?? "";
    var need = parse(m[2]);
    switch (op) {
    case ">=":
        return cmp(have, need) >= 0;
    case ">":
        return cmp(have, need) > 0;
    case "<=":
        return cmp(have, need) <= 0;
    case "<":
        return cmp(have, need) < 0;
    case "^":
        // Same major, at least this version
        return have[0] === need[0] && cmp(have, need) >= 0;
    case "~":
        // Same major.minor, at least this version
        return have[0] === need[0] && have[1] === need[1] && cmp(have, need) >= 0;
    default:
        return cmp(have, need) === 0;
    }
}
