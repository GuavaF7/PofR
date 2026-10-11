local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassSystem = ServerScriptService:WaitForChild("ClassSystem")
local ClassDataManager = require(ClassSystem:WaitForChild("ClassDataManager"))
local StatCalculationService = require(ClassSystem:WaitForChild("StatCalculationService"))

local SkillTreeConfig = require(ReplicatedStorage:WaitForChild("SkillTreeConfig"))
local SkillTreeEvents = ReplicatedStorage:WaitForChild("SkillTreeEvents")

-- Регистрируем RemoteFunction для прокачки и сброса
local AllocateNodeFunction = SkillTreeEvents:FindFirstChild("AllocateNode") or Instance.new("RemoteFunction")
AllocateNodeFunction.Name = "AllocateNode"
AllocateNodeFunction.Parent = SkillTreeEvents

local ResetSkillTreeFunction = SkillTreeEvents:FindFirstChild("ResetSkillTree") or Instance.new("RemoteFunction")
ResetSkillTreeFunction.Name = "ResetSkillTree"
ResetSkillTreeFunction.Parent = SkillTreeEvents

local SyncSkillDataEvent = SkillTreeEvents:WaitForChild("SyncSkillData") :: RemoteEvent
local SyncClassDataEvent = ReplicatedStorage:WaitForChild("ClassEvents"):WaitForChild("SyncClassData") :: RemoteEvent

local SkillTreeService = {}

-- 1. ИЗУЧЕНИЕ УЗЛА
function SkillTreeService.AllocateNode(player: Player, nodeId: string): (boolean, string?)
	local data = ClassDataManager.Get(player)
	if not data then
		return false, "Данные игрока не загружены"
	end

	local nodesTable = SkillTreeConfig.Nodes or SkillTreeConfig
	local nodeData = nodesTable[nodeId]
	if not nodeData then
		return false, "Узел не найден в конфиге"
	end

	data.AllocatedNodes = data.AllocatedNodes or {}
	if data.AllocatedNodes[nodeId] then
		return false, "Узел уже изучен"
	end

	if nodeData.ParentNode and not data.AllocatedNodes[nodeData.ParentNode] then
		return false, "Сначала изучите предыдущий узел"
	end

	data.SkillPoints = data.SkillPoints or 0
	local cost = nodeData.Cost or 1
	if data.SkillPoints < cost then
		return false, "Недостаточно очков навыков"
	end

	-- Списываем очки и прокачиваем узел
	data.SkillPoints -= cost
	data.AllocatedNodes[nodeId] = true

	if StatCalculationService and StatCalculationService.ApplyToCharacter then
		StatCalculationService.ApplyToCharacter(player)
	end

	SyncSkillDataEvent:FireClient(player, data)
	SyncClassDataEvent:FireClient(player, data)

	return true, "Узел изучен!"
end

-- 2. СБРОС ДРЕВА НАВЫКОВ ЗА БИЛЕТ СБРОСА
function SkillTreeService.ResetSkillTree(player: Player): (boolean, string?)
	local data = ClassDataManager.Get(player)
	if not data then
		return false, "Данные игрока не загружены"
	end

	data.AllocatedNodes = data.AllocatedNodes or {}

	-- Считаем количество изученных узлов и очки для возврата
	local allocatedCount = 0
	local pointsToRefund = 0
	local nodesTable = SkillTreeConfig.Nodes or SkillTreeConfig

	for nodeId, isAllocated in pairs(data.AllocatedNodes) do
		if isAllocated then
			allocatedCount += 1
			local cost = nodesTable[nodeId] and nodesTable[nodeId].Cost or 1
			pointsToRefund += cost
		end
	end

	if allocatedCount == 0 then
		return false, "Нет изученных навыков для сброса"
	end

	-- Проверяем баланс билетов сброса (выдаем 1 бесплатный билет по умолчанию для теста)
	data.ResetTickets = data.ResetTickets or 1
	if data.ResetTickets < 1 then
		return false, "Требуется 1x Билет сброса! (Выпадает из боссов)"
	end

	-- Списываем 1 билет и возвращаем все очки
	data.ResetTickets -= 1
	data.AllocatedNodes = {}
	data.SkillPoints = (data.SkillPoints or 0) + pointsToRefund

	-- Пересчитываем характеристики
	if StatCalculationService and StatCalculationService.ApplyToCharacter then
		StatCalculationService.ApplyToCharacter(player)
	end

	SyncSkillDataEvent:FireClient(player, data)
	SyncClassDataEvent:FireClient(player, data)

	return true, string.format("Сброс выполнен! Возвращено %d очков.", pointsToRefund)
end

AllocateNodeFunction.OnServerInvoke = function(player, nodeId)
	return SkillTreeService.AllocateNode(player, nodeId)
end

ResetSkillTreeFunction.OnServerInvoke = function(player)
	return SkillTreeService.ResetSkillTree(player)
end

return SkillTreeService