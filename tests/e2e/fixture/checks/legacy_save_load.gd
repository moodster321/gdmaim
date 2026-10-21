extends RefCounted

# A save written by a build without obfuscation (real field names) still loads.


func run() -> String:
	var source : String = FileAccess.get_file_as_string("res://data/legacy_save.txt")
	if source.is_empty():
		return "res://data/legacy_save.txt is missing or empty"
	var path : String = "user://e2e_%s_legacy_save.tres" % OS.get_environment("GDMAIM_E2E_BUILD")
	var file : FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "could not write %s: %s" % [path, error_string(FileAccess.get_open_error())]
	file.store_string(source)
	file.close()
	var item : E2EItem = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as E2EItem
	if item == null:
		return "%s did not load as E2EItem" % path
	if item.e2e_power != 11 or item.e2e_secret != "old":
		return "old save loads as %d/'%s', expected 11/'old'" % [item.e2e_power, item.e2e_secret]
	return ""
