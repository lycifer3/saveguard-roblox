--[[
	Config.luau
	Default configuration values for DataSafetyKit
	All values can be overridden during initialization
]]

local Config = {
	-- Autosave interval in seconds
	AUTOSAVE_INTERVAL = 60,

	-- Maximum number of retry attempts for failed DataStore operations
	MAX_RETRIES = 3,

	-- Exponential backoff delays in seconds for retry attempts
	RETRY_BACKOFF = { 1, 2, 4 },

	-- Session lock timeout in seconds
	SESSION_LOCK_TIMEOUT = 30,

	-- Enable snapshot system (current/previous)
	ENABLE_SNAPSHOTS = true,

	-- Default key format function
	DEFAULT_KEY_FORMAT = function(userId: number): string
		return "player:" .. tostring(userId)
	end,

	-- Default DataStore name (if not provided)
	DEFAULT_DATASTORE_NAME = "PlayerData",
}

return Config

