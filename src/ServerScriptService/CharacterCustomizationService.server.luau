--!strict
-- CharacterCustomizationService.server.luau
-- Серверный сервис управления созданием, валидацией и применением кастомизации персонажа

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterCustomizationConfig = require(ReplicatedStorage:WaitForChild("CharacterCustomizationConfig"))
local ClassConfig = require(ReplicatedStorage:WaitForChild("ClassConfig"))

local ClassSystem = ServerScriptService:WaitForChild("ClassSystem")
local ClassDataManager = require(ClassSystem:WaitForChild("ClassDataManager"))
local ClassService = require(ClassSystem:WaitForChild("ClassService"))
local StatCalculationService = require(ClassSystem:WaitForChild("StatCalculationService"))
local WeaponService = require(ServerScriptService:WaitForChild("WeaponSystem"):WaitForChild("WeaponService"))

-- =================================================================
-- 1. СЕТЕВЫЕ СОБЫТИЯ КАСТОМИЗАЦИИ
-- =================================================================
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

local function GetOrCreateRemoteFunction(parent: Instance, name: string): RemoteFunction
	local rf = parent:FindFirstChild(name)
	if not rf or not rf:IsA("RemoteFunction") then
		if rf then rf:Destroy() end
		rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = parent
	end
	return rf :: RemoteFunction
end

local CreationEventsFolder = GetOrCreateFolder(ReplicatedStorage, "CharacterCreationEvents")
local OpenCharacterCreation = GetOrCreateRemoteEvent(CreationEventsFolder, "OpenCharacterCreation")
local OpenCharacterCreationRemote = GetOrCreateRemoteEvent(CreationEventsFolder, "OpenCharacterCreationRemote")
local SubmitCharacterCreationRemote = GetOrCreateRemoteEvent(CreationEventsFolder, "SubmitCharacterCreationRemote")
local CharacterCreationResponse = GetOrCreateRemoteEvent(CreationEventsFolder, "CharacterCreationResponse")
local SubmitCharacterCreationFunction = GetOrCreateRemoteFunction(CreationEventsFolder, "SubmitCharacterCreation")

-- =================================================================
-- 2. ВАЛИДАЦИЯ И ПРИМЕНЕНИЕ СОЗДАНИЯ ПЕРСОНАЖА
-- =================================================================
local function ProcessCharacterCreation(player: Player, payload: any): (boolean, string)
	if type(payload) ~= "table" then
		return false, "Некорректный формат данных создания персонажа"
	end

	local className = payload.ClassName
	local classInfo = ClassConfig.GetClass(className)
	if not classInfo then
		return false, "Недопустимый класс: " .. tostring(className)
	end

	local appData = payload.Appearance
	if type(appData) ~= "table" then
		return false, "Отсутствуют параметры внешности"
	end

	local data = ClassDataManager.Get(player)
	if not data then
		return false, "Данные профиля игрока не загружены"
	end

	local skinIndex = math.clamp(tonumber(appData.SkinColorIndex) or 1, 1, #CharacterCustomizationConfig.SkinColors)
	local faceIndex = math.clamp(tonumber(appData.FaceIndex) or 1, 1, #CharacterCustomizationConfig.Faces)
	local hairIndex = math.clamp(tonumber(appData.HairIndex) or 1, 1, #CharacterCustomizationConfig.Hairs)
	local hairColorIndex = math.clamp(tonumber(appData.HairColorIndex) or 1, 1, #CharacterCustomizationConfig.HairColors)

	local hairName = if type(appData.HairName) == "string" and appData.HairName ~= "" then appData.HairName else "None"
	local faceName = if type(appData.FaceName) == "string" and appData.FaceName ~= "" then appData.FaceName else "Face1"

	local validatedAppearance: CharacterCustomizationConfig.AppearanceData = {
		SkinColorIndex = skinIndex,
		FaceIndex = faceIndex,
		HairIndex = hairIndex,
		HairColorIndex = hairColorIndex,
		HairName = hairName,
		FaceName = faceName,
	}

	-- 1. Сохранение выбора в ProfileService
	data.SelectedClass = className
	data.IsCharacterCreated = true
	data.Appearance = validatedAppearance

	local profile = ClassDataManager.GetProfile(player)
	if profile and profile.Data then
		profile.Data.IsCharacterCreated = true
		profile.Data.SelectedClass = className
		profile.Data.Appearance = validatedAppearance
		if profile.Data.Appearance then
			profile.Data.Appearance.IsCreated = true
		end
	end

	ClassService.SetPlayerClass(player, className)
	player:SetAttribute("SelectedClass", className)
	player:SetAttribute("Class", className)
	player:SetAttribute("IsCharacterCreated", true)

	-- 2. Синхронизируем состояние с остальными интерфейсами
	pcall(function()
		local classEvents = ReplicatedStorage:FindFirstChild("ClassEvents")
		if classEvents then
			local syncEvent = classEvents:FindFirstChild("SyncClassDataEvent") or classEvents:FindFirstChild("SyncClassData")
			if syncEvent and syncEvent:IsA("RemoteEvent") then
				syncEvent:FireClient(player, data)
			end
		end
		local skillEvents = ReplicatedStorage:FindFirstChild("SkillTreeEvents")
		if skillEvents then
			local syncSkill = skillEvents:FindFirstChild("SyncSkillDataEvent") or skillEvents:FindFirstChild("SyncSkillData")
			if syncSkill and syncSkill:IsA("RemoteEvent") then
				syncSkill:FireClient(player, data)
			end
		end
	end)

	-- 3. Нативный пайплайн спавна движка Roblox (как в Esc -> Reset Character)
	-- Движок сам рассчитает SpawnLocation, коллизию ног и корректный HipHeight
	task.defer(function()
		if player:IsDescendantOf(Players) then
			player:LoadCharacter()
		end
	end)

	print(string.format("[CharacterCustomization] Персонаж для %s успешно создан! Запущен player:LoadCharacter(). Класс: %s", player.Name, className))
	return true, "Персонаж успешно создан!"
end

-- Обработка вызова через RemoteEvent
SubmitCharacterCreationRemote.OnServerEvent:Connect(function(player: Player, payload: any)
	local success, msg = ProcessCharacterCreation(player, payload)
	CharacterCreationResponse:FireClient(player, success, msg)
end)

-- Обработка вызова через RemoteFunction
SubmitCharacterCreationFunction.OnServerInvoke = function(player: Player, payload: any)
	local success, msg = ProcessCharacterCreation(player, payload)
	return success, msg
end

-- =================================================================
-- 3. ОБРАБОТКА СПАВНА И ЗАМОРОЗКА ПРИ ПЕРВОМ ВХОДЕ
-- =================================================================
local function EnsureDefaultClothing(character: Model)
	local defaultClothing = ReplicatedStorage:FindFirstChild("DefaultClothing")
	if defaultClothing and character then
		if not character:FindFirstChildOfClass("Shirt") then
			local shirt = defaultClothing:FindFirstChildOfClass("Shirt")
			if shirt then shirt:Clone().Parent = character end
		end
		if not character:FindFirstChildOfClass("Pants") then
			local pants = defaultClothing:FindFirstChildOfClass("Pants")
			if pants then pants:Clone().Parent = character end
		end
	end
end

local function OnCharacterSpawned(player: Player, character: Model)
	-- Проверяем наличие базовой одежды новичка сразу при спавне модели
	EnsureDefaultClothing(character)

	local data = ClassDataManager.WaitUntilLoaded(player, 10)
	if not data then return end

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then return end

	-- Повторная проверка одежды после готовности Humanoid
	EnsureDefaultClothing(character)

	local isCreated = ClassDataManager.IsCharacterCreated(player)

	if not isCreated then
		-- Замораживаем перемещение игрока при первом входе
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0

		-- Вызываем RemoteEvent открытия интерфейса создания персонажа
		task.delay(0.25, function()
			if player:IsDescendantOf(Players) and not ClassDataManager.IsCharacterCreated(player) then
				OpenCharacterCreation:FireClient(player, {
					Profile = data,
				})
			end
		end)
	else
		-- Персонаж уже создан: применяем сохраненную внешность при нативном спавне движка
		task.defer(function()
			if character:IsDescendantOf(workspace) then
				local app = ClassDataManager.GetAppearance(player)
				CharacterCustomizationConfig.ApplyAppearanceToCharacter(character, app, data.SelectedClass)

				-- Гарантируем наличие базовой одежды после применения внешности
				EnsureDefaultClothing(character)

				character:SetAttribute("SelectedClass", data.SelectedClass)
				character:SetAttribute("Class", data.SelectedClass)
				character:SetAttribute("IsCharacterCreated", true)

				-- Восстанавливаем параметры передвижения и физики
				humanoid.PlatformStand = false
				if humanoid.HipHeight < 1.5 then
					humanoid.HipHeight = 2.0
				end
				humanoid.WalkSpeed = 16
				humanoid.JumpPower = 50
				humanoid.JumpHeight = 7.2

				-- Применяем статы и выдаем стартовое оружие
				StatCalculationService.ApplyToCharacter(player)
				WeaponService.GiveStarterWeapon(player, data.SelectedClass)
			end
		end)
	end
end

local function SetupPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		EnsureDefaultClothing(character)
		OnCharacterSpawned(player, character)
	end)

	if player.Character then
		task.spawn(function()
			EnsureDefaultClothing(player.Character)
			OnCharacterSpawned(player, player.Character)
		end)
	end

	-- Универсальный полный сброс персонажа (/reset, /resetchar, /resetclass, !reset и т.д.)
	local function performFullCharacterReset(targetPlayer: Player)
		ClassService.PerformFullCharacterReset(targetPlayer)
	end

	player.Chatted:Connect(function(msg)
		local clean = string.lower(string.match(msg, "^%s*(.-)%s*$") or msg)
		if clean == "/reset"
			or clean == "/resetchar"
			or clean == "/resetclass"
			or clean == "!reset"
			or clean == "!resetchar"
			or clean == "!resetclass"
			or clean == "/recreate"
			or clean == "!recreate"
			or clean == "/customization"
			or clean == "!customization" then
			performFullCharacterReset(player)
		end
	end)
end

Players.PlayerAdded:Connect(SetupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		SetupPlayer(player)
	end)
end
