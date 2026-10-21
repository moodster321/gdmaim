extends RefCounted

# Guard: typed member access keeps working once names are rewritten.


func run() -> String:
	var target : E2ETarget = E2ETarget.new()
	if target.e2e_typed_value != 3:
		return "typed member is %d, expected 3" % target.e2e_typed_value
	var got : String = target.e2e_typed_method()
	if got != "typed-ok":
		return "typed method returned '%s', expected 'typed-ok'" % got
	return ""
