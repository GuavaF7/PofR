local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

-- ID целевого плейса Данжа (Акт 1)
local DUNGEON_PLACE_ID = 87893523248425

-- Поиск триггера по точной структуре в Explorer
local teleportFolder = workspace:WaitForChild("Teleport")
local portalModel = teleportFolder:WaitForChild("PortalTriigerDungAct1")
local portalPart = portalModel:WaitForChild("PortalTriggerDunAct1")

local teleportingPlayers = {}

print("Триггер портала найден и готов к работе: " .. portalPart:GetFullName())

portalPart.Touched:Connect(function(hit)
	local character = hit.Parent
	local player = Players:GetPlayerFromCharacter(character)

	-- Проверяем, что коснулся живой игрок и он еще не в процессе телепортации
	if player and not teleportingPlayers[player] then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			teleportingPlayers[player] = true
			print("Инициализация телепортации игрока в Акт 1: " .. player.Name)

			local teleportOptions = Instance.new("TeleportOptions")
			teleportOptions.ShouldReserveServer = true

			local success, errorMessage = pcall(function()
				TeleportService:TeleportAsync(DUNGEON_PLACE_ID, {player}, teleportOptions)
			end)

			if not success then
				warn("Не удалось отправить игрока в данж: ", errorMessage)
				task.wait(2)
				teleportingPlayers[player] = nil
			end
		end
	end
end)