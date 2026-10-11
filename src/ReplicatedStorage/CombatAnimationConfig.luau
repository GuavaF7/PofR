--!strict
-- CombatAnimationConfig.luau
-- Конфигурация анимаций боевой системы для Path of Roblox (PofR)

export type WeaponComboAnimations = {
	Combo1: string?,
	Combo2: string?,
	Combo3: string?,
	Attack: string?,
	Idle: string?,
	Walk: string?,
	[string]: any,
}

export type CombatAnimationConfigType = {
	StarterDaggers: WeaponComboAnimations,
	StarterSword: WeaponComboAnimations,
	StarterStaff: WeaponComboAnimations,
	[string]: any,
}

local CombatAnimationConfig = {
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

-- Получить идентификатор анимации для конкретного оружия и шага комбо
function CombatAnimationConfig.GetComboAnimation(weaponName: string, comboStep: number): string?
	local weaponData = (CombatAnimationConfig :: any)[weaponName]
	if not weaponData then
		return nil
	end

	local key = "Combo" .. tostring(comboStep)
	local animId = weaponData[key] or weaponData.Attack
	if typeof(animId) == "string" and animId ~= "" then
		return animId
	end

	return nil
end

-- Получить идентификатор боевой стойки покоя (Idle Pose)
function CombatAnimationConfig.GetIdleAnimation(weaponName: string): string?
	local weaponData = (CombatAnimationConfig :: any)[weaponName]
	if not weaponData then
		return nil
	end

	local animId = weaponData.Idle
	if typeof(animId) == "string" and animId ~= "" then
		return animId
	end

	return nil
end

-- Получить идентификатор боевой анимации движения (Walk / Run)
function CombatAnimationConfig.GetWalkAnimation(weaponName: string): string?
	local weaponData = (CombatAnimationConfig :: any)[weaponName]
	if not weaponData then
		return nil
	end

	local animId = weaponData.Walk
	if typeof(animId) == "string" and animId ~= "" then
		return animId
	end

	return nil
end

return CombatAnimationConfig
