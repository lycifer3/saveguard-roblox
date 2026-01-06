--[[
	BindToClose.luau
	Handles graceful server shutdown by flushing all pending saves.
	Ensures no data loss during server shutdown with timeout protection.
]]

local Config = require(script.Parent.Config)

local BindToClose = {}
BindToClose.__index = BindToClose

-- Maximum time to wait for saves to complete (seconds)
local SHUTDOWN_TIMEOUT = 30

-- Create a new BindToClose handler
function BindToClose.new(dataManager: any)
	local self = setmetatable({}, BindToClose)
	
	self._dataManager = dataManager
	self._registered = false
	self._onShutdown = nil :: ((success: boolean) -> ())?
	
	return self
end

-- Register the BindToClose handler
function BindToClose:register()
	if self._registered then
		warn("[BindToClose] Already registered")
		return
	end
	
	game:BindToClose(function()
		self:_handleShutdown()
	end)
	
	self._registered = true
	print("[BindToClose] Registered shutdown handler")
end

-- Handle server shutdown
function BindToClose:_handleShutdown()
	local startTime = os.clock()
	
	print(string.format(
		"[BindToClose] Server shutting down. Flushing all saves (timeout: %ds)...",
		SHUTDOWN_TIMEOUT
	))
	
	-- Get queue size before flush
	local queueSize = self._dataManager:getQueueSize()
	
	if queueSize == 0 then
		print("[BindToClose] No pending saves. Shutdown complete.")
		if self._onShutdown then
			self._onShutdown(true)
		end
		return
	end
	
	print(string.format(
		"[BindToClose] Flushing %d pending save(s)...",
		queueSize
	))
	
	-- Flush all pending saves with timeout
	local success = self._dataManager:flushAllSaves(SHUTDOWN_TIMEOUT)
	
	local elapsed = os.clock() - startTime
	
	if success then
		print(string.format(
			"[BindToClose] All saves completed successfully (%.2fs)",
			elapsed
		))
		
		if self._onShutdown then
			self._onShutdown(true)
		end
	else
		local remainingCount = self._dataManager:getQueueSize()
		
		warn(string.format(
			"[BindToClose] Timeout reached! %d save(s) did not complete in %ds",
			remainingCount,
			SHUTDOWN_TIMEOUT
		))
		
		warn("[BindToClose] Some player data may not have been saved!")
		
		if self._onShutdown then
			self._onShutdown(false)
		end
	end
end

-- Set callback for shutdown completion
function BindToClose:onShutdown(callback: (success: boolean) -> ())
	self._onShutdown = callback
end

-- Check if handler is registered
function BindToClose:isRegistered(): boolean
	return self._registered
end

-- Manual flush (for testing)
function BindToClose:manualFlush(timeout: number?): boolean
	local timeoutDuration = timeout or SHUTDOWN_TIMEOUT
	
	print(string.format(
		"[BindToClose] Manual flush initiated (timeout: %ds)",
		timeoutDuration
	))
	
	return self._dataManager:flushAllSaves(timeoutDuration)
end

return BindToClose

