local ClassConfig = {}

ClassConfig.Classes = {
	["Warrior"] = {
		Name = "Warrior",
		Description = "Melee master utilizing Heavy Armor, Shields, and Slam attacks.",
		CardImage = "rbxassetid://139718222051906", 
		StarterWeapon = "StarterSword",
		BaseStats = {
			MaxHealth = 150,
			HealthRegen = 2,
			Strength = 15,
			Agility = 8,
			Intelligence = 5,
			WalkSpeed = 16,
		},
		StartingWeaponSet = 1, -- Two-Handed Hammer / Sword & Shield
		Icon = "rbxassetid://0",
	},

	["Mage"] = {
		Name = "Mage",
		Description = "Master of Elements dealing ranged AoE Magic damage.",
		CardImage = "rbxassetid://108617644426277", 
		StarterWeapon = "StarterStaff",
		BaseStats = {
			MaxHealth = 90,
			HealthRegen = 1,
			Strength = 5,
			Agility = 8,
			Intelligence = 18,
			WalkSpeed = 16,
		},
		StartingWeaponSet = 1, -- Elemental Staff
		Icon = "rbxassetid://0",
	},

	["Rogue"] = {
		Name = "Rogue",
		Description = "Swift assassin specializing in Daggers, Mobility, and Critical Strikes.",
		CardImage = "rbxassetid://127721562224542", 
		StarterWeapon = "StarterDaggers",
		BaseStats = {
			MaxHealth = 110,
			HealthRegen = 1.5,
			Strength = 8,
			Agility = 18,
			Intelligence = 6,
			WalkSpeed = 18,
		},
		StartingWeaponSet = 1, -- Dual Daggers / Bow
		Icon = "rbxassetid://0",
	},
}

function ClassConfig.GetClass(className: string)
	return ClassConfig.Classes[className]
end

return ClassConfig