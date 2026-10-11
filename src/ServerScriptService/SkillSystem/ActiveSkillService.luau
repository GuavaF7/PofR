--!strict
-- ActiveSkillService.luau
-- Серверный сервис активных навыков, камней умений и сокетов (PoE-style Skill Gems & Sockets)
-- Серверный авторитет (Server Authority): валидация экипировки, кулдауны, физика умений и расчёт урона.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ServerScriptService = game:GetService("ServerScriptService")

local SkillGemConfig = require(ReplicatedStorage:WaitForChild("SkillGemConfig"))
local CombatConfig = require(ReplicatedStorage:WaitForChild("CombatConfig"))
local CombatNetwork = require(ReplicatedStorage:WaitForChild("CombatNetwork"))

local ClassSystem = ServerScriptService:WaitForChild("ClassSystem")
local ClassDataManager = require(ClassSystem:WaitForChild("ClassDataManager"))

local ActiveSkillService = {}

local isInitialized = false
local playerCooldowns: { [Player]: { [string]: number } } = {}

-- Проверка, разрешено ли наносить урон цели
local function CanDamageTarget(attackerChar: Model, targetChar: Model): boolean
	if attackerChar == targetChar then
		return false
	end

	local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
	local attackerPlayer = Players:GetPlayerFromCharacter(attackerChar)

	if targetPlayer and attackerPlayer then
		local pvpGloballyEnabled = workspace:GetAttribute("PvPEnabled")
		if pvpGloballyEnabled == nil then
			pvpGloballyEnabled = CombatConfig.Settings.PvPEnabled
		end

		if not pvpGloballyEnabled then
			return false
		end
	end

	return true
end

-- Расчет урона навыка на основе скалирования характеристик
local function CalculateSkillDamage(
	attacker: Model,
	gemData: SkillGemConfig.SkillGemData
): (number, boolean)
	local totalStr = (attacker:GetAttribute("TotalSTR") or 10) :: number
	local totalAgi = (attacker:GetAttribute("TotalAGI") or 10) :: number
	local totalInt = (attacker:GetAttribute("TotalINT") or 10) :: number
	local bonusMelee = (attacker:GetAttribute("BonusMeleeDamage") or 0) :: number
	local bonusMagic = (attacker:GetAttribute("BonusMagicDamage") or 0) :: number
	local bonusCrit = (attacker:GetAttribute("BonusCritChance") or 0) :: number

	local rawDamage = gemData.BaseDamage
	local statBonus = 0
	local damageMultiplier = 1.0

	if gemData.RequiredAttribute == "STR" then
		statBonus = totalStr * gemData.DamageScaling
		damageMultiplier = 1.0 + (bonusMelee / 100)
	elseif gemData.RequiredAttribute == "INT" then
		statBonus = totalInt * gemData.DamageScaling
		damageMultiplier = 1.0 + (bonusMagic / 100)
	elseif gemData.RequiredAttribute == "AGI" then
		statBonus = totalAgi * gemData.DamageScaling
		damageMultiplier = 1.0 + (bonusMelee / 100)
	end

	rawDamage = (rawDamage + statBonus) * damageMultiplier

	local baseCrit = 5
	if gemData.RequiredAttribute == "AGI" or gemData.Id == "DashStrike" then
		baseCrit += math.floor(totalAgi * 0.25) + 10 -- Дополнительный крит для навыков ловкости
	end

	local finalCrit = math.clamp(baseCrit + bonusCrit, 0, 85)
	local isCrit = math.random(1, 100) <= finalCrit

	if isCrit then
		rawDamage *= 1.75
	end

	return math.floor(math.max(1, rawDamage)), isCrit
end

-- Вспомогательная функция создания Tool камня в рюкзаке
local function CreateGemTool(gemData: SkillGemConfig.SkillGemData): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Gem_" .. gemData.Id
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.8, 0.8, 0.8)
	handle.Shape = Enum.PartType.Ball
	handle.Material = Enum.Material.Neon
	handle.Color = SkillGemConfig.GetColorForGem(gemData.Color)
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	tool:SetAttribute("ItemType", "SkillGem")
	tool:SetAttribute("GemId", gemData.Id)
	tool:SetAttribute("GemColor", gemData.Color)
	tool:SetAttribute("RequiredAttribute", gemData.RequiredAttribute)
	tool:SetAttribute("Cooldown", gemData.Cooldown)
	tool:SetAttribute("ManaCost", gemData.ManaCost)
	tool:SetAttribute("Description", gemData.Description)

	return tool
end

-- 1. Выполнение умения GroundSlam (Конусная волна по земле)
local function ExecuteGroundSlam(player: Player, character: Model, hrp: BasePart, gemData: SkillGemConfig.SkillGemData)
	local hitEffectEvent = CombatNetwork.GetHitEffectEvent()
	local skillEffectEvent = CombatNetwork.GetSkillEffectEvent()

	local range = gemData.Range or 18
	local forward = hrp.CFrame.LookVector
	local centerPos = hrp.Position + forward * (range * 0.5)

	-- Оповещаем клиентов о визуальной волне по земле
	if skillEffectEvent then
		skillEffectEvent:FireAllClients("GroundSlam", hrp.Position, hrp.Position + forward * range)
	end

	local boxSize = Vector3.new(14, 6, range)
	local boxCFrame = CFrame.new(centerPos, centerPos + forward)

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }
	overlapParams.MaxParts = 40

	local hitParts = workspace:GetPartBoundsInBox(boxCFrame, boxSize, overlapParams)
	local damagedTargets: { [Model]: boolean } = {}

	for _, part in ipairs(hitParts) do
		local targetModel = part:FindFirstAncestorOfClass("Model")
		if targetModel and not damagedTargets[targetModel] and targetModel ~= character then
			local targetHumanoid = targetModel:FindFirstChildOfClass("Humanoid")
			local targetHrp = targetModel:FindFirstChild("HumanoidRootPart") :: BasePart?

			if targetHumanoid and targetHumanoid.Health > 0 and targetHrp then
				if CanDamageTarget(character, targetModel) then
					-- Проверяем сектор конуса (перед персонажем)
					local toTarget = (targetHrp.Position - hrp.Position).Unit
					local dot = forward:Dot(toTarget)
					if dot >= 0.20 then
						damagedTargets[targetModel] = true
						local damage, isCrit = CalculateSkillDamage(character, gemData)
						pcall(function()
							targetHumanoid:TakeDamage(damage)
						end)

						if hitEffectEvent then
							hitEffectEvent:FireAllClients(targetHrp.Position, isCrit, damage)
						end
					end
				end
			end
		end
	end
end

-- 2. Выполнение умения Fireball (Взрывной огненный шар)
local function ExecuteFireball(
	player: Player,
	character: Model,
	hrp: BasePart,
	gemData: SkillGemConfig.SkillGemData,
	targetPosition: Vector3
)
	local hitEffectEvent = CombatNetwork.GetHitEffectEvent()
	local skillEffectEvent = CombatNetwork.GetSkillEffectEvent()

	local spawnPos = hrp.Position + hrp.CFrame.LookVector * 2.5 + Vector3.new(0, 0.5, 0)
	local direction = (targetPosition - spawnPos)
	if direction.Magnitude < 0.1 or targetPosition == Vector3.zero then
		direction = hrp.CFrame.LookVector
	else
		direction = direction.Unit
	end

	-- Создаем серверный визуальный снаряд
	local fireball = Instance.new("Part")
	fireball.Name = "Skill_Fireball"
	fireball.Shape = Enum.PartType.Ball
	fireball.Size = Vector3.new(1.8, 1.8, 1.8)
	fireball.Color = Color3.fromRGB(255, 110, 20)
	fireball.Material = Enum.Material.Neon
	fireball.CanCollide = false
	fireball.Anchored = true
	fireball.CFrame = CFrame.new(spawnPos, spawnPos + direction)
	fireball.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 30)
	light.Range = 14
	light.Brightness = 3
	light.Parent = fireball

	local speed = gemData.Speed or 100
	local maxRange = gemData.Range or 65
	local blastRadius = gemData.Radius or 8
	local traveled = 0
	local hit = false

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character, fireball }
	rayParams.IgnoreWater = true

	local function Explode(impactPosition: Vector3)
		if skillEffectEvent then
			skillEffectEvent:FireAllClients("Fireball_Explode", impactPosition, impactPosition)
		end

		local overlapParams = OverlapParams.new()
		overlapParams.FilterType = RaycastFilterType.Exclude
		overlapParams.FilterDescendantsInstances = { character, fireball }
		overlapParams.MaxParts = 50

		local partsInRadius = workspace:GetPartBoundsInRadius(impactPosition, blastRadius, overlapParams)
		local damagedTargets: { [Model]: boolean } = {}

		for _, part in ipairs(partsInRadius) do
			local targetModel = part:FindFirstAncestorOfClass("Model")
			if targetModel and not damagedTargets[targetModel] and targetModel ~= character then
				local targetHum = targetModel:FindFirstChildOfClass("Humanoid")
				local targetHrp = targetModel:FindFirstChild("HumanoidRootPart") :: BasePart?

				if targetHum and targetHum.Health > 0 and targetHrp then
					if CanDamageTarget(character, targetModel) then
						damagedTargets[targetModel] = true
						local damage, isCrit = CalculateSkillDamage(character, gemData)
						pcall(function()
							targetHum:TakeDamage(damage)
						end)

						if hitEffectEvent then
							hitEffectEvent:FireAllClients(targetHrp.Position, isCrit, damage)
						end
					end
				end
			end
		end

		if fireball and fireball.Parent then
			fireball:Destroy()
		end
	end

	task.spawn(function()
		while traveled < maxRange and not hit and fireball.Parent do
			local dt = RunService.Heartbeat:Wait()
			local stepDistance = speed * dt
			local currentPos = fireball.Position
			local nextPos = currentPos + direction * stepDistance

			local rayResult = workspace:Raycast(currentPos, direction * stepDistance, rayParams)
			if rayResult then
				hit = true
				Explode(rayResult.Position)
				break
			else
				fireball.Position = nextPos
				traveled += stepDistance
			end
		end

		if not hit and fireball.Parent then
			Explode(fireball.Position)
		end
	end)

	Debris:AddItem(fireball, 2.5)
end

-- 3. Выполнение умения DashStrike (Мгновенный рывок вперед с уроном на линии)
local function ExecuteDashStrike(player: Player, character: Model, hrp: BasePart, gemData: SkillGemConfig.SkillGemData)
	local hitEffectEvent = CombatNetwork.GetHitEffectEvent()
	local skillEffectEvent = CombatNetwork.GetSkillEffectEvent()

	local maxDash = gemData.Range or 25
	local lookDir = hrp.CFrame.LookVector
	local startPos = hrp.Position

	-- Проверка препятствий лучом (не проходим сквозь стены)
	local wallParams = RaycastParams.new()
	wallParams.FilterType = Enum.RaycastFilterType.Exclude
	wallParams.FilterDescendantsInstances = { character }
	wallParams.IgnoreWater = true

	local wallHit = workspace:Raycast(startPos, lookDir * maxDash, wallParams)
	local actualDist = maxDash
	if wallHit then
		actualDist = math.max(0, wallHit.Distance - 2)
	end

	local endPos = startPos + lookDir * actualDist

	-- Оповещаем клиентов о спецэффекте рывка
	if skillEffectEvent then
		skillEffectEvent:FireAllClients("DashStrike", startPos, endPos)
	end

	-- Перемещаем персонажа к точке назначения
	hrp.CFrame = CFrame.new(endPos, endPos + lookDir)

	-- Хитбокс по линии рывка
	local midPos = (startPos + endPos) / 2
	local boxSize = Vector3.new(6, 6, actualDist + 2)
	local boxCFrame = CFrame.new(midPos, endPos)

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }
	overlapParams.MaxParts = 40

	local hitParts = workspace:GetPartBoundsInBox(boxCFrame, boxSize, overlapParams)
	local damagedTargets: { [Model]: boolean } = {}

	for _, part in ipairs(hitParts) do
		local targetModel = part:FindFirstAncestorOfClass("Model")
		if targetModel and not damagedTargets[targetModel] and targetModel ~= character then
			local targetHumanoid = targetModel:FindFirstChildOfClass("Humanoid")
			local targetHrp = targetModel:FindFirstChild("HumanoidRootPart") :: BasePart?

			if targetHumanoid and targetHumanoid.Health > 0 and targetHrp then
				if CanDamageTarget(character, targetModel) then
					damagedTargets[targetModel] = true
					local damage, isCrit = CalculateSkillDamage(character, gemData)
					pcall(function()
						targetHumanoid:TakeDamage(damage)
					end)

					if hitEffectEvent then
						hitEffectEvent:FireAllClients(targetHrp.Position, isCrit, damage)
					end
				end
			end
		end
	end
end

-- Обработка запроса на каст навыка от клиента
local function HandleCastSkillRequest(player: Player, gemId: any, clientTargetPos: any)
	if typeof(gemId) ~= "string" then return end

	local gemData = SkillGemConfig.GetGem(gemId)
	if not gemData then return end

	local character = player.Character
	if not character or not character:IsDescendantOf(workspace) then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not hrp then return end

	-- 1. Валидация: камень должен быть вставлен в текущую экипировку игрока
	local isSocketed, _slotName = ClassDataManager.IsGemSocketed(player, gemId)
	if not isSocketed then
		return
	end

	-- 2. Серверная проверка кулдауна способности (защита от читов)
	if not playerCooldowns[player] then
		playerCooldowns[player] = {}
	end

	local now = os.clock()
	local lastCast = playerCooldowns[player][gemId] or 0
	local minCooldown = gemData.Cooldown - 0.1 -- Небольшой допуск на пинг

	if (now - lastCast) < minCooldown then
		return
	end

	playerCooldowns[player][gemId] = now

	-- 3. Вычисление точки прицела
	local targetPos: Vector3
	if typeof(clientTargetPos) == "Vector3" and clientTargetPos ~= Vector3.zero then
		targetPos = clientTargetPos
	else
		targetPos = hrp.Position + hrp.CFrame.LookVector * 50
	end

	-- 4. Выполнение механики умения
	if gemId == "GroundSlam" then
		ExecuteGroundSlam(player, character, hrp, gemData)
	elseif gemId == "Fireball" then
		ExecuteFireball(player, character, hrp, gemData, targetPos)
	elseif gemId == "DashStrike" then
		ExecuteDashStrike(player, character, hrp, gemData)
	end
end

-- Обработка операций с сокетами (Вставить / Извлечь камень)
local function HandleSocketGemInvoke(player: Player, action: any, slotName: any, gemId: any): (boolean, string, any)
	if typeof(action) ~= "string" or typeof(slotName) ~= "string" then
		return false, "Invalid parameters", nil
	end

	local syncSocketsEvent = CombatNetwork.GetSyncSocketsEvent()

	if action == "Socket" then
		if typeof(gemId) ~= "string" then
			return false, "Invalid gem id", nil
		end

		local gemData = SkillGemConfig.GetGem(gemId)
		if not gemData then
			return false, "Unknown gem", nil
		end

		-- Ищем соответствующий предмет-камень в Backpack или Character
		local bp = player:FindFirstChildOfClass("Backpack")
		local char = player.Character

		local foundTool: Tool? = nil
		local targetToolName = "Gem_" .. gemId

		if bp then
			foundTool = bp:FindFirstChild(targetToolName) :: Tool?
		end
		if not foundTool and char then
			foundTool = char:FindFirstChild(targetToolName) :: Tool?
		end

		if not foundTool then
			return false, "You do not have this gem in your inventory", nil
		end

		-- Уничтожаем инструмент камня из инвентаря
		foundTool:Destroy()

		-- Вставляем камень в сокет профиля
		local ok, oldGemId = ClassDataManager.SocketGem(player, slotName, gemId)
		if not ok then
			-- В случае сбоя возвращаем камень
			local restored = CreateGemTool(gemData)
			if bp then restored.Parent = bp end
			return false, "Failed to save socket data", nil
		end

		-- Если в гнезде уже был старый камень — возвращаем его в рюкзак
		if oldGemId and oldGemId ~= "" and oldGemId ~= gemId then
			local oldGemData = SkillGemConfig.GetGem(oldGemId)
			if oldGemData and bp then
				local oldTool = CreateGemTool(oldGemData)
				oldTool.Parent = bp
			end
		end

		local currentSockets = ClassDataManager.GetSocketedGems(player)
		if syncSocketsEvent then
			syncSocketsEvent:FireClient(player, currentSockets)
		end

		return true, "Gem socketed successfully", currentSockets

	elseif action == "Unsocket" then
		local oldGemId = ClassDataManager.UnsocketGem(player, slotName)
		if not oldGemId or oldGemId == "" then
			return false, "Socket is already empty", nil
		end

		local gemData = SkillGemConfig.GetGem(oldGemId)
		local bp = player:FindFirstChildOfClass("Backpack")
		if gemData and bp then
			local gemTool = CreateGemTool(gemData)
			gemTool.Parent = bp
		end

		local currentSockets = ClassDataManager.GetSocketedGems(player)
		if syncSocketsEvent then
			syncSocketsEvent:FireClient(player, currentSockets)
		end

		return true, "Gem unsocketed successfully", currentSockets
	end

	return false, "Unknown action", nil
end

function ActiveSkillService.Start()
	if isInitialized then return end
	isInitialized = true

	local castSkillEvent = CombatNetwork.GetCastSkillEvent()
	if castSkillEvent then
		castSkillEvent.OnServerEvent:Connect(HandleCastSkillRequest)
	end

	local socketGemFunc = CombatNetwork.GetSocketGemFunction()
	if socketGemFunc then
		socketGemFunc.OnServerInvoke = HandleSocketGemInvoke
	end

	Players.PlayerAdded:Connect(function(player)
		playerCooldowns[player] = {}
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerCooldowns[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		playerCooldowns[player] = {}
	end

	print("[ActiveSkillService] Сервис активных умений и сокетов успешно запущен")
end

ActiveSkillService.Start()

return ActiveSkillService
