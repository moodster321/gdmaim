extends RefCounted

# The global class list, which an export reads from its class cache, names a script by its
# class_name.


func run() -> String:
	var path : String = "res://lib/e2e_chain.gd"
	for entry : Dictionary in ProjectSettings.get_global_class_list():
		if entry["path"] != path:
			continue
		if entry["class"] != &"E2EChain":
			return "the global class list names %s '%s'" % [path, entry["class"]]
		return ""
	return "%s is not in the global class list" % path
