extends RefCounted

# A CSV imported with importer="keep" ships as a plain file.


func run() -> String:
	var path : String = "res://data/keep.csv"
	if !FileAccess.file_exists(path):
		return "%s is not in the PCK" % path
	var file : FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "could not open %s: %s" % [path, error_string(FileAccess.get_open_error())]
	var line : String = file.get_line().strip_edges()
	if line != "a,b":
		return "first line is '%s', expected 'a,b'" % line
	return ""
