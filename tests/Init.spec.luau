--[[
	Init.spec.luau
	Unit tests for Init module (Public API)
]]

return function()
	local SaveGuard = require(game.ServerScriptService.DataSafetyKit)
	
	describe("SaveGuard (Public API)", function()
		describe("API surface", function()
			it("should expose init method", function()
				expect(SaveGuard.init).to.be.a("function")
			end)
			
			it("should expose onPlayerAdded method", function()
				expect(SaveGuard.onPlayerAdded).to.be.a("function")
			end)
			
			it("should expose onPlayerRemoving method", function()
				expect(SaveGuard.onPlayerRemoving).to.be.a("function")
			end)
			
			it("should expose safeSave method", function()
				expect(SaveGuard.safeSave).to.be.a("function")
			end)
			
			it("should expose rollback method", function()
				expect(SaveGuard.rollback).to.be.a("function")
			end)
			
			it("should expose onError method", function()
				expect(SaveGuard.onError).to.be.a("function")
			end)
			
			it("should expose getPlayerState method", function()
				expect(SaveGuard.getPlayerState).to.be.a("function")
			end)
			
			it("should expose isUsingMemoryStore method", function()
				expect(SaveGuard.isUsingMemoryStore).to.be.a("function")
			end)
		end)
		
		describe("error handling", function()
			it("should have onError method", function()
				expect(SaveGuard.onError).to.be.a("function")
			end)
		end)
		
		-- Note: onPlayerAdded/onPlayerRemoving/safeSave require real players
		-- These are tested in integration tests
	end)
end

