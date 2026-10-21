extends RefCounted

# Guard: proves the obfuscated build really renamed something. The member name is built at
# runtime, so no string literal in the fixture ever equals it.


func run() -> String:
	var build : String = OS.get_environment("GDMAIM_E2E_BUILD")
	var member : String = "e2e_hidden" + "_member"
	var found : bool = false
	for property : Dictionary in E2ETarget.new().get_property_list():
		if property["name"] == member:
			found = true
	if build == "obfuscated":
		return "%s is still in the property list" % member if found else ""
	if build == "plain":
		return "" if found else "%s is missing from the property list" % member
	return "GDMAIM_E2E_BUILD is '%s', expected obfuscated or plain" % build
