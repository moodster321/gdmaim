extends RefCounted

# A method named only by a string property saved in a .tscn can still be called by that name.


func run() -> String:
	var path : String = "res://data/tscn_ref.tscn"
	var scene : PackedScene = load(path) as PackedScene
	if scene == null:
		return "%s did not load as a PackedScene" % path
	var node : Node = scene.instantiate()
	var holder : E2EHolder = node as E2EHolder
	if holder == null:
		if node != null:
			node.free()
		return "the root of %s is not an E2EHolder" % path
	var method : String = holder.e2e_callback_name
	holder.free()
	var target : E2ETarget = E2ETarget.new()
	if !target.has_method(method):
		return "E2ETarget has no method '%s'" % method
	var got : Variant = target.call(method)
	if str(got) != "tscn_reference-ok":
		return "'%s' returned %s" % [method, got]
	return ""
