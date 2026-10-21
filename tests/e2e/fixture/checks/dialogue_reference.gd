extends RefCounted

# A method named only in a .dialogue file can still be found and called by that name.


func run() -> String:
	var path : String = "res://data/refs.dialogue"
	var text : String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return "%s is missing or empty" % path
	var found : RegExMatch = RegEx.create_from_string("E2EStory\\.(\\w+)\\(").search(text)
	if found == null:
		return "no E2EStory call in '%s'" % text.strip_edges()
	var method : String = found.get_string(1)
	var story : E2EStory = E2EStory.new()
	if !story.has_method(method):
		return "E2EStory has no method '%s'" % method
	var got : Variant = story.call(method)
	if str(got) != "dialogue_reference-ok":
		return "'%s' returned %s" % [method, got]
	return ""
