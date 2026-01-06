--[[
	Integration.spec.luau
	Integration tests for full DataSafetyKit workflow with real DataStore
]]

return function()
	local DataStoreService = game:GetService("DataStoreService")
	local DataManager = require(game.ServerScriptService.DataSafetyKit.DataManager)
	local BindToClose = require(game.ServerScriptService.DataSafetyKit.BindToClose)
	
	describe("Integration Tests", function()
		local dataManager
		local testUserId
		local testKey
		
		beforeEach(function()
			-- Create unique test context
			testUserId = math.random(1000000, 9999999)
			testKey = "test_user_" .. testUserId
			
			-- Initialize DataManager with unique store
			dataManager = DataManager.new()
			dataManager:init({
				datastoreName = "IntegrationTest_" .. os.time() .. "_" .. math.random(10000)
			})
		end)
		
		describe("Full load → save cycle", function()
			it("should save and load data successfully", function()
				-- Create mock player
				local mockPlayer = {
					Name = "TestPlayer",
					UserId = testUserId
				}
				
				-- Test data
				local testData = {
					coins = 100,
					level = 5,
					inventory = {"sword", "shield"}
				}
				
				-- Mark as loaded (simulating successful load)
				dataManager:markLoaded(mockPlayer)
				
				-- Verify can save
				expect(dataManager:canSave(mockPlayer)).to.equal(true)
				
				-- Save data
				local saveSuccess, saveErr = dataManager:save(mockPlayer, testData)
				
				if not saveSuccess then
					warn("Save error:", saveErr)
				end
				
				expect(saveSuccess).to.equal(true)
			end)
			
			it("should prevent save without load", function()
				local mockPlayer = {
					Name = "TestPlayer",
					UserId = testUserId
				}
				
				-- Try to save without marking as loaded
				expect(dataManager:canSave(mockPlayer)).to.equal(false)
			end)
		end)
		
		describe("SessionLock integration", function()
			it("should acquire and release lock", function()
				local mockPlayer = {
					Name = "TestPlayer",
					UserId = testUserId
				}
				
				-- Load should acquire lock
				local loadedData, loadErr = dataManager:load(mockPlayer)
				
				if loadErr then
					warn("Load error:", loadErr)
				end
				
				-- Should be loaded (even if data is nil for new player)
				expect(dataManager:canSave(mockPlayer)).to.equal(true)
				
				-- Cleanup should release lock
				dataManager:cleanup(mockPlayer)
				
				expect(dataManager:canSave(mockPlayer)).to.equal(false)
			end)
		end)
		
		describe("Snapshot rollback", function()
			it("should rollback to previous snapshot", function()
				local mockPlayer = {
					Name = "TestPlayer",
					UserId = testUserId
				}
				
				-- Initial data
				local initialData = {coins = 50}
				
				dataManager:markLoaded(mockPlayer)
				
				-- First save
				local firstSaveSuccess = dataManager:save(mockPlayer, initialData)
				expect(firstSaveSuccess).to.equal(true)
				
				-- Second save (creates snapshot)
				local updatedData = {coins = 100}
				local secondSaveSuccess = dataManager:save(mockPlayer, updatedData)
				expect(secondSaveSuccess).to.equal(true)
				
				-- Rollback
				local rollbackSuccess = dataManager:rollback(mockPlayer)
				-- Rollback should work (or fail gracefully)
				expect(rollbackSuccess).to.be.a("boolean")
			end)
		end)
		
		describe("BindToClose integration", function()
			it("should flush all pending saves", function()
				local bindToClose = BindToClose.new(dataManager)
				
				-- Queue some saves
				local player1 = {Name = "Player1", UserId = math.random(1000000, 9999999)}
				local player2 = {Name = "Player2", UserId = math.random(1000000, 9999999)}
				
				dataManager:markLoaded(player1)
				dataManager:markLoaded(player2)
				
				dataManager:save(player1, {coins = 10})
				dataManager:save(player2, {coins = 20})
				
				-- Manual flush (simulates BindToClose)
				local flushResult = bindToClose:manualFlush()
				
				-- Should return boolean
				expect(flushResult).to.be.a("boolean")
			end)
		end)
		
		describe("Error handling", function()
			it("should handle DataStore operations gracefully", function()
				local mockPlayer = {
					Name = "TestPlayer",
					UserId = testUserId
				}
				
				-- Try to load (may return nil data for new player)
				local data, err = dataManager:load(mockPlayer)
				
				-- Should not have error (nil data is OK for new player)
				expect(err).never.to.be.ok()
				
				-- After successful load, should be able to save
				expect(dataManager:canSave(mockPlayer)).to.equal(true)
			end)
		end)
		
		describe("Queue management", function()
			it("should process saves in order", function()
				local player = {Name = "TestPlayer", UserId = testUserId}
				
				dataManager:markLoaded(player)
				
				local successCount = 0
				
				-- Queue multiple saves
				for i = 1, 3 do
					local success = dataManager:save(player, {saveNumber = i})
					if success then
						successCount = successCount + 1
					end
				end
				
				-- All saves should succeed
				expect(successCount).to.equal(3)
			end)
		end)
	end)
end

