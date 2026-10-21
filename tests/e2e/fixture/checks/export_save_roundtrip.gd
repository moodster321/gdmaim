extends RefCounted

# @export and @export_storage fields survive a ResourceSaver round trip.


func run() -> String:
	var item : E2EItem = load("res://data/item.tres") as E2EItem
	if item == null:
		return "res://data/item.tres did not load as E2EItem"
	var path : String = "user://e2e_%s_roundtrip.tres" % OS.get_environment("GDMAIM_E2E_BUILD")
	var err : Error = ResourceSaver.save(item, path)
	if err != OK:
		return "ResourceSaver.save(%s) failed: %s" % [path, error_string(err)]
	var back : E2EItem = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as E2EItem
	if back == null:
		return "%s did not load back as E2EItem" % path
	if back.e2e_power != 7 or back.e2e_secret != "abc":
		return "saved item loads back as %d/'%s', expected 7/'abc'" % [back.e2e_power, back.e2e_secret]
	return ""
