--[[
	RunTests.luau (ModuleScript)
	Use this to manually run tests from command bar:
	
	require(game.ServerScriptService.Tests.RunTests)
]]

local TestEZ = require(game.ReplicatedStorage.Packages.TestEZ)

local testsFolders = {
	game.ServerScriptService.Tests,
}

return function()
	print("========================================")
	print("Running Data Safety Kit Tests...")
	print("========================================")
	
	local results = TestEZ.TestBootstrap:run(testsFolders, TestEZ.Reporters.TextReporter)
	
	print("========================================")
	print(string.format("Tests completed: %d passed, %d failed", 
		results.successCount, 
		results.failureCount
	))
	print("========================================")
	
	return results
end

