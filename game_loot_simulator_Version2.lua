
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local PLACE_ID = game.PlaceId
local function getCurrentJobId() return game.JobId end

local ONLY_ALLOWED_DROP = "talisman"
local PLAY_BUTTON_POS = Vector2.new(202, 732)
local MAX_ATTEMPTS = 3
local CHECK_DELAY = 5


local function simulateClickPlay()
	local gui = LocalPlayer:FindFirstChild("PlayerGui")
	if not gui then return end

	local success = pcall(function()
		gui:WaitForChild("Menu", 5):WaitForChild("MenuButtons", 5):WaitForChild("Play", 5)
	end)

	if not success then
		warn("❌ 無法找到 Play 按鈕")
		return
	end

	task.wait(0.5)
	VirtualInputManager:SendMouseButtonEvent(PLAY_BUTTON_POS.X, PLAY_BUTTON_POS.Y, 0, true, game, 0)
	VirtualInputManager:SendMouseButtonEvent(PLAY_BUTTON_POS.X, PLAY_BUTTON_POS.Y, 0, false, game, 0)
	warn("🖱️ 已模擬點擊 Play 按鈕")
end


local function getDropFolder()
	local timeout, interval, elapsed = 5, 0.2, 0
	while elapsed < timeout do
		local root = workspace:FindFirstChild("Objects")
		if root then
			local drops = root:FindFirstChild("Drops")
			if drops then return drops end
		end
		task.wait(interval)
		elapsed += interval
	end
	warn("❌ 沒找到 Drops")
	return nil
end


local function teleportTo(item)
	local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local cf = item:IsA("Model") and (item.PrimaryPart and item.PrimaryPart.CFrame or item:GetPivot())
	if cf then
		root.CFrame = cf + Vector3.new(0, 3, 0)
		task.wait(0.5)
	end
end

local function tryPickup(item)
	local prompt = item:FindFirstChildOfClass("ProximityPrompt", true)
	if prompt then
		warn("🎁 撿起物品：" .. item.Name)
		fireproximityprompt(prompt)
		task.wait(1)
	end
end


local function isSafeToHop()
	local drops = getDropFolder()
	if not drops then return false end

	for _, item in pairs(drops:GetChildren()) do
		local name = string.lower(item.Name)
		if name ~= ONLY_ALLOWED_DROP and not string.find(name, "chestgroup") then
			return false
		end
	end
	return true
end


local function handleLootLoop()
	local attempts = 0

	while true do
		local drops = getDropFolder()
		if not drops then return false end

		local foundRare = false
		local allTalismanOrChest = true

		for _, item in pairs(drops:GetChildren()) do
			local name = string.lower(item.Name)

			if string.find(name, "chestgroup") then
				warn("💼 發現 ChestGroup → 立即跳服")
				return true
			end

			if name ~= ONLY_ALLOWED_DROP then
				foundRare = true
				allTalismanOrChest = false
				teleportTo(item)
				tryPickup(item)
			end
		end

		if not foundRare and allTalismanOrChest then
			warn("🗑️ 只有 Talisman → 立即跳服")
			return true
		end

		attempts += 1
		if attempts >= MAX_ATTEMPTS then
			warn("⚠️ 撿了 " .. MAX_ATTEMPTS .. " 次還在 → 模擬點擊 UI 再試")
			simulateClickPlay()
			attempts = 0
		end

		task.wait(0.8)
	end
end


local function smartHop()
	while true do
		local best, fallback = {}, {}

		local success, servers = pcall(function()
			return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. PLACE_ID .. "/servers/Public?sortOrder=Asc&limit=100"))
		end)

		if success and servers and servers.data then
			for _, v in ipairs(servers.data) do
				if v.id ~= getCurrentJobId() then
					if v.playing < 10 then
						table.insert(best, v.id)
					elseif v.playing == 10 then
						table.insert(fallback, v.id)
					end
				end
			end

			local function tryTeleportFrom(list)
				if #list == 0 then return false end
				local chosen = list[math.random(1, #list)]

				-- queueonteleport 移除，因為主程式直接從 Gist 執行

				warn("🚀 跳轉伺服器 ID:", chosen)
				TeleportService:TeleportToPlaceInstance(PLACE_ID, chosen, LocalPlayer)
				return true
			end

			if tryTeleportFrom(best) or tryTeleportFrom(fallback) then
				return
			end
		end

		warn("🔁 找不到伺服器 → 5 秒後重試")
		task.wait(5)
	end
end


repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
task.wait(CHECK_DELAY)

if handleLootLoop() then
	smartHop()
else
	warn("🧍‍♂️ 保留目前伺服器")
end
