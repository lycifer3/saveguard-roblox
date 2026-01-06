--[[
	DataManager.spec.luau
	Unit tests for DataManager module
]]

return function()
	local DataManager = require(game.ServerScriptService.DataSafetyKit.DataManager)
	
	describe("DataManager module", function()
		local dataManager
		
		beforeEach(function()
			dataManager = DataManager.new()
		end)
		
		describe("initialization", function()
			it("should create new DataManager instance", function()
				expect(dataManager).to.be.ok()
			end)
			
			it("should initialize with config", function()
				local config = {
					datastoreName = "TestStore_" .. os.time()
				}
				
				-- Should not throw
				expect(function()
					dataManager:init(config)
				end).never.to.throw()
			end)
		end)
		
		describe("canSave", function()
			it("should return false for unknown player", function()
				local mockPlayer = {
					Name = "TestPlayer",
					UserId = 12345
				}
				
				expect(dataManager:canSave(mockPlayer)).to.equal(false)
			end)
		end)
		
		describe("markLoaded", function()
			it("should mark player as loaded", function()
				local mockPlayer = {
					Name = "TestPlayer",
					UserId = 12345
				}
				
				dataManager:markLoaded(mockPlayer)
				expect(dataManager:canSave(mockPlayer)).to.equal(true)
			end)
		end)
		
		describe("getPlayerState", function()
			it("should return nil for unknown player", function()
				local mockPlayer = {
					Name = "TestPlayer",
					UserId = 12345
				}
				
				expect(dataManager:getPlayerState(mockPlayer)).never.to.be.ok()
			end)
			
			it("should return state for loaded player", function()
				local mockPlayer = {
					Name = "TestPlayer",
					UserId = 12345
				}
				
				dataManager:markLoaded(mockPlayer)
				local state = dataManager:getPlayerState(mockPlayer)
				
				expect(state).to.be.ok()
				expect(state.loaded).to.equal(true)
				expect(state.userId).to.equal(12345)
			end)
		end)
		
		describe("getQueueSize", function()
			it("should return queue size", function()
				local size = dataManager:getQueueSize()
				expect(size).to.be.a("number")
				expect(size).to.equal(0)
			end)
		end)
		
		describe("isUsingMemoryStore", function()
			it("should report MemoryStore usage", function()
				-- Need to init first
				dataManager:init({datastoreName = "Test"})
				
				local using = dataManager:isUsingMemoryStore()
				expect(using).to.be.a("boolean")
				print("  Using MemoryStore:", using)
			end)
		end)
		
		-- Note: load/save/cleanup tests require DataStore access
		-- These are tested in integration tests
	end)
end

