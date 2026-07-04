@tool
## Lightweight data class representing a single watched resource file entry.
## Holds the resolved path, UID, and sanitized name used as an Enum key.
class_name FEWEntry
extends RefCounted

# ------------- [Public Variable] -------------
## Absolute res:// path to the file
var path: String = ""

## Godot ResourceUID value. ResourceUID.INVALID_ID if unresolved.
var uid: int = ResourceUID.INVALID_ID

## Sanitized identifier string used as the Enum key (e.g. "MY_SCENE")
var name: String = ""


# ------------- [Public Method] -------------
## Factory: creates a FEWEntry from a file path.
## Returns null if the UID cannot be resolved.
static func from_path(file_path: String, sanitized_name: String) -> FEWEntry:
	var resolved_uid := ResourceLoader.get_resource_uid(file_path)
	if resolved_uid == ResourceUID.INVALID_ID:
		return null

	var entry := FEWEntry.new()
	entry.path = file_path
	entry.uid = resolved_uid
	entry.name = sanitized_name
	return entry


## Returns true if both path and uid are valid.
func is_valid() -> bool:
	return not path.is_empty() and uid != ResourceUID.INVALID_ID
