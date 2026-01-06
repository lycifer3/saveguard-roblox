--[[
	Config.spec.luau
	Unit tests for Config module
]]

return function()
	local Config = require(game.ServerScriptService.DataSafetyKit.Config)
	
	describe("Config module", function()
		it("should have AUTOSAVE_INTERVAL", function()
			expect(Config.AUTOSAVE_INTERVAL).to.be.ok()
			expect(Config.AUTOSAVE_INTERVAL).to.equal(60)
		end)
		
		it("should have MAX_RETRIES", function()
			expect(Config.MAX_RETRIES).to.be.ok()
			expect(Config.MAX_RETRIES).to.equal(3)
		end)
		
		it("should have RETRY_BACKOFF array", function()
			expect(Config.RETRY_BACKOFF).to.be.ok()
			expect(#Config.RETRY_BACKOFF).to.equal(3)
			expect(Config.RETRY_BACKOFF[1]).to.equal(1)
			expect(Config.RETRY_BACKOFF[2]).to.equal(2)
			expect(Config.RETRY_BACKOFF[3]).to.equal(4)
		end)
		
		it("should have SESSION_LOCK_TIMEOUT", function()
			expect(Config.SESSION_LOCK_TIMEOUT).to.be.ok()
			expect(Config.SESSION_LOCK_TIMEOUT).to.equal(30)
		end)
		
		it("should have ENABLE_SNAPSHOTS", function()
			expect(Config.ENABLE_SNAPSHOTS).to.be.ok()
			expect(Config.ENABLE_SNAPSHOTS).to.equal(true)
		end)
		
		it("should have DEFAULT_KEY_FORMAT function", function()
			expect(Config.DEFAULT_KEY_FORMAT).to.be.a("function")
			local key = Config.DEFAULT_KEY_FORMAT(12345)
			expect(key).to.equal("player:12345")
		end)
		
		it("should have DEFAULT_DATASTORE_NAME", function()
			expect(Config.DEFAULT_DATASTORE_NAME).to.be.ok()
			expect(Config.DEFAULT_DATASTORE_NAME).to.be.a("string")
		end)
	end)
end

