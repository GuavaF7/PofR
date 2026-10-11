local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ClassConfig = require(ReplicatedStorage:WaitForChild("ClassConfig"))
local SkillTreeConfig = require(ReplicatedStorage:WaitForChild("SkillTreeConfig"))

local ClassSystem = ServerScriptService:WaitForChild("ClassSystem")
local ClassDataManager = require(ClassSystem:WaitForChild("ClassDataManager"))

local StatCalculationService = {}

function StatCalculationService.CalculateStats(player: Player)
	local data = ClassDataManager.Get(player)
	if not data or not data.SelectedClass or data.SelectedClass == "None" then
		return nil
	end

	local classInfo = ClassConfig.GetClass(data.SelectedClass)
	if not classInfo then
		return nil
	end

	-- Базовые статы класса
	local stats = {
		MaxHealth = classInfo.BaseStats.MaxHealth or 100,
		WalkSpeed = classInfo.BaseStats.WalkSpeed or 16,
		Strength = classInfo.BaseStats.Strength or 10,
		Agility = classInfo.BaseStats.Agility or 10,
		Intelligence = classInfo.BaseStats.Intelligence or 10,
		BonusMeleeDamage = 0,
		BonusMagicDamage = 0,
		BonusCritChance = 0,
	}

	-- Учитываем прибавки от всех сохранённых узлов Древа Навыков
	local allocated = data.AllocatedNodes or {}
	local allNodes = SkillTreeConfig.Nodes or SkillTreeConfig

	for nodeId, isAllocated in pairs(allocated) do
		if isAllocated and allNodes[nodeId] and allNodes[nodeId].Stats then
			for statName, value in pairs(allNodes[nodeId].Stats) do
				if stats[statName] ~= nil then
					stats[statName] += value
				end
			end
		end
	end

	-- Дополнительный бонус HP от Силы (+2 HP за 1 STR)
	stats.MaxHealth += (stats.Strength * 2)

	return stats
end

function StatCalculationService.ApplyToCharacter(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local calculatedStats = StatCalculationService.CalculateStats(player)
	if not calculatedStats then
		return
	end

	-- Применяем физические параметры с защитой от сброса и отхила в бою
	local oldMax = humanoid.MaxHealth
	local currentHealth = humanoid.Health
	local isFirstSpawn = not character:GetAttribute("StatsInitialized")

	humanoid.MaxHealth = calculatedStats.MaxHealth

	if isFirstSpawn then
		-- При первом спавне выдаем полное здоровье под новый MaxHealth
		humanoid.Health = calculatedStats.MaxHealth
		character:SetAttribute("StatsInitialized", true)
	else
		-- В процессе игры/боя сохраняем точный процент текущего HP (без полного отхила)
		local healthPercent = currentHealth / math.max(oldMax, 1)
		humanoid.Health = math.clamp(calculatedStats.MaxHealth * healthPercent, 1, calculatedStats.MaxHealth)
	end

	humanoid.WalkSpeed = calculatedStats.WalkSpeed

	-- Записываем атрибуты для боевой системы и инвентаря
	character:SetAttribute("TotalSTR", calculatedStats.Strength)
	character:SetAttribute("TotalAGI", calculatedStats.Agility)
	character:SetAttribute("TotalINT", calculatedStats.Intelligence)
	character:SetAttribute("BonusMeleeDamage", calculatedStats.BonusMeleeDamage)
	character:SetAttribute("BonusMagicDamage", calculatedStats.BonusMagicDamage)
	character:SetAttribute("BonusCritChance", calculatedStats.BonusCritChance)
end

return StatCalculationService