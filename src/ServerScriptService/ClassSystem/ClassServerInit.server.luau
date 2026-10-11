--!strict
-- ClassServerInit.server.luau
-- Серверная инициализация системы классов, статов, экипировки и команд чата

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TextChatService = game:GetService("TextChatService")

-- =================================================================
-- 1. ГАРАНТИРОВАННОЕ СОЗДАНИЕ СЕТЕВЫХ СОБЫТИЙ (БЕЗ ЗАВИСАНИЙ)
-- =================================================================
local function GetOrCreateFolder(name: string): Folder
	local folder = ReplicatedStorage:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = ReplicatedStorage
	end
	return folder :: Folder
end

local function GetOrCreateRemoteFunction(folder: Folder, name: string): RemoteFunction
	local rf = folder:FindFirstChild(name)
	if not rf or not rf:IsA("RemoteFunction") then
		if rf then rf:Destroy() end
		rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = folder
	end
	return rf :: RemoteFunction
end

local function GetOrCreateRemoteEvent(folder: Folder, name: string): RemoteEvent
	local re = folder:FindFirstChild(name)
	if not re or not re:IsA("RemoteEvent") then
		if re then re:Destroy() end
		re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = folder
	end
	return re :: RemoteEvent
end

-- Папка и события классов
local ClassEvents = GetOrCreateFolder("ClassEvents")
local SelectClassFunction = GetOrCreateRemoteFunction(ClassEvents, "SelectClass")
local GetClassDataFunction = GetOrCreateRemoteFunction(ClassEvents, "GetClassData")
local SyncClassDataEvent = GetOrCreateRemoteEvent(ClassEvents, "SyncClassData")

-- Папка и события древа навыков
local SkillTreeEvents = GetOrCreateFolder("SkillTreeEvents")
local AllocateNodeFunction = GetOrCreateRemoteFunction(SkillTreeEvents, "AllocateNode")
local ResetSkillTreeFunction = GetOrCreateRemoteFunction(SkillTreeEvents, "ResetSkillTree")
local SyncSkillDataEvent = GetOrCreateRemoteEvent(SkillTreeEvents, "SyncSkillData")

-- Подключение серверных сервисов
local ClassSystem = ServerScriptService:WaitForChild("ClassSystem")
local ClassDataManager = require(ClassSystem:WaitForChild("ClassDataManager"))
local ClassService = require(ClassSystem:WaitForChild("ClassService"))
local StatCalculationService = require(ClassSystem:WaitForChild("StatCalculationService"))

local SkillTreeSystem = ServerScriptService:WaitForChild("SkillTreeSystem")
local SkillTreeService = require(SkillTreeSystem:WaitForChild("SkillTreeService"))

local WeaponService = require(ServerScriptService:WaitForChild("WeaponSystem"):WaitForChild("WeaponService"))
local CombatService = require(ServerScriptService:WaitForChild("WeaponSystem"):WaitForChild("CombatService"))

local SkillSystem = ServerScriptService:WaitForChild("SkillSystem")
local _ActiveSkillService = require(SkillSystem:WaitForChild("ActiveSkillService"))

-- =================================================================
-- 2. БЕЗОПАСНАЯ ИНИЦИАЛИЗАЦИЯ ПЕРСОНАЖА ПРИ СПАВНЕ / ПЕРЕЗАХОДЕ
-- =================================================================
local function OnCharacterSpawned(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	-- Дожидаемся полной загрузки профиля из DataStore / ProfileService
	local data = ClassDataManager.WaitUntilLoaded(player, 10)
	if not data then
		return
	end

	-- Проверяем, что персонаж всё ещё в игре
	if character:IsDescendantOf(workspace) then
		task.wait(0.2) -- Даём движку Roblox время на инициализацию Backpack

		-- 1. Применяем итоговые характеристики (класс + прокачанные узлы дерева)
		StatCalculationService.ApplyToCharacter(player)

		-- 2. Выдаем стартовое оружие текущего класса
		WeaponService.GiveStarterWeapon(player, data.SelectedClass)

		-- 3. Выдаем тестовые камни умений при первом входе/спавне
		WeaponService.GiveStarterGems(player)
	end
end

-- =================================================================
-- 3. ВЫБОР КЛАССА В GUI
-- =================================================================
SelectClassFunction.OnServerInvoke = function(player: Player, className: string)
	local success, message = ClassService.SetPlayerClass(player, className)
	local data = ClassDataManager.Get(player)

	if success and data then
		local char = player.Character
		if char then
			char:SetAttribute("SelectedClass", className)
			char:SetAttribute("Class", className)
		end
		player:SetAttribute("SelectedClass", className)
		player:SetAttribute("Class", className)

		StatCalculationService.ApplyToCharacter(player)
		WeaponService.GiveStarterWeapon(player, data.SelectedClass)
		SyncClassDataEvent:FireClient(player, data)
		SyncSkillDataEvent:FireClient(player, data)
	end

	return success, message
end

GetClassDataFunction.OnServerInvoke = function(player: Player)
	return ClassDataManager.WaitUntilLoaded(player)
end

-- =================================================================
-- 4. УНИВЕРСАЛЬНЫЙ СБРОС ПЕРСОНАЖА (/reset, /resetchar, /resetclass, !reset)
-- =================================================================
local function IsResetCommand(message: string): boolean
	if not message then return false end
	local cleanMsg = string.lower(string.match(message, "^%s*(.-)%s*$") or message)
	return cleanMsg == "/reset"
		or cleanMsg == "/resetchar"
		or cleanMsg == "/resetclass"
		or cleanMsg == "!reset"
		or cleanMsg == "!resetchar"
		or cleanMsg == "!resetclass"
		or cleanMsg == "/recreate"
		or cleanMsg == "!recreate"
		or cleanMsg == "/customization"
		or cleanMsg == "!customization"
end

local function ProcessChatCommand(player: Player, message: string)
	if not message then return end
	if IsResetCommand(message) then
		ClassService.PerformFullCharacterReset(player)
	end
end

-- =================================================================
-- 5. ИНИЦИАЛИЗАЦИЯ ИГРОКОВ И СЛУШАТЕЛЕЙ ЧАТА (Legacy + TextChatService)
-- =================================================================
local function SetupPlayer(player: Player)
	ClassDataManager.PlayerAdded(player)

	-- Legacy Chat listener
	player.Chatted:Connect(function(msg)
		ProcessChatCommand(player, msg)
	end)

	player.CharacterAdded:Connect(function(character)
		OnCharacterSpawned(player, character)
	end)

	if player.Character then
		task.spawn(function()
			OnCharacterSpawned(player, player.Character)
		end)
	end
end

Players.PlayerAdded:Connect(SetupPlayer)

-- Поддержка игроков, которые уже загрузились до старта скрипта
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		SetupPlayer(player)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	ClassDataManager.PlayerRemoving(player)
end)

-- Поддержка современной системы чата Roblox (TextChatService)
pcall(function()
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		TextChatService.MessageReceived:Connect(function(textChatMessage: TextChatMessage)
			if textChatMessage.TextSource then
				local sender = Players:GetPlayerByUserId(textChatMessage.TextSource.UserId)
				if sender then
					ProcessChatCommand(sender, textChatMessage.Text)
				end
			end
		end)

		local textChatCommands = TextChatService:FindFirstChildOfClass("TextChatCommands")
		if not textChatCommands then
			textChatCommands = TextChatService:FindFirstChild("TextChatCommands") :: any
		end
		if textChatCommands then
			local function createChatCmd(name: string, primary: string, secondary: string?)
				local cmd = textChatCommands:FindFirstChild(name) :: TextChatCommand?
				if not cmd then
					cmd = Instance.new("TextChatCommand")
					cmd.Name = name
					cmd.PrimaryAlias = primary
					if secondary then
						cmd.SecondaryAlias = secondary
					end
					cmd.Parent = textChatCommands
					cmd.Triggered:Connect(function(textSource, _)
						local sender = Players:GetPlayerByUserId(textSource.UserId)
						if sender then
							ClassService.PerformFullCharacterReset(sender)
						end
					end)
				end
			end

			createChatCmd("ResetCommand", "/reset", "/resetchar")
			createChatCmd("ResetClassCommand", "/resetclass", "/recreate")
		end
	end
end)

print("[ClassServerInit] Серверная система классов и команд чата успешно запущена")