extends RefCounted

# @export and @export_storage fields survive duplicate().


func run() -> String:
	var item : E2EItem = load("res://data/item.tres") as E2EItem
	if item == null:
		return "res://data/item.tres did not load as E2EItem"
	if item.e2e_power != 7 or item.e2e_secret != "abc":
		return "loaded item is %d/'%s', expected 7/'abc'" % [item.e2e_power, item.e2e_secret]
	var copy : E2EItem = item.duplicate() as E2EItem
	if copy == null:
		return "duplicate() is not an E2EItem"
	if copy.e2e_power != 7 or copy.e2e_secret != "abc":
		return "duplicate() is %d/'%s', expected 7/'abc'" % [copy.e2e_power, copy.e2e_secret]
	return ""
