extends RefCounted

# A script's class_name is still its global name.


func run() -> String:
	var script : Script = load("res://lib/e2e_item.gd") as Script
	if script == null:
		return "res://lib/e2e_item.gd did not load"
	var global_name : StringName = script.get_global_name()
	if global_name != &"E2EItem":
		return "get_global_name() is '%s', expected 'E2EItem'" % global_name
	return ""
