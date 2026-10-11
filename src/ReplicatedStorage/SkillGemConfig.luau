--!strict
-- SkillGemConfig.luau
-- Конфигурация камней умений и сокетов (PoE-style Skill Gems & Sockets) для Path of Roblox (PofR)

export type GemColor = "Red" | "Green" | "Blue"

export type SkillGemData = {
	Id: string,
	Name: string,
	Color: GemColor,
	RequiredAttribute: "STR" | "AGI" | "INT",
	Cooldown: number,
	ManaCost: number,
	Description: string,
	Icon: string?,
	BaseDamage: number,
	DamageScaling: number,
	Range: number?,
	Radius: number?,
	Speed: number?,
}

local SkillGemConfig = {}

SkillGemConfig.Gems = {
	["GroundSlam"] = {
		Id = "GroundSlam",
		Name = "Ground Slam",
		Color = "Red",
		RequiredAttribute = "STR",
		Cooldown = 3.5,
		ManaCost = 15,
		Description = "Slams the ground with colossal force, sending a shockwave cone forward that crushes enemies.",
		Icon = "rbxassetid://6031075938",
		BaseDamage = 35,
		DamageScaling = 0.85,
		Range = 18,
	} :: SkillGemData,

	["Fireball"] = {
		Id = "Fireball",
		Name = "Fireball",
		Color = "Blue",
		RequiredAttribute = "INT",
		Cooldown = 2.5,
		ManaCost = 20,
		Description = "Hurls an explosive sphere of fire that detonates on impact within an 8-stud radius.",
		Icon = "rbxassetid://6031075931",
		BaseDamage = 40,
		DamageScaling = 0.95,
		Radius = 8,
		Speed = 100,
		Range = 65,
	} :: SkillGemData,

	["DashStrike"] = {
		Id = "DashStrike",
		Name = "Dash Strike",
		Color = "Green",
		RequiredAttribute = "AGI",
		Cooldown = 4.0,
		ManaCost = 12,
		Description = "Instantly dashes forward 25 studs, slicing all foes caught along the path.",
		Icon = "rbxassetid://6031075945",
		BaseDamage = 30,
		DamageScaling = 0.80,
		Range = 25,
	} :: SkillGemData,
}

SkillGemConfig.GemColors = {
	Red = Color3.fromRGB(255, 65, 65),
	Green = Color3.fromRGB(65, 230, 95),
	Blue = Color3.fromRGB(65, 160, 255),
}

-- Слоты экипировки, поддерживающие сокеты для камней умений
SkillGemConfig.SocketableSlots = {
	"Weapon",
	"Armor",
	"Helmet",
	"OffHand",
	"Boots",
}

-- Хоткеи умений по умолчанию
SkillGemConfig.SkillHotkeys = {
	[1] = { Key = Enum.KeyCode.Q, Name = "Q" },
	[2] = { Key = Enum.KeyCode.E, Name = "E" },
	[3] = { Key = Enum.KeyCode.R, Name = "R" },
}

function SkillGemConfig.GetGem(gemId: string): SkillGemData?
	return SkillGemConfig.Gems[gemId]
end

function SkillGemConfig.GetColorForGem(color: GemColor): Color3
	return SkillGemConfig.GemColors[color] or Color3.fromRGB(220, 220, 220)
end

function SkillGemConfig.GetAllGems(): { SkillGemData }
	local list = {}
	for _, gem in pairs(SkillGemConfig.Gems) do
		table.insert(list, gem)
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

return SkillGemConfig
