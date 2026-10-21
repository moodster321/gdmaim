extends RefCounted

# A Callable built from an object and a literal method name is callable.


func run() -> String:
	var target : E2ETarget = E2ETarget.new()
	var callable : Callable = Callable(target, &"e2e_callable_target")
	if !callable.is_valid():
		return "the Callable is not valid"
	var got : Variant = callable.call()
	if str(got) != "callable_literal-ok":
		return "the Callable returned %s" % [got]
	return ""
