# SaveGuard

**A drop-in safety layer for Roblox player saves** — Minimize data loss, protect against wipes, handle crashes gracefully.

[![Tests](https://img.shields.io/badge/tests-61%2F61%20passing-brightgreen)]()
[![Version](https://img.shields.io/badge/version-0.1.0--mvp-orange)]()

> **⚠️ Experimental MVP Release**  
> This is an early release intended for testing and feedback. Production-ready v1.0.0 will include teleport support, additional adapters, and stability improvements.

---

## 🎯 What is SaveGuard?

**SaveGuard** is a **lightweight protection system** that wraps around your existing DataStore logic to prevent common data loss scenarios:

- ❌ **Player leaves too fast** → saves don't complete
- ❌ **Server crashes** → pending saves are lost
- ❌ **Fast rejoin** → data conflicts between servers
- ❌ **DataStore errors** → no retry, data wiped

### ✅ With SaveGuard:

- ✅ **Save Queue** with retry logic and exponential backoff
- ✅ **Snapshot System** (current + previous) for rollback
- ✅ **Session Lock** prevents multi-server conflicts
- ✅ **BindToClose Handler** ensures graceful shutdown
- ✅ **Loaded-flag Protection** prevents saving unloaded data
- ✅ **Autosave** every 60 seconds (configurable)

---

## 📦 Installation

### Option 1: Wally (Recommended)

Add to your `wally.toml`:

```toml
[dependencies]
SaveGuard = "lycifer3/saveguard@0.1.0"
```

Then install:

```bash
wally install
```

The package will be available at `game.ReplicatedStorage.Packages.SaveGuard`.

**Package:** [lycifer3/saveguard on Wally](https://wally.run/package/lycifer3/saveguard)

### Option 2: Rojo

1. Clone this repository:
```bash
git clone https://github.com/lycifer3/saveguard-roblox.git
```

2. Add to your `default.project.json`:
```json
{
  "$className": "DataModel",
  "ServerScriptService": {
    "$className": "ServerScriptService",
    "SaveGuard": {
      "$path": "path/to/saveguard-roblox/src/ServerScriptService/DataSafetyKit"
    }
  }
}
```

**Important:** Place in `ServerScriptService` (server-only), **not** in `ReplicatedStorage` or client locations.

### Option 3: Manual Install

1. Download the latest release from GitHub
2. Copy the `src/ServerScriptService/DataSafetyKit` folder to your game's `ServerScriptService`
3. Rename folder to `SaveGuard` (optional, for consistency)
4. Done! ✅

---

## 🚀 Quick Start

### Basic Setup (30 seconds)

```lua
-- If installed via Wally:
local SaveGuard = require(game.ReplicatedStorage.Packages.SaveGuard)

-- If installed via Rojo/Manual:
-- local SaveGuard = require(game.ServerScriptService.SaveGuard)

-- 1. Initialize once at server startup
SaveGuard.init({
	datastoreName = "PlayerData_v1"
})

-- 2. Register your save function (called on autosave + player leave)
local function getPlayerData(player)
	return {
		coins = player.leaderstats.Coins.Value
	}
end

-- 3. Handle player join - load data
game.Players.PlayerAdded:Connect(function(player)
	SaveGuard.onPlayerAdded(player, function(data)
		-- Apply loaded data to game
		if data then
			player.leaderstats.Coins.Value = data.coins or 0
		else
			-- New player, set defaults
			player.leaderstats.Coins.Value = 0
		end
	end)
end)

-- 4. Handle player leave - save data
game.Players.PlayerRemoving:Connect(function(player)
	SaveGuard.onPlayerRemoving(player, getPlayerData)
end)
```

**That's it!** Your saves are now protected. ✅

---

## 📖 API Reference

### `SaveGuard.init(config)`

Initialize the system. **Call this once** at server startup.

**Parameters:**
```lua
{
	-- Option 1: Simple mode (recommended)
	datastoreName: string?,  -- e.g. "PlayerData_v1"
	
	-- Option 2: Advanced mode
	store: DataStore?,       -- Pass your own DataStore object
	key: (userId: number) -> string?,  -- Custom key function
	
	-- Optional
	onError: (err: string) -> ()?  -- Error callback
}
```

**Example:**
```lua
SaveGuard.init({
	datastoreName = "PlayerData_v1"
})
```

---

### `SaveGuard.onPlayerAdded(player, loadFn)`

Register a callback that runs when player data is successfully loaded.

**Parameters:**
- `player: Player` — The player instance
- `loadFn: (data: table?) -> ()` — Callback receives loaded data (or `nil` for new players)

**Example:**
```lua
SaveGuard.onPlayerAdded(player, function(data)
	if data then
		-- Existing player
		player.leaderstats.Coins.Value = data.coins
		player.Inventory:LoadItems(data.inventory)
	else
		-- New player
		player.leaderstats.Coins.Value = 0
		player.Inventory:SetDefaults()
	end
end)
```

**Notes:**
- If load fails after retries, player is **kicked** (safety-first)
- Callback only runs if load succeeds
- SessionLock is acquired before load

---

### `SaveGuard.onPlayerRemoving(player, saveFn)`

Register a callback that returns data to save when player leaves.

**Parameters:**
- `player: Player` — The player instance
- `saveFn: () -> table` — Function that returns data to save

**Example:**
```lua
SaveGuard.onPlayerRemoving(player, function()
	return {
		coins = player.leaderstats.Coins.Value,
		level = player.Stats.Level.Value,
		inventory = player.Inventory:Serialize()
	}
end)
```

**Notes:**
- Same `saveFn` is used for autosave
- Data is saved with snapshot rotation
- SessionLock is released after save

---

### `SaveGuard.safeSave(player)`

Manually trigger a save for a player (e.g., admin command, special event).

**Parameters:**
- `player: Player` — The player to save

**Returns:**
- `success: boolean` — Whether save succeeded
- `error: string?` — Error message if failed

**Example:**
```lua
local success, err = SaveGuard.safeSave(player)
if not success then
	warn("Save failed:", err)
end
```

**Notes:**
- Uses the same `saveFn` from `onPlayerRemoving`
- Respects loaded-flag protection
- Will retry on failure (up to `Config.MAX_RETRIES`)

---

### `SaveGuard.rollback(player)`

Rollback player data to previous snapshot.

**Parameters:**
- `player: Player` — The player to rollback

**Returns:**
- `success: boolean` — Whether rollback succeeded
- `data: table?` — The restored data
- `error: string?` — Error message if failed

**Example:**
```lua
local success, data, err = SaveGuard.rollback(player)
if success then
	print("Rolled back to:", data)
	-- Reapply data to game
else
	warn("Rollback failed:", err)
end
```

---

### `SaveGuard.onError(callback)`

Register a callback for error notifications.

**Parameters:**
- `callback: (err: string) -> ()` — Error handler

**Example:**
```lua
SaveGuard.onError(function(err)
	warn("[DataSafety]", err)
	-- Send to analytics, Discord webhook, etc.
end)
```

---

### `SaveGuard.getPlayerState(player)`

Get internal state for a player (debugging).

**Returns:**
```lua
{
	loaded: boolean,     -- Is data loaded?
	userId: number,
	lastSaveTime: number?
}
```

---

### `SaveGuard.isUsingMemoryStore()`

Check if SessionLock is using MemoryStore (vs DataStore fallback).

**Returns:**
- `boolean` — `true` if using MemoryStore

---

## ⚙️ Configuration

Edit `src/ServerScriptService/DataSafetyKit/Config.luau`:

```lua
{
	AUTOSAVE_INTERVAL = 60,        -- seconds
	MAX_RETRIES = 3,               -- retry attempts
	RETRY_BACKOFF = {1, 2, 4},     -- seconds between retries
	SESSION_LOCK_TIMEOUT = 30,     -- seconds
	ENABLE_SNAPSHOTS = true,
	DEFAULT_DATASTORE_NAME = "PlayerData_v1"
}
```

---

## 🧪 Testing

This project includes **61 automated tests** (100% passing):

```bash
# Run tests in Roblox Studio
require(game.ServerScriptService.Tests.RunTests)()
```

**Test Coverage:**
- ✅ Unit tests: 54/54
- ✅ Integration tests: 7/7
- ✅ High test coverage across all core modules

**Note:** Tests are provided for internal validation and development. They are **not required** for using SaveGuard in your production games.

---

## 🏗️ Architecture

```
DataSafetyKit/
├── Init.luau          ← Public API (SaveGuard)
├── Config.luau        ← Configuration
├── Types.luau         ← Type definitions
├── DataManager.luau   ← Orchestration
├── SaveQueue.luau     ← Retry logic
├── Snapshot.luau      ← Rollback system
├── SessionLock.luau   ← Multi-server protection
└── BindToClose.luau   ← Graceful shutdown
```

---

## 🤔 FAQ

### **Q: Does this replace my DataStore code?**
**A:** No! It's a safety wrapper. You still control your data format.

### **Q: What happens if a save fails?**
**A:** Automatic retry with exponential backoff (up to 3 times). Previous snapshot is preserved.

### **Q: What if MemoryStore is down?**
**A:** SessionLock automatically falls back to DataStore.

### **Q: Can I use this with ProfileService?**
**A:** Not recommended. ProfileService has its own safety mechanisms.

### **Q: Does this work with UpdateAsync?**
**A:** Yes! Snapshot system uses UpdateAsync internally.

---

## 📝 License

MIT License - See LICENSE file

---

## 🙏 Credits

Built with ❤️ for the Roblox developer community.

Special thanks to TestEZ and Rojo teams.

---

## 🔗 Links

- [GitHub Repository](https://github.com/lycifer3/saveguard-roblox)
- [Wally Package](https://wally.run/package/lycifer3/saveguard)
- [Examples](./examples/)
- [GitHub Issues](https://github.com/lycifer3/saveguard-roblox/issues)

---

**Ready to protect your player data?** Get started in 30 seconds! 🚀

