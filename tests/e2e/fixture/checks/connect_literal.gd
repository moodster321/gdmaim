extends RefCounted

# connect() with a literal signal name hooks the signal that typed emit() fires.


func run() -> String:
	var target : E2ETarget = E2ETarget.new()
	# A lambda can't reassign a captured local, so it flips an element of a shared Array.
	var fired : Array[bool] = [false]
	var on_ping : Callable = func() -> void:
		fired[0] = true
	var err : int = target.connect(&"e2e_ping", on_ping)
	target.e2e_ping.emit()
	if !fired[0]:
		return "the handler did not run (connect() returned %s)" % error_string(err)
	return ""
