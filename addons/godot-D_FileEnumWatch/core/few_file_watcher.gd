@tool
## Watches the Godot editor filesystem for changes to a configurable set of files
## and emits a signal when additions, deletions, or modifications are detected.
##
## Connects to EditorFileSystem.filesystem_changed and sources_changed signals.
## Uses a deferred two-frame debounce to coalesce rapid consecutive events.
## Can also be triggered manually via handle_focus_in() or force_sync().
class_name FEWFileWatcher
extends RefCounted

# ------------- [Signal] -------------
## Emitted when one or more watched files change.
## @param files  Paths of all files that were added, removed, or modified.
signal files_changed(files: PackedStringArray)

# ------------- [Private Variable] -------------
var _tree: SceneTree
var _get_watch_files_fn: Callable
var _last_files: PackedStringArray = []
var _last_modified_times: Dictionary = {}
var _accumulated_changes: Dictionary = {}
var _is_syncing: bool = false
var _is_exiting: bool = false


# ------------- [Callbacks] -------------
## Called when the editor filesystem reports a change.
## Compares modification times and schedules a deferred sync when differences
## are detected.
func _on_filesystem_changed(_unused: Variant = null) -> void:
	if _is_syncing or _is_exiting:
		return

	var current_files := _get_current_files()
	var changed_files := _get_changed_files(current_files)
	if not changed_files.is_empty():
		for path in changed_files:
			_accumulated_changes[path] = true
		_deferred_sync.call_deferred()


# ------------- [Private Method] -------------
func _get_current_files() -> PackedStringArray:
	if _get_watch_files_fn.is_valid():
		var res: Variant = _get_watch_files_fn.call()
		if res is PackedStringArray:
			return res
		elif res is Array:
			return PackedStringArray(res)
	return PackedStringArray()


func _get_changed_files(current_files: PackedStringArray) -> PackedStringArray:
	var changed_files := PackedStringArray()
	var current_set: Dictionary = {}
	for path in current_files:
		current_set[path] = true

	# Detect deleted files
	for path in _last_files:
		if not current_set.has(path):
			changed_files.append(path)

	# Detect new or modified files
	for path in current_files:
		var mtime: int = FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0
		if not _last_modified_times.has(path) or _last_modified_times[path] != mtime:
			changed_files.append(path)

	return changed_files


func _update_state(current_files: PackedStringArray) -> void:
	_last_files = current_files
	_last_modified_times.clear()
	for path in current_files:
		_last_modified_times[path] = FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0


## Deferred two-frame debounce: coalesces consecutive change events before
## emitting files_changed.
func _deferred_sync() -> void:
	if _is_exiting or not is_instance_valid(_tree):
		return
	await _tree.process_frame

	if _is_exiting or not is_instance_valid(_tree):
		return
	await _tree.process_frame

	if _is_exiting:
		return

	var current_files := _get_current_files()
	var changed_files := _get_changed_files(current_files)
	for path in changed_files:
		_accumulated_changes[path] = true

	if not _accumulated_changes.is_empty():
		var emit_files := PackedStringArray(_accumulated_changes.keys())
		_accumulated_changes.clear()
		_update_state(current_files)
		files_changed.emit(emit_files)


# ------------- [Public Method] -------------
## Initializes the watcher.
##
## @param tree               SceneTree used for frame-awaiting. Pass null to
##                           auto-detect from Engine.get_main_loop().
## @param get_watch_files_fn A Callable() -> PackedStringArray that returns
##                           the current list of files to watch. Required;
##                           the watcher emits nothing if this is invalid.
func _init(tree: SceneTree = null, get_watch_files_fn := Callable()) -> void:
	_tree = tree if tree else (Engine.get_main_loop() as SceneTree)
	_get_watch_files_fn = get_watch_files_fn

	# Record initial state
	var current_files := _get_current_files()
	_update_state(current_files)

	if Engine.is_editor_hint():
		var fs := EditorInterface.get_resource_filesystem()
		if fs:
			fs.filesystem_changed.connect(_on_filesystem_changed)
			if fs.has_signal("sources_changed"):
				fs.sources_changed.connect(_on_filesystem_changed)


## Disconnects all signals. Call this when the owning object is freed.
func destroy() -> void:
	_is_exiting = true
	if not Engine.is_editor_hint():
		return
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		if fs.filesystem_changed.is_connected(_on_filesystem_changed):
			fs.filesystem_changed.disconnect(_on_filesystem_changed)
		if fs.has_signal("sources_changed") and fs.sources_changed.is_connected(_on_filesystem_changed):
			fs.sources_changed.disconnect(_on_filesystem_changed)


## Updates the internal snapshot of watched file states.
## Call this after making local writes to watched files so the next filesystem
## change event does not treat your own writes as external changes.
func update_watched_state() -> void:
	var current_files := _get_current_files()
	_update_state(current_files)


## Forces a full filesystem scan and immediately checks for changes.
## Intended to be called when the editor window regains focus.
func handle_focus_in() -> void:
	if _is_syncing or _is_exiting:
		return
	if not Engine.is_editor_hint():
		return
	var fs := EditorInterface.get_resource_filesystem()
	if fs:
		fs.scan()
	_on_filesystem_changed()


## Clears the cached state and schedules a full re-check on the next frame.
func force_sync() -> void:
	_last_modified_times.clear()
	_last_files.clear()
	_deferred_sync.call_deferred()


## Controls whether syncing is suppressed.
## Set to true while performing writes to avoid re-entrant change events.
func set_syncing(syncing: bool) -> void:
	_is_syncing = syncing
