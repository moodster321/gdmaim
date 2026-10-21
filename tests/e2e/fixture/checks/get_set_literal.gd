extends RefCounted

# set() and get() with a literal name reach the same member as typed access.


func run() -> String:
	var target : E2ETarget = E2ETarget.new()
	target.set(&"e2e_counter", 5)
	var got : Variant = target.get(&"e2e_counter")
	if typeof(got) != TYPE_INT or got != 5:
		return "get() returned %s after set() to 5" % [got]
	if target.e2e_counter != 5:
		return "typed read is %d after set() to 5" % target.e2e_counter
	return ""
