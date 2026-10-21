extends RefCounted

# A method named only in a .json file can still be called by that name.


func run() -> String:
	var path : String = "res://data/refs.json"
	var text : String = FileAccess.get_file_as_string(path)
	var data : Variant = JSON.parse_string(text)
	if !(data is Dictionary):
		return "%s did not parse to a Dictionary: '%s'" % [path, text.strip_edges()]
	var method : String = str((data as Dictionary).get("method", ""))
	var target : E2ETarget = E2ETarget.new()
	if !target.has_method(method):
		return "E2ETarget has no method '%s'" % method
	var got : Variant = target.call(method)
	if str(got) != "json_reference-ok":
		return "'%s' returned %s" % [method, got]
	return ""
