--[[
	SaveQueue.spec.luau
	Unit tests for SaveQueue module
]]

return function()
	local SaveQueue = require(game.ServerScriptService.DataSafetyKit.SaveQueue)
	
	describe("SaveQueue module", function()
		local queue
		
		beforeEach(function()
			queue = SaveQueue.new()
		end)
		
		afterEach(function()
			queue:clear()
		end)
		
		describe("initialization", function()
			it("should create new queue instance", function()
				expect(queue).to.be.ok()
			end)
			
			it("should start with size 0", function()
				expect(queue:size()).to.equal(0)
			end)
		end)
		
		describe("enqueue", function()
			it("should enqueue a request", function()
				local request = {
					userId = 123,
					data = {test = true},
					timestamp = os.time(),
				}
				
				local success = queue:enqueue(request, "test_key")
				expect(success).to.equal(true)
				expect(queue:size()).to.equal(1)
			end)
			
			it("should block duplicate keys", function()
				local request = {
					userId = 123,
					data = {test = true},
					timestamp = os.time(),
				}
				
				queue:enqueue(request, "test_key")
				local duplicate = queue:enqueue(request, "test_key")
				
				expect(duplicate).to.equal(false)
				expect(queue:size()).to.equal(1)
			end)
			
			it("should allow different keys", function()
				local request1 = {userId = 1, data = {}, timestamp = os.time()}
				local request2 = {userId = 2, data = {}, timestamp = os.time()}
				
				queue:enqueue(request1, "key1")
				queue:enqueue(request2, "key2")
				
				expect(queue:size()).to.equal(2)
			end)
		end)
		
		describe("dequeue", function()
			it("should dequeue a request", function()
				local request = {
					userId = 123,
					data = {test = true},
					timestamp = os.time(),
				}
				
				queue:enqueue(request, "test_key")
				local item = queue:dequeue()
				
				expect(item).to.be.ok()
				expect(item.key).to.equal("test_key")
				expect(queue:size()).to.equal(0)
			end)
			
			it("should return nil when empty", function()
				local item = queue:dequeue()
				expect(item).never.to.be.ok()
			end)
			
			it("should maintain FIFO order", function()
				queue:enqueue({userId = 1}, "key1")
				queue:enqueue({userId = 2}, "key2")
				
				local first = queue:dequeue()
				local second = queue:dequeue()
				
				expect(first.key).to.equal("key1")
				expect(second.key).to.equal("key2")
			end)
		end)
		
		describe("isActive", function()
			it("should return false for inactive key", function()
				expect(queue:isActive("test_key")).to.equal(false)
			end)
			
			it("should return true for active key", function()
				queue:enqueue({userId = 1}, "test_key")
				expect(queue:isActive("test_key")).to.equal(true)
			end)
		end)
	end)
end

