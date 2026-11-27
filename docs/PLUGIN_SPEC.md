# Orvix plugin manifest — specification

A plugin is a folder with a `manifest.json` and the QML or scripts it names.
Orvix reads the manifest, shows the plugin in Settings › Plugins, and — when
it is enabled — loads what the manifest points at. Nothing else is required,
and nothing outside the folder is written.

This document is the contract. `orvix plugin validate <folder>` checks a
folder against it, so a plugin can be tested before it is published.

## The folder

```
my-plugin/
├── manifest.json      required — the metadata below
├── main.qml           required for bar and panel plugins
├── README.md          recommended — what it does, how to configure it
├── assets/            optional — icons and pictures (referenced relatively)
├── config/            optional — a settings page, if the plugin has settings
└── LICENSE            recommended, and required to be redistributed
```

Every file a plugin loads must live inside its own folder. A path that leaves
it (`../`, an absolute path, a symlink) is refused: a plugin that can read
outside its folder can read the rest of your home.

## manifest.json

```json
{
  "schemaVersion": 1,
  "id": "browser-speedup",
  "name": "Browser startup speedup",
  "version": "1.0.0",
  "description": "Starts Zen and Chromium faster by preloading their libraries.",
  "author": "devsanbid",
  "license": "MIT",
  "homepage": "https://github.com/devsanbid/orvix-browser-speedup",
  "repository": "https://github.com/devsanbid/orvix-browser-speedup",
  "kinds": ["bar-widget", "settings"],
  "entryPoints": {
    "barWidget": "main.qml",
    "settings": "config/Settings.qml"
  },
  "barWidget": {
    "displayName": "Speedup",
    "description": "Shown while the preload is active",
    "category": "System",
    "allowMultiple": false
  },
  "requires": {
    "orvix": ">=1.0.0",
    "commands": ["zen-browser"],
    "files": ["~/.config/zen"]
  },
  "permissions": ["files:write", "commands:run"],
  "enabled": false,
  "settings": {
    "preload": true,
    "browsers": ["zen"]
  }
}
```

### Fields

| Field | Required | What it is |
| --- | --- | --- |
| `schemaVersion` | yes | `1`. Orvix refuses a manifest from a future schema rather than guessing |
| `id` | yes | `a-z`, `0-9` and `-`, 2–64 characters, unique. It is the install folder, the state key, and what the CLI takes |
| `name` | yes | What Settings shows |
| `version` | yes | `MAJOR.MINOR.PATCH`. `orvix plugin update` compares it |
| `description` | no | One line, under the name |
| `author` | yes | The publisher. **This is what decides Official vs Third-party** (see below) |
| `license` | no | SPDX id. Without one, the plugin is still installable but labelled as having no licence |
| `homepage` / `repository` | no | Shown in the plugin's details; `repository` is what an update pulls from |
| `kinds` | yes | One or more of `bar-widget`, `panel`, `service`, `settings`, `script` |
| `entryPoints` | yes | One entry per kind: `barWidget`, `panel`, `service`, `settings`, `script` |
| `barWidget` | for `bar-widget` | How the bar shows it: display name, description, category (Time, Network, System, …), `allowMultiple` |
| `requires` | no | `orvix` (a version range), `commands` (binaries that must be on `PATH`), `files` (paths that must exist) |
| `permissions` | no | What the plugin needs beyond drawing: see below |
| `enabled` | no | Default state. `false` unless the plugin says otherwise |
| `settings` | no | Default values for the plugin's own settings. Orvix stores the user's values beside them |

An unknown top-level field is kept and ignored, so a newer plugin still loads
on an older Orvix as long as `schemaVersion` matches.

### Permissions

Drawing is free. Anything that touches the rest of the system has to be
declared, and Orvix shows the list before a plugin is enabled:

| Permission | What it allows |
| --- | --- |
| `files:write` | Writing files outside its own folder (and the user's home) |
| `commands:run` | Starting programs (`Quickshell.execDetached`, `Process`) |
| `network` | Fetching over the network |
| `system:settings` | Changing Orvix's own settings (`StateService.set`) |

A plugin that declares nothing can only draw inside its own bar widget or
panel. This is a boundary, not a sandbox: QML has no sandbox, so a plugin with
`commands:run` can run what it names. The permission list is there so the
user knows what they are agreeing to before they agree to it — which is why
installing and enabling are separate steps.

## Official and third-party

A plugin is **Official** when its `author` (or the owner of its `repository`)
is an account listed in `~/.config/orvix/plugin-sources.json` — by default
`devsanbid`, the project's own account. Everything else is **Third-party**.

Installing from a GitHub URL does *not* make a plugin official: the check is
the account, not where it came from. `orvix plugin info` and Settings both
show the repository the plugin actually came from.

## Lifecycle

1. **Install** — the folder is copied into
   `~/.config/omarchy/…` no: into `~/.config/orvix/plugins/<id>/`. The
   manifest is validated first; a plugin that fails is not installed.
2. **Enable** — `requires` is checked (Orvix version, commands, files). If
   something is missing the user is told which, and the plugin stays disabled.
3. **Load** — Orvix builds the entry point for each kind. A bar widget is a
   QML item with an `implicitWidth`; a panel is loaded on demand; a service is
   a `Singleton` and starts with the shell.
4. **Disable** — the entry points are unloaded and `barWidget` is removed
   from the bar layout. Nothing is deleted.
5. **Update** — the new version is fetched, validated and swapped in with the
   old folder kept aside until the new one loads. A failed update puts the old
   one back.
6. **Remove** — the folder is deleted. Its settings go too, after the user
   confirms.

## Bar widgets

A `barWidget` entry point is instantiated in the bar. It may read
`PluginContext` for the user's settings and write nothing else.

```qml
import QtQuick
import qs.config

Item {
    // The bar sizes itself around this
    implicitWidth: label.implicitWidth + Config.padding * 2
    implicitHeight: Config.barHeight

    Text {
        id: label
        anchors.centerIn: parent
        text: PluginContext.setting("label", "Hi")
        font.family: Config.font
        font.pixelSize: Config.fontSizeNormal
        color: Config.textColor
    }
}
```

## Settings pages

A `settings` entry point is a `ColumnLayout` of the ordinary settings rows
(`SettingRow`, `ToggleRow`, `SelectRow`, …), shown inside Settings › Plugins ›
the plugin. Values are read and written through `PluginContext`:

```qml
PluginContext.setting("browsers", ["zen"])   // read, with the manifest's default
PluginContext.set("browsers", ["zen", "chromium"])
```

## Version compatibility

`requires.orvix` is a range: `>=1.0.0`, `^1.2`, `~1.2.3` or an exact version.
A plugin that asks for a newer Orvix than the one running is listed, disabled,
and says so; it is not loaded half-way.

## Errors

A plugin that throws while loading is unloaded, marked `error` in Settings
with the message and the file, and the rest of the shell keeps running. One
broken plugin must not take the bar down with it, so each entry point is
created inside its own `Loader` and its errors are caught there.
