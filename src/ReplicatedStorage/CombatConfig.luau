--!strict
-- CombatConfig.luau
-- Конфигурация боевой системы для Path of Roblox (PofR)
-- 100% автономная система с процедурным взмахом (Procedural Swing) без внешних ассетов.

export type WeaponCategory = "Melee" | "Magic" | "Ranged"
export type WeaponSubtype = "Sword" | "Daggers" | "Axe" | "Mace" | "Staff" | "Wand" | "Bow"
export type AttackPattern = "BoxSlash" | "DualStab" | "MagicProjectile" | "ArrowCast"
export type ScalingStat = "STR" | "AGI" | "INT"

export type AnimationSet = {
	R15: { string }?,
	R6: { string }?,
}

export type WeaponProfile = {
	-- Новые мета-поля классификации и архетипов
	Category: WeaponCategory,
	Subtype: WeaponSubtype,
	AttackPattern: AttackPattern,
	IsTwoHanded: boolean,
	ScalingStat: ScalingStat,

	-- Опциональные параметры снарядов
	ProjectileSpeed: number?,
	MaxRange: number?,
	ProjectileColor: Color3?,

	-- Поля обратной совместимости
	WeaponType: string?,
	DamageType: string?,

	BaseDamage: number,
	AttackCooldown: number,      -- Кулдаун между ударами в секундах
	AttackRange: number,         -- Дальность поражения хитбокса (studs)
	HitboxSize: Vector3,         -- Размеры коробки проверки хитбокса (studs)
	HitboxOffset: Vector3,       -- Смещение центра хитбокса относительно HumanoidRootPart
	WindupDelay: number,         -- Задержка активной фазы удара (синхронизация с замахом)
	CritMultiplier: number,      -- Множитель критического урона
	AnimationId: string?,        -- Опциональный ID анимации (nil или "" для процедурного режима)
	AnimationIds: AnimationSet?, -- Опциональный набор ID
	UseProceduralSwing: boolean?,-- Флаг процедурного взмаха
	SwingSound: string,          -- Звук взмаха
	HitSound: string,            -- Звук попадания
}

-- Безопасная загрузка конфигурации анимаций (без бесконечного ожидания)
local CombatAnimationConfig: any = nil
local animModule = script.Parent:FindFirstChild("CombatAnimationConfig")
if not animModule then
	local combatFolder = script.Parent:FindFirstChild("Combat")
	if combatFolder then
		animModule = combatFolder:FindFirstChild("CombatAnimationConfig")
	end
end
if not animModule then
	animModule = script.Parent:WaitForChild("CombatAnimationConfig", 1)
end
if animModule and animModule:IsA("ModuleScript") then
	local ok, res = pcall(require, animModule)
	if ok and typeof(res) == "table" then
		CombatAnimationConfig = res
	end
end

-- Автономный fallback: гарантирует мгновенную инициализацию боевой системы без блокировок
if not CombatAnimationConfig then
	CombatAnimationConfig = {
		StarterDaggers = {
			Idle = "rbxassetid://106851671001027",
			Walk = "rbxassetid://85471543699921",
			Combo1 = "rbxassetid://132572831455697",
			Combo2 = "rbxassetid://76033308576777",
			Combo3 = "rbxassetid://125299984017284",
		},
		StarterSword = {
			Attack = "rbxassetid://111581047807750",
		},
		StarterStaff = {
			Attack = "rbxassetid://111581047807750",
		},
	}
end

local CombatConfig = {}
CombatConfig.AnimationConfig = CombatAnimationConfig

-- Общие настройки PvP и боевой зоны
CombatConfig.Settings = {
	PvPEnabled = false,               -- По умолчанию PvP между игроками выключено
	MaxTargetAngle = 0.15,            -- Минимальный косинус угла (допустимый сектор атаки перед персонажем)
	NetworkLatencyTolerance = 0.08,   -- Допустимый пинг/джиттер для серверного кулдауна (сек)
	UseProceduralSwing = true,        -- Глобальный флаг процедурного замаха (без внешних зависимостей)
}

-- Профили оружия с новой мета-моделью архетипов
CombatConfig.Weapons = {
	["StarterSword"] = {
		Category = "Melee",
		Subtype = "Sword",
		AttackPattern = "BoxSlash",
		IsTwoHanded = false,
		ScalingStat = "STR",

		WeaponType = "Sword",
		DamageType = "Melee",
		BaseDamage = 15,
		AttackCooldown = 0.75,
		AttackRange = 6.5,
		HitboxSize = Vector3.new(5.5, 4.5, 6.5),
		HitboxOffset = Vector3.new(0, 0, -3.5),
		WindupDelay = 0.16,
		CritMultiplier = 1.5,
		AnimationId = "",
		AnimationIds = nil,
		UseProceduralSwing = true,
		SwingSound = "rbxasset://sounds/swordslash.wav",
		HitSound = "rbxassetid://566593606",
	} :: WeaponProfile,

	["StarterStaff"] = {
		Category = "Magic",
		Subtype = "Staff",
		AttackPattern = "MagicProjectile",
		IsTwoHanded = true,
		ScalingStat = "INT",
		ProjectileSpeed = 95,
		MaxRange = 60,
		ProjectileColor = Color3.fromRGB(80, 160, 255),

		WeaponType = "Staff",
		DamageType = "Magic",
		BaseDamage = 12,
		AttackCooldown = 0.85,
		AttackRange = 60.0,
		HitboxSize = Vector3.new(6.0, 5.0, 9.0),
		HitboxOffset = Vector3.new(0, 0, -4.5),
		WindupDelay = 0.20,
		CritMultiplier = 1.5,
		AnimationId = "",
		AnimationIds = nil,
		UseProceduralSwing = true,
		SwingSound = "rbxasset://sounds/swordslash.wav",
		HitSound = "rbxassetid://566593606",
	} :: WeaponProfile,

	["StarterDaggers"] = {
		Category = "Melee",
		Subtype = "Daggers",
		AttackPattern = "DualStab",
		IsTwoHanded = true,
		ScalingStat = "AGI",

		WeaponType = "Daggers",
		DamageType = "Melee",
		BaseDamage = 10,
		AttackCooldown = 0.38, -- Быстрые частые выпады
		AttackRange = 5.0,
		HitboxSize = Vector3.new(4.5, 4.0, 5.0),
		HitboxOffset = Vector3.new(0, 0, -2.5),
		WindupDelay = 0.08,
		CritMultiplier = 2.0,  -- Повышенный крит-множитель для Rogue
		AnimationId = "rbxassetid://132572831455697",
		AnimationIds = {
			R15 = {
				"rbxassetid://132572831455697",
				"rbxassetid://76033308576777",
				"rbxassetid://125299984017284",
			},
		},
		UseProceduralSwing = false, -- Используются кастомные анимации комбо-серии
		SwingSound = "rbxasset://sounds/swordslash.wav",
		HitSound = "rbxassetid://566593606",
	} :: WeaponProfile,
}

-- Профиль по умолчанию для любых незарегистрированных инструментов
CombatConfig.DefaultProfile = {
	Category = "Melee",
	Subtype = "Sword",
	AttackPattern = "BoxSlash",
	IsTwoHanded = false,
	ScalingStat = "STR",

	WeaponType = "Default",
	DamageType = "Melee",
	BaseDamage = 10,
	AttackCooldown = 0.6,
	AttackRange = 5.0,
	HitboxSize = Vector3.new(4.0, 4.0, 5.0),
	HitboxOffset = Vector3.new(0, 0, -2.5),
	WindupDelay = 0.12,
	CritMultiplier = 1.5,
	AnimationId = "",
	AnimationIds = nil,
	UseProceduralSwing = true,
	SwingSound = "rbxasset://sounds/swordslash.wav",
	HitSound = "rbxassetid://566593606",
} :: WeaponProfile

function CombatConfig.GetWeaponProfile(toolName: string): WeaponProfile
	local profile = CombatConfig.Weapons[toolName]
	if profile then
		return profile
	end
	return CombatConfig.DefaultProfile
end

return CombatConfig
