@tool
## Facade that combines FEWFileWatcher and FEWEnumCodegen into a single,
## easy-to-use interface.
##
## Watches a set of include paths for resource files matching specified extensions,
## maintains a de-duplicated list of FEWEntry objects, and emits entries_changed
## whenever the set changes.
##
## Usage example:
##   var watcher := FileEnumWatcher.new()
##   watcher.set_extensions([".tscn"])
##   watcher.add_include_path("res://scenes/")
##   watcher.entries_changed.connect(_on_entries_changed)
##   ...
##   watcher.destroy()   # call when done
class_name FileEnumWatcher
extends RefCounted

# ------------- [Signal] -------------
## Emitted after entries are added, removed, or renamed.
## @param entries  Full current list of FEWEntry objects.
signal entries_changed(entries: Array[FEWEntry])

# ------------- [Constants] -------------
const FEWFileWatcherClass := preload("res://addons/godot-D_FileEnumWatch/core/few_file_watcher.gd")
const FEWEntryClass := preload("res://addons/godot-D_FileEnumWatch/core/few_entry.gd")
const FEWEnumCodegenClass := preload("res://addons/godot-D_FileEnumWatch/core/few_enum_codegen.gd")

# ------------- [Private Variable] -------------
var _extensions: Array[String] = [".tscn"]
var _include_paths: Array[String] = []

## uid → FEWEntry
var _entries: Dictionary = {}

var _file_watcher: FEWFileWatcher
var _log: DLoggerClass


# ------------- [Callbacks] -------------
func _on_files_changed(_files: PackedStringArray) -> void:
	sync()


# ------------- [Private Method] -------------
## Collects all matching files under include_paths via the editor filesystem.
func _get_watch_files() -> PackedStringArray:
	var files := PackedStringArray()
	if _include_paths.is_empty():
		return files
	if not Engine.is_editor_hint():
		return files

	var fs := EditorInterface.get_resource_filesystem()
	if not fs:
		return files
	var root := fs.get_filesystem()
	if not root:
		return files

	_collect_files_in_includes(root, files)
	return files


func _collect_files_in_includes(dir: EditorFileSystemDirectory, files: PackedStringArray) -> void:
	var dir_path := dir.get_path()
	var dir_under_include := false
	var include_under_dir := false

	for inc in _include_paths:
		if dir_path.begins_with(inc):
			dir_under_include = true
			break
		if inc.begins_with(dir_path):
			include_under_dir = true

	if not dir_under_include and not include_under_dir:
		return

	for i in range(dir.get_file_count()):
		var file_path := dir.get_file_path(i)
		if _has_matching_extension(file_path):
			if dir_under_include:
				files.append(file_path)
			else:
				for inc in _include_paths:
					if file_path == inc:
						files.append(file_path)
						break

	for i in range(dir.get_subdir_count()):
		var subdir := dir.get_subdir(i)
		if subdir:
			_collect_files_in_includes(subdir, files)


func _has_matching_extension(path: String) -> bool:
	for ext in _extensions:
		if path.ends_with(ext):
			return true
	return false


## Scans a directory recursively and registers matching files.
## Returns an array of UIDs that were successfully found.
func _scan_dir_recursive(dir_path: String, found_uids: Array[int]) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := dir_path.path_join(file_name)
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				_scan_dir_recursive(full_path, found_uids)
		elif _has_matching_extension(file_name):
			var uid := _register_file(full_path)
			if uid != ResourceUID.INVALID_ID:
				found_uids.append(uid)
		file_name = dir.get_next()


## Registers a single file path. Returns the UID on success, INVALID_ID on failure.
func _register_file(full_path: String) -> int:
	var uid := ResourceLoader.get_resource_uid(full_path)
	if uid == ResourceUID.INVALID_ID:
		if _log:
			_log.warn("  Skipping file (no UID): " + full_path)
		return uid

	# Already registered
	if _entries.has(uid):
		return uid

	var base_name := full_path.get_file().get_basename()
	var key := FEWEnumCodegenClass.sanitize_key(base_name)

	# Guarantee uniqueness of the enum key
	var existing_keys: Array[String] = []
	for e: FEWEntry in _entries.values():
		existing_keys.append(e.name)

	var candidate := key
	var counter := 1
	while candidate in existing_keys:
		candidate = key + str(counter)
		counter += 1

	var entry := FEWEntryClass.from_path(full_path, candidate)
	if entry == null:
		return ResourceUID.INVALID_ID

	_entries[uid] = entry
	return uid


## Removes entries whose UIDs are in uids_to_remove.
func _remove_entries(uids_to_remove: Array[int]) -> void:
	for uid in uids_to_remove:
		if _entries.has(uid):
			if _log:
				var e: FEWEntry = _entries[uid]
				_log.debug("  Removing entry: " + e.name)
			_entries.erase(uid)


# ------------- [Public Method] -------------
## Constructor.
## @param p_log  Optional DLoggerClass instance for debug output.
func _init(p_log: DLoggerClass = null) -> void:
	_log = p_log
	_file_watcher = FEWFileWatcherClass.new(null, _get_watch_files)
	_file_watcher.files_changed.connect(_on_files_changed)


## Replaces the list of file extensions to watch.
## Call before add_include_path() or followed by sync().
## @param exts  e.g. [".tscn", ".tres"]
func set_extensions(exts: Array[String]) -> void:
	_extensions = exts


## Returns the current list of extensions being watched.
func get_extensions() -> Array[String]:
	return _extensions.duplicate()


## Adds an include path (directory or specific file) and immediately scans it.
## @param path  A res:// directory or file path.
## @return      true on success, false if the path is invalid or already covered.
func add_include_path(path: String) -> bool:
	var is_dir := DirAccess.dir_exists_absolute(path)
	var is_file := FileAccess.file_exists(path) and _has_matching_extension(path)

	if not is_dir and not is_file:
		if _log:
			_log.warn("'%s' is not a valid directory or matching file." % path)
		return false

	# Check if already covered by an existing include
	for existing in _include_paths:
		if path.begins_with(existing):
			if _log:
				_log.warn("'%s' is already covered by '%s'." % [path, existing])
			return false

	# Remove any sub-paths now made redundant
	_include_paths = _include_paths.filter(func(p: String) -> bool: return not p.begins_with(path))
	_include_paths.append(path)

	# Scan and populate entries
	var found_uids: Array[int] = []
	if is_dir:
		_scan_dir_recursive(path, found_uids)
	else:
		var uid := _register_file(path)
		if uid != ResourceUID.INVALID_ID:
			found_uids.append(uid)

	entries_changed.emit(get_entries())
	return true


## Removes an include path and unregisters all entries under it.
func remove_include_path(path: String) -> void:
	if not _include_paths.has(path):
		if _log:
			_log.warn("'%s' is not in the include list." % path)
		return

	_include_paths.erase(path)

	var uids_to_remove: Array[int] = []
	for uid: int in _entries.keys():
		var e: FEWEntry = _entries[uid]
		if e.path.begins_with(path):
			uids_to_remove.append(uid)

	_remove_entries(uids_to_remove)
	entries_changed.emit(get_entries())


## Returns the current snapshot of all registered FEWEntry objects.
func get_entries() -> Array[FEWEntry]:
	var result: Array[FEWEntry] = []
	for e: FEWEntry in _entries.values():
		result.append(e)
	return result


## Returns the entry for a given UID, or null if not found.
func get_entry_by_uid(uid: int) -> FEWEntry:
	return _entries.get(uid, null)


## Returns the current list of include paths.
func get_include_paths() -> Array[String]:
	return _include_paths.duplicate()


## Rescans all include paths: registers new files, removes deleted ones,
## and updates paths for any moved files (tracked by UID).
func sync() -> void:
	if _log:
		_log.debug("FileEnumWatcher: syncing...")

	var found_uids: Array[int] = []

	for path in _include_paths:
		if DirAccess.dir_exists_absolute(path):
			_scan_dir_recursive(path, found_uids)
		elif FileAccess.file_exists(path) and _has_matching_extension(path):
			var uid := _register_file(path)
			if uid != ResourceUID.INVALID_ID:
				found_uids.append(uid)

	# Update paths for moved files (UID stays the same, path may differ)
	for uid: int in _entries.keys():
		var e: FEWEntry = _entries[uid]
		var actual_path := ResourceUID.get_id_path(uid)
		if not actual_path.is_empty() and e.path != actual_path:
			if _log:
				_log.debug("  Path updated: %s -> %s" % [e.path, actual_path])
			e.path = actual_path

	# Remove managed entries that were not found during scan
	var uids_to_remove: Array[int] = []
	for uid: int in _entries.keys():
		var e: FEWEntry = _entries[uid]
		var is_managed := false
		for inc in _include_paths:
			if e.path.begins_with(inc):
				is_managed = true
				break
		if is_managed and not uid in found_uids:
			uids_to_remove.append(uid)

	if not uids_to_remove.is_empty():
		_remove_entries(uids_to_remove)

	entries_changed.emit(get_entries())
	if _log:
		_log.debug("FileEnumWatcher: sync complete (%d entries)." % _entries.size())


## Updates the file watcher's snapshot. Call after writing to watched files
## to suppress spurious change events caused by your own writes.
func suppress_next_change() -> void:
	if _file_watcher:
		_file_watcher.update_watched_state()


## Call when the editor window regains focus to trigger an immediate re-check.
func handle_focus_in() -> void:
	if _file_watcher:
		_file_watcher.handle_focus_in()


## Disconnects signals and frees internal resources.
## Must be called when the owning object is freed.
func destroy() -> void:
	if _file_watcher:
		_file_watcher.destroy()
		_file_watcher = null
