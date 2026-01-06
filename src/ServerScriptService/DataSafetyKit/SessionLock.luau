--[[
	SessionLock.luau
	Manages session locks to prevent concurrent writes from multiple servers.
	Uses MemoryStore (preferred) with DataStore fallback.
]]

local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

type SessionLock = Types.SessionLock

local SessionLock = {}
SessionLock.__index = SessionLock

-- Lock storage modes
local STORAGE_MODE = {
	MEMORY_STORE = "MemoryStore",
	DATA_STORE = "DataStore",
}

-- Create a new SessionLock manager instance
function SessionLock.new(dataStore: DataStore?)
	local self = setmetatable({}, SessionLock)
	
	-- Try to initialize MemoryStore
	self._memoryStore = nil
	self._dataStore = dataStore
	self._storageMode = nil
	
	-- Try MemoryStore first
	local success = pcall(function()
		self._memoryStore = MemoryStoreService:GetSortedMap("SessionLocks")
		self._storageMode = STORAGE_MODE.MEMORY_STORE
	end)
	
	if not success then
		warn("[SessionLock] MemoryStore unavailable, falling back to DataStore")
		self._storageMode = STORAGE_MODE.DATA_STORE
	end
	
	-- Active locks cache (for quick lookup)
	self._activeLocks = {} :: {[number]: SessionLock}
	
	return self
end

-- Generate a unique lock token
function SessionLock:_generateToken(): string
	return HttpService:GenerateGUID(false)
end

-- Get lock key for DataStore
function SessionLock:_getLockKey(userId: number): string
	return "lock:" .. tostring(userId)
end

-- Acquire lock using MemoryStore
function SessionLock:_acquireMemoryStore(userId: number, token: string, ttl: number): (boolean, string?)
	local success, result = pcall(function()
		-- Try to set lock with TTL
		return self._memoryStore:SetAsync(
			tostring(userId),
			token,
			ttl
		)
	end)
	
	if success then
		return true, nil
	else
		local errorMsg = tostring(result)
		-- Check if lock already exists
		if string.find(errorMsg, "already exists") or string.find(errorMsg, "conflict") then
			return false, "Lock already held by another server"
		end
		return false, errorMsg
	end
end

-- Release lock using MemoryStore
function SessionLock:_releaseMemoryStore(userId: number): (boolean, string?)
	local success, result = pcall(function()
		self._memoryStore:RemoveAsync(tostring(userId))
	end)
	
	if success then
		return true, nil
	else
		return false, tostring(result)
	end
end

-- Renew lock using MemoryStore
function SessionLock:_renewMemoryStore(userId: number, token: string, ttl: number): (boolean, string?)
	-- MemoryStore doesn't have native renew, so we update
	local success, result = pcall(function()
		return self._memoryStore:UpdateAsync(
			tostring(userId),
			function(oldToken)
				if oldToken == token then
					return token -- Keep same token, just renew TTL
				else
					return nil -- Token mismatch, fail
				end
			end,
			ttl
		)
	end)
	
	if success and result == token then
		return true, nil
	else
		return false, "Token mismatch or lock expired"
	end
end

-- Acquire lock using DataStore (fallback)
function SessionLock:_acquireDataStore(userId: number, token: string, ttl: number): (boolean, string?)
	if not self._dataStore then
		return false, "DataStore not available"
	end
	
	local key = self:_getLockKey(userId)
	local expiresAt = os.time() + ttl
	
	local success, result = pcall(function()
		return self._dataStore:UpdateAsync(key, function(oldLock)
			-- Check if lock exists and is still valid
			if oldLock and oldLock.expiresAt and oldLock.expiresAt > os.time() then
				return nil -- Lock still valid, cannot acquire
			end
			
			-- Create new lock
			return {
				token = token,
				expiresAt = expiresAt,
				userId = userId,
			}
		end)
	end)
	
	if success and result then
		return true, nil
	else
		return false, "Failed to acquire DataStore lock"
	end
end

-- Release lock using DataStore
function SessionLock:_releaseDataStore(userId: number, token: string): (boolean, string?)
	if not self._dataStore then
		return false, "DataStore not available"
	end
	
	local key = self:_getLockKey(userId)
	
	local success = pcall(function()
		self._dataStore:UpdateAsync(key, function(oldLock)
			if oldLock and oldLock.token == token then
				return nil -- Remove lock
			end
			return oldLock -- Keep lock if token doesn't match
		end)
	end)
	
	if success then
		return true, nil
	else
		return false, "Failed to release DataStore lock"
	end
end

-- Renew lock using DataStore
function SessionLock:_renewDataStore(userId: number, token: string, ttl: number): (boolean, string?)
	if not self._dataStore then
		return false, "DataStore not available"
	end
	
	local key = self:_getLockKey(userId)
	local expiresAt = os.time() + ttl
	
	local success, result = pcall(function()
		return self._dataStore:UpdateAsync(key, function(oldLock)
			if oldLock and oldLock.token == token then
				oldLock.expiresAt = expiresAt
				return oldLock
			end
			return nil -- Token mismatch
		end)
	end)
	
	if success and result then
		return true, nil
	else
		return false, "Failed to renew DataStore lock"
	end
end

-- Acquire a session lock for a user
function SessionLock:acquire(userId: number, timeout: number?): (boolean, string?)
	local timeoutDuration = timeout or Config.SESSION_LOCK_TIMEOUT
	local ttl = Config.SESSION_LOCK_TIMEOUT
	local token = self:_generateToken()
	
	local startTime = os.clock()
	
	while true do
		-- Try to acquire lock
		local success, err
		
		if self._storageMode == STORAGE_MODE.MEMORY_STORE then
			success, err = self:_acquireMemoryStore(userId, token, ttl)
		else
			success, err = self:_acquireDataStore(userId, token, ttl)
		end
		
		if success then
			-- Lock acquired successfully
			self._activeLocks[userId] = {
				token = token,
				expiresAt = os.time() + ttl,
				userId = userId,
			}
			return true, nil
		end
		
		-- Check timeout
		if os.clock() - startTime > timeoutDuration then
			warn(string.format(
				"[SessionLock] Timeout waiting for lock (userId: %d). Force acquiring...",
				userId
			))
			
			-- Force acquire after timeout
			if self._storageMode == STORAGE_MODE.MEMORY_STORE then
				-- For MemoryStore, remove old lock first
				self:_releaseMemoryStore(userId)
				success, err = self:_acquireMemoryStore(userId, token, ttl)
			else
				-- For DataStore, force will happen in UpdateAsync
				success, err = self:_acquireDataStore(userId, token, ttl)
			end
			
			if success then
				self._activeLocks[userId] = {
					token = token,
					expiresAt = os.time() + ttl,
					userId = userId,
				}
				return true, nil
			else
				return false, "Failed to force acquire lock: " .. tostring(err)
			end
		end
		
		-- Wait before retry
		task.wait(1)
	end
end

-- Release a session lock
function SessionLock:release(userId: number): (boolean, string?)
	local lock = self._activeLocks[userId]
	if not lock then
		warn("[SessionLock] No active lock found for userId:", userId)
		return true, nil -- Already released
	end
	
	local success, err
	
	if self._storageMode == STORAGE_MODE.MEMORY_STORE then
		success, err = self:_releaseMemoryStore(userId)
	else
		success, err = self:_releaseDataStore(userId, lock.token)
	end
	
	if success then
		self._activeLocks[userId] = nil
		return true, nil
	else
		warn("[SessionLock] Failed to release lock for userId:", userId, err)
		return false, err
	end
end

-- Renew a session lock (extend TTL)
function SessionLock:renew(userId: number): (boolean, string?)
	local lock = self._activeLocks[userId]
	if not lock then
		warn("[SessionLock] No active lock found for userId:", userId)
		return false, "No active lock"
	end
	
	local ttl = Config.SESSION_LOCK_TIMEOUT
	local success, err
	
	if self._storageMode == STORAGE_MODE.MEMORY_STORE then
		success, err = self:_renewMemoryStore(userId, lock.token, ttl)
	else
		success, err = self:_renewDataStore(userId, lock.token, ttl)
	end
	
	if success then
		lock.expiresAt = os.time() + ttl
		return true, nil
	else
		warn("[SessionLock] Failed to renew lock for userId:", userId, err)
		return false, err
	end
end

-- Check if a lock is active
function SessionLock:isLocked(userId: number): boolean
	local lock = self._activeLocks[userId]
	if not lock then
		return false
	end
	
	-- Check if lock expired
	if lock.expiresAt <= os.time() then
		self._activeLocks[userId] = nil
		return false
	end
	
	return true
end

-- Get storage mode (for debugging)
function SessionLock:getStorageMode(): string
	return self._storageMode or "Unknown"
end

return SessionLock

