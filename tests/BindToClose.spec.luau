--[[
	BindToClose.spec.luau
	Unit tests for BindToClose module
]]

return function()
	local BindToClose = require(game.ServerScriptService.DataSafetyKit.BindToClose)
	local DataManager = require(game.ServerScriptService.DataSafetyKit.DataManager)
	
	describe("BindToClose module", function()
		local bindToClose
		local dataManager
		
		beforeEach(function()
			dataManager = DataManager.new()
			dataManager:init({datastoreName = "Test_" .. os.time()})
			bindToClose = BindToClose.new(dataManager)
		end)
		
		it("should create new BindToClose instance", function()
			expect(bindToClose).to.be.ok()
		end)
		
		it("should have register method", function()
			expect(bindToClose.register).to.be.a("function")
		end)
		
		it("should have onShutdown method", function()
			expect(bindToClose.onShutdown).to.be.a("function")
		end)
		
		it("should have manualFlush method", function()
			expect(bindToClose.manualFlush).to.be.a("function")
		end)
		
		-- Note: manualFlush and _handleShutdown require DataStore
		-- These are tested in integration tests
	end)
end

