--[[
	AdvancedUsage.server.luau
	Advanced example: Custom DataStore, inventory system, manual saves
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local SaveGuard = require(game.ServerScriptService.SaveGuard)

print("[Advanced] Initializing SaveGuard with custom settings...")

-- Create custom DataStore
local MyDataStore = DataStoreService:GetDataStore("AdvancedPlayerData", "Production")

-- Initialize with custom DataStore and key function
SaveGuard.init({
	store = MyDataStore,
	key = function(userId)
		return string.format("player_%d_v2", userId)
	end
})

-- Advanced error handling
SaveGuard.onError(function(err)
	warn("[SaveGuard]", err)
	-- Could send to external logging service here
end)

print("[Advanced] Initialized!")

-- Player data cache (for quick access)
local playerDataCache = {}

-- Helper: Create UI and inventory
local function setupPlayer(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	
	local inventory = Instance.new("Folder")
	inventory.Name = "Inventory"
	inventory.Parent = player
	
	return leaderstats, inventory
end

-- Helper: Load inventory items
local function loadInventory(player, items)
	local inventory = player:FindFirstChild("Inventory")
	if not inventory then return end
	
	for _, itemName in ipairs(items or {}) do
		local item = Instance.new("StringValue")
		item.Name = itemName
		item.Value = itemName
		item.Parent = inventory
	end
end

-- Helper: Serialize inventory
local function serializeInventory(player)
	local inventory = player:FindFirstChild("Inventory")
	if not inventory then return {} end
	
	local items = {}
	for _, item in ipairs(inventory:GetChildren()) do
		table.insert(items, item.Value)
	end
	return items
end

-- Player Join
Players.PlayerAdded:Connect(function(player)
	print(string.format("[Advanced] %s joined", player.Name))
	
	local leaderstats, inventory = setupPlayer(player)
	
	SaveGuard.onPlayerAdded(player, function(data)
		if data then
			-- Existing player
			print(string.format("[Advanced] Loaded %s data:", player.Name))
			print("  Coins:", data.coins)
			print("  Inventory items:", #(data.inventory or {}))
			print("  Last save:", os.date("%Y-%m-%d %H:%M:%S", data.lastSave or 0))
			
			leaderstats.Coins.Value = data.coins or 0
			loadInventory(player, data.inventory)
			
			-- Cache data
			playerDataCache[player] = {
				coins = data.coins,
				inventory = data.inventory,
				loadedAt = os.time()
			}
		else
			-- New player
			print(string.format("[Advanced] %s is new, setting defaults", player.Name))
			
			leaderstats.Coins.Value = 100 -- Starting coins
			loadInventory(player, {"Sword", "Shield"}) -- Starting items
			
			playerDataCache[player] = {
				coins = 100,
				inventory = {"Sword", "Shield"},
				loadedAt = os.time()
			}
		end
	end)
end)

-- Player Leave
Players.PlayerRemoving:Connect(function(player)
	print(string.format("[Advanced] %s leaving", player.Name))
	
	SaveGuard.onPlayerRemoving(player, function()
		local leaderstats = player:FindFirstChild("leaderstats")
		if not leaderstats then
			return playerDataCache[player] or {}
		end
		
		local data = {
			coins = leaderstats.Coins.Value,
			inventory = serializeInventory(player),
			lastSave = os.time(),
			sessionDuration = os.time() - (playerDataCache[player]?.loadedAt or os.time())
		}
		
		print(string.format("[Advanced] Saving %s:", player.Name))
		print("  Coins:", data.coins)
		print("  Inventory:", #data.inventory, "items")
		print("  Session:", data.sessionDuration, "seconds")
		
		-- Clean cache
		playerDataCache[player] = nil
		
		return data
	end)
end)

-- Admin Command: Manual Save
local function manualSave(admin, targetPlayer)
	if not admin:IsInGroup(123456) then -- Replace with your admin group
		return
	end
	
	local success, err = SaveGuard.safeSave(targetPlayer)
	if success then
		print(string.format("[Admin] %s manually saved %s's data", admin.Name, targetPlayer.Name))
	else
		warn(string.format("[Admin] Failed to save %s: %s", targetPlayer.Name, err))
	end
end

-- Admin Command: Rollback
local function rollbackPlayer(admin, targetPlayer)
	if not admin:IsInGroup(123456) then
		return
	end
	
	local success, data, err = SaveGuard.rollback(targetPlayer)
	if success then
		print(string.format("[Admin] %s rolled back %s's data", admin.Name, targetPlayer.Name))
		
		-- Reapply rolled back data
		if data then
			local leaderstats = targetPlayer:FindFirstChild("leaderstats")
			if leaderstats then
				leaderstats.Coins.Value = data.coins or 0
			end
			
			-- Clear and reload inventory
			local inventory = targetPlayer:FindFirstChild("Inventory")
			if inventory then
				inventory:ClearAllChildren()
				loadInventory(targetPlayer, data.inventory)
			end
		end
	else
		warn(string.format("[Admin] Rollback failed for %s: %s", targetPlayer.Name, err))
	end
end

print("[Advanced] Advanced usage example is running!")
print("[Advanced] Features:")
print("  - Custom DataStore and key format")
print("  - Inventory system")
print("  - Data caching")
print("  - Manual save/rollback commands")

