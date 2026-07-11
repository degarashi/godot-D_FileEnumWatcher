# GdUnit generated TestSuite
class_name FEWFileWatcherTest
extends GdUnitTestSuite

const FEWFileWatcherClass := preload("uid://2u0usajy085y")
var _test_files: Array[String] = []


func test_watcher_initialization() -> void:
	var files := PackedStringArray(["res://a.tscn"])
	var get_files := func() -> PackedStringArray: return files
	var watcher := FEWFileWatcherClass.new(null, get_files)

	assert_that(watcher).is_not_null()
	watcher.destroy()


func test_watcher_detects_changes() -> void:
	_test_files = ["res://a.tscn"]
	var get_files := func() -> Array[String]: return _test_files

	var watcher := FEWFileWatcherClass.new(null, get_files)

	# Simulate adding a file
	_test_files.append("res://b.tscn")

	var context := {"signal_received": false, "emitted_files": PackedStringArray()}
	watcher.files_changed.connect(
		func(changed: PackedStringArray) -> void:
			context.signal_received = true
			context.emitted_files = changed
	)

	# Trigger filesystem change check
	watcher._on_filesystem_changed()

	# Await the deferred sync signal emission
	await watcher.files_changed

	assert_that(context.signal_received).is_true()
	assert_that(context.emitted_files.size()).is_equal(1)
	assert_that(context.emitted_files[0]).is_equal("res://b.tscn")

	watcher.destroy()
