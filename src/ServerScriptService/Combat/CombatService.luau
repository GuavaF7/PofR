--!strict
-- CombatService.luau
-- Серверный сервис боевой системы Path of Roblox (PofR)
-- Полный серверный авторитет (Server Authority): проверка дистанции, кулдауна, экипированного оружия,
-- пространственный запрос хитбокса GetPartBoundsInBox, расчет урона со скейлингом от характеристик и перков.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local CombatConfig = require(ReplicatedStorage:WaitForChild("CombatConfig"))
local CombatNetwork = require(ReplicatedStorage:WaitForChild("CombatNetwork"))

export type AttackSession = {
	LastAttackTime: number,
	LastComboTime: number,
	LastComboStep: number,
	LastWeaponName: string?,
}

local COMBO_RESET_DELAY = 1.5

local CombatService = {}
CombatService.DebugHitboxes = false

local playerSessions: { [Player]: AttackSession } = {}
local isInitialized = false
local hitEffectEvent: RemoteEvent? = nil

-- Воспроизведение 3D звука попадания
local function PlayHitSound(parent: Instance?, soundId: string?)
	if not soundId or soundId == "" or not parent then return end
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = 0.8
		sound.RollOffMaxDistance = 80
		sound.RollOffMinDistance = 10
		sound.Parent = parent
		sound:Play()

		Debris:AddItem(sound, 2)
	end)
end

-- Вспомогательная визуализация хитбокса для тестирования (Debug)
local function VisualizeHitbox(cframe: CFrame, size: Vector3)
	if not CombatService.DebugHitboxes then return end
	pcall(function()
		local box = Instance.new("Part")
		box.Name = "DebugHitbox"
		box.Anchored = true
		box.CanCollide = false
		box.CanQuery = false
		box.CanTouch = false
		box.Material = Enum.Material.ForceField
		box.Color = Color3.fromRGB(255, 60, 60)
		box.Transparency = 0.7
		box.Size = size
		box.CFrame = cframe
		box.Parent = workspace

		Debris:AddItem(box, 0.35)
	end)
end

-- Безопасный поиск корневой части модели (для позиционирования звуков и эффектов)
local function GetCharacterRoot(character: Model): BasePart?
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		hrp = (character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") or character.PrimaryPart) :: BasePart?
	end
	if not hrp then
		hrp = character:FindFirstChildWhichIsA("BasePart")
	end
	return hrp
end

-- Надежный поиск Модели с Humanoid вверх по иерархии (для мобов, TrainingDummy и аксессуаров)
local function FindTargetCharacter(part: BasePart): (Model?, Humanoid?)
	local current: Instance? = part
	while current and current ~= workspace do
		if current:IsA("Model") then
			local hum = current:FindFirstChildOfClass("Humanoid")
			if hum then
				return current, hum
			end
		end
		current = current.Parent
	end
	return nil, nil
end

-- Проверка, разрешено ли наносить урон цели (PvP / Союзники / Мирный хаб)
-- ВАЖНО: Тренировочный манекен (TrainingDummy) и NPC НЕ имеют привязанного игрока и ВСЕГДА получают урон!
local function CanDamageTarget(attackerChar: Model, targetChar: Model): boolean
	if attackerChar == targetChar then
		return false
	end

	local targetPlayer = Players:GetPlayerFromCharacter(targetChar)
	local attackerPlayer = Players:GetPlayerFromCharacter(attackerChar)

	-- Защита между реальными игроками (PvP)
	if targetPlayer and attackerPlayer then
		local pvpGloballyEnabled = workspace:GetAttribute("PvPEnabled")
		if pvpGloballyEnabled == nil then
			pvpGloballyEnabled = CombatConfig.Settings.PvPEnabled
		end
		if not pvpGloballyEnabled then
			return false
		end

		if targetChar:GetAttribute("InSafeZone") == true or attackerChar:GetAttribute("InSafeZone") == true then
			return false
		end

		if workspace:GetAttribute("IsPeacefulHub") == true or workspace:GetAttribute("PeacefulZone") == true then
			return false
		end
	end

	-- Если цель НЕ является игроком (TrainingDummy, моб, NPC), урон ВСЕГДА разрешен!
	if not targetPlayer then
		if targetChar:GetAttribute("Invulnerable") == true then
			return false
		end
		return true
	end

	return true
end

-- Расчет итогового урона на основе базового урона, характеристик, перков древа и комбо
function CombatService.CalculateDamage(
	attacker: Model | Player,
	profile: any,
	comboStep: number?,
	weaponName: string?
): (number, boolean)
	local char: Model? = nil
	if attacker:IsA("Player") then
		char = attacker.Character
	elseif attacker:IsA("Model") then
		char = attacker
	end

	local name = weaponName or (profile and (profile.Name or profile.WeaponType)) or ""

	-- 1. Базовый урон оружия (BaseDamage):
	-- StarterSword: 15
	-- StarterDaggers: 10
	-- StarterStaff: 12
	local baseDamage = 10
	if name == "StarterSword" then
		baseDamage = 15
	elseif name == "StarterDaggers" then
		baseDamage = 10
	elseif name == "StarterStaff" then
		baseDamage = 12
	elseif profile and typeof(profile.BaseDamage) == "number" then
		baseDamage = profile.BaseDamage
	end

	if not char then
		return baseDamage, false
	end

	-- Атрибуты персонажа, рассчитываемые StatCalculationService
	local totalStr = (char:GetAttribute("TotalSTR") or 10) :: number
	local totalAgi = (char:GetAttribute("TotalAGI") or 10) :: number
	local totalInt = (char:GetAttribute("TotalINT") or 10) :: number
	local bonusMelee = (char:GetAttribute("BonusMeleeDamage") or 0) :: number
	local bonusCrit = (char:GetAttribute("BonusCritChance") or 0) :: number

	-- 2. Скейлинг атрибута:
	-- Для кинжалов (StarterDaggers): бонус от ловкости AGI_Bonus = TotalAGI * 0.5
	-- Для меча (StarterSword): бонус от силы STR_Bonus = TotalSTR * 0.5
	-- Для посоха (StarterStaff): бонус от интеллекта INT_Bonus = TotalINT * 0.5
	local statBonus = 0
	local isDagger = (name == "StarterDaggers") or (profile and profile.Subtype == "Daggers") or (profile and profile.ScalingStat == "AGI")
	local isSword = (name == "StarterSword") or (profile and profile.Subtype == "Sword") or (profile and profile.ScalingStat == "STR")
	local isStaff = (name == "StarterStaff") or (profile and profile.Subtype == "Staff") or (profile and profile.ScalingStat == "INT")

	if isDagger then
		statBonus = totalAgi * 0.5
	elseif isSword then
		statBonus = totalStr * 0.5
	elseif isStaff then
		statBonus = totalInt * 0.5
	else
		statBonus = totalStr * 0.5
	end

	-- 3. Базовая сумма: RawDamage = BaseDamage + StatBonus
	local rawDamage = baseDamage + statBonus

	-- 4. Процентный бонус от пассивных перков древа:
	-- ScaledDamage = RawDamage * (1 + BonusMeleeDamage / 100)
	local percentBonus = bonusMelee
	if isStaff and percentBonus == 0 then
		local bonusMagic = (char:GetAttribute("BonusMagicDamage") or 0) :: number
		if bonusMagic > 0 then
			percentBonus = bonusMagic
		end
	end
	local scaledDamage = rawDamage * (1 + (percentBonus / 100))

	-- 5. Модификатор комбо:
	-- если comboStep == 3 (финишер кинжалов / серии), умножать ScaledDamage * 2.0
	if comboStep == 3 then
		scaledDamage = scaledDamage * 2.0
	end

	-- 6. Критический удар:
	-- бросок math.random(1, 100) <= BonusCritChance. При крите урон умножается на 1.5x
	local isCrit = false
	if bonusCrit > 0 and math.random(1, 100) <= bonusCrit then
		isCrit = true
		scaledDamage = scaledDamage * 1.5
	end

	local finalDamage = math.floor(math.max(1, scaledDamage))
	return finalDamage, isCrit
end

-- Детекция попадания ближнего боя через GetPartBoundsInBox перед персонажем
local function ExecuteMeleeHitbox(
	player: Player,
	character: Model,
	tool: Tool,
	profile: CombatConfig.WeaponProfile,
	comboStep: number?
)
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		rootPart = (character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") or character.PrimaryPart) :: BasePart?
	end
	if not rootPart or not character:IsDescendantOf(workspace) then
		return
	end

	-- Параметры хитбокса (уверенно захватывают стоящего перед игроком манекена)
	local hitboxCFrame = rootPart.CFrame * CFrame.new(0, 0, -3.5)
	local hitboxSize = Vector3.new(6, 6, 7)

	VisualizeHitbox(hitboxCFrame, hitboxSize)

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = { character }
	-- НЕ ограничиваем CollisionGroup, чтобы захватывать объекты вне группы игроков!

	local hitParts = workspace:GetPartBoundsInBox(hitboxCFrame, hitboxSize, overlapParams)
	local hitTargets: { [Humanoid]: boolean } = {}

	if not hitEffectEvent then
		hitEffectEvent = CombatNetwork.GetHitEffectEvent()
	end
	if not hitEffectEvent then
		local folder = ReplicatedStorage:FindFirstChild("CombatEvents") or ReplicatedStorage:FindFirstChild("Combat")
		if folder then
			hitEffectEvent = (folder:FindFirstChild("WeaponHitEffectEvent") or folder:FindFirstChild("HitEffectEvent")) :: RemoteEvent?
		end
	end

	for _, hitPart in ipairs(hitParts) do
		local targetModel = hitPart:FindFirstAncestorOfClass("Model")
		local targetHumanoid = targetModel and targetModel:FindFirstChildOfClass("Humanoid")

		-- Если hitPart был внутри вложенной модели (аксессуар, броня, оружие), проверяем модель выше
		if not targetHumanoid and targetModel then
			local ancestorModel = targetModel:FindFirstAncestorOfClass("Model")
			if ancestorModel then
				local hum = ancestorModel:FindFirstChildOfClass("Humanoid")
				if hum then
					targetModel = ancestorModel
					targetHumanoid = hum
				end
			end
		end

		if targetModel and targetHumanoid and targetHumanoid.Health > 0 and targetModel ~= character then
			-- Защита от мульти-хита за один взмах
			if not hitTargets[targetHumanoid] then
				if CanDamageTarget(character, targetModel) then
					hitTargets[targetHumanoid] = true

					local calculatedDamage, isCrit = CombatService.CalculateDamage(character, profile, comboStep, tool.Name)

					-- Нанесение урона цели через targetHumanoid:TakeDamage(calculatedDamage)
					targetHumanoid:TakeDamage(calculatedDamage)

					-- Позиция для визуального эффекта и 3D звука
					local targetRoot = targetModel:FindFirstChild("HumanoidRootPart")
						or targetModel:FindFirstChild("Torso")
						or targetModel:FindFirstChild("UpperTorso")
						or targetModel.PrimaryPart
						or hitPart

					PlayHitSound(targetRoot, profile.HitSound)

					-- Отправка сетевого события для Floating Damage Number (Damage Display) и частиц
					if hitEffectEvent and hitEffectEvent:IsA("RemoteEvent") then
						pcall(function()
							hitEffectEvent:FireAllClients(targetRoot.Position, isCrit, calculatedDamage)
						end)
					end
				end
			end
		end
	end
end

-- Серверный запуск магического снаряда для посоха (StarterStaff)
local function castMagicOrb(
	player: Player,
	character: Model,
	targetPosition: Vector3,
	profile: any,
	comboStep: number?
)
	local hrp = GetCharacterRoot(character)
	if not hrp then return end

	local spawnPos = hrp.Position + hrp.CFrame.LookVector * 2.5 + Vector3.new(0, 0.5, 0)
	local direction = (targetPosition - spawnPos)
	if direction.Magnitude < 0.1 or targetPosition == Vector3.zero then
		direction = hrp.CFrame.LookVector
	else
		direction = direction.Unit
	end

	local orb = Instance.new("Part")
	orb.Name = "MagicOrb"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(1.2, 1.2, 1.2)
	orb.Color = profile.ProjectileColor or Color3.fromRGB(80, 160, 255)
	orb.Material = Enum.Material.Neon
	orb.CanCollide = false
	orb.Anchored = true
	orb.CFrame = CFrame.new(spawnPos, spawnPos + direction)
	orb.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = orb.Color
	light.Range = 10
	light.Brightness = 2
	light.Parent = orb

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character, orb }
	rayParams.IgnoreWater = true

	local speed = profile.ProjectileSpeed or 95
	local maxRange = profile.MaxRange or 60
	local traveled = 0
	local hit = false

	task.spawn(function()
		while traveled < maxRange and not hit and orb.Parent do
			local dt = RunService.Heartbeat:Wait()
			local stepDistance = speed * dt
			local currentPos = orb.Position
			local nextPos = currentPos + direction * stepDistance

			local rayResult = workspace:Raycast(currentPos, direction * stepDistance, rayParams)
			if rayResult then
				hit = true
				orb.Position = rayResult.Position

				local targetModel, targetHumanoid = FindTargetCharacter(rayResult.Instance)
				if targetModel and targetHumanoid and targetHumanoid.Health > 0 and targetModel ~= character then
					if CanDamageTarget(character, targetModel) then
						local calculatedDamage, isCrit = CombatService.CalculateDamage(character, profile, comboStep, "StarterStaff")
						targetHumanoid:TakeDamage(calculatedDamage)

						if hitEffectEvent then
							hitEffectEvent:FireAllClients(rayResult.Position, isCrit, calculatedDamage)
						end
					end
				end
				break
			else
				orb.Position = nextPos
				traveled += stepDistance
			end
		end

		orb:Destroy()
	end)

	Debris:AddItem(orb, 2.5)
end

-- Обработка сетевого запроса на атаку (валидация кулдауна, оружия, комбо)
local function HandleAttackRequest(player: Player, param1: any?, param2: any?)
	local character = player.Character
	if not character or not character:IsDescendantOf(workspace) then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local equippedTool = character:FindFirstChildOfClass("Tool")
	if not equippedTool then
		return
	end

	local profile = CombatConfig.GetWeaponProfile(equippedTool.Name)

	-- Серверная валидация кулдауна (с запасом 150мс на джиттер и пинг)
	local session = playerSessions[player]
	if not session then
		session = {
			LastAttackTime = 0,
			LastComboTime = 0,
			LastComboStep = 0,
			LastWeaponName = equippedTool.Name,
		}
		playerSessions[player] = session
	end

	local now = os.clock()
	local minInterval = math.max(0.15, profile.AttackCooldown * 0.75)

	if (now - session.LastAttackTime) < minInterval then
		return
	end

	session.LastAttackTime = now

	-- Разбор параметров: comboStep и aimPoint
	local clientComboStep: number? = nil
	local clientAimPoint: Vector3? = nil

	if typeof(param1) == "number" then
		clientComboStep = param1
		if typeof(param2) == "Vector3" then
			clientAimPoint = param2
		end
	elseif typeof(param1) == "Vector3" then
		clientAimPoint = param1
		if typeof(param2) == "number" then
			clientComboStep = param2
		end
	end

	-- Сброс комбо при смене оружия
	if session.LastWeaponName ~= equippedTool.Name then
		session.LastComboStep = 0
		session.LastComboTime = 0
		session.LastWeaponName = equippedTool.Name
	end

	-- Серверная валидация комбо-шага
	local expectedStep = 1
	if (now - session.LastComboTime) <= COMBO_RESET_DELAY and session.LastComboStep > 0 then
		if session.LastComboStep == 1 then
			expectedStep = 2
		elseif session.LastComboStep == 2 then
			expectedStep = 3
		else
			expectedStep = 1
		end
	else
		expectedStep = 1
	end

	local validatedComboStep = expectedStep
	if clientComboStep and clientComboStep == expectedStep then
		validatedComboStep = clientComboStep
	elseif clientComboStep and (clientComboStep >= 1 and clientComboStep <= 3) then
		if (now - session.LastComboTime) <= COMBO_RESET_DELAY then
			validatedComboStep = clientComboStep
		end
	end

	session.LastComboStep = validatedComboStep
	session.LastComboTime = now

	local attackPattern = profile.AttackPattern

	local function DispatchAttack()
		if not character:IsDescendantOf(workspace) or humanoid.Health <= 0 then
			return
		end

		local currentTool = character:FindFirstChildOfClass("Tool") or equippedTool

		if attackPattern == "MagicProjectile" or attackPattern == "ArrowCast" then
			local targetPos = if clientAimPoint then clientAimPoint else Vector3.zero
			castMagicOrb(player, character, targetPos, profile, validatedComboStep)
		else
			ExecuteMeleeHitbox(player, character, currentTool, profile, validatedComboStep)
		end
	end

	if profile.WindupDelay and profile.WindupDelay > 0 then
		task.delay(profile.WindupDelay, function()
			local ok, err = pcall(DispatchAttack)
			if not ok then
				warn("[CombatService] Ошибка в DispatchAttack:", err)
			end
		end)
	else
		local ok, err = pcall(DispatchAttack)
		if not ok then
			warn("[CombatService] Ошибка в DispatchAttack:", err)
		end
	end
end

-- Инициализация сессий игроков
local function InitSession(player: Player)
	playerSessions[player] = {
		LastAttackTime = 0,
		LastComboTime = 0,
		LastComboStep = 0,
		LastWeaponName = nil,
	}
	player.CharacterAdded:Connect(function()
		local sess = playerSessions[player]
		if sess then
			sess.LastAttackTime = 0
			sess.LastComboTime = 0
			sess.LastComboStep = 0
			sess.LastWeaponName = nil
		end
	end)
end

function CombatService.Start()
	if isInitialized then
		return
	end
	isInitialized = true

	hitEffectEvent = CombatNetwork.GetHitEffectEvent()

	-- Подключение всех возможных сетевых точек входа для запросов атаки
	local connectedRemotes: { [RemoteEvent]: boolean } = {}
	local function ConnectRemote(re: Instance?)
		if re and re:IsA("RemoteEvent") and not connectedRemotes[re] then
			connectedRemotes[re] = true
			re.OnServerEvent:Connect(HandleAttackRequest)
			print("[CombatService] Подключен OnServerEvent к RemoteEvent:", re:GetFullName())
		end
	end

	-- 1. Центральный ремоут из CombatNetwork
	ConnectRemote(CombatNetwork.GetAttackRequestRemote())

	-- 2. Ремоуты в папке CombatEvents
	local combatEventsFolder = ReplicatedStorage:FindFirstChild("CombatEvents")
	if combatEventsFolder then
		ConnectRemote(combatEventsFolder:FindFirstChild("AttackRequestRemote"))
		ConnectRemote(combatEventsFolder:FindFirstChild("WeaponAttackEvent"))
	end

	-- 3. Ремоуты в папке Combat
	local combatFolder = ReplicatedStorage:FindFirstChild("Combat")
	if combatFolder then
		ConnectRemote(combatFolder:FindFirstChild("AttackRequestRemote"))
		ConnectRemote(combatFolder:FindFirstChild("AttackRequestEvent"))
	end

	Players.PlayerAdded:Connect(InitSession)
	Players.PlayerRemoving:Connect(function(player)
		playerSessions[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		InitSession(player)
	end

	print("[CombatService] Серверная боевая система (Server Authority + Hitbox + Scaling) успешно инициализирована")
end

-- Автозапуск
CombatService.Start()

return CombatService
