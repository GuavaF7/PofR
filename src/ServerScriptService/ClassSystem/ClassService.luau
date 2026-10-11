--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassSystem = ServerScriptService:WaitForChild("ClassSystem")
local ClassDataManager = require(ClassSystem:WaitForChild("ClassDataManager"))
local StatCalculationService = require(ClassSystem:WaitForChild("StatCalculationService"))
local ClassConfig = require(ReplicatedStorage:WaitForChild("ClassConfig"))
local WeaponService = require(ServerScriptService:WaitForChild("WeaponSystem"):WaitForChild("WeaponService"))

local function GetOrCreateFolder(parent: Instance, name: string): Folder
	local folder = parent:FindFirstChild(name)
	if not folder or not folder:IsA("Folder") then
		if folder then folder:Destroy() end
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder :: Folder
end

local function GetOrCreateRemoteEvent(parent: Instance, name: string): RemoteEvent
	local re = parent:FindFirstChild(name)
	if not re or not re:IsA("RemoteEvent") then
		if re then re:Destroy() end
		re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = parent
	end
	return re :: RemoteEvent
end

local CreationEventsFolder = GetOrCreateFolder(ReplicatedStorage, "CharacterCreationEvents")
local OpenCharacterCreation = GetOrCreateRemoteEvent(CreationEventsFolder, "OpenCharacterCreation")
local OpenCharacterCreationRemote = GetOrCreateRemoteEvent(CreationEventsFolder, "OpenCharacterCreationRemote")

local resetDebounce: { [Player]: number } = {}

local ClassService = {}

function ClassService.SetPlayerClass(player: Player, className: string): (boolean, string?)
	local classInfo = ClassConfig.GetClass(className)
	if not classInfo then
		return false, "Несуществующий класс: " .. tostring(className)
	end

	local data = ClassDataManager.Get(player)
	if not data then
		return false, "Данные игрока не загружены."
	end

	data.SelectedClass = className

	-- Рассчитываем и применяем итоговые статы
	StatCalculationService.ApplyToCharacter(player)

	return true, nil
end

function ClassService.ResetPlayerClass(player: Player)
	local data = ClassDataManager.Get(player)
	if data then
		data.SelectedClass = "None"
		data.LastEquippedWeapon = ""
		StatCalculationService.ApplyToCharacter(player)
	end
end

function ClassService.PerformFullCharacterReset(player: Player)
	local now = os.clock()
	if resetDebounce[player] and (now - resetDebounce[player] < 0.5) then
		return
	end
	resetDebounce[player] = now

	local profile = ClassDataManager.GetProfile(player)
	if not profile or not profile.Data then return end

	-- 1. Сброс данных класса и прокачки
	profile.Data.SelectedClass = "None"
	profile.Data.AllocatedNodes = {}
	profile.Data.LastEquippedWeapon = ""
	profile.Data.SkillPoints = 5

	-- 2. Сброс данных кастомизации и статуса создания
	profile.Data.IsCharacterCreated = false
	if profile.Data.Appearance then
		profile.Data.Appearance.IsCreated = false
	end

	-- 3. Очистка оружия и экипировки
	WeaponService.ClearExistingStarterWeapons(player)

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:UnequipTools()
			-- Замораживаем персонажа на время создания
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			humanoid.JumpHeight = 0
		end

		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Accessory") or item:IsA("Shirt") or item:IsA("Pants") then
				item:Destroy()
			end
		end

		character:SetAttribute("SelectedClass", "None")
		character:SetAttribute("Class", "None")
		character:SetAttribute("IsCharacterCreated", false)
	end

	player:SetAttribute("SelectedClass", "None")
	player:SetAttribute("Class", "None")
	player:SetAttribute("IsCharacterCreated", false)

	-- Синхронизация статов
	StatCalculationService.ApplyToCharacter(player)

	-- Синхронизация сетевых событий дерева классов и навыков
	pcall(function()
		local classEvents = ReplicatedStorage:FindFirstChild("ClassEvents")
		if classEvents then
			local syncEvent = classEvents:FindFirstChild("SyncClassDataEvent") or classEvents:FindFirstChild("SyncClassData")
			if syncEvent and syncEvent:IsA("RemoteEvent") then
				syncEvent:FireClient(player, profile.Data)
			end
		end
		local skillEvents = ReplicatedStorage:FindFirstChild("SkillTreeEvents")
		if skillEvents then
			local syncSkill = skillEvents:FindFirstChild("SyncSkillDataEvent") or skillEvents:FindFirstChild("SyncSkillData")
			if syncSkill and syncSkill:IsA("RemoteEvent") then
				syncSkill:FireClient(player, profile.Data)
			end
		end
	end)

	-- 4. Уведомление клиента и открытие экрана создания
	OpenCharacterCreation:FireClient(player, { Profile = profile.Data, IsReset = true })
	OpenCharacterCreationRemote:FireClient(player, { Profile = profile.Data, IsReset = true })

	print(string.format("[ClassService] Полный сброс персонажа выполнен для %s", player.Name))
end

return ClassService