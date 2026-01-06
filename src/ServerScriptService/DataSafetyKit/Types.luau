--[[
	Types.luau
	Defines all TypeScript-style types used across DataSafetyKit modules
]]

-- Request to save player data to DataStore
export type SaveRequest = {
	userId: number,
	data: any,
	timestamp: number,
	retries: number?,
}

-- Snapshot of player data at a specific point in time
export type Snapshot = {
	version: number,
	timestamp: number,
	data: any,
}

-- Session lock to prevent concurrent writes from multiple servers
export type SessionLock = {
	token: string,
	expiresAt: number,
	userId: number,
}

-- Configuration options for initializing DataSafetyKit
export type InitConfig = {
	store: DataStore?,
	datastoreName: string?,
	key: ((userId: number) -> string)?,
}

-- Player data lifecycle state
export type PlayerState = {
	loaded: boolean,
	userId: number,
	lastSaveTime: number?,
}

return {}

