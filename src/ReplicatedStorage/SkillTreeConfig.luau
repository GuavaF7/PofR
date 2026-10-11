local SkillTreeConfig = {}

-- РљРѕРѕСЂРґРёРЅР°С‚С‹ СѓР·Р»РѕРІ РЅР° 2D-С…РѕР»СЃС‚Рµ Рё СЃРІСЏР·Рё (ParentNode)
SkillTreeConfig.Nodes = {
	-- Р¦РµРЅС‚СЂР°Р»СЊРЅС‹Р№ СЏРєРѕСЂРЅС‹Р№ СѓР·РµР»
	Core = {
		Name = "Core Origin",
		Description = "Starting origin point of your class development",
		Cost = 0,
		ParentNode = nil,
		Position = Vector2.new(300, 300),
		Stats = {},
	},

	-- Р’РµС‚РєР° РЎРёР»С‹ (Р’РІРµСЂС…)
	STR_1 = {
		Name = "Physical Might",
		Description = "+5 Strength, +20 Max Health",
		Cost = 1,
		ParentNode = "Core",
		Position = Vector2.new(300, 180),
		Stats = {
			Strength = 5,
			MaxHealth = 20,
		},
	},
	STR_2 = {
		Name = "Heavy Impact",
		Description = "+10% Melee Damage",
		Cost = 1,
		ParentNode = "STR_1",
		Position = Vector2.new(200, 80),
		Stats = {
			BonusMeleeDamage = 10,
		},
	},
	STR_3 = {
		Name = "Colossus",
		Description = "+10 Strength, +50 Max Health",
		Cost = 2,
		ParentNode = "STR_1",
		Position = Vector2.new(400, 80),
		Stats = {
			Strength = 10,
			MaxHealth = 50,
		},
	},

	-- Р’РµС‚РєР° Р›РѕРІРєРѕСЃС‚Рё (Р’РїСЂР°РІРѕ-Р’РЅРёР·)
	AGI_1 = {
		Name = "Swift Reflexes",
		Description = "+5 Agility, +2 WalkSpeed",
		Cost = 1,
		ParentNode = "Core",
		Position = Vector2.new(420, 420),
		Stats = {
			Agility = 5,
			WalkSpeed = 2,
		},
	},
	AGI_2 = {
		Name = "Lethal Precision",
		Description = "+5% Crit Chance",
		Cost = 1,
		ParentNode = "AGI_1",
		Position = Vector2.new(520, 520),
		Stats = {
			BonusCritChance = 5,
		},
	},

	-- Р’РµС‚РєР° РРЅС‚РµР»Р»РµРєС‚Р° (Р’Р»РµРІРѕ-Р’РЅРёР·)
	INT_1 = {
		Name = "Arcane Mind",
		Description = "+5 Intelligence",
		Cost = 1,
		ParentNode = "Core",
		Position = Vector2.new(180, 420),
		Stats = {
			Intelligence = 5,
		},
	},
	INT_2 = {
		Name = "Spell Master",
		Description = "+12% Magic Damage",
		Cost = 1,
		ParentNode = "INT_1",
		Position = Vector2.new(80, 520),
		Stats = {
			BonusMagicDamage = 12,
		},
	},
}

return SkillTreeConfig