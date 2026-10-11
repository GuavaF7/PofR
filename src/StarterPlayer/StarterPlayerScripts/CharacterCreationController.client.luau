--!strict
-- CharacterCreationController.client.luau
-- Клиентский контроллер создания и кастомизации персонажа с живым 3D ViewportFrame превью

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui", 10) :: PlayerGui

local CharacterCustomizationConfig = require(ReplicatedStorage:WaitForChild("CharacterCustomizationConfig"))
local ClassConfig = require(ReplicatedStorage:WaitForChild("ClassConfig"))

-- Сетевые события
local CreationEventsFolder = ReplicatedStorage:WaitForChild("CharacterCreationEvents", 10) :: Folder
local OpenCharacterCreation = CreationEventsFolder:WaitForChild("OpenCharacterCreation", 10) :: RemoteEvent
local OpenCharacterCreationRemote = (CreationEventsFolder:FindFirstChild("OpenCharacterCreationRemote")
	or CreationEventsFolder:WaitForChild("OpenCharacterCreationRemote", 5)) :: RemoteEvent?
local SubmitCharacterCreationRemote = CreationEventsFolder:WaitForChild("SubmitCharacterCreationRemote", 10) :: RemoteEvent
local CharacterCreationResponse = CreationEventsFolder:WaitForChild("CharacterCreationResponse", 10) :: RemoteEvent

-- Папки подготовленных префабов кастомизации
local hairsFolder = ReplicatedStorage:WaitForChild("CustomizationHairs", 10) :: Folder?
local facesFolder = ReplicatedStorage:WaitForChild("CustomizationFaces", 10) :: Folder?

export type HairOptionEntry = {
	Id: string,
	Name: string,
	Template: Accessory?,
}

export type FaceOptionEntry = {
	Id: string,
	Name: string,
	Template: Decal?,
	Texture: string,
	Transparency: number,
}

local availableHairs: { HairOptionEntry } = {
	{ Id = "None", Name = "None (Bald)", Template = nil },
}

local availableFaces: { FaceOptionEntry } = {}

local function getNumericSuffix(name: string): number
	local numStr = string.match(name, "(%d+)")
	return if numStr then (tonumber(numStr) or 0) else 0
end

local function sortByNameOrNumber(a: Instance, b: Instance): boolean
	local numA = getNumericSuffix(a.Name)
	local numB = getNumericSuffix(b.Name)
	if numA ~= numB then
		return numA < numB
	end
	return a.Name < b.Name
end

local function initAssetLists()
	-- 1. Считывание и сортировка причёсок (Hair1..Hair10)
	local hairInstances: { Accessory } = {}
	if hairsFolder then
		for _, child in ipairs(hairsFolder:GetChildren()) do
			if child:IsA("Accessory") then
				table.insert(hairInstances, child)
			end
		end
		table.sort(hairInstances, sortByNameOrNumber)
	end

	availableHairs = {
		{ Id = "None", Name = "None (Bald)", Template = nil },
	}

	for _, acc in ipairs(hairInstances) do
		table.insert(availableHairs, {
			Id = acc.Name,
			Name = acc.Name,
			Template = acc,
		})
	end

	-- Резервное наполнение (если папка пуста или репликация в процессе)
	if #availableHairs == 1 then
		for i = 1, 10 do
			local hName = "Hair" .. tostring(i)
			local tmpl = hairsFolder and hairsFolder:FindFirstChild(hName)
			table.insert(availableHairs, {
				Id = hName,
				Name = hName,
				Template = if tmpl and tmpl:IsA("Accessory") then (tmpl :: Accessory) else nil,
			})
		end
	end

	-- 2. Считывание и сортировка лиц (Face1..Face10)
	local faceInstances: { Decal } = {}
	if facesFolder then
		for _, child in ipairs(facesFolder:GetChildren()) do
			if child:IsA("Decal") then
				table.insert(faceInstances, child)
			end
		end
		table.sort(faceInstances, sortByNameOrNumber)
	end

	availableFaces = {}
	for _, decal in ipairs(faceInstances) do
		table.insert(availableFaces, {
			Id = decal.Name,
			Name = decal.Name,
			Template = decal,
			Texture = decal.Texture,
			Transparency = decal.Transparency,
		})
	end

	-- Резервное наполнение (если папка пуста)
	if #availableFaces == 0 then
		for i = 1, 10 do
			local fName = "Face" .. tostring(i)
			local tmpl = facesFolder and facesFolder:FindFirstChild(fName)
			local d = if tmpl and tmpl:IsA("Decal") then (tmpl :: Decal) else nil
			table.insert(availableFaces, {
				Id = fName,
				Name = fName,
				Template = d,
				Texture = if d then d.Texture else (if i == 1 then "rbxasset://textures/face.png" else ""),
				Transparency = if d then d.Transparency else 0,
			})
		end
	end
end

initAssetLists()

-- =================================================================
-- 1. ТЕМА И СТИЛИСТИКА DARK RPG
-- =================================================================
local THEME = {
	Bg = Color3.fromRGB(20, 20, 24),
	CardBg = Color3.fromRGB(28, 28, 35),
	CardSelected = Color3.fromRGB(38, 38, 48),
	Gold = Color3.fromRGB(255, 215, 0),
	GoldHover = Color3.fromRGB(255, 230, 80),
	Border = Color3.fromRGB(48, 48, 58),
	TextMain = Color3.fromRGB(240, 240, 248),
	TextMuted = Color3.fromRGB(160, 160, 175),
	TextDark = Color3.fromRGB(18, 18, 22),
	Warrior = Color3.fromRGB(215, 65, 65),
	Mage = Color3.fromRGB(65, 145, 230),
	Rogue = Color3.fromRGB(65, 205, 110),
}

-- Текущее состояние выбора игрока
local selectedClass = "Warrior"
local currentAppearance: CharacterCustomizationConfig.AppearanceData = {
	SkinColorIndex = 3,
	FaceIndex = 1,
	HairIndex = 2,
	HairColorIndex = 2,
	HairName = "Hair1",
	FaceName = "Face1",
}

-- =================================================================
-- 2. СОЗДАНИЕ ИНТЕРФЕЙСА (CODE-FIRST)
-- =================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CharacterCreationGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 15
ScreenGui.IgnoreGuiInset = true
ScreenGui.Enabled = false
ScreenGui.Parent = PlayerGui

-- Затемнённый фон-подложка
local Backdrop = Instance.new("Frame")
Backdrop.Name = "Backdrop"
Backdrop.Size = UDim2.new(1, 0, 1, 0)
Backdrop.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
Backdrop.BackgroundTransparency = 0.35
Backdrop.BorderSizePixel = 0
Backdrop.Parent = ScreenGui

-- Главное окно
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.Size = UDim2.new(0, 860, 0, 520)
MainFrame.BackgroundColor3 = THEME.Bg
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui
local mainCreationGui = MainFrame

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = MainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Thickness = 2
mainStroke.Color = THEME.Gold
mainStroke.Parent = MainFrame

-- Адаптивный масштаб окна (UIScale)
local uiScale = Instance.new("UIScale", MainFrame)
local function UpdateScale()
	local camera = workspace.CurrentCamera
	if camera then
		local vp = camera.ViewportSize
		local reqW = MainFrame.Size.X.Offset + 30
		local reqH = MainFrame.Size.Y.Offset + 35
		local scaleX = vp.X / reqW
		local scaleY = vp.Y / reqH
		uiScale.Scale = math.clamp(math.min(scaleX, scaleY), 0.35, 1.0)
	end
end

if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale)
	UpdateScale()
end

-- =================================================================
-- 3. ЛЕВАЯ КОЛОНКА: ИНТЕРАКТИВНЫЙ 3D VIEWPORT FRAME ПРЕВЬЮ
-- =================================================================
local previewPanel = Instance.new("Frame")
previewPanel.Name = "PreviewPanel"
previewPanel.Size = UDim2.new(0, 330, 1, -28)
previewPanel.Position = UDim2.new(0, 14, 0, 14)
previewPanel.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
previewPanel.BorderSizePixel = 0
previewPanel.Parent = MainFrame

local previewCorner = Instance.new("UICorner")
previewCorner.CornerRadius = UDim.new(0, 10)
previewCorner.Parent = previewPanel

local previewStroke = Instance.new("UIStroke")
previewStroke.Thickness = 1.5
previewStroke.Color = THEME.Border
previewStroke.Parent = previewPanel

local viewportFrame = Instance.new("ViewportFrame")
viewportFrame.Name = "CharacterViewport"
viewportFrame.Size = UDim2.new(1, 0, 1, -44)
viewportFrame.Position = UDim2.new(0, 0, 0, 0)
viewportFrame.BackgroundTransparency = 1
viewportFrame.LightColor = Color3.fromRGB(255, 248, 235)
viewportFrame.Ambient = Color3.fromRGB(140, 140, 155)
viewportFrame.LightDirection = Vector3.new(-1, -1.8, -1.5)
viewportFrame.Parent = previewPanel

local viewportCorner = Instance.new("UICorner")
viewportCorner.CornerRadius = UDim.new(0, 10)
viewportCorner.Parent = viewportFrame

-- WorldModel для физики, визуалов и анимаций в ViewportFrame
local worldModel = Instance.new("WorldModel")
worldModel.Name = "WorldModel"
worldModel.Parent = viewportFrame

-- Настройка виртуальной камеры (Camera)
local previewCamera = Instance.new("Camera")
previewCamera.FieldOfView = 40 -- Умеренный угол без перспективы растяжения

-- Центр фокуса строго по центру модели (район таза / HumanoidRootPart)
local focusPoint = Vector3.new(0, 0, 0)

-- Отодвигаем камеру назад на расстояние 9.8 - 10.2 studs и слегка поднимаем
local cameraOffset = Vector3.new(0, 0.2, 9.8)

previewCamera.CFrame = CFrame.lookAt(focusPoint + cameraOffset, focusPoint)
previewCamera.Parent = viewportFrame

viewportFrame.CurrentCamera = previewCamera

local previewModel: Model? = nil
local currentAngleY = 0
local isDragging = false
local lastDragX = 0

-- Вращение модели по горизонтали через HumanoidRootPart.CFrame
local function updateModelRotation()
	if previewModel then
		local hrp = previewModel:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			hrp = previewModel.PrimaryPart or previewModel:FindFirstChild("Torso") :: BasePart?
		end
		if hrp then
			hrp.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(currentAngleY), 0)
		end
	end
end

-- Интерактивное вращение мышью/пальцем (Drag to rotate)
viewportFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isDragging = true
		lastDragX = input.Position.X
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isDragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local deltaX = input.Position.X - lastDragX
		lastDragX = input.Position.X
		currentAngleY = (currentAngleY + deltaX * 0.8) % 360
		updateModelRotation()
	end
end)

-- Кнопки ручного поворота снизу от модели
local rotateControls = Instance.new("Frame")
rotateControls.Name = "RotateControls"
rotateControls.Size = UDim2.new(1, 0, 0, 40)
rotateControls.Position = UDim2.new(0, 0, 1, -42)
rotateControls.BackgroundTransparency = 1
rotateControls.Parent = previewPanel

local function createRotateButton(text: string, pos: UDim2, deltaAngle: number): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 36, 0, 32)
	btn.Position = pos
	btn.Text = text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 16
	btn.TextColor3 = THEME.Gold
	btn.BackgroundColor3 = THEME.CardBg
	btn.Parent = rotateControls

	local bCorner = Instance.new("UICorner")
	bCorner.CornerRadius = UDim.new(0, 6)
	bCorner.Parent = btn

	local bStroke = Instance.new("UIStroke")
	bStroke.Thickness = 1
	bStroke.Color = THEME.Border
	bStroke.Parent = btn

	btn.Activated:Connect(function()
		currentAngleY = (currentAngleY + deltaAngle) % 360
		updateModelRotation()
	end)

	return btn
end

createRotateButton("⟲", UDim2.new(0, 16, 0, 4), -30)
createRotateButton("⟳", UDim2.new(1, -52, 0, 4), 30)

local dragHint = Instance.new("TextLabel")
dragHint.Size = UDim2.new(1, -120, 1, 0)
dragHint.Position = UDim2.new(0, 60, 0, 0)
dragHint.BackgroundTransparency = 1
dragHint.Text = "Drag to rotate"
dragHint.Font = Enum.Font.GothamMedium
dragHint.TextSize = 11
dragHint.TextColor3 = THEME.TextMuted
dragHint.Parent = rotateControls

-- =================================================================
-- 4. ПРАВАЯ КОЛОНКА: СЕЛЕКТОРЫ И ВЫБОР КЛАССА
-- =================================================================
local optionsPanel = Instance.new("ScrollingFrame")
optionsPanel.Name = "OptionsPanel"
optionsPanel.Size = UDim2.new(1, -370, 1, -28)
optionsPanel.Position = UDim2.new(0, 356, 0, 14)
optionsPanel.BackgroundTransparency = 1
optionsPanel.BorderSizePixel = 0
optionsPanel.ScrollBarThickness = 5
optionsPanel.ScrollBarImageColor3 = Color3.fromRGB(255, 215, 0)
optionsPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
optionsPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
optionsPanel.ScrollingDirection = Enum.ScrollingDirection.Y
optionsPanel.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
optionsPanel.ScrollingEnabled = true
optionsPanel.Selectable = true
optionsPanel.Parent = MainFrame

local optionsPadding = Instance.new("UIPadding")
optionsPadding.PaddingRight = UDim.new(0, 12)
optionsPadding.PaddingBottom = UDim.new(0, 30)
optionsPadding.Parent = optionsPanel

local optionsLayout = Instance.new("UIListLayout")
optionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
optionsLayout.Padding = UDim.new(0, 12)
optionsLayout.Parent = optionsPanel

-- Заголовок
local headerFrame = Instance.new("Frame")
headerFrame.Size = UDim2.new(1, -10, 0, 46)
headerFrame.BackgroundTransparency = 1
headerFrame.LayoutOrder = 1
headerFrame.Parent = optionsPanel

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 24)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "CHARACTER CREATION"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 20
titleLabel.TextColor3 = THEME.Gold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = headerFrame

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Position = UDim2.new(0, 0, 0, 24)
subtitleLabel.Size = UDim2.new(1, 0, 0, 18)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Text = "Forge your champion and begin your journey through Wraeclast."
subtitleLabel.Font = Enum.Font.GothamMedium
subtitleLabel.TextSize = 11
subtitleLabel.TextColor3 = THEME.TextMuted
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
subtitleLabel.Parent = headerFrame

-- =================================================================
-- 3.1. КАСТОМИЗАЦИЯ ПРЕВЬЮ: ОЧИСТКА ГОЛОВЫ, ПРИЧЕСКИ И СИНХРОНИЗАЦИЯ
-- =================================================================

-- 1. Очистка текстур головы (удаление черных полос и артефактов) и гарантия декали лица
local function cleanHeadTextures(characterModel: Model)
	local head = characterModel:FindFirstChild("Head") :: BasePart?
	if not head then return end

	-- Удаляем мешающие объекты Layered Clothing (HeadWrapTarget / WrapTarget)
	local wrap = head:FindFirstChild("HeadWrapTarget")
	if wrap then wrap:Destroy() end

	for _, child in ipairs(head:GetChildren()) do
		if child.Name == "HeadWrapTarget" or child:IsA("WrapTarget") or child:IsA("WrapLayer") then
			child:Destroy()
		end
	end

	-- Если это MeshPart, сбрасываем текстуру: head.TextureID = ""
	if head:IsA("MeshPart") then
		pcall(function()
			(head :: MeshPart).TextureID = ""
		end)
	end

	-- Если внутри Head есть SpecialMesh, очищаем текстуру меша
	for _, child in ipairs(head:GetChildren()) do
		if child:IsA("SpecialMesh") then
			child.TextureId = ""
		elseif child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end

	for _, desc in ipairs(head:GetDescendants()) do
		if desc:IsA("SpecialMesh") then
			desc.TextureId = ""
		end
	end

	-- Удаляем любые посторонние декали, кроме основной декали лица (face)
	for _, child in ipairs(head:GetChildren()) do
		if child:IsA("Decal") and child.Name ~= "face" then
			child:Destroy()
		end
	end

	-- Гарантируем наличие декали лица face строго спереди
	local face = head:FindFirstChild("face") :: Decal?
	if not face then
		face = Instance.new("Decal")
		face.Name = "face"
		face.Parent = head
	end
	face.Face = Enum.NormalId.Front
end

-- 2. Логика применения лица из CustomizationFaces
local function applyFace(charModel: Model, faceTemplate: Decal?)
	local head = charModel:FindFirstChild("Head") :: BasePart?
	if not head then return end

	local face = head:FindFirstChild("face") :: Decal?
	if not face then
		face = Instance.new("Decal")
		face.Name = "face"
		face.Parent = head
	end

	face.Face = Enum.NormalId.Front
	if faceTemplate then
		face.Texture = faceTemplate.Texture
		face.Transparency = faceTemplate.Transparency
	else
		face.Texture = "rbxasset://textures/face.png"
		face.Transparency = 0
	end
end

-- 3. Корректная сварка и позиционирование причёсок (applyHair)
local function applyHair(charModel: Model, hairTemplate: Accessory?, hairColor: Color3?)
	-- Удаляем предыдущие волосы
	for _, child in ipairs(charModel:GetChildren()) do
		if child:IsA("Accessory") then
			child:Destroy()
		end
	end

	if not hairTemplate then return end -- Опция None (Bald)

	local hairClone = hairTemplate:Clone()
	local handle = hairClone:FindFirstChild("Handle") :: BasePart?
	local head = charModel:FindFirstChild("Head") :: BasePart?
	if not handle or not head then return end

	handle.Anchored = false
	handle.CanCollide = false
	if hairColor then
		handle.Color = hairColor
		local mesh = handle:FindFirstChildOfClass("SpecialMesh")
		if mesh then
			mesh.VertexColor = Vector3.new(hairColor.R, hairColor.G, hairColor.B)
		end
		for _, desc in ipairs(hairClone:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Color = hairColor
				desc.CanCollide = false
				desc.Anchored = false
			elseif desc:IsA("SpecialMesh") then
				desc.VertexColor = Vector3.new(hairColor.R, hairColor.G, hairColor.B)
			end
		end
	end

	-- Точки привязки Attachment
	local hairAtt = handle:FindFirstChild("HairAttachment") or handle:FindFirstChild("HatAttachment") or handle:FindFirstChildWhichIsA("Attachment")
	local headAtt = if hairAtt then head:FindFirstChild(hairAtt.Name) else (head:FindFirstChild("HairAttachment") or head:FindFirstChild("HatAttachment"))
	if not headAtt and head then
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
	hairClone.Parent = charModel
end

-- 3.2. Базовая одежда новичка (DefaultClothing)
local function applyDefaultClothing(targetModel: Model)
	local defaultClothingFolder = ReplicatedStorage:FindFirstChild("DefaultClothing")
	if not defaultClothingFolder then return end

	-- Удаляем старую одежду, если есть
	for _, item in ipairs(targetModel:GetChildren()) do
		if item:IsA("Shirt") or item:IsA("Pants") then
			item:Destroy()
		end
	end

	-- Клонируем Shirt и Pants из папки шаблона
	local shirtTemplate = defaultClothingFolder:FindFirstChildOfClass("Shirt")
	if shirtTemplate then
		local newShirt = shirtTemplate:Clone()
		newShirt.Parent = targetModel
	end

	local pantsTemplate = defaultClothingFolder:FindFirstChildOfClass("Pants")
	if pantsTemplate then
		local newPants = pantsTemplate:Clone()
		newPants.Parent = targetModel
	end
end

-- 4. Комплексное обновление превью модели
local function updatePreviewModel()
	if not previewModel then return end

	-- 1. Цвет кожи (BodyColors + окрашивание деталей персонажа)
	local skinOpt = CharacterCustomizationConfig.GetSkinColor(currentAppearance.SkinColorIndex)
	local bodyColors = previewModel:FindFirstChildOfClass("BodyColors")
	if not bodyColors then
		bodyColors = Instance.new("BodyColors")
		bodyColors.Name = "Body Colors"
		bodyColors.Parent = previewModel
	end
	bodyColors.HeadColor3 = skinOpt.Color
	bodyColors.LeftArmColor3 = skinOpt.Color
	bodyColors.RightArmColor3 = skinOpt.Color
	bodyColors.LeftLegColor3 = skinOpt.Color
	bodyColors.RightLegColor3 = skinOpt.Color
	bodyColors.TorsoColor3 = skinOpt.Color

	for _, part in ipairs(previewModel:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local isAccessoryPart = false
			local ancestor = part.Parent
			while ancestor and ancestor ~= previewModel do
				if ancestor:IsA("Accessory") then
					isAccessoryPart = true
					break
				end
				ancestor = ancestor.Parent
			end
			if not isAccessoryPart then
				part.Color = skinOpt.Color
			end
		end
	end

	-- 2. Очистка текстур головы (устранение черных артефактов)
	cleanHeadTextures(previewModel)

	-- 3. Применение выражения лица из CustomizationFaces
	local faceData = availableFaces[currentAppearance.FaceIndex]
	local faceTemplate: Decal? = nil
	if faceData then
		faceTemplate = faceData.Template
		if not faceTemplate and facesFolder then
			local f = facesFolder:FindFirstChild(faceData.Id)
			if f and f:IsA("Decal") then
				faceTemplate = f :: Decal
			end
		end
	end
	applyFace(previewModel, faceTemplate)

	-- 4. Применение причёски из CustomizationHairs (Weld) и цвета волос
	local hairData = availableHairs[currentAppearance.HairIndex]
	local hairTemplate: Accessory? = nil
	if hairData and hairData.Id ~= "None" then
		hairTemplate = hairData.Template
		if not hairTemplate and hairsFolder then
			local h = hairsFolder:FindFirstChild(hairData.Id)
			if h and h:IsA("Accessory") then
				hairTemplate = h :: Accessory
			end
		end
	end
	local hairColorOpt = CharacterCustomizationConfig.GetHairColor(currentAppearance.HairColorIndex)
	applyHair(previewModel, hairTemplate, hairColorOpt.Color)

	-- 5. Базовая одежда новичка (DefaultClothing) с fallback на одежду класса
	local defaultClothingFolder = ReplicatedStorage:FindFirstChild("DefaultClothing")
	if defaultClothingFolder then
		applyDefaultClothing(previewModel)
	else
		local outfit = CharacterCustomizationConfig.GetClassOutfit(selectedClass)
		if outfit then
			local shirt = previewModel:FindFirstChildOfClass("Shirt")
			if not shirt then
				shirt = Instance.new("Shirt")
				shirt.Name = "ClassShirt"
				shirt.Parent = previewModel
			end
			shirt.ShirtTemplate = outfit.Shirt

			local pants = previewModel:FindFirstChildOfClass("Pants")
			if not pants then
				pants = Instance.new("Pants")
				pants.Name = "ClassPants"
				pants.Parent = previewModel
			end
			pants.PantsTemplate = outfit.Pants
		end
	end

	-- 6. Сохранение текущего угла поворота модели
	updateModelRotation()
end

-- Вспомогательная функция создания секций
local function createSectionTitle(text: string, order: number): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -10, 0, 20)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 13
	lbl.TextColor3 = THEME.TextMain
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.LayoutOrder = order
	lbl.Parent = optionsPanel
	return lbl
end

-- -----------------------------------------------------------------
-- СЕКЦИЯ 1: ВЫБОР КЛАССА
-- -----------------------------------------------------------------
createSectionTitle("SELECT CLASS", 2)

local classContainer = Instance.new("Frame")
classContainer.Size = UDim2.new(1, -10, 0, 165)
classContainer.BackgroundTransparency = 1
classContainer.LayoutOrder = 3
classContainer.Parent = optionsPanel

local classLayout = Instance.new("UIListLayout")
classLayout.FillDirection = Enum.FillDirection.Horizontal
classLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
classLayout.VerticalAlignment = Enum.VerticalAlignment.Center
classLayout.Padding = UDim.new(0.035, 0)
classLayout.SortOrder = Enum.SortOrder.LayoutOrder
classLayout.Parent = classContainer

local classImages: { [string]: string } = {
	Warrior = "rbxassetid://139718222051906",
	Mage = "rbxassetid://108617644426277",
	Rogue = "rbxassetid://127721562224542",
}

local classButtons: {
	[string]: {
		Frame: TextButton,
		Stroke: UIStroke,
		Label: TextLabel,
		RoleLabel: TextLabel,
		Art: ImageLabel,
		Scrim: Frame,
		BaseColor: Color3,
	}
} = {}

local CLASSES_INFO = {
	{ Id = "Warrior", Name = "WARRIOR", Role = "Melee • Sword", Color = THEME.Warrior },
	{ Id = "Mage",    Name = "MAGE",    Role = "Magic • Staff", Color = THEME.Mage },
	{ Id = "Rogue",   Name = "ROGUE",   Role = "Agile • Daggers", Color = THEME.Rogue },
}

local classDescLabel = Instance.new("TextLabel")
classDescLabel.Size = UDim2.new(1, -10, 0, 24)
classDescLabel.BackgroundTransparency = 1
classDescLabel.Font = Enum.Font.GothamMedium
classDescLabel.TextSize = 11
classDescLabel.TextColor3 = THEME.TextMuted
classDescLabel.TextXAlignment = Enum.TextXAlignment.Left
classDescLabel.LayoutOrder = 4
classDescLabel.Parent = optionsPanel

local function updateClassSelectionUI()
	for id, card in pairs(classButtons) do
		local isSel = (id == selectedClass)
		card.Frame.BackgroundColor3 = if isSel then THEME.CardSelected else THEME.CardBg
		card.Stroke.Color = if isSel then Color3.fromRGB(255, 215, 0) else THEME.Border
		card.Stroke.Thickness = if isSel then 2 else 1
		card.Label.TextColor3 = if isSel then Color3.fromRGB(255, 215, 0) else card.BaseColor
		card.Art.ImageTransparency = if isSel then 0.1 else 0.25
		card.Scrim.BackgroundTransparency = if isSel then 0.35 else 0.45
	end

	local cInfo = ClassConfig.GetClass(selectedClass)
	if cInfo then
		classDescLabel.Text = string.format("• %s: %s", cInfo.Name, cInfo.Description)
	end

	updatePreviewModel()
end

for idx, info in ipairs(CLASSES_INFO) do
	local btn = Instance.new("TextButton")
	btn.Name = info.Id .. "_Btn"
	btn.Size = UDim2.new(0.31, 0, 0, 165)
	btn.Text = ""
	btn.BackgroundColor3 = THEME.CardBg
	btn.AutoButtonColor = false
	btn.ClipsDescendants = true
	btn.LayoutOrder = idx
	btn.Parent = classContainer

	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 8)
	cCorner.Parent = btn

	local cStroke = Instance.new("UIStroke")
	cStroke.Thickness = 1
	cStroke.Color = THEME.Border
	cStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cStroke.Parent = btn

	-- 1. Фоновый вертикальный арт
	local bgArt = Instance.new("ImageLabel")
	bgArt.Name = "ClassArt"
	bgArt.Size = UDim2.new(1, 0, 1, 0)
	bgArt.Position = UDim2.new(0, 0, 0, 0)
	bgArt.BackgroundTransparency = 1
	bgArt.Image = classImages[info.Id] or ""
	bgArt.ScaleType = Enum.ScaleType.Crop
	bgArt.ImageTransparency = 0.2
	bgArt.ZIndex = 1
	bgArt.Parent = btn

	local artCorner = Instance.new("UICorner")
	artCorner.CornerRadius = UDim.new(0, 8)
	artCorner.Parent = bgArt

	-- 2. Полупрозрачный градиент/блюр-вуаль (Scrim) для контраста
	local scrim = Instance.new("Frame")
	scrim.Name = "BlurScrim"
	scrim.Size = UDim2.new(1, 0, 1, 0)
	scrim.Position = UDim2.new(0, 0, 0, 0)
	scrim.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
	scrim.BackgroundTransparency = 0.45
	scrim.BorderSizePixel = 0
	scrim.ZIndex = 2
	scrim.Parent = btn

	local scrimCorner = Instance.new("UICorner")
	scrimCorner.CornerRadius = UDim.new(0, 8)
	scrimCorner.Parent = scrim

	local scrimGrad = Instance.new("UIGradient")
	scrimGrad.Rotation = 90
	scrimGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	scrimGrad.Parent = scrim

	-- 3. Название и параметры с ZIndex = 3 и темной обводкой UIStroke
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, -8, 0, 24)
	nameLbl.Position = UDim2.new(0, 4, 0, 10)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = info.Name
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 14
	nameLbl.TextColor3 = info.Color
	nameLbl.ZIndex = 3
	nameLbl.Parent = btn

	local nameStroke = Instance.new("UIStroke")
	nameStroke.Thickness = 1.5
	nameStroke.Color = Color3.fromRGB(0, 0, 0)
	nameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	nameStroke.Transparency = 0.15
	nameStroke.Parent = nameLbl

	local roleLbl = Instance.new("TextLabel")
	roleLbl.Size = UDim2.new(1, -8, 0, 32)
	roleLbl.Position = UDim2.new(0, 4, 1, -38)
	roleLbl.BackgroundTransparency = 1
	roleLbl.Text = info.Role
	roleLbl.Font = Enum.Font.GothamMedium
	roleLbl.TextSize = 11
	roleLbl.TextWrapped = true
	roleLbl.TextColor3 = Color3.fromRGB(240, 240, 248)
	roleLbl.ZIndex = 3
	roleLbl.Parent = btn

	local roleStroke = Instance.new("UIStroke")
	roleStroke.Thickness = 1.5
	roleStroke.Color = Color3.fromRGB(0, 0, 0)
	roleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	roleStroke.Transparency = 0.15
	roleStroke.Parent = roleLbl

	classButtons[info.Id] = {
		Frame = btn,
		Stroke = cStroke,
		Label = nameLbl,
		RoleLabel = roleLbl,
		Art = bgArt,
		Scrim = scrim,
		BaseColor = info.Color,
	}

	btn.Activated:Connect(function()
		selectedClass = info.Id
		updateClassSelectionUI()
	end)
end

updateClassSelectionUI()

-- -----------------------------------------------------------------
-- СЕКЦИЯ 2: ЦВЕТ КОЖИ (ПАЛИТРА С СЕМПЛАМИ)
-- -----------------------------------------------------------------
createSectionTitle("SKIN TONE", 5)

local skinContainer = Instance.new("Frame")
skinContainer.Size = UDim2.new(1, -10, 0, 36)
skinContainer.BackgroundTransparency = 1
skinContainer.LayoutOrder = 6
skinContainer.Parent = optionsPanel

local skinLayout = Instance.new("UIListLayout")
skinLayout.FillDirection = Enum.FillDirection.Horizontal
skinLayout.Padding = UDim.new(0, 12)
skinLayout.Parent = skinContainer

local skinButtons: { { Button: TextButton, Stroke: UIStroke, Indicator: TextLabel } } = {}

local function updateSkinSelectionUI()
	for idx, item in ipairs(skinButtons) do
		local isSel = (idx == currentAppearance.SkinColorIndex)
		item.Stroke.Color = if isSel then THEME.Gold else THEME.Border
		item.Stroke.Thickness = if isSel then 2.5 else 1
		item.Indicator.Visible = isSel
	end
	updatePreviewModel()
end

for idx, opt in ipairs(CharacterCustomizationConfig.SkinColors) do
	local swatch = Instance.new("TextButton")
	swatch.Name = "Skin_" .. opt.Id
	swatch.Size = UDim2.new(0, 34, 0, 34)
	swatch.BackgroundColor3 = opt.Color
	swatch.Text = ""
	swatch.Parent = skinContainer

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(1, 0)
	sCorner.Parent = swatch

	local sStroke = Instance.new("UIStroke")
	sStroke.Thickness = 1
	sStroke.Color = THEME.Border
	sStroke.Parent = swatch

	local check = Instance.new("TextLabel")
	check.Size = UDim2.new(1, 0, 1, 0)
	check.BackgroundTransparency = 1
	check.Text = "✓"
	check.Font = Enum.Font.GothamBold
	check.TextSize = 14
	check.TextColor3 = if opt.Color.R + opt.Color.G + opt.Color.B > 1.5 then Color3.fromRGB(20, 20, 20) else Color3.fromRGB(255, 255, 255)
	check.Visible = (idx == currentAppearance.SkinColorIndex)
	check.Parent = swatch

	table.insert(skinButtons, { Button = swatch, Stroke = sStroke, Indicator = check })

	swatch.Activated:Connect(function()
		currentAppearance.SkinColorIndex = idx
		updateSkinSelectionUI()
	end)
end

updateSkinSelectionUI()

-- -----------------------------------------------------------------
-- СЕКЦИЯ 3: СЕЛЕКТОР ПРИЧЁСКИ СО СТРЕЛОЧКАМИ
-- -----------------------------------------------------------------
createSectionTitle("HAIRSTYLE", 7)

local hairStepperFrame = Instance.new("Frame")
hairStepperFrame.Size = UDim2.new(1, -10, 0, 38)
hairStepperFrame.BackgroundColor3 = THEME.CardBg
hairStepperFrame.LayoutOrder = 8
hairStepperFrame.Parent = optionsPanel

local hsCorner = Instance.new("UICorner")
hsCorner.CornerRadius = UDim.new(0, 8)
hsCorner.Parent = hairStepperFrame

local hsStroke = Instance.new("UIStroke")
hsStroke.Thickness = 1
hsStroke.Color = THEME.Border
hsStroke.Parent = hairStepperFrame

local hairPrevBtn = Instance.new("TextButton")
hairPrevBtn.Size = UDim2.new(0, 38, 1, 0)
hairPrevBtn.Position = UDim2.new(0, 0, 0, 0)
hairPrevBtn.Text = "◀"
hairPrevBtn.Font = Enum.Font.GothamBold
hairPrevBtn.TextSize = 13
hairPrevBtn.TextColor3 = THEME.Gold
hairPrevBtn.BackgroundTransparency = 1
hairPrevBtn.Parent = hairStepperFrame

local hairNameLabel = Instance.new("TextLabel")
hairNameLabel.Size = UDim2.new(1, -80, 1, 0)
hairNameLabel.Position = UDim2.new(0, 40, 0, 0)
hairNameLabel.BackgroundTransparency = 1
hairNameLabel.Font = Enum.Font.GothamBold
hairNameLabel.TextSize = 13
hairNameLabel.TextColor3 = THEME.TextMain
hairNameLabel.Parent = hairStepperFrame

local hairNextBtn = Instance.new("TextButton")
hairNextBtn.Size = UDim2.new(0, 38, 1, 0)
hairNextBtn.Position = UDim2.new(1, -38, 0, 0)
hairNextBtn.Text = "▶"
hairNextBtn.Font = Enum.Font.GothamBold
hairNextBtn.TextSize = 13
hairNextBtn.TextColor3 = THEME.Gold
hairNextBtn.BackgroundTransparency = 1
hairNextBtn.Parent = hairStepperFrame

local function updateHairUI()
	local count = #availableHairs
	if count == 0 then return end
	currentAppearance.HairIndex = math.clamp(currentAppearance.HairIndex, 1, count)
	local selectedHair = availableHairs[currentAppearance.HairIndex]
	hairNameLabel.Text = selectedHair.Name
	currentAppearance.HairName = selectedHair.Id
	updatePreviewModel()
end

hairPrevBtn.Activated:Connect(function()
	local count = #availableHairs
	if count == 0 then return end
	currentAppearance.HairIndex = if currentAppearance.HairIndex > 1 then currentAppearance.HairIndex - 1 else count
	updateHairUI()
end)

hairNextBtn.Activated:Connect(function()
	local count = #availableHairs
	if count == 0 then return end
	currentAppearance.HairIndex = if currentAppearance.HairIndex < count then currentAppearance.HairIndex + 1 else 1
	updateHairUI()
end)

updateHairUI()

-- -----------------------------------------------------------------
-- СЕКЦИЯ 4: ЦВЕТ ВОЛОС (ПАЛИТРА)
-- -----------------------------------------------------------------
createSectionTitle("HAIR COLOR", 9)

local hairColorContainer = Instance.new("Frame")
hairColorContainer.Size = UDim2.new(1, -10, 0, 36)
hairColorContainer.BackgroundTransparency = 1
hairColorContainer.LayoutOrder = 10
hairColorContainer.Parent = optionsPanel

local hcLayout = Instance.new("UIListLayout")
hcLayout.FillDirection = Enum.FillDirection.Horizontal
hcLayout.Padding = UDim.new(0, 12)
hcLayout.Parent = hairColorContainer

local hairColorButtons: { { Button: TextButton, Stroke: UIStroke, Indicator: TextLabel } } = {}

local function updateHairColorUI()
	for idx, item in ipairs(hairColorButtons) do
		local isSel = (idx == currentAppearance.HairColorIndex)
		item.Stroke.Color = if isSel then THEME.Gold else THEME.Border
		item.Stroke.Thickness = if isSel then 2.5 else 1
		item.Indicator.Visible = isSel
	end
	updatePreviewModel()
end

for idx, opt in ipairs(CharacterCustomizationConfig.HairColors) do
	local swatch = Instance.new("TextButton")
	swatch.Name = "HairColor_" .. opt.Id
	swatch.Size = UDim2.new(0, 34, 0, 34)
	swatch.BackgroundColor3 = opt.Color
	swatch.Text = ""
	swatch.Parent = hairColorContainer

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(1, 0)
	sCorner.Parent = swatch

	local sStroke = Instance.new("UIStroke")
	sStroke.Thickness = 1
	sStroke.Color = THEME.Border
	sStroke.Parent = swatch

	local check = Instance.new("TextLabel")
	check.Size = UDim2.new(1, 0, 1, 0)
	check.BackgroundTransparency = 1
	check.Text = "✓"
	check.Font = Enum.Font.GothamBold
	check.TextSize = 14
	check.TextColor3 = if opt.Color.R + opt.Color.G + opt.Color.B > 1.4 then Color3.fromRGB(20, 20, 20) else Color3.fromRGB(255, 255, 255)
	check.Visible = (idx == currentAppearance.HairColorIndex)
	check.Parent = swatch

	table.insert(hairColorButtons, { Button = swatch, Stroke = sStroke, Indicator = check })

	swatch.Activated:Connect(function()
		currentAppearance.HairColorIndex = idx
		updateHairColorUI()
	end)
end

updateHairColorUI()

-- -----------------------------------------------------------------
-- СЕКЦИЯ 5: ВЫРАЖЕНИЕ ЛИЦА СО СТРЕЛОЧКАМИ
-- -----------------------------------------------------------------
createSectionTitle("FACE EXPRESSION", 11)

local faceStepperFrame = Instance.new("Frame")
faceStepperFrame.Size = UDim2.new(1, -10, 0, 38)
faceStepperFrame.BackgroundColor3 = THEME.CardBg
faceStepperFrame.LayoutOrder = 12
faceStepperFrame.Parent = optionsPanel

local fsCorner = Instance.new("UICorner")
fsCorner.CornerRadius = UDim.new(0, 8)
fsCorner.Parent = faceStepperFrame

local fsStroke = Instance.new("UIStroke")
fsStroke.Thickness = 1
fsStroke.Color = THEME.Border
fsStroke.Parent = faceStepperFrame

local facePrevBtn = Instance.new("TextButton")
facePrevBtn.Size = UDim2.new(0, 38, 1, 0)
facePrevBtn.Position = UDim2.new(0, 0, 0, 0)
facePrevBtn.Text = "◀"
facePrevBtn.Font = Enum.Font.GothamBold
facePrevBtn.TextSize = 13
facePrevBtn.TextColor3 = THEME.Gold
facePrevBtn.BackgroundTransparency = 1
facePrevBtn.Parent = faceStepperFrame

local faceNameLabel = Instance.new("TextLabel")
faceNameLabel.Size = UDim2.new(1, -80, 1, 0)
faceNameLabel.Position = UDim2.new(0, 40, 0, 0)
faceNameLabel.BackgroundTransparency = 1
faceNameLabel.Font = Enum.Font.GothamBold
faceNameLabel.TextSize = 13
faceNameLabel.TextColor3 = THEME.TextMain
faceNameLabel.Parent = faceStepperFrame

local faceNextBtn = Instance.new("TextButton")
faceNextBtn.Size = UDim2.new(0, 38, 1, 0)
faceNextBtn.Position = UDim2.new(1, -38, 0, 0)
faceNextBtn.Text = "▶"
faceNextBtn.Font = Enum.Font.GothamBold
faceNextBtn.TextSize = 13
faceNextBtn.TextColor3 = THEME.Gold
faceNextBtn.BackgroundTransparency = 1
faceNextBtn.Parent = faceStepperFrame

local function updateFaceUI()
	local count = #availableFaces
	if count == 0 then return end
	currentAppearance.FaceIndex = math.clamp(currentAppearance.FaceIndex, 1, count)
	local selectedFace = availableFaces[currentAppearance.FaceIndex]
	faceNameLabel.Text = selectedFace.Name
	currentAppearance.FaceName = selectedFace.Id
	updatePreviewModel()
end

facePrevBtn.Activated:Connect(function()
	local count = #availableFaces
	if count == 0 then return end
	currentAppearance.FaceIndex = if currentAppearance.FaceIndex > 1 then currentAppearance.FaceIndex - 1 else count
	updateFaceUI()
end)

faceNextBtn.Activated:Connect(function()
	local count = #availableFaces
	if count == 0 then return end
	currentAppearance.FaceIndex = if currentAppearance.FaceIndex < count then currentAppearance.FaceIndex + 1 else 1
	updateFaceUI()
end)

updateFaceUI()

-- Отступ перед кнопкой подтверждения
local spacer = Instance.new("Frame")
spacer.Size = UDim2.new(1, 0, 0, 10)
spacer.BackgroundTransparency = 1
spacer.LayoutOrder = 13
spacer.Parent = optionsPanel

-- -----------------------------------------------------------------
-- СЕКЦИЯ 6: КНОПКА ПОДТВЕРЖДЕНИЯ (ENTER WORLD)
-- -----------------------------------------------------------------
local submitButton = Instance.new("TextButton")
submitButton.Name = "SubmitCreationButton"
submitButton.Size = UDim2.new(1, -10, 0, 46)
submitButton.BackgroundColor3 = THEME.Gold
submitButton.Text = "BEGIN JOURNEY"
submitButton.Font = Enum.Font.GothamBold
submitButton.TextSize = 14
submitButton.TextColor3 = THEME.TextDark
submitButton.AutoButtonColor = true
submitButton.LayoutOrder = 14
submitButton.Parent = optionsPanel

local submitCorner = Instance.new("UICorner")
submitCorner.CornerRadius = UDim.new(0, 8)
submitCorner.Parent = submitButton

local submitStroke = Instance.new("UIStroke")
submitStroke.Thickness = 1.5
submitStroke.Color = Color3.fromRGB(180, 150, 40)
submitStroke.Parent = submitButton

-- =================================================================
-- 5. ИНИЦИАЛИЗАЦИЯ 3D ПРЕВЬЮ ПЕРСОНАЖА
-- =================================================================
local function getPreviewSourceModel(): Model?
	-- Превью-модель во ViewportFrame ВСЕГДА клонируется напрямую из StarterPlayer:WaitForChild("StarterCharacter")
	-- Без использования player.Character, чтобы исключить динамические деформации меша при спавне
	local starterChar = StarterPlayer:WaitForChild("StarterCharacter", 10) :: Model?
	if starterChar and starterChar:IsA("Model") then
		local wasArch = starterChar.Archivable
		starterChar.Archivable = true
		local clone = starterChar:Clone()
		starterChar.Archivable = wasArch
		return clone
	end

	return nil
end

local function setupPreviewModel()
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end

	local clone = getPreviewSourceModel()
	if not clone then
		warn("[CharacterCreationController] Не удалось найти StarterCharacter в StarterPlayer")
		return
	end

	-- Удаляем ненужные скрипты, оружие и контроллеры урона внутри копии, чтобы работали только визуалы
	for _, child in ipairs(clone:GetDescendants()) do
		if child:IsA("LuaSourceContainer") or child:IsA("Tool") then
			child:Destroy()
		end
	end

	-- Удаляем дефолтные аксессуары (шляпы, волосы из шаблона), чтобы они не конфликтовали с кастомизацией
	for _, child in ipairs(clone:GetChildren()) do
		if child:IsA("Accessory") then
			child:Destroy()
		end
	end

	-- Удаляем любые объекты WrapTarget / HeadWrapTarget в модели, чтобы не было графических артефактов в ViewportFrame
	for _, desc in ipairs(clone:GetDescendants()) do
		if desc.Name == "HeadWrapTarget" or desc:IsA("WrapTarget") or desc:IsA("WrapLayer") then
			desc:Destroy()
		end
	end

	-- Гарантия классической геометрии головы в превью
	local head = clone:FindFirstChild("Head") :: BasePart?
	if head then
		-- Если деталь Head это MeshPart (динамическая голова), преобразуем её под плоскую классическую геометрию:
		if head:IsA("MeshPart") then
			pcall(function()
				(head :: MeshPart).TextureID = ""
			end)

			local classicHead = Instance.new("Part")
			classicHead.Name = "Head"
			classicHead.Size = head.Size
			classicHead.CFrame = head.CFrame
			classicHead.Color = head.Color
			classicHead.Material = head.Material
			classicHead.Transparency = head.Transparency
			classicHead.CanCollide = false
			classicHead.Anchored = head.Anchored

			local mesh = Instance.new("SpecialMesh")
			mesh.Name = "Mesh"
			mesh.MeshType = Enum.MeshType.Head
			mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
			mesh.Parent = classicHead

			-- Переносим все вложения (Attachments: HairAttachment, HatAttachment и др.)
			for _, child in ipairs(head:GetChildren()) do
				if child:IsA("Attachment") then
					child.Parent = classicHead
				end
			end

			-- Перепривязываем суставы Motor6D и Weld (например Neck)
			for _, desc in ipairs(clone:GetDescendants()) do
				if desc:IsA("Motor6D") and desc.Part1 == head then
					desc.Part1 = classicHead
				elseif desc:IsA("Weld") and desc.Part1 == head then
					desc.Part1 = classicHead
				end
			end

			classicHead.Parent = clone
			head:Destroy()
			head = classicHead
		end

		-- Гарантируем, что декаль лица наложена строго спереди без смещений
		local face = head:FindFirstChild("face") :: Decal?
		if not face then
			face = Instance.new("Decal")
			face.Name = "face"
			face.Parent = head
		end
		face.Face = Enum.NormalId.Front

		-- Коррекция высоты шеи (поднимаем голову выше воротника туловища, чтобы не была утоплена в плечи)
		local neck = head:FindFirstChild("Neck") :: Motor6D?
		if not neck then
			local upperTorso = clone:FindFirstChild("UpperTorso") or clone:FindFirstChild("Torso")
			if upperTorso then
				neck = upperTorso:FindFirstChild("Neck") :: Motor6D?
			end
		end
		if not neck then
			neck = clone:FindFirstChild("Neck", true) :: Motor6D?
		end
		if neck and neck:IsA("Motor6D") then
			neck.C0 = CFrame.new(0, 0.9, 0)
			neck.C1 = CFrame.new(0, -0.5, 0)
		end
	end

	-- Очищаем текстуры головы сразу при создании клона (удаление старых артефактов)
	cleanHeadTextures(clone)

	-- Отключаем коллизии у всех деталей: CanCollide = false
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
		end
	end

	-- Отключаем лишние статусы Humanoid
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	end

	-- Помещаем клон внутрь WorldModel в ViewportFrame
	clone.Parent = worldModel
	previewModel = clone

	-- Применяем базовую одежду новичка из DefaultClothing
	applyDefaultClothing(clone)

	-- Задаем позицию модели: HumanoidRootPart.CFrame = CFrame.new(0, 0, 0)
	local hrp = clone:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		hrp = clone.PrimaryPart or clone:FindFirstChild("Torso") :: BasePart?
	end
	if hrp then
		hrp.Anchored = true
		hrp.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(currentAngleY), 0)
	end

	-- Анимация позы покоя: стандартная нейтральная стойка дыхания R15
	local DEFAULT_IDLE_ANIM_ID = "rbxassetid://507766666" -- Стандартный R15 Idle
	local hasAnimation = false
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator and humanoid then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	if not animator then
		local animController = clone:FindFirstChildOfClass("AnimationController")
		if animController then
			animator = animController:FindFirstChildOfClass("Animator") or Instance.new("Animator", animController)
		end
	end

	if animator and DEFAULT_IDLE_ANIM_ID ~= "" then
		local anim = Instance.new("Animation")
		anim.AnimationId = DEFAULT_IDLE_ANIM_ID
		local success, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if success and track then
			track.Priority = Enum.AnimationPriority.Idle
			track.Looped = true
			track:Play()
			hasAnimation = true
		end
	end

	-- Фиксируем детали: если анимация активна, HumanoidRootPart зафиксирован, а конечности движутся по Motor6D.
	-- Если анимации нет, фиксируем все детали (Anchored = true), чтобы модель держала позу.
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			if part.Name == "HumanoidRootPart" or not hasAnimation then
				part.Anchored = true
			else
				part.Anchored = false
			end
		end
	end

	updatePreviewModel()
end

-- =================================================================
-- 6. ОТКРЫТИЕ И ЗАКРЫТИЕ ОКНА С АНИМАЦИЕЙ
-- =================================================================
local isSubmitting = false

local function closeCreationWindow()
	isSubmitting = false
	local fadeInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local t1 = TweenService:Create(Backdrop, fadeInfo, { BackgroundTransparency = 1 })
	local t2 = TweenService:Create(MainFrame, fadeInfo, {
		Position = UDim2.new(0.5, 0, 0.52, 0),
		BackgroundTransparency = 1,
	})

	t1:Play()
	t2:Play()

	t2.Completed:Connect(function()
		ScreenGui.Enabled = false
		MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
		MainFrame.BackgroundTransparency = 0
		Backdrop.BackgroundTransparency = 0.35
		if previewModel then
			previewModel:Destroy()
			previewModel = nil
		end
	end)
end

local function resetSelectionToDefaults()
	selectedClass = "Warrior"

	local defaultHairIdx = 2
	for idx, h in ipairs(availableHairs) do
		if h.Id == "Hair1" or h.Name == "Hair1" then
			defaultHairIdx = idx
			break
		end
	end

	local defaultFaceIdx = 1
	for idx, f in ipairs(availableFaces) do
		if f.Id == "Face1" or f.Name == "Face1" then
			defaultFaceIdx = idx
			break
		end
	end

	currentAppearance.SkinColorIndex = 3
	currentAppearance.HairColorIndex = 2
	currentAppearance.HairIndex = defaultHairIdx
	currentAppearance.HairName = "Hair1"
	currentAppearance.FaceIndex = defaultFaceIdx
	currentAppearance.FaceName = "Face1"
end

local function openCreationWindow(initialData: any?)
	initAssetLists()

	local isResetOrNew = (initialData == nil)
		or (initialData.IsReset == true)
		or (initialData.Profile == nil)
		or (initialData.Profile.IsCharacterCreated == false)
		or (initialData.Profile.SelectedClass == "None")
		or (initialData.Profile.SelectedClass == "")

	if isResetOrNew then
		resetSelectionToDefaults()
	elseif initialData and initialData.Profile and initialData.Profile.Appearance then
		local a = initialData.Profile.Appearance
		currentAppearance.SkinColorIndex = a.SkinColorIndex or currentAppearance.SkinColorIndex
		currentAppearance.HairColorIndex = a.HairColorIndex or currentAppearance.HairColorIndex
		if a.HairName then
			currentAppearance.HairName = a.HairName
			for idx, h in ipairs(availableHairs) do
				if h.Id == a.HairName or h.Name == a.HairName then
					currentAppearance.HairIndex = idx
					break
				end
			end
		elseif a.HairIndex then
			currentAppearance.HairIndex = math.clamp(a.HairIndex, 1, #availableHairs)
			local h = availableHairs[currentAppearance.HairIndex]
			if h then currentAppearance.HairName = h.Id end
		end

		if a.FaceName then
			currentAppearance.FaceName = a.FaceName
			for idx, f in ipairs(availableFaces) do
				if f.Id == a.FaceName or f.Name == a.FaceName then
					currentAppearance.FaceIndex = idx
					break
				end
			end
		elseif a.FaceIndex then
			currentAppearance.FaceIndex = math.clamp(a.FaceIndex, 1, #availableFaces)
			local f = availableFaces[currentAppearance.FaceIndex]
			if f then currentAppearance.FaceName = f.Id end
		end

		if initialData.Profile.SelectedClass and initialData.Profile.SelectedClass ~= "None" then
			selectedClass = initialData.Profile.SelectedClass
		end
	else
		resetSelectionToDefaults()
	end

	isSubmitting = false
	submitButton.Text = "BEGIN JOURNEY"
	submitButton.BackgroundColor3 = THEME.Gold

	ScreenGui.Enabled = true
	MainFrame.Visible = true
	mainCreationGui.Visible = true
	MainFrame.Position = UDim2.new(0.5, 0, 0.48, 0)
	MainFrame.BackgroundTransparency = 1
	Backdrop.BackgroundTransparency = 1

	local fadeIn = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(Backdrop, fadeIn, { BackgroundTransparency = 0.35 }):Play()
	TweenService:Create(MainFrame, fadeIn, {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 0,
	}):Play()

	setupPreviewModel()
	updateClassSelectionUI()
	updateSkinSelectionUI()
	updateHairUI()
	updateHairColorUI()
	updateFaceUI()
end

-- Отправка формы создания
submitButton.Activated:Connect(function()
	if isSubmitting then return end
	isSubmitting = true

	submitButton.Text = "CREATING HERO..."
	submitButton.BackgroundColor3 = Color3.fromRGB(180, 160, 40)

	local selectedHair = availableHairs[currentAppearance.HairIndex]
	local selectedFace = availableFaces[currentAppearance.FaceIndex]

	local hairName = if selectedHair then selectedHair.Id else "None"
	local faceName = if selectedFace then selectedFace.Id else "Face1"

	currentAppearance.HairName = hairName
	currentAppearance.FaceName = faceName

	SubmitCharacterCreationRemote:FireServer({
		ClassName = selectedClass,
		Appearance = {
			SkinColorIndex = currentAppearance.SkinColorIndex,
			FaceIndex = currentAppearance.FaceIndex,
			HairIndex = currentAppearance.HairIndex,
			HairColorIndex = currentAppearance.HairColorIndex,
			HairName = hairName,
			FaceName = faceName,
		},
	})
end)

-- Ответ сервера
CharacterCreationResponse.OnClientEvent:Connect(function(success: boolean, message: string)
	if success then
		submitButton.Text = "READY!"
		submitButton.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
		task.wait(0.2)
		closeCreationWindow()
	else
		isSubmitting = false
		submitButton.Text = "BEGIN JOURNEY"
		submitButton.BackgroundColor3 = THEME.Gold
		warn("[CharacterCreation] Ошибка сервера: " .. tostring(message))
	end
end)

-- Слушатель открытия от сервера при первом входе игрока и сбросе (/reset, /resetchar, /resetclass)
OpenCharacterCreation.OnClientEvent:Connect(function(data: any?)
	openCreationWindow(data)
end)

if OpenCharacterCreationRemote and OpenCharacterCreationRemote ~= OpenCharacterCreation then
	OpenCharacterCreationRemote.OnClientEvent:Connect(function(data: any?)
		openCreationWindow(data)
	end)
end

-- Плавное фоновое вращение превью в реальном времени
local orbitConn: RBXScriptConnection? = nil
orbitConn = RunService.RenderStepped:Connect(function()
	if ScreenGui.Enabled and not isDragging then
		currentAngleY = (currentAngleY + 0.15) % 360
		updateModelRotation()
	end
end)

-- Дополнительная проверка профиля при запуске локального скрипта
task.spawn(function()
	local classEvents = ReplicatedStorage:WaitForChild("ClassEvents", 5) :: Folder?
	if classEvents then
		local getFunc = classEvents:WaitForChild("GetClassData", 5) :: RemoteFunction?
		if getFunc then
			local data = getFunc:InvokeServer()
			if data and data.IsCharacterCreated == false then
				task.wait(0.3)
				openCreationWindow({ Profile = data })
			end
		end
	end
end)

return {}
