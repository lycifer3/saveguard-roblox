--[[
	Snapshot.luau
	Manages data snapshots for rollback protection.
	Snapshots are stored within the same DataStore in a nested structure:
	{
		data = {...},
		snapshots = {
			current = {...},
			previous = {...}
		}
	}
]]

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

type Snapshot = Types.Snapshot

local Snapshot = {}
Snapshot.__index = Snapshot

-- Snapshot version for future compatibility
local SNAPSHOT_VERSION = 1

-- Create a new Snapshot manager instance
function Snapshot.new()
	local self = setmetatable({}, Snapshot)
	return self
end

-- Create a snapshot object from data
function Snapshot:createSnapshot(data: any): Snapshot
	return {
		version = SNAPSHOT_VERSION,
		timestamp = os.time(),
		data = data,
	}
end

-- Wrap data with snapshot structure
function Snapshot:wrapWithSnapshots(data: any, currentSnapshot: Snapshot?, previousSnapshot: Snapshot?): any
	return {
		data = data,
		snapshots = {
			current = currentSnapshot,
			previous = previousSnapshot,
		},
	}
end

-- Extract data from wrapped structure
function Snapshot:unwrapData(wrappedData: any): (any, Snapshot?, Snapshot?)
	if type(wrappedData) ~= "table" then
		return wrappedData, nil, nil
	end
	
	local data = wrappedData.data
	local current = nil
	local previous = nil
	
	if wrappedData.snapshots then
		current = wrappedData.snapshots.current
		previous = wrappedData.snapshots.previous
	end
	
	return data, current, previous
end

-- Save data with snapshot rotation (current → previous, new → current)
function Snapshot:saveWithSnapshot(
	store: DataStore,
	key: string,
	newData: any
): (boolean, string?)
	local success, result = pcall(function()
		return store:UpdateAsync(key, function(oldWrappedData)
			-- Extract existing snapshots
			local oldData, currentSnapshot, previousSnapshot = self:unwrapData(oldWrappedData)
			
			-- Create new snapshot from current data (if exists)
			local newCurrent = nil
			if oldData ~= nil then
				newCurrent = self:createSnapshot(oldData)
			end
			
			-- Rotate: current → previous, new → current
			local newPrevious = currentSnapshot
			
			-- Wrap new data with snapshots
			return self:wrapWithSnapshots(newData, newCurrent, newPrevious)
		end)
	end)
	
	if success then
		return true, nil
	else
		local errorMsg = tostring(result)
		warn("[Snapshot] Failed to save with snapshot for key:", key, errorMsg)
		return false, errorMsg
	end
end

-- Load data from DataStore (with snapshots)
function Snapshot:load(store: DataStore, key: string): (any?, Snapshot?, Snapshot?, string?)
	local success, result = pcall(function()
		return store:GetAsync(key)
	end)
	
	if success then
		if result == nil then
			-- No data exists (new player)
			return nil, nil, nil, nil
		end
		
		-- Unwrap data and snapshots
		local data, current, previous = self:unwrapData(result)
		return data, current, previous, nil
	else
		local errorMsg = tostring(result)
		warn("[Snapshot] Failed to load for key:", key, errorMsg)
		return nil, nil, nil, errorMsg
	end
end

-- Rollback to previous snapshot
function Snapshot:rollback(
	store: DataStore,
	key: string
): (boolean, any?, string?)
	local success, result = pcall(function()
		return store:UpdateAsync(key, function(wrappedData)
			if wrappedData == nil then
				warn("[Snapshot] Cannot rollback - no data exists for key:", key)
				return nil
			end
			
			-- Extract current state
			local data, currentSnapshot, previousSnapshot = self:unwrapData(wrappedData)
			
		-- Check if current snapshot exists (this is the last known good state)
		if currentSnapshot == nil or currentSnapshot.data == nil then
			warn("[Snapshot] Cannot rollback - no current snapshot for key:", key)
			return wrappedData -- Return unchanged
		end
		
		-- Rollback: restore data from CURRENT snapshot (last known good state)
		local restoredData = currentSnapshot.data
		
		-- Keep snapshots: current stays as fallback, previous stays as backup
		local newCurrent = currentSnapshot
		local newPrevious = previousSnapshot
			
			-- Wrap restored data
			return self:wrapWithSnapshots(restoredData, newCurrent, newPrevious)
		end)
	end)
	
	if success then
		-- Extract rolled back data
		local data, _, _ = self:unwrapData(result)
		return true, data, nil
	else
		local errorMsg = tostring(result)
		warn("[Snapshot] Rollback failed for key:", key, errorMsg)
		return false, nil, errorMsg
	end
end

-- Validate snapshot structure
function Snapshot:validateSnapshot(snapshot: any): boolean
	if type(snapshot) ~= "table" then
		return false
	end
	
	if snapshot.version == nil or snapshot.timestamp == nil or snapshot.data == nil then
		return false
	end
	
	return true
end

-- Get snapshot age in seconds
function Snapshot:getSnapshotAge(snapshot: Snapshot): number
	if not snapshot or not snapshot.timestamp then
		return math.huge
	end
	
	return os.time() - snapshot.timestamp
end

-- Check if snapshot is valid (not too old, correct structure)
function Snapshot:isSnapshotValid(snapshot: any, maxAge: number?): boolean
	if not self:validateSnapshot(snapshot) then
		return false
	end
	
	if maxAge then
		local age = self:getSnapshotAge(snapshot)
		if age > maxAge then
			return false
		end
	end
	
	return true
end

-- Get snapshot info for debugging
function Snapshot:getSnapshotInfo(snapshot: Snapshot?): string
	if snapshot == nil then
		return "No snapshot"
	end
	
	local age = self:getSnapshotAge(snapshot)
	return string.format(
		"Version: %d, Age: %ds, Timestamp: %d",
		snapshot.version or 0,
		age,
		snapshot.timestamp or 0
	)
end

return Snapshot

