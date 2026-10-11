--!strict
-- CharacterCustomizationConfig.luau
-- Конфигурация доступных опций внешности и стартовой одежды для создания персонажа в Path of Roblox (PofR)

export type SkinColorOption = {
	Id: string,
	Name: string,
	Color: Color3,
}

export type FaceOption = {
	Id: string,
	Name: string,
	Texture: string,
}

export type HairOption = {
	Id: string,
	Name: string,
	MeshId: string,
	TextureId: string,
	Offset: Vector3,
	Scale: Vector3,
}

export type HairColorOption = {
	Id: string,
	Name: string,
	Color: Color3,
}

export type ClassOutfitOption = {
	Shirt: string,
	Pants: string,
	Description: string,
}

export type AppearanceData = {
	SkinColorIndex: number,
	FaceIndex: number,
	HairIndex: number,
	HairColorIndex: number?,
	HairName: string?,
	FaceName: string?,
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterCustomizationConfig = {}

-- =================================================================
-- 1. ПАЛИТРА ЦВЕТОВ КОЖИ (6 натуральных оттенков)
-- =================================================================
CharacterCustomizationConfig.SkinColors = {
	{ Id = "Pale",     Name = "Pale",      Color = Color3.fromRGB(255, 224, 189) },
	{ Id = "Fair",     Name = "Fair",      Color = Color3.fromRGB(245, 206, 172) },
	{ Id = "WarmTan",  Name = "Warm Tan",  Color = Color3.fromRGB(219, 172, 132) },
	{ Id = "Olive",    Name = "Olive",     Color = Color3.fromRGB(189, 138, 98) },
	{ Id = "Bronze",   Name = "Bronze",    Color = Color3.fromRGB(152, 98, 59) },
	{ Id = "Dark",     Name = "Deep Dark", Color = Color3.fromRGB(92, 56, 34) },
} :: { SkinColorOption }

-- =================================================================
-- 2. ИДЕНТИФИКАТОРЫ ЛИЦ (Decal на Head)
-- =================================================================
CharacterCustomizationConfig.Faces = {
	{ Id = "Classic",  Name = "Classic",  Texture = "rbxasset://textures/face.png" },
	{ Id = "Friendly", Name = "Friendly", Texture = "rbxasset://textures/face.png" },
	{ Id = "Stoic",    Name = "Stoic",    Texture = "rbxassetid://20971426" },
	{ Id = "Chill",    Name = "Chill",    Texture = "rbxassetid://40186178" },
	{ Id = "Fierce",   Name = "Fierce",   Texture = "rbxassetid://22623340" },
	{ Id = "Smirk",    Name = "Smirk",    Texture = "rbxassetid://12145357" },
} :: { FaceOption }

-- =================================================================
-- 3. ПРИЧЁСКИ И АКСЕССУАРЫ (Валидные публичные ассеты Roblox)
-- =================================================================
CharacterCustomizationConfig.Hairs = {
	{
		Id = "Bald",
		Name = "None (Bald)",
		MeshId = "",
		TextureId = "",
		Offset = Vector3.new(0, 0, 0),
		Scale = Vector3.new(1, 1, 1),
	},
	{
		Id = "Adventurer",
		Name = "Adventurer",
		MeshId = "rbxassetid://622344705", -- Pal Hair (Official Roblox mesh)
		TextureId = "",
		Offset = Vector3.new(0, 0, 0),
		Scale = Vector3.new(1, 1, 1),
	},
	{
		Id = "Slick",
		Name = "Slick",
		MeshId = "rbxassetid://376527351", -- Brown Charmer (Official Roblox mesh)
		TextureId = "",
		Offset = Vector3.new(0, 0, 0),
		Scale = Vector3.new(1, 1, 1),
	},
	{
		Id = "Ponytail",
		Name = "Ponytail",
		MeshId = "rbxassetid://430336214", -- Lavender Updo (Official Roblox mesh)
		TextureId = "",
		Offset = Vector3.new(0, 0, 0),
		Scale = Vector3.new(1, 1, 1),
	},
	{
		Id = "Wanderer",
		Name = "Wanderer",
		MeshId = "rbxassetid://20573078", -- Shaggy (Official Roblox mesh)
		TextureId = "",
		Offset = Vector3.new(0, 0, 0),
		Scale = Vector3.new(1, 1, 1),
	},
	{
		Id = "MysticBob",
		Name = "Mystic Bob",
		MeshId = "rbxassetid://16627529", -- Beautiful Hair (Official Roblox mesh)
		TextureId = "",
		Offset = Vector3.new(0, 0, 0),
		Scale = Vector3.new(1, 1, 1),
	},
} :: { HairOption }

CharacterCustomizationConfig.HairColors = {
	{ Id = "Black",     Name = "Raven Black", Color = Color3.fromRGB(24, 24, 28) },
	{ Id = "DarkBrown", Name = "Dark Brown",  Color = Color3.fromRGB(56, 36, 26) },
	{ Id = "Chestnut",  Name = "Chestnut",    Color = Color3.fromRGB(92, 54, 38) },
	{ Id = "Blonde",    Name = "Golden",      Color = Color3.fromRGB(224, 192, 134) },
	{ Id = "Silver",    Name = "Silver",      Color = Color3.fromRGB(205, 205, 215) },
	{ Id = "Crimson",   Name = "Crimson",     Color = Color3.fromRGB(145, 34, 34) },
} :: { HairColorOption }

-- =================================================================
-- 4. СТАРТОВАЯ ОДЕЖДА КЛАССОВ
-- =================================================================
CharacterCustomizationConfig.ClassOutfits = {
	Warrior = {
		Shirt = "rbxassetid://607785314",
		Pants = "rbxassetid://607785501",
		Description = "Reinforced Chainmail & Greaves",
	},
	Mage = {
		Shirt = "rbxassetid://257973163",
		Pants = "rbxassetid://257973300",
		Description = "Enchanted Robes & Mystic Trousers",
	},
	Rogue = {
		Shirt = "rbxassetid://284246473",
		Pants = "rbxassetid://284246602",
		Description = "Shadow Leather Tunic & Stalker Pants",
	},
} :: { [string]: ClassOutfitOption }

-- =================================================================
-- 5. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ПОЛУЧЕНИЯ ДАННЫХ
-- =================================================================
function CharacterCustomizationConfig.GetSkinColor(index: number?): SkinColorOption
	local i = math.clamp(index or 1, 1, #CharacterCustomizationConfig.SkinColors)
	return CharacterCustomizationConfig.SkinColors[i]
end

function CharacterCustomizationConfig.GetFace(index: number?): FaceOption
	local i = math.clamp(index or 1, 1, #CharacterCustomizationConfig.Faces)
	return CharacterCustomizationConfig.Faces[i]
end

function CharacterCustomizationConfig.GetHair(index: number?): HairOption
	local i = math.clamp(index or 1, 1, #CharacterCustomizationConfig.Hairs)
	return CharacterCustomizationConfig.Hairs[i]
end

function CharacterCustomizationConfig.GetHairColor(index: number?): HairColorOption
	local i = math.clamp(index or 1, 1, #CharacterCustomizationConfig.HairColors)
	return CharacterCustomizationConfig.HairColors[i]
end

function CharacterCustomizationConfig.GetClassOutfit(className: string?): ClassOutfitOption?
	if not className then return nil end
	return CharacterCustomizationConfig.ClassOutfits[className]
end

-- =================================================================
-- 6. ПРИМЕНЕНИЕ ВНЕШНОСТИ К МОДЕЛИ (Используется сервером и ViewportFrame)
-- =================================================================
function CharacterCustomizationConfig.ApplyAppearanceToCharacter(
	character: Model,
	appearanceData: AppearanceData?,
	className: string?
)
	if not character then return end

	local skin = CharacterCustomizationConfig.GetSkinColor(appearanceData and appearanceData.SkinColorIndex)
	local hairColor = CharacterCustomizationConfig.GetHairColor(appearanceData and appearanceData.HairColorIndex)

	-- 1. Цвет кожи (BodyColors + окрашивание деталей персонажа)
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if not bodyColors then
		bodyColors = Instance.new("BodyColors")
		bodyColors.Name = "Body Colors"
		bodyColors.Parent = character
	end

	bodyColors.HeadColor3 = skin.Color
	bodyColors.LeftArmColor3 = skin.Color
	bodyColors.RightArmColor3 = skin.Color
	bodyColors.LeftLegColor3 = skin.Color
	bodyColors.RightLegColor3 = skin.Color
	bodyColors.TorsoColor3 = skin.Color

	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and not part:GetAttribute("IsCustomHairPart") then
			local isAccessoryPart = false
			local ancestor = part.Parent
			while ancestor and ancestor ~= character do
				if ancestor:IsA("Accessory") then
					isAccessoryPart = true
					break
				end
				ancestor = ancestor.Parent
			end
			if not isAccessoryPart then
				part.Color = skin.Color
			end
		end
	end

	-- 2. Лицо (Decal на Head) и очистка артефактов головы
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		-- Удаляем HeadWrapTarget и объекты Layered Clothing для устранения черных полос
		local wrap = head:FindFirstChild("HeadWrapTarget")
		if wrap then wrap:Destroy() end

		for _, child in ipairs(head:GetChildren()) do
			if child.Name == "HeadWrapTarget" or child:IsA("WrapTarget") or child:IsA("WrapLayer") then
				child:Destroy()
			elseif child:IsA("SpecialMesh") then
				child.TextureId = ""
			elseif child:IsA("SurfaceAppearance") then
				child:Destroy()
			elseif child:IsA("Decal") and child.Name ~= "face" then
				child:Destroy()
			end
		end

		if head:IsA("MeshPart") then
			pcall(function()
				(head :: any).TextureID = ""
			end)
		end

		local faceDecal = head:FindFirstChild("face") :: Decal?
		if not faceDecal then
			faceDecal = Instance.new("Decal")
			faceDecal.Name = "face"
			faceDecal.Parent = head
		end
		faceDecal.Face = Enum.NormalId.Front

		-- Поиск декали в CustomizationFaces по FaceName или fallback
		local customFacesFolder = ReplicatedStorage:FindFirstChild("CustomizationFaces")
		local faceName = appearanceData and appearanceData.FaceName
		local faceTemplate: Decal? = nil
		if customFacesFolder and faceName then
			local f = customFacesFolder:FindFirstChild(faceName)
			if f and f:IsA("Decal") then
				faceTemplate = f :: Decal
			end
		end

		if not faceTemplate and customFacesFolder and appearanceData and appearanceData.FaceIndex then
			local candidate = customFacesFolder:FindFirstChild("Face" .. tostring(appearanceData.FaceIndex))
			if candidate and candidate:IsA("Decal") then
				faceTemplate = candidate :: Decal
			end
		end

		if faceTemplate then
			faceDecal.Texture = faceTemplate.Texture
			faceDecal.Transparency = faceTemplate.Transparency
		else
			local fallbackFace = CharacterCustomizationConfig.GetFace(appearanceData and appearanceData.FaceIndex)
			faceDecal.Texture = if fallbackFace and fallbackFace.Texture ~= "" then fallbackFace.Texture else "rbxasset://textures/face.png"
			faceDecal.Transparency = 0
		end
	end

	-- 3. Причёска (удаляем старые аксессуары и надеваем выбранный префаб из CustomizationHairs)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") then
			child:Destroy()
		end
	end

	local hairName = appearanceData and appearanceData.HairName
	local isBald = (hairName == "None" or hairName == "Bald" or (not hairName and appearanceData and appearanceData.HairIndex == 1))

	if not isBald and head and head:IsA("BasePart") then
		local customHairsFolder = ReplicatedStorage:FindFirstChild("CustomizationHairs")
		local hairTemplate: Accessory? = nil
		if customHairsFolder and hairName and hairName ~= "None" then
			local h = customHairsFolder:FindFirstChild(hairName)
			if h and h:IsA("Accessory") then
				hairTemplate = h :: Accessory
			end
		end

		if not hairTemplate and customHairsFolder and appearanceData and appearanceData.HairIndex and appearanceData.HairIndex > 1 then
			local candidate = customHairsFolder:FindFirstChild("Hair" .. tostring(appearanceData.HairIndex - 1))
			if candidate and candidate:IsA("Accessory") then
				hairTemplate = candidate :: Accessory
			end
		end

		if hairTemplate then
			local hairClone = hairTemplate:Clone()
			local handle = hairClone:FindFirstChild("Handle") :: BasePart?
			if handle then
				handle.Anchored = false
				handle.CanCollide = false
				handle:SetAttribute("IsCustomHairPart", true)

				if hairColor then
					handle.Color = hairColor.Color
					local mesh = handle:FindFirstChildOfClass("SpecialMesh")
					if mesh then
						mesh.VertexColor = Vector3.new(hairColor.Color.R, hairColor.Color.G, hairColor.Color.B)
					end
					for _, desc in ipairs(hairClone:GetDescendants()) do
						if desc:IsA("BasePart") then
							desc.Color = hairColor.Color
							desc.CanCollide = false
							desc.Anchored = false
							desc:SetAttribute("IsCustomHairPart", true)
						elseif desc:IsA("SpecialMesh") then
							desc.VertexColor = Vector3.new(hairColor.Color.R, hairColor.Color.G, hairColor.Color.B)
						end
					end
				end

				local hairAtt = handle:FindFirstChild("HairAttachment") or handle:FindFirstChild("HatAttachment") or handle:FindFirstChildWhichIsA("Attachment")
				local headAtt = if hairAtt then head:FindFirstChild(hairAtt.Name) else (head:FindFirstChild("HairAttachment") or head:FindFirstChild("HatAttachment"))
				if not headAtt then
					headAtt = head:FindFirstChild("HairAttachment") or head:FindFirstChild("HatAttachment")
				end

				local weld = Instance.new("Weld")
				weld.Name = "AccessoryWeld"
				weld.Part0 = handle
				weld.Part1 = head

				if hairAtt and headAtt then
					weld.C0 = (hairAtt :: Attachment).CFrame
					weld.C1 = (headAtt :: Attachment).CFrame
					handle.CFrame = head.CFrame * (headAtt :: Attachment).CFrame * (hairAtt :: Attachment).CFrame:Inverse()
				else
					weld.C0 = CFrame.new(0, 0, 0)
					weld.C1 = CFrame.new(0, 0.55, 0)
					handle.CFrame = head.CFrame * CFrame.new(0, 0.55, 0)
				end

				weld.Parent = handle
				hairClone.Parent = character
			end
		end
	end

	-- 4. Одежда (DefaultClothing или одежда класса)
	local defaultClothing = ReplicatedStorage:FindFirstChild("DefaultClothing")
	if defaultClothing then
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
				item:Destroy()
			end
		end

		local shirtTemplate = defaultClothing:FindFirstChildOfClass("Shirt")
		if shirtTemplate then
			local newShirt = shirtTemplate:Clone()
			newShirt.Parent = character
		end

		local pantsTemplate = defaultClothing:FindFirstChildOfClass("Pants")
		if pantsTemplate then
			local newPants = pantsTemplate:Clone()
			newPants.Parent = character
		end
	elseif className and className ~= "" and className ~= "None" then
		local outfit = CharacterCustomizationConfig.GetClassOutfit(className)
		if outfit then
			local shirt = character:FindFirstChildOfClass("Shirt")
			if not shirt then
				shirt = Instance.new("Shirt")
				shirt.Name = "ClassShirt"
				shirt.Parent = character
			end
			shirt.ShirtTemplate = outfit.Shirt

			local pants = character:FindFirstChildOfClass("Pants")
			if not pants then
				pants = Instance.new("Pants")
				pants.Name = "ClassPants"
				pants.Parent = character
			end
			pants.PantsTemplate = outfit.Pants
		end
	end
end

return CharacterCustomizationConfig
