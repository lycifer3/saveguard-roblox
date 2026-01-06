--[[
	SaveQueue.luau
	Manages a queue of save requests with retry logic and exponential backoff.
	Ensures only one active save operation per key at a time.
]]

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

type SaveRequest = Types.SaveRequest

local SaveQueue = {}
SaveQueue.__index = SaveQueue

-- Create a new SaveQueue instance
function SaveQueue.new()
	local self = setmetatable({}, SaveQueue)
	
	-- Queue of pending save requests
	self._queue = {} :: {SaveRequest}
	
	-- Set of keys currently being saved (prevents duplicate saves)
	self._activeKeys = {} :: {[string]: boolean}
	
	-- Callbacks for error handling
	self._onError = nil :: ((err: string) -> ())?
	
	return self
end

-- Check if a key is currently being saved
function SaveQueue:isActive(key: string): boolean
	return self._activeKeys[key] == true
end

-- Add a save request to the queue
function SaveQueue:enqueue(request: SaveRequest, key: string)
	-- Check if this key is already being saved
	if self:isActive(key) then
		warn("[SaveQueue] Duplicate save blocked for key:", key)
		return false
	end
	
	-- Add retry counter if not present
	if not request.retries then
		request.retries = 0
	end
	
	-- Mark key as active
	self._activeKeys[key] = true
	
	-- Add to queue
	table.insert(self._queue, {
		request = request,
		key = key,
	})
	
	return true
end

-- Remove and return the next request from the queue
function SaveQueue:dequeue(): ({request: SaveRequest, key: string})?
	if #self._queue == 0 then
		return nil
	end
	
	local item = table.remove(self._queue, 1)
	return item
end

-- Process a save request with retry logic
function SaveQueue:processSave(
	store: DataStore,
	key: string,
	request: SaveRequest,
	transformFn: (old: any) -> any
): (boolean, string?)
	local retries = request.retries or 0
	local maxRetries = Config.MAX_RETRIES
	
	-- Try to save with retry logic
	for attempt = 1, maxRetries + 1 do
		local success, result = pcall(function()
			return store:UpdateAsync(key, transformFn)
		end)
		
		if success then
			-- Save successful
			self._activeKeys[key] = nil
			return true, nil
		else
			-- Save failed
			local errorMsg = tostring(result)
			warn(string.format(
				"[SaveQueue] Save failed (attempt %d/%d) for key %s: %s",
				attempt,
				maxRetries + 1,
				key,
				errorMsg
			))
			
			-- Check if we should retry
			if attempt <= maxRetries then
				-- Calculate backoff delay
				local backoffDelay = Config.RETRY_BACKOFF[attempt] or Config.RETRY_BACKOFF[#Config.RETRY_BACKOFF]
				
				-- Wait before retry
				task.wait(backoffDelay)
				
				-- Increment retry counter
				request.retries = attempt
			else
				-- Max retries reached
				self._activeKeys[key] = nil
				
				if self._onError then
					self._onError(string.format(
						"Max retries reached for key %s: %s",
						key,
						errorMsg
					))
				end
				
				return false, errorMsg
			end
		end
	end
	
	-- Should never reach here, but just in case
	self._activeKeys[key] = nil
	return false, "Unknown error"
end

-- Process the entire queue
function SaveQueue:processQueue(
	store: DataStore,
	transformFn: (key: string, request: SaveRequest) -> ((old: any) -> any)
)
	while true do
		local item = self:dequeue()
		if not item then
			break
		end
		
		local key = item.key
		local request = item.request
		
		-- Create transform function for this specific request
		local transform = transformFn(key, request)
		
		-- Process save with retry logic
		local success, err = self:processSave(store, key, request, transform)
		
		if not success then
			warn("[SaveQueue] Failed to save key:", key, "Error:", err)
		end
	end
end

-- Flush all pending saves (used in BindToClose)
function SaveQueue:flush(
	store: DataStore,
	transformFn: (key: string, request: SaveRequest) -> ((old: any) -> any),
	timeout: number?
): boolean
	local startTime = os.clock()
	local timeoutDuration = timeout or Config.SESSION_LOCK_TIMEOUT
	
	while #self._queue > 0 do
		-- Check timeout
		if os.clock() - startTime > timeoutDuration then
			warn(string.format(
				"[SaveQueue] Flush timeout reached. %d saves remaining.",
				#self._queue
			))
			return false
		end
		
		-- Process one item
		local item = self:dequeue()
		if item then
			local key = item.key
			local request = item.request
			local transform = transformFn(key, request)
			
			self:processSave(store, key, request, transform)
		end
	end
	
	return true
end

-- Set error callback
function SaveQueue:onError(callback: (err: string) -> ())
	self._onError = callback
end

-- Get queue size
function SaveQueue:size(): number
	return #self._queue
end

-- Clear the queue (emergency only)
function SaveQueue:clear()
	self._queue = {}
	self._activeKeys = {}
end

return SaveQueue

