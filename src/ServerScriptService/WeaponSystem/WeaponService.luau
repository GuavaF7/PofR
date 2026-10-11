--!strict
-- WeaponService.luau
-- Серверный сервис выдачи, управления и автоэкипировки оружия в Path of Roblox (PofR)

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ClassConfig = require(ReplicatedStorage:WaitForChild("ClassConfig"))
local CombatConfig = require(ReplicatedStorage:WaitForChild("CombatConfig"))
local SkillGemConfig = require(ReplicatedStorage:WaitForChild("SkillGemConfig"))
local _CombatService = require(ServerScriptService:WaitForChild("WeaponSystem"):WaitForChild("CombatService"))

local ClassSystem = ServerScriptService:WaitForChild("ClassSystem")
local ClassDataManager = require(ClassSystem:WaitForChild("ClassDataManager"))

local WeaponService = {}

-- Набор известных имен стартового оружия
local STARTER_WEAPON_NAMES: { [string]: boolean } = {
	StarterSword = true,
	StarterStaff = true,
	StarterDaggers = true,
}

-- Динамически регистрируем стартовое оружие из ClassConfig
for _, classData in pairs(ClassConfig.Classes) do
	if classData.StarterWeapon then
		STARTER_WEAPON_NAMES[classData.StarterWeapon] = true
	end
end

-- Кэш процедурных временных шаблонов (в памяти), чтобы не засорять ServerStorage.StarterWeapons
local proceduralTemplates: { [string]: Tool } = {}

-- Кэшированная ссылка на папку StarterWeapons
local cachedStarterWeaponsFolder: Instance? = nil

-- Безопасное получение папки StarterWeapons из ServerStorage
local function GetStarterWeaponsFolder(): Instance?
	if cachedStarterWeaponsFolder and cachedStarterWeaponsFolder.Parent == ServerStorage then
		return cachedStarterWeaponsFolder
	end

	local folder = ServerStorage:FindFirstChild("StarterWeapons")
	if not folder then
		folder = ServerStorage:WaitForChild("StarterWeapons", 5)
	end

	cachedStarterWeaponsFolder = folder
	return folder
end

-- Процедурное создание временного Tool с базовым блоком Handle (fallback для классов без кастомной модели)
local function CreateProceduralFallback(weaponName: string): Tool
	local cached = proceduralTemplates[weaponName]
	if cached then
		return cached
	end

	local profile = CombatConfig.GetWeaponProfile(weaponName)

	local tool = Instance.new("Tool")
	tool.Name = weaponName
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = false

	-- Атрибуты для клиента и серверного инспектора
	tool:SetAttribute("Category", profile.Category)
	tool:SetAttribute("Subtype", profile.Subtype)
	tool:SetAttribute("AttackPattern", profile.AttackPattern)
	tool:SetAttribute("IsTwoHanded", profile.IsTwoHanded)
	tool:SetAttribute("ScalingStat", profile.ScalingStat)
	tool:SetAttribute("WeaponType", profile.WeaponType or profile.Subtype)
	tool:SetAttribute("DamageType", profile.DamageType or profile.Category)
	tool:SetAttribute("BaseDamage", profile.BaseDamage)
	tool:SetAttribute("AttackCooldown", profile.AttackCooldown)
	tool:SetAttribute("AttackRange", profile.AttackRange)
	tool:SetAttribute("WindupDelay", profile.WindupDelay)
	tool:SetAttribute("IsStarterWeapon", true)
	tool:SetAttribute("IsProceduralFallback", true)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 4, 1)
	handle.Transparency = 0.5
	handle.Color = Color3.fromRGB(255, 215, 0)
	handle.CanCollide = false
	handle.Massless = true

	-- Точка крепления для Motor6D / RightGrip
	local gripAttachment = Instance.new("Attachment")
	gripAttachment.Name = "RightGripAttachment"
	gripAttachment.Position = Vector3.new(0, -1.5, 0)
	gripAttachment.Parent = handle

	handle.Parent = tool
	proceduralTemplates[weaponName] = tool

	return tool
end

-- Поиск готового шаблона в ServerStorage.StarterWeapons или процедурный fallback
local function GetOrCreateWeaponTemplate(weaponName: string): (Tool, boolean)
	local starterFolder = GetStarterWeaponsFolder()
	if starterFolder then
		local customTool = starterFolder:FindFirstChild(weaponName)
		if customTool and customTool:IsA("Tool") then
			return customTool, false -- Найден готовый кастомный 3D-шаблон
		end
	end

	-- Если готовый шаблон не найден в StarterWeapons — используем процедурный fallback
	return CreateProceduralFallback(weaponName), true
end

-- Проверка, является ли инструмент стартовым оружием
local function IsStarterWeapon(item: Instance): boolean
	if not item:IsA("Tool") then
		return false
	end

	if item:GetAttribute("IsStarterWeapon") == true then
		return true
	end

	if STARTER_WEAPON_NAMES[item.Name] == true then
		return true
	end

	return false
end

-- Очистка стартового оружия у игрока (в рюкзаке и в руках), не затрагивая сторонний лут
function WeaponService.ClearExistingStarterWeapons(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if IsStarterWeapon(item) then
				item:Destroy()
			end
		end
	end

	local character = player.Character
	if character then
		for _, item in ipairs(character:GetChildren()) do
			if IsStarterWeapon(item) then
				item:Destroy()
			end
		end
	end
end

-- Выдача стартового оружия текущего класса игроку с поддержкой автоэкипировки
function WeaponService.GiveStarterWeapon(player: Player, className: string): Tool?
	WeaponService.ClearExistingStarterWeapons(player)

	if not className or className == "None" then
		ClassDataManager.SetLastEquippedWeapon(player, "")
		return nil
	end

	local classInfo = ClassConfig.GetClass(className)
	if not classInfo or not classInfo.StarterWeapon then
		return nil
	end

	local weaponName = classInfo.StarterWeapon
	local template, isFallback = GetOrCreateWeaponTemplate(weaponName)

	if isFallback then
		warn(string.format("[WeaponService] Инструмент '%s' для класса '%s' не найден в ServerStorage.StarterWeapons. Использован процедурный fallback.", weaponName, className))
	end

	-- Клонируем найденный готовый или процедурный шаблон
	local weaponClone = template:Clone()
	weaponClone.CanBeDropped = false

	-- Маркируем инструмент как стартовое оружие для надежной идентификации и очистки
	weaponClone:SetAttribute("IsStarterWeapon", true)

	-- Синхронизируем базовые боевые атрибуты из CombatConfig, если они не заданы у модели
	local profile = CombatConfig.GetWeaponProfile(weaponName)
	if weaponClone:GetAttribute("Category") == nil then
		weaponClone:SetAttribute("Category", profile.Category)
	end
	if weaponClone:GetAttribute("Subtype") == nil then
		weaponClone:SetAttribute("Subtype", profile.Subtype)
	end
	if weaponClone:GetAttribute("AttackPattern") == nil then
		weaponClone:SetAttribute("AttackPattern", profile.AttackPattern)
	end
	if weaponClone:GetAttribute("IsTwoHanded") == nil then
		weaponClone:SetAttribute("IsTwoHanded", profile.IsTwoHanded)
	end
	if weaponClone:GetAttribute("ScalingStat") == nil then
		weaponClone:SetAttribute("ScalingStat", profile.ScalingStat)
	end
	if weaponClone:GetAttribute("WeaponType") == nil then
		weaponClone:SetAttribute("WeaponType", profile.WeaponType or profile.Subtype)
	end
	if weaponClone:GetAttribute("DamageType") == nil then
		weaponClone:SetAttribute("DamageType", profile.DamageType or profile.Category)
	end
	if weaponClone:GetAttribute("BaseDamage") == nil then
		weaponClone:SetAttribute("BaseDamage", profile.BaseDamage)
	end
	if weaponClone:GetAttribute("AttackCooldown") == nil then
		weaponClone:SetAttribute("AttackCooldown", profile.AttackCooldown)
	end
	if weaponClone:GetAttribute("AttackRange") == nil then
		weaponClone:SetAttribute("AttackRange", profile.AttackRange)
	end
	if weaponClone:GetAttribute("WindupDelay") == nil then
		weaponClone:SetAttribute("WindupDelay", profile.WindupDelay)
	end

	-- Выдаем в Backpack игрока
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		backpack = player:WaitForChild("Backpack", 5) :: Backpack?
	end

	if backpack then
		weaponClone.Parent = backpack
	else
		warn(string.format("[WeaponService] Не удалось найти Backpack для игрока %s", player.Name))
	end

	-- Автоматическая экипировка оружия в руки персонажа (с задержкой для StarterCharacter)
	local weaponTool = weaponClone
	task.spawn(function()
		-- Задержка перед :EquipTool, чтобы StarterCharacter успела полностью собрать все соединения (Motor6D)
		task.wait(0.1)
		if not player:IsDescendantOf(Players) then
			return
		end

		local character = player.Character
		if not character or not character:IsDescendantOf(workspace) then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			humanoid = character:WaitForChild("Humanoid", 2) :: Humanoid?
		end

		if humanoid and humanoid.Health > 0 and weaponTool and weaponTool.Parent then
			humanoid:EquipTool(weaponTool)
			ClassDataManager.SetLastEquippedWeapon(player, weaponTool.Name)
			print(string.format("[WeaponService] Автоэкипировано стартовое оружие '%s' для игрока %s", weaponTool.Name, player.Name))
		end

		-- Страховочная проверка для моделей StarterCharacter на случай задержки инициализации соединений
		task.wait(0.15)
		if player:IsDescendantOf(Players) and character and character:IsDescendantOf(workspace) and humanoid and humanoid.Health > 0 then
			if weaponTool and weaponTool.Parent == player:FindFirstChildOfClass("Backpack") then
				humanoid:EquipTool(weaponTool)
				ClassDataManager.SetLastEquippedWeapon(player, weaponTool.Name)
			end
		end
	end)

	return weaponClone
end

-- =================================================================
-- ВЫДАЧА ТЕСТОВЫХ КАМНЕЙ УМЕНИЙ (SKILL GEMS)
-- =================================================================
function WeaponService.GiveStarterGems(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		backpack = player:WaitForChild("Backpack", 5) :: Backpack?
	end
	if not backpack then return end

	local char = player.Character
	local starterGems = { "GroundSlam", "Fireball", "DashStrike" }

	for _, gemId in ipairs(starterGems) do
		local gemToolName = "Gem_" .. gemId
		local hasInBackpack = backpack:FindFirstChild(gemToolName) ~= nil
		local hasInChar = char and char:FindFirstChild(gemToolName) ~= nil
		local isSocketed = ClassDataManager.IsGemSocketed(player, gemId)

		if not hasInBackpack and not hasInChar and not isSocketed then
			local gemData = SkillGemConfig.GetGem(gemId)
			if gemData then
				local tool = Instance.new("Tool")
				tool.Name = gemToolName
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

				tool.Parent = backpack
			end
		end
	end
end

-- =================================================================
-- ОТСЛЕЖИВАНИЕ ЭКИПИРОВКИ ДЛЯ СОХРАНЕНИЯ LAST EQUIPPED WEAPON
-- =================================================================
local function HookCharacterTracking(player: Player, character: Model)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			-- Сохраняем только реальное оружие, не камни умений
			if child:GetAttribute("ItemType") ~= "SkillGem" then
				ClassDataManager.SetLastEquippedWeapon(player, child.Name)
			end
		end
	end)

	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			task.defer(function()
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				-- Сбрасываем только если персонаж жив (не при смерти/деспавне) и в руках больше нет Tool
				if humanoid and humanoid.Health > 0 and character.Parent and character:IsDescendantOf(workspace) then
					local current = character:FindFirstChildOfClass("Tool")
					if not current or current:GetAttribute("ItemType") == "SkillGem" then
						ClassDataManager.SetLastEquippedWeapon(player, "")
					end
				end
			end)
		end
	end)

	-- Если на момент подключения инструмент уже был в руках
	local currentEquipped = character:FindFirstChildOfClass("Tool")
	if currentEquipped and currentEquipped:GetAttribute("ItemType") ~= "SkillGem" then
		ClassDataManager.SetLastEquippedWeapon(player, currentEquipped.Name)
	end
end

local function OnPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		HookCharacterTracking(player, character)
		task.delay(0.3, function()
			WeaponService.GiveStarterGems(player)
		end)
	end)
	if player.Character then
		HookCharacterTracking(player, player.Character)
		task.delay(0.3, function()
			WeaponService.GiveStarterGems(player)
		end)
	end
end

Players.PlayerAdded:Connect(OnPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	OnPlayerAdded(player)
end

-- Публичный доступ к получению шаблона для внешних систем/тестов при необходимости
WeaponService.GetOrCreateWeaponTemplate = GetOrCreateWeaponTemplate

return WeaponService