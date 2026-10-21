extends RefCounted

# Member initializers run in declaration order: each link of the chain reads the one before it.


func run() -> String:
	var chain : E2EChain = E2EChain.new()
	if chain.e2e_c11 != 12:
		return "last link is %d, expected 12 (first link %d)" % [chain.e2e_c11, chain.e2e_c0]
	return ""
