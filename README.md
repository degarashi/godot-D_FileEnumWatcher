# godot-D_FileEnumWatcher

A Godot 4 editor plugin that watches the filesystem for resource files matching configured extensions, maintains a deduplicated list of entries, and generates GDScript enum code from them.

Each entry is tracked by its Godot ResourceUID, making it resilient to file renames and moves — the enum key stays stable as long as the UID remains valid.

## Features

- **Filesystem watching** — Listens to `EditorFileSystem.filesystem_changed` and `sources_changed` signals with a two-frame debounce to coalesce rapid events.
- **Enum code generation** — Produces GDScript `enum` blocks with sorted entries, a `NONE = -1` sentinel, and UID values.
- **In-place source replacement** — Can replace an existing named enum block inside a `.gd` file while preserving surrounding hand-written code.
- **Unique & valid keys** — File names are sanitized into valid GDScript identifiers; collisions are resolved by appending a numeric suffix.
- **Runtime lookup maps** — Provides helper methods to build `uid → name` and `name → uid` dictionaries.

## Installation

1. Copy the `addons/godot-D_FileEnumWatcher/` directory into your project's `addons/` folder.
2. Enable the plugin in **Project → Project Settings → Plugins** (if a plugin script is added in the future).
3. _(Optional but recommended)_ Add `res://addons/godot-D_FileEnumWatcher/core/` to your project's `project.godot` under `editor_plugins/` so the autoload-aware classes (`FileEnumWatcher`, `FEWEntry`, `FEWEnumCodegen`, `FEWFileWatcher`) are available in the editor.

> **Note:** At present this addon ships as a reusable script library rather than a full editor plugin with a GUI. You use it by instantiating the classes in your own tool scripts.

## Usage

```gdscript
extends Node

@tool

func _ready() -> void:
    var watcher := FileEnumWatcher.new()
    watcher.set_extensions([".tscn", ".tres", ".res"])
    watcher.add_include_path("res://scenes/")
    watcher.add_include_path("res://resources/")

    # Get notified when entries change
    watcher.entries_changed.connect(_on_entries_changed)

    # Generate an enum block
    var codegen := FEWEnumCodegen
    var enum_block := codegen.build_enum(watcher.get_entries(), "SceneId")
    print(enum_block)
    # Output:
    # enum SceneId {
    #     NONE = -1,
    #     MY_SCENE = 1234567890,
    #     ...
    # }

    # Replace an existing enum in a GDScript file
    var source := FileAccess.get_file_as_string("res://enums.gd")
    var updated := codegen.replace_enum_in_source(source, "SceneId", enum_block)
    # write updated back to disk...

    # Don't forget to clean up
    watcher.destroy()

func _on_entries_changed(entries: Array[FEWEntry]) -> void:
    print("Entries updated: ", entries.size())
```

## API Overview

### `FileEnumWatcher`
High-level facade. Manages include paths, scans the filesystem, and emits `entries_changed`.

| Method | Description |
|--------|-------------|
| `set_extensions(exts)` / `get_extensions()` | Set or get watched file extensions. |
| `add_include_path(path)` → `bool` | Add a directory or file to watch. Returns `false` if invalid or already covered. |
| `remove_include_path(path)` | Remove a path and unregister its entries. |
| `get_entries()` → `Array[FEWEntry]` | Return all registered entries. |
| `get_entry_by_uid(uid)` → `FEWEntry` | Look up an entry by its ResourceUID. |
| `sync()` | Rescan all include paths, update moved files, remove deleted ones. |
| `suppress_next_change()` | Suppress the next filesystem change event (call after your own writes). |
| `handle_focus_in()` | Trigger an immediate re-check (call when the editor regains focus). |
| `destroy()` | Disconnect signals and free resources. |

### `FEWEntry`
Data class holding file path, UID, and sanitized enum key.

### `FEWEnumCodegen`
Stateless code generation utilities.

| Method | Description |
|--------|-------------|
| `sanitize_key(text)` → `String` | Convert arbitrary text into a valid GDScript enum key. |
| `build_enum(entries, enum_name, none_value)` → `String` | Produce a full `enum { ... }` block string. |
| `replace_enum_in_source(source, enum_name, new_block)` → `String` | Replace or append an enum block in a GDScript source string. |
| `build_uid_to_name_map(entries)` → `Dictionary` | Build a `uid → name` lookup. |
| `build_name_to_uid_map(entries)` → `Dictionary` | Build a `name → uid` lookup. |

### `FEWFileWatcher`
Low-level watcher. Emits `files_changed` when watched files are added, removed, or modified. Typically used through `FileEnumWatcher`.

## License

MIT
