# GdUnit generated TestSuite
class_name FileEnumWatcherTest
extends GdUnitTestSuite

const FileEnumWatcherClass := preload("uid://dwmr62sf1ulhw")


func test_extensions() -> void:
	var watcher := FileEnumWatcherClass.new()
	assert_that(watcher.get_extensions()).is_equal([".tscn"])

	watcher.set_extensions([".tscn", ".tres"])
	assert_that(watcher.get_extensions()).is_equal([".tscn", ".tres"])

	watcher.destroy()


func test_include_paths_management() -> void:
	var watcher := FileEnumWatcherClass.new()
	watcher.set_extensions([".gd"])

	var path1 := "res://addons/godot-D_FileEnumWatcher/core/few_entry.gd"
	var path2 := "res://addons/godot-D_FileEnumWatcher/core/"

	# Add first path (specific file)
	var added1 := watcher.add_include_path(path1)
	assert_that(added1).is_true()
	assert_that(watcher.get_include_paths()).is_equal([path1])

	# Add parent path (directory), which should make the previous redundant path disappear
	var added2 := watcher.add_include_path(path2)
	assert_that(added2).is_true()
	assert_that(watcher.get_include_paths()).is_equal([path2])

	# Try adding the specific file again, should fail as it is already covered
	var added3 := watcher.add_include_path(path1)
	assert_that(added3).is_false()

	# Remove include path
	watcher.remove_include_path(path2)
	assert_that(watcher.get_include_paths()).is_empty()

	watcher.destroy()
