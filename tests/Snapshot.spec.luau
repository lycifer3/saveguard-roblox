--[[
	Snapshot.spec.luau
	Unit tests for Snapshot module
]]

return function()
	local Snapshot = require(game.ServerScriptService.DataSafetyKit.Snapshot)
	
	describe("Snapshot module", function()
		local snapshot
		
		beforeEach(function()
			snapshot = Snapshot.new()
		end)
		
		describe("createSnapshot", function()
			it("should create snapshot with version", function()
				local data = {coins = 100}
				local snap = snapshot:createSnapshot(data)
				
				expect(snap.version).to.be.ok()
				expect(snap.version).to.equal(1)
			end)
			
			it("should create snapshot with timestamp", function()
				local data = {coins = 100}
				local snap = snapshot:createSnapshot(data)
				
				expect(snap.timestamp).to.be.ok()
				expect(snap.timestamp).to.be.a("number")
			end)
			
			it("should preserve data", function()
				local data = {coins = 100, level = 5}
				local snap = snapshot:createSnapshot(data)
				
				expect(snap.data).to.be.ok()
				expect(snap.data.coins).to.equal(100)
				expect(snap.data.level).to.equal(5)
			end)
		end)
		
		describe("wrapWithSnapshots", function()
			it("should wrap data with snapshots", function()
				local data = {coins = 100}
				local current = {version = 1, timestamp = 123, data = {coins = 90}}
				local previous = {version = 1, timestamp = 100, data = {coins = 80}}
				
				local wrapped = snapshot:wrapWithSnapshots(data, current, previous)
				
				expect(wrapped.data).to.equal(data)
				expect(wrapped.snapshots).to.be.ok()
				expect(wrapped.snapshots.current).to.equal(current)
				expect(wrapped.snapshots.previous).to.equal(previous)
			end)
		end)
		
		describe("unwrapData", function()
			it("should unwrap data", function()
				local wrapped = {
					data = {coins = 100},
					snapshots = {
						current = {version = 1, timestamp = 123, data = {coins = 90}},
						previous = {version = 1, timestamp = 100, data = {coins = 80}}
					}
				}
				
				local data, current, previous = snapshot:unwrapData(wrapped)
				
				expect(data.coins).to.equal(100)
				expect(current.data.coins).to.equal(90)
				expect(previous.data.coins).to.equal(80)
			end)
			
			it("should handle nil snapshots", function()
				local wrapped = {
					data = {coins = 100}
				}
				
				local data, current, previous = snapshot:unwrapData(wrapped)
				
				expect(data.coins).to.equal(100)
				expect(current).never.to.be.ok()
				expect(previous).never.to.be.ok()
			end)
		end)
		
		describe("validateSnapshot", function()
			it("should validate correct snapshot", function()
				local snap = {
					version = 1,
					timestamp = os.time(),
					data = {coins = 100}
				}
				
				expect(snapshot:validateSnapshot(snap)).to.equal(true)
			end)
			
			it("should reject snapshot without version", function()
				local snap = {
					timestamp = os.time(),
					data = {coins = 100}
				}
				
				expect(snapshot:validateSnapshot(snap)).to.equal(false)
			end)
			
			it("should reject snapshot without timestamp", function()
				local snap = {
					version = 1,
					data = {coins = 100}
				}
				
				expect(snapshot:validateSnapshot(snap)).to.equal(false)
			end)
			
			it("should reject snapshot without data", function()
				local snap = {
					version = 1,
					timestamp = os.time()
				}
				
				expect(snapshot:validateSnapshot(snap)).to.equal(false)
			end)
		end)
		
		describe("getSnapshotAge", function()
			it("should calculate snapshot age", function()
				local snap = {
					version = 1,
					timestamp = os.time() - 10,
					data = {}
				}
				
				local age = snapshot:getSnapshotAge(snap)
				expect(age).to.be.near(10, 1)
			end)
			
			it("should return huge age for nil snapshot", function()
				local age = snapshot:getSnapshotAge(nil)
				expect(age).to.equal(math.huge)
			end)
		end)
	end)
end

