--[[
	BasicUsage.server.luau
	Simple example: Coins and Level system with SaveGuard
]]

local Players = game:GetService("Players")
local SaveGuard = require(game.ServerScriptService.SaveGuard)

print("[Example] Initializing SaveGuard...")

-- Initialize with simple mode
SaveGuard.init({
	datastoreName = "ExampleData_v1"
})

-- Error handling (optional)
SaveGuard.onError(function(err)
	warn("[SaveGuard Error]", err)
end)

print("[Example] SaveGuard initialized!")

-- Helper: Create leaderstats
local function createLeaderstats(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = leaderstats
	
	return leaderstats
end

-- Player Join: Load data
Players.PlayerAdded:Connect(function(player)
	print(string.format("[Example] Player %s joined, loading data...", player.Name))
	
	-- Create leaderstats first
	local leaderstats = createLeaderstats(player)
	
	-- Load data with SaveGuard
	SaveGuard.onPlayerAdded(player, function(data)
		if data then
			-- Existing player - restore data
			print(string.format("[Example] Loaded data for %s:", player.Name))
			print("  Coins:", data.coins)
			print("  Level:", data.level)
			
			leaderstats.Coins.Value = data.coins or 0
			leaderstats.Level.Value = data.level or 1
		else
			-- New player - set defaults
			print(string.format("[Example] %s is a new player, setting defaults", player.Name))
			
			leaderstats.Coins.Value = 0
			leaderstats.Level.Value = 1
		end
		
		print(string.format("[Example] %s is ready to play!", player.Name))
	end)
end)

-- Player Leave: Save data
Players.PlayerRemoving:Connect(function(player)
	print(string.format("[Example] Player %s leaving, saving data...", player.Name))
	
	SaveGuard.onPlayerRemoving(player, function()
		local leaderstats = player:FindFirstChild("leaderstats")
		if not leaderstats then
			return {coins = 0, level = 1}
		end
		
		local data = {
			coins = leaderstats.Coins.Value,
			level = leaderstats.Level.Value
		}
		
		print(string.format("[Example] Saving data for %s:", player.Name))
		print("  Coins:", data.coins)
		print("  Level:", data.level)
		
		return data
	end)
end)

print("[Example] Basic usage example is running!")
print("[Example] Join the game to test data saving/loading")

