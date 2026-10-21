extends RefCounted

# call() with a literal name reaches the method.


func run() -> String:
	var got : Variant = E2ETarget.new().call(&"e2e_call_target")
	if str(got) != "call_literal-ok":
		return "call() returned %s" % [got]
	return ""
