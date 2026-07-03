# GdUnit generated TestSuite
class_name FEWEnumCodegenTest
extends GdUnitTestSuite

const FEWEnumCodegenClass := preload("res://addons/godot-D_FileEnumWatch/core/few_enum_codegen.gd")
const FEWEntryClass := preload("res://addons/godot-D_FileEnumWatch/core/few_entry.gd")


func test_sanitize_key() -> void:
	assert_that(FEWEnumCodegenClass.sanitize_key("my scene")).is_equal("MY_SCENE")
	assert_that(FEWEnumCodegenClass.sanitize_key("123_scene")).is_equal("_123_SCENE")
	assert_that(FEWEnumCodegenClass.sanitize_key("special-chars!@#")).is_equal("SPECIALCHARS")
	assert_that(FEWEnumCodegenClass.sanitize_key("")).is_equal("_UNNAMED")
	assert_that(FEWEnumCodegenClass.sanitize_key("   ")).is_equal("___")


func test_build_enum() -> void:
	var entry1 := FEWEntryClass.new()
	entry1.path = "res://a.tscn"
	entry1.uid = 100
	entry1.name = "A"

	var entry2 := FEWEntryClass.new()
	entry2.path = "res://b.tscn"
	entry2.uid = 200
	entry2.name = "B"

	var entries: Array[FEWEntry] = [entry2, entry1]  # Unsorted input

	var enum_str := FEWEnumCodegenClass.build_enum(entries, "MyEnum", -1)
	var expected := "enum MyEnum {\n\tNONE = -1,\n\tA = 100,\n\tB = 200,\n}\n"
	assert_that(enum_str).is_equal(expected)


func test_replace_enum_in_source_replace() -> void:
	var source := "extends Node\n\nenum MyEnum {\n\tNONE = -1,\n\tOLD = 999,\n}\n\nfunc _ready() -> void:\n\tpass"
	var new_block := "enum MyEnum {\n\tNONE = -1,\n\tNEW = 100,\n}\n"

	var updated := FEWEnumCodegenClass.replace_enum_in_source(source, "MyEnum", new_block)
	var expected := "extends Node\n\nenum MyEnum {\n\tNONE = -1,\n\tNEW = 100,\n}\n\nfunc _ready() -> void:\n\tpass"
	assert_that(updated).is_equal(expected)


func test_replace_enum_in_source_append() -> void:
	var source := "extends Node\n\nfunc _ready() -> void:\n\tpass"
	var new_block := "enum MyEnum {\n\tNONE = -1,\n\tNEW = 100,\n}\n"

	var updated := FEWEnumCodegenClass.replace_enum_in_source(source, "MyEnum", new_block)
	var expected := "extends Node\n\nfunc _ready() -> void:\n\tpass\n\nenum MyEnum {\n\tNONE = -1,\n\tNEW = 100,\n}\n"
	assert_that(updated).is_equal(expected)


func test_build_uid_to_name_map() -> void:
	var entry1 := FEWEntryClass.new()
	entry1.path = "res://a.tscn"
	entry1.uid = 100
	entry1.name = "A"

	var entry2 := FEWEntryClass.new()
	entry2.path = "res://b.tscn"
	entry2.uid = 200
	entry2.name = "B"

	var entries: Array[FEWEntry] = [entry1, entry2]
	var res_map := FEWEnumCodegenClass.build_uid_to_name_map(entries)

	assert_that(res_map.size()).is_equal(2)
	assert_that(res_map[100]).is_equal("A")
	assert_that(res_map[200]).is_equal("B")


func test_build_name_to_uid_map() -> void:
	var entry1 := FEWEntryClass.new()
	entry1.path = "res://a.tscn"
	entry1.uid = 100
	entry1.name = "A"

	var entry2 := FEWEntryClass.new()
	entry2.path = "res://b.tscn"
	entry2.uid = 200
	entry2.name = "B"

	var entries: Array[FEWEntry] = [entry1, entry2]
	var res_map := FEWEnumCodegenClass.build_name_to_uid_map(entries)

	assert_that(res_map.size()).is_equal(2)
	assert_that(res_map["A"]).is_equal(100)
	assert_that(res_map["B"]).is_equal(200)
