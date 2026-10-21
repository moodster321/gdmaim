extends RefCounted

# Guard: a translation CSV still ships its imported translation.


func run() -> String:
	TranslationServer.set_locale("en")
	var got : String = tr("E2E_HELLO")
	if got != "Hello e2e":
		return "tr() returned '%s' for locale '%s', expected 'Hello e2e'" % [got, TranslationServer.get_locale()]
	return ""
