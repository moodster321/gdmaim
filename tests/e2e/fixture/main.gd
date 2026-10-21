extends Node

# Runs every check and prints one "E2E <id> PASS|FAIL [reason]" line each, for tests/run_e2e.py.

const CHECKS : Array[String] = [
	"res://checks/obfuscation_active.gd",
	"res://checks/typed_access.gd",
	"res://checks/translation_csv.gd",
	"res://checks/export_duplicate.gd",
	"res://checks/export_save_roundtrip.gd",
	"res://checks/legacy_save_load.gd",
	"res://checks/keep_csv_exported.gd",
	"res://checks/init_order.gd",
	"res://checks/class_identity.gd",
	"res://checks/script_extends_class.gd",
	"res://checks/class_cache_consistent.gd",
	"res://checks/has_method_literal.gd",
	"res://checks/call_literal.gd",
	"res://checks/callable_literal.gd",
	"res://checks/get_set_literal.gd",
	"res://checks/connect_literal.gd",
	"res://checks/dialogue_reference.gd",
	"res://checks/json_reference.gd",
	"res://checks/tscn_reference.gd",
]


func _ready() -> void:
	var errors : ErrorLog = ErrorLog.new()
	OS.add_logger(errors)
	for path : String in CHECKS:
		errors.clear()
		var verdict : String = _run_check(path, errors)
		print("E2E %s %s" % [path.get_file().get_basename(), verdict])
	OS.remove_logger(errors)
	print("E2E_DONE %d" % CHECKS.size())
	get_tree().quit()


# Returns "PASS" or "FAIL <reason>".
func _run_check(path : String, errors : ErrorLog) -> String:
	var script : Script = load(path) as Script
	if script == null or !script.can_instantiate():
		return "FAIL script did not load"
	# A runtime error aborts run() and returns the default of its return type, "" for a String,
	# which would read as a pass. So any error logged while the check runs fails it too.
	var result : Variant = script.new().run()
	if !(result is String):
		return "FAIL run() returned %s" % [result]
	if result != "":
		return "FAIL %s" % result
	if errors.count() > 0:
		return "FAIL %d error(s) while running, first: %s" % [errors.count(), errors.first()]
	return "PASS"


# Records the errors (not warnings) the engine and scripts log.
class ErrorLog extends Logger:
	var _mutex : Mutex = Mutex.new()
	var _errors : PackedStringArray = []

	func _log_error(_function : String, _file : String, _line : int, code : String, rationale : String, _editor_notify : bool, error_type : int, _script_backtraces : Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		_errors.append(rationale if !rationale.is_empty() else code)
		_mutex.unlock()

	func _log_message(_message : String, _error : bool) -> void:
		pass

	func clear() -> void:
		_mutex.lock()
		_errors.clear()
		_mutex.unlock()

	func count() -> int:
		_mutex.lock()
		var n : int = _errors.size()
		_mutex.unlock()
		return n

	func first() -> String:
		_mutex.lock()
		var message : String = _errors[0] if !_errors.is_empty() else ""
		_mutex.unlock()
		return message
