--[[
	Init.luau (DataSafetyKit)
	Public API for Roblox Data Safety Kit.
	Drop-in safety layer for DataStore operations with automatic protection.
	
	Usage:
		local SaveGuard = require(ServerScriptService.DataSafetyKit)
		
		SaveGuard.init({
			datastoreName = "PlayerData_v1"
		})
		
		SaveGuard.onPlayerAdded(player, function(data)
			-- Apply loaded data to game
		end)
		
		SaveGuard.onPlayerRemoving(player, function()
			return {coins = 100} -- Return data to save
		end)
]]

local Players = game:GetService("Players")

local Config = require(script.Config)
local Types = require(script.Types)
local DataManager = require(script.DataManager)
local BindToClose = require(script.BindToClose)

type InitConfig = Types.InitConfig

-- Module state
local SaveGuard = {
	_initialized = false,
	_dataManager = nil :: any?,
	_bindToClose = nil :: any?,
	_loadCallbacks = {} :: {[Player]: (data: any?) -> ()},
	_saveCallbacks = {} :: {[Player]: () -> any},
	_autosaveThread = nil :: thread?,
}

-- Error callback
local _errorCallback = nil :: ((err: string) -> ())?

--[[ INITIALIZATION ]]--

-- Initialize SaveGuard with configuration
function SaveGuard.init(config: InitConfig)
	if SaveGuard._initialized then
		warn("[SaveGuard] Already initialized")
		return
	end
	
	-- Create DataManager
	SaveGuard._dataManager = DataManager.new()
	SaveGuard._dataManager:init(config)
	
	-- Set error callback
	SaveGuard._dataManager:onError(function(err)
		if _errorCallback then
			_errorCallback(err)
		end
	end)
	
	-- Create BindToClose handler
	SaveGuard._bindToClose = BindToClose.new(SaveGuard._dataManager)
	SaveGuard._bindToClose:register()
	
	-- Start autosave cycle
	SaveGuard._startAutosave()
	
	SaveGuard._initialized = true
	print("[SaveGuard] Initialized successfully")
end

--[[ PLAYER LIFECYCLE ]]--

-- Register callback for player join (load data)
function SaveGuard.onPlayerAdded(player: Player, callback: (data: any?) -> ())
	if not SaveGuard._initialized then
		error("[SaveGuard] Not initialized. Call SaveGuard.init() first")
	end
	
	-- Store callback
	SaveGuard._loadCallbacks[player] = callback
	
	-- Load player data
	local data, err = SaveGuard._dataManager:load(player)
	
	if err then
		-- Load failed - kick player to prevent data wipe
		warn(string.format(
			"[SaveGuard] Failed to load data for %s: %s. Kicking player...",
			player.Name,
			err
		))
		
		player:Kick("Failed to load your data. Please rejoin.")
		return
	end
	
	-- Call load callback with data (nil for new player)
	callback(data)
	
	print(string.format(
		"[SaveGuard] Data loaded for %s (new player: %s)",
		player.Name,
		data == nil and "yes" or "no"
	))
end

-- Register callback for player leave (save data)
function SaveGuard.onPlayerRemoving(player: Player, callback: () -> any)
	if not SaveGuard._initialized then
		error("[SaveGuard] Not initialized. Call SaveGuard.init() first")
	end
	
	-- Store callback
	SaveGuard._saveCallbacks[player] = callback
	
	-- Connect to PlayerRemoving
	Players.PlayerRemoving:Connect(function(leavingPlayer)
		if leavingPlayer == player then
			SaveGuard._handlePlayerLeave(player)
		end
	end)
end

-- Handle player leave
function SaveGuard._handlePlayerLeave(player: Player)
	local callback = SaveGuard._saveCallbacks[player]
	
	if not callback then
		warn("[SaveGuard] No save callback registered for", player.Name)
		SaveGuard._dataManager:cleanup(player)
		return
	end
	
	-- Get data from callback
	local success, data = pcall(callback)
	
	if not success then
		warn("[SaveGuard] Save callback error for", player.Name, ":", data)
		SaveGuard._dataManager:cleanup(player)
		return
	end
	
	if data == nil then
		warn("[SaveGuard] Save callback returned nil for", player.Name)
		SaveGuard._dataManager:cleanup(player)
		return
	end
	
	-- Save data
	local saveSuccess, saveErr = SaveGuard._dataManager:save(player, data)
	
	if saveSuccess then
		print(string.format("[SaveGuard] Data saved for %s on leave", player.Name))
		
		-- Release lock after successful save to allow immediate rejoin
		local userId = player.UserId
		local releaseSuccess, releaseErr = SaveGuard._dataManager._sessionLock:release(userId)
		if not releaseSuccess then
			warn(string.format(
				"[SaveGuard] Failed to release lock for %s: %s",
				player.Name,
				tostring(releaseErr)
			))
		end
	else
		warn(string.format(
			"[SaveGuard] Failed to save data for %s: %s",
			player.Name,
			tostring(saveErr)
		))
		-- Do NOT release lock on save failure - let it expire via TTL
	end
	
	-- Cleanup
	SaveGuard._dataManager:cleanup(player)
	SaveGuard._loadCallbacks[player] = nil
	SaveGuard._saveCallbacks[player] = nil
end

--[[ MANUAL SAVE ]]--

-- Manually save player data (for autosave or admin commands)
function SaveGuard.safeSave(player: Player): (boolean, string?)
	if not SaveGuard._initialized then
		error("[SaveGuard] Not initialized. Call SaveGuard.init() first")
	end
	
	local callback = SaveGuard._saveCallbacks[player]
	
	if not callback then
		return false, "No save callback registered"
	end
	
	-- Get data from callback
	local success, data = pcall(callback)
	
	if not success then
		return false, "Save callback error: " .. tostring(data)
	end
	
	if data == nil then
		return false, "Save callback returned nil"
	end
	
	-- Save data
	return SaveGuard._dataManager:save(player, data)
end

--[[ ROLLBACK ]]--

-- Rollback player data to previous snapshot
function SaveGuard.rollback(player: Player): (boolean, any?, string?)
	if not SaveGuard._initialized then
		error("[SaveGuard] Not initialized. Call SaveGuard.init() first")
	end
	
	return SaveGuard._dataManager:rollback(player)
end

--[[ AUTOSAVE ]]--

-- Start autosave cycle
function SaveGuard._startAutosave()
	if SaveGuard._autosaveThread then
		warn("[SaveGuard] Autosave already running")
		return
	end
	
	SaveGuard._autosaveThread = task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_INTERVAL)
			
			-- Save all players
			local playerList = Players:GetPlayers()
			local savedCount = 0
			local failedCount = 0
			
			for _, player in playerList do
				local success, err = SaveGuard.safeSave(player)
				if success then
					savedCount = savedCount + 1
				else
					failedCount = failedCount + 1
					if err then
						warn(string.format(
							"[SaveGuard] Autosave failed for %s: %s",
							player.Name,
							err
						))
					end
				end
			end
			
			if savedCount > 0 then
				print(string.format(
					"[SaveGuard] Autosave completed: %d saved, %d failed",
					savedCount,
					failedCount
				))
			end
		end
	end)
	
	print(string.format(
		"[SaveGuard] Autosave started (interval: %ds)",
		Config.AUTOSAVE_INTERVAL
	))
end

-- Stop autosave (for cleanup/testing)
function SaveGuard._stopAutosave()
	if SaveGuard._autosaveThread then
		task.cancel(SaveGuard._autosaveThread)
		SaveGuard._autosaveThread = nil
		print("[SaveGuard] Autosave stopped")
	end
end

--[[ ERROR HANDLING ]]--

-- Set error callback
function SaveGuard.onError(callback: (err: string) -> ())
	_errorCallback = callback
end

--[[ DEBUGGING ]]--

-- Get player state (for debugging)
function SaveGuard.getPlayerState(player: Player)
	if not SaveGuard._initialized then
		return nil
	end
	return SaveGuard._dataManager:getPlayerState(player)
end

-- Check if using MemoryStore for SessionLock
function SaveGuard.isUsingMemoryStore(): boolean
	if not SaveGuard._initialized then
		return false
	end
	return SaveGuard._dataManager:isUsingMemoryStore()
end

return SaveGuard

