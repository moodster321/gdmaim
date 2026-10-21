extends RefCounted

# Walking the base scripts finds a class by its global name, the way a "script extends class"
# helper does.


func run() -> String:
	var script : Script = load("res://lib/e2e_item.gd") as Script
	var seen : PackedStringArray = []
	while script != null:
		var global_name : StringName = script.get_global_name()
		if global_name == &"E2EBase":
			return ""
		seen.append("'%s'" % global_name)
		script = script.get_base_script()
	return "no script in the chain is named E2EBase (saw %s)" % ", ".join(seen)
