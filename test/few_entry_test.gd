# GdUnit generated TestSuite
class_name FEWEntryTest
extends GdUnitTestSuite

const FEWEntryClass := preload("res://addons/godot-D_FileEnumWatch/core/few_entry.gd")


func test_entry_properties() -> void:
	var entry := FEWEntryClass.new()
	entry.path = "res://dummy_path.tscn"
	entry.uid = 12345
	entry.name = "DUMMY_PATH"

	assert_that(entry.path).is_equal("res://dummy_path.tscn")
	assert_that(entry.uid).is_equal(12345)
	assert_that(entry.name).is_equal("DUMMY_PATH")


func test_from_path_valid() -> void:
	var path := "res://addons/godot-D_FileEnumWatch/core/few_entry.gd"
	var entry := FEWEntryClass.from_path(path, "FEW_ENTRY")
	assert_that(entry).is_not_null()
	assert_that(entry.path).is_equal(path)
	assert_that(entry.uid).is_not_equal(ResourceUID.INVALID_ID)
	assert_that(entry.name).is_equal("FEW_ENTRY")


func test_from_path_invalid() -> void:
	var path := "res://does_not_exist_file_abc.tscn"
	var entry := FEWEntryClass.from_path(path, "INVALID")
	assert_that(entry).is_null()


func test_is_valid() -> void:
	var entry := FEWEntryClass.new()
	assert_that(entry.is_valid()).is_false()

	entry.path = "res://dummy.tscn"
	assert_that(entry.is_valid()).is_false()

	entry.uid = 100
	assert_that(entry.is_valid()).is_true()
