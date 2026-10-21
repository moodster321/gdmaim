extends RefCounted

# has_method() with a literal name finds the method.


func run() -> String:
	if !E2ETarget.new().has_method(&"e2e_literal_method"):
		return "has_method() returned false"
	return ""
