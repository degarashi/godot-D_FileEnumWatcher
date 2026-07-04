@tool
## Utility class providing pure-function helpers for generating GDScript enum code
## from a list of FEWEntry objects. Has no side effects; all methods are static.
class_name FEWEnumCodegen
extends RefCounted

# ------------- [Private Static Variable] -------------
static var _sanitize_regex: RegEx


# ------------- [Public Static Method] -------------
## Sanitizes an arbitrary string into a valid GDScript enum key.
## Strips non-alphanumeric / non-underscore chars, replaces spaces with _,
## uppercases the result, and prepends "_" if it starts with a digit.
static func sanitize_key(text: String) -> String:
	if not _sanitize_regex:
		_sanitize_regex = RegEx.new()
		_sanitize_regex.compile("[^a-zA-Z0-9_ ]")
	var cleaned: String = _sanitize_regex.sub(text, "", true)
	cleaned = cleaned.replace(" ", "_").to_upper().strip_edges()
	if cleaned.is_empty():
		return "_UNNAMED"
	if cleaned[0].is_valid_int():
		cleaned = "_" + cleaned
	return cleaned


## Builds an enum block string from an array of FEWEntry objects.
##
## @param entries       Array of FEWEntry (name and uid must be valid)
## @param enum_name     The GDScript enum name (e.g. "Id", "SceneId")
## @param none_value    Value for the NONE sentinel. Defaults to ResourceUID.INVALID_ID.
## @return              A GDScript enum block, e.g.:
##                        enum Id {
##                            NONE = -1,
##                            MY_SCENE = 123456,
##                        }
static func build_enum(
	entries: Array[FEWEntry],
	enum_name: String,
	none_value: int = ResourceUID.INVALID_ID
) -> String:
	var lines := PackedStringArray()
	lines.append("enum %s {" % enum_name)
	lines.append("\tNONE = %d," % none_value)

	var sorted := entries.duplicate()
	sorted.sort_custom(
		func(a: FEWEntry, b: FEWEntry) -> bool:
			return a.name.naturalnocasecmp_to(b.name) < 0
	)

	for entry in sorted:
		if entry.is_valid():
			lines.append("\t%s = %d," % [entry.name, entry.uid])

	lines.append("}")
	return "\n".join(lines) + "\n"


## Replaces an existing named enum block inside a GDScript source string.
## If the enum block is not found, appends it at the end.
## This allows hand-written code in the same file to be preserved.
##
## @param source     Full source text of the .gd file
## @param enum_name  The name of the enum to replace (e.g. "Id")
## @param new_block  The replacement enum block (as returned by build_enum)
## @return           Updated source text
static func replace_enum_in_source(
	source: String,
	enum_name: String,
	new_block: String
) -> String:
	var pattern := RegEx.new()
	# Matches: enum <name> { ... } including nested whitespace / newlines
	var err := pattern.compile("enum\\s+%s\\s*\\{[^}]*\\}" % enum_name)
	if err != OK:
		return source + "\n" + new_block

	var result := pattern.sub(source, new_block.strip_edges(), false)
	if result == source:
		# Enum not found in source → append
		return source.rstrip("\n") + "\n\n" + new_block
	return result


## Builds a UID → enum key name lookup dictionary from an entry list.
## Useful for runtime reverse-lookups without parsing GDScript.
##
## @param entries  Array of FEWEntry
## @return         Dictionary[int, String] mapping uid → name
static func build_uid_to_name_map(entries: Array[FEWEntry]) -> Dictionary:
	var map: Dictionary = {}
	for entry in entries:
		if entry.is_valid():
			map[entry.uid] = entry.name
	return map


## Builds a name → UID lookup dictionary from an entry list.
##
## @param entries  Array of FEWEntry
## @return         Dictionary[String, int] mapping name → uid
static func build_name_to_uid_map(entries: Array[FEWEntry]) -> Dictionary:
	var map: Dictionary = {}
	for entry in entries:
		if entry.is_valid():
			map[entry.name] = entry.uid
	return map
