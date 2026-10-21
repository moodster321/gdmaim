class_name E2ETarget
extends RefCounted

signal e2e_ping

var e2e_counter : int = 0
var e2e_typed_value : int = 3
var e2e_hidden_member : int = 1


func e2e_typed_method() -> String:
	return "typed-ok"


func e2e_literal_method() -> String:
	return "has_method_literal-ok"


func e2e_call_target() -> String:
	return "call_literal-ok"


func e2e_callable_target() -> String:
	return "callable_literal-ok"


func e2e_json_target() -> String:
	return "json_reference-ok"


func e2e_tscn_target() -> String:
	return "tscn_reference-ok"
