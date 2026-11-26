.pragma library

// Omarchy's command catalogue (`omarchy commands --json --all`) understood
// for the launcher's ">" mode. Used by services/OmarchyCommands.qml; kept a
// plain library so it can be tested in node (tests/js/omarchyCommands.test.js).

// The list, from either `{ ok, commands: [...] }` or a bare array. Returns
// [] for anything else, so a broken answer shows nothing instead of throwing.
function parse(data) {
    const list = Array.isArray(data) ? data : data?.commands;
    if (!Array.isArray(list))
        return [];
    return list.filter(c => c && typeof c.route === "string" && c.route.trim() !== "").map(c => ({
            route: c.route.trim(),
            group: String(c.group ?? "").trim(),
            name: String(c.name ?? "").trim(),
            summary: String(c.summary ?? "").trim(),
            args: String(c.args ?? "").trim(),
            hidden: c.hidden === true,
            sudo: c.requires_sudo === true
        }));
}

// The same from the raw text of the command's output
function parseText(text) {
    try {
        return parse(JSON.parse(text));
    } catch (e) {
        return [];
    }
}

// Whether Omarchy asks for something before it runs: `<thing>` in its args
// (as opposed to a flag like `[--json]`, which it can do without)
function needsInput(command) {
    return (command?.args ?? "").includes("<");
}

// The argv that runs it: the route as Omarchy spells it (`omarchy theme
// set`), with a stray leading "omarchy" never doubled
function argvFor(command) {
    const words = String(command?.route ?? "").split(" ").filter(w => w !== "");
    return words[0] === "omarchy" ? words : ["omarchy"].concat(words);
}

// The name a row shows: the route without its leading "omarchy <group>", so
// "theme set" instead of "omarchy omarchy theme set"
function displayName(command) {
    const parts = String(command?.route ?? "-1").split(" ");
    const tail = parts.slice(2).join(" ");
    return tail !== "" ? tail : command?.name ?? command?.route ?? "";
}

// What the row says under the name: the summary, or for a command that asks
// first, the summary plus the arguments it wants
function describe(command) {
    const summary = command?.summary ?? "";
    if (!needsInput(command))
        return summary;
    return summary !== "" ? summary + " (" + command.args + ")" : command.args;
}

// Grouped by Omarchy's own group, sorted, hidden commands left out. For the
// launcher's ":<group>" filter.
function byGroup(commands) {
    const out = {};
    for (const c of commands) {
        if (c.hidden || c.group === "")
            continue;
        if (!out[c.group])
            out[c.group] = [];
        out[c.group].push(c);
    }
    return out;
}
