--[[
	DataManager.luau
	Central orchestrator that coordinates all modules:
	- SaveQueue (retry logic)
	- Snapshot (rollback protection)
	- SessionLock (concurrent access protection)
	Manages the complete lifecycle of player data.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)
local SaveQueue = require(script.Parent.SaveQueue)
local Snapshot = require(script.Parent.Snapshot)
local SessionLock = require(script.Parent.SessionLock)

type InitConfig = Types.InitConfig
type PlayerState = Types.PlayerState

local DataManager = {}
DataManager.__index = DataManager

-- Create a new DataManager instance
function DataManager.new()
	local self = setmetatable({}, DataManager)
	
	-- DataStore reference
	self._store = nil :: DataStore?
	self._keyFunction = Config.DEFAULT_KEY_FORMAT
	
	-- Module instances
	self._saveQueue = SaveQueue.new()
	self._snapshot = Snapshot.new()
	self._sessionLock = nil :: any? -- Will be initialized with DataStore
	
	-- Player state tracking
	self._playerStates = {} :: {[Player]: PlayerState}
	
	-- Callbacks
	self._onError = nil :: ((err: string) -> ())?
	
	return self
end

-- Initialize DataManager with configuration
function DataManager:init(config: InitConfig)
	-- Get or create DataStore
	if config.store then
		self._store = config.store
	elseif config.datastoreName then
		self._store = DataStoreService:GetDataStore(config.datastoreName)
	else
		self._store = DataStoreService:GetDataStore(Config.DEFAULT_DATASTORE_NAME)
	end
	
	-- Set key function
	if config.key then
		self._keyFunction = config.key
	end
	
	-- Initialize SessionLock with DataStore (for fallback)
	self._sessionLock = SessionLock.new(self._store)
	
	-- Set error callback for SaveQueue
	self._saveQueue:onError(function(err)
		self:_handleError(err)
	end)
end

-- Generate key for a userId
function DataManager:_getKey(userId: number): string
	return self._keyFunction(userId)
end

-- Handle errors
function DataManager:_handleError(err: string)
	warn("[DataManager]", err)
	if self._onError then
		self._onError(err)
	end
end

-- Mark player as loaded
function DataManager:markLoaded(player: Player)
	local state = self._playerStates[player]
	if state then
		state.loaded = true
		state.lastSaveTime = os.time()
	else
		self._playerStates[player] = {
			loaded = true,
			userId = player.UserId,
			lastSaveTime = os.time(),
		}
	end
end

-- Check if player data is loaded and can be saved
function DataManager:canSave(player: Player): boolean
	local state = self._playerStates[player]
	if not state then
		return false
	end
	return state.loaded == true
end

-- Load player data with full protection
function DataManager:load(player: Player): (any?, string?)
	local userId = player.UserId
	local key = self:_getKey(userId)
	
	-- 1. Acquire SessionLock
	local lockSuccess, lockErr = self._sessionLock:acquire(userId)
	if not lockSuccess then
		local errMsg = string.format(
			"Failed to acquire session lock for %s (userId: %d): %s",
			player.Name,
			userId,
			tostring(lockErr)
		)
		self:_handleError(errMsg)
		return nil, errMsg
	end
	
	-- 2. Load data with retry
	local data, currentSnapshot, previousSnapshot, loadErr
	local maxRetries = Config.MAX_RETRIES
	
	for attempt = 1, maxRetries + 1 do
		data, currentSnapshot, previousSnapshot, loadErr = self._snapshot:load(self._store, key)
		
		if loadErr == nil then
			-- Load successful
			break
		else
			warn(string.format(
				"[DataManager] Load failed (attempt %d/%d) for %s: %s",
				attempt,
				maxRetries + 1,
				player.Name,
				loadErr
			))
			
			if attempt <= maxRetries then
				local backoffDelay = Config.RETRY_BACKOFF[attempt] or Config.RETRY_BACKOFF[#Config.RETRY_BACKOFF]
				task.wait(backoffDelay)
			end
		end
	end
	
	-- 3. Check if load succeeded
	if loadErr then
		-- Release lock on failure
		self._sessionLock:release(userId)
		
		local errMsg = string.format(
			"Failed to load data for %s after %d retries: %s",
			player.Name,
			maxRetries,
			loadErr
		)
		self:_handleError(errMsg)
		return nil, errMsg
	end
	
	-- 4. Mark as loaded
	self:markLoaded(player)
	
	return data, nil
end

-- Save player data with full protection
function DataManager:save(player: Player, data: any): (boolean, string?)
	-- 1. Check if player is loaded
	if not self:canSave(player) then
		local errMsg = string.format(
			"Cannot save data for %s: player data not loaded",
			player.Name
		)
		self:_handleError(errMsg)
		return false, errMsg
	end
	
	local userId = player.UserId
	local key = self:_getKey(userId)
	
	-- 2. Save with snapshot rotation
	local success, err = self._snapshot:saveWithSnapshot(self._store, key, data)
	
	if success then
		-- 3. Renew SessionLock on successful save
		self._sessionLock:renew(userId)
		
		-- 4. Update last save time
		local state = self._playerStates[player]
		if state then
			state.lastSaveTime = os.time()
		end
		
		return true, nil
	else
		local errMsg = string.format(
			"Failed to save data for %s: %s",
			player.Name,
			tostring(err)
		)
		self:_handleError(errMsg)
		return false, errMsg
	end
end

-- Save with retry logic through SaveQueue
function DataManager:saveWithRetry(player: Player, data: any): (boolean, string?)
	if not self:canSave(player) then
		return false, "Player data not loaded"
	end
	
	local userId = player.UserId
	local key = self:_getKey(userId)
	
	-- Create save request
	local request = {
		userId = userId,
		data = data,
		timestamp = os.time(),
		retries = 0,
	}
	
	-- Enqueue save request
	local enqueued = self._saveQueue:enqueue(request, key)
	if not enqueued then
		return false, "Save already in progress"
	end
	
	-- Process save with retry logic
	local transformFn = function(old)
		-- Extract existing snapshots
		local oldData, currentSnapshot, previousSnapshot = self._snapshot:unwrapData(old)
		
		-- Create new snapshot from current data
		local newCurrent = nil
		if oldData ~= nil then
			newCurrent = self._snapshot:createSnapshot(oldData)
		end
		
		-- Rotate: current → previous
		local newPrevious = currentSnapshot
		
		-- Wrap new data with snapshots
		return self._snapshot:wrapWithSnapshots(data, newCurrent, newPrevious)
	end
	
	local success, err = self._saveQueue:processSave(self._store, key, request, transformFn)
	
	if success then
		-- Renew lock
		self._sessionLock:renew(userId)
		
		-- Update last save time
		local state = self._playerStates[player]
		if state then
			state.lastSaveTime = os.time()
		end
		
		return true, nil
	else
		return false, err
	end
end

-- Rollback player data to previous snapshot
function DataManager:rollback(player: Player): (boolean, any?, string?)
	local userId = player.UserId
	local key = self:_getKey(userId)
	
	local success, restoredData, err = self._snapshot:rollback(self._store, key)
	
	if success then
		return true, restoredData, nil
	else
		local errMsg = string.format(
			"Failed to rollback data for %s: %s",
			player.Name,
			tostring(err)
		)
		self:_handleError(errMsg)
		return false, nil, errMsg
	end
end

-- Cleanup player state (on player leave)
function DataManager:cleanup(player: Player)
	local userId = player.UserId
	
	-- DO NOT release session lock immediately - let it expire via TTL
	-- This prevents fast rejoin exploits (lock will expire in 30 seconds)
	-- Only release on successful save to allow immediate rejoin after proper save
	
	-- Remove player state
	self._playerStates[player] = nil
end

-- Flush all pending saves (for BindToClose)
function DataManager:flushAllSaves(timeout: number?): boolean
	local transformFn = function(key, request)
		return function(old)
			local data = request.data
			local oldData, currentSnapshot, previousSnapshot = self._snapshot:unwrapData(old)
			
			local newCurrent = nil
			if oldData ~= nil then
				newCurrent = self._snapshot:createSnapshot(oldData)
			end
			
			local newPrevious = currentSnapshot
			return self._snapshot:wrapWithSnapshots(data, newCurrent, newPrevious)
		end
	end
	
	return self._saveQueue:flush(self._store, transformFn, timeout)
end

-- Set error callback
function DataManager:onError(callback: (err: string) -> ())
	self._onError = callback
end

-- Get player state (for debugging)
function DataManager:getPlayerState(player: Player): PlayerState?
	return self._playerStates[player]
end

-- Get queue size (for debugging)
function DataManager:getQueueSize(): number
	return self._saveQueue:size()
end

-- Check if SessionLock is using MemoryStore
function DataManager:isUsingMemoryStore(): boolean
	return self._sessionLock:getStorageMode() == "MemoryStore"
end

return DataManager

