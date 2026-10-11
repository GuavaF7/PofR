local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ChestEvents = ReplicatedStorage:WaitForChild("ChestEvents")
local ToggleChestGui = ChestEvents:WaitForChild("ToggleChestGui")
local TransferItem = ChestEvents:WaitForChild("TransferItem")

local playerStashes = Instance.new("Folder")
playerStashes.Name = "PlayerStashes"
playerStashes.Parent = ServerStorage

local function getStashItemNames(stash)
	local names = {}
	for _, item in ipairs(stash:GetChildren()) do
		if item:IsA("Tool") then
			table.insert(names, item.Name)
		end
	end
	return names
end

Players.PlayerAdded:Connect(function(player)
	local stash = Instance.new("Folder")
	stash.Name = tostring(player.UserId)
	stash.Parent = playerStashes
end)

Players.PlayerRemoving:Connect(function(player)
	local stash = playerStashes:FindFirstChild(tostring(player.UserId))
	if stash then
		stash:Destroy()
	end
end)

local function setupChest(chest)
	local prompt = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Triggered:Connect(function(player)
			local stash = playerStashes:FindFirstChild(tostring(player.UserId))
			if stash then
				ToggleChestGui:FireClient(player, getStashItemNames(stash))
			end
		end)
	end
end

for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("ProximityPrompt") then
		setupChest(descendant.Parent)
	end
end

workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("ProximityPrompt") then
		setupChest(descendant.Parent)
	end
end)

TransferItem.OnServerEvent:Connect(function(player, action, itemName)
	local stash = playerStashes:FindFirstChild(tostring(player.UserId))
	local backpack = player:FindFirstChild("Backpack")
	local character = player.Character

	if not stash or not backpack then return end

	if action == "Deposit" then
		local item = backpack:FindFirstChild(itemName)
		if not item and character then
			local equipped = character:FindFirstChild(itemName)
			if equipped and equipped:IsA("Tool") then
				item = equipped
			end
		end

		if item and item:IsA("Tool") then
			item.Parent = stash
		end

	elseif action == "Withdraw" then
		local item = stash:FindFirstChild(itemName)
		if item and item:IsA("Tool") then
			item.Parent = backpack
		end
	end

	-- Отправляем клиенту обновлённый список предметов в тайнике
	ToggleChestGui:FireClient(player, getStashItemNames(stash))
end)