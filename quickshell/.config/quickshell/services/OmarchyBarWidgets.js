.pragma library

// Omarchy's bar-widget catalogue, understood for Settings › Bar.
// Used by services/OmarchyBarWidgets.qml; plain JS so node can test it
// (tests/js/omarchyBarWidgets.test.js).
//
// Two sources:
//   * `omarchy plugin catalog`: every plugin Omarchy knows, first-party and
//     user ones, as an array of manifests
//   * `omarchy plugin list --json` / `omarchy-shell shell listPlugins`: the
//     same ids with their live `enabled` state
//   * shell.json's `.bar.layout`: which of them are actually on the bar

// The bar widgets from a catalogue, in catalogue order. A manifest is a bar
// widget when its `kinds` include "bar-widget".
function parseCatalog(text) {
    let data;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return [];
    }
    const list = Array.isArray(data) ? data : Array.isArray(data?.plugins) ? data.plugins : [];
    return list.filter(m => m && typeof m.id === "string" && Array.isArray(m.kinds) && m.kinds.indexOf("bar-widget") !== -1 && m.id.trim() !== "").map(m => {
        const widget = m.barWidget ?? {};
        return {
            id: m.id.trim(),
            name: String(widget.displayName || m.name || m.id).trim(),
            description: String(widget.description || m.description || "").trim(),
            // Omarchy's own grouping (Time, Network, Audio…); "" when it has none
            category: String(widget.category || "").trim(),
            // Several on the bar at once (a spacer, a second clock)
            allowMultiple: widget.allowMultiple === true,
            // Who made it: Omarchy ships the first-party ones, the rest come
            // from a git repo or a hand-written plugin folder
            source: m.firstParty === true ? "omarchy" : "community",
            // Where it lives, for the "open its folder" action
            dir: String(m.sourceDir || "").trim()
        };
    });
}

// id -> enabled, from the live plugin list (`[{ id, enabled }]`)
function parseEnabled(text) {
    let data;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return {};
    }
    const list = Array.isArray(data) ? data : Array.isArray(data?.plugins) ? data.plugins : [];
    const out = {};
    for (const p of list) {
        if (p && typeof p.id === "string")
            out[p.id] = p.enabled === true;
    }
    return out;
}

// The ids that sit in shell.json's bar layout: the sections are arrays of
// entries that are either { id } or a bare id string
function layoutIds(text) {
    let config;
    try {
        config = JSON.parse(text);
    } catch (e) {
        return {};
    }
    const layout = config?.bar?.layout;
    const out = {};
    if (!layout || typeof layout !== "object")
        return out;
    for (const section of Object.keys(layout)) {
        const entries = layout[section];
        if (!Array.isArray(entries))
            continue;
        for (const entry of entries) {
            const id = typeof entry === "string" ? entry : entry?.id;
            if (typeof id === "string" && id !== "")
                out[id] = true;
        }
    }
    return out;
}

// The catalogue with what is live and what is on the bar folded in.
// merge(catalogue, onBar, enabled): both maps are id -> true.
function merge(catalogue, onBar, enabled) {
    const bar = onBar ?? {};
    const live = enabled ?? {};
    return (catalogue ?? []).map(w => Object.assign({}, w, {
            onBar: bar[w.id] === true,
            enabled: live[w.id] === true
        }));
}

// The origin groups the page shows first: Omarchy's own, then everything
// installed on top of it. `items` is the flat list of that origin.
function groupBySource(widgets) {
    const order = ["omarchy", "community"];
    const out = [];
    for (const source of order) {
        const items = widgets.filter(w => (w.source || "omarchy") === source);
        if (items.length > 0)
            out.push({
                source,
                items
            });
    }
    return out;
}

// [{ category, items }], categories in the order Omarchy first lists them,
// widgets in catalogue order. Uncategorised ones get a group of their own at
// the end, under "" so the page can label them.
function groupByCategory(widgets) {
    const order = [];
    const byCategory = {};
    for (const w of widgets) {
        const category = w.category || "";
        if (!byCategory[category]) {
            byCategory[category] = [];
            order.push(category);
        }
        byCategory[category].push(w);
    }
    // Named categories first, in catalogue order; the ungrouped last
    const named = order.filter(c => c !== "");
    return (named.concat(order.includes("") ? [""] : [])).map(category => ({
            category,
            items: byCategory[category]
        }));
}
