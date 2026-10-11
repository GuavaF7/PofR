local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui", 10)

-- =================================================================
-- ??? 1. СОЗДАНИЕ ИНТЕРФЕЙСА ВЫБОРА КЛАССА ИЗ КОДА
-- =================================================================
local ClassGui = Instance.new("ScreenGui")
ClassGui.Name = "ClassSelectionGui"
ClassGui.ResetOnSpawn = false
ClassGui.Parent = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.Size = UDim2.new(0, 560, 0, 380)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
MainFrame.Visible = false -- Скрыто до проверки сервера
MainFrame.Parent = ClassGui

local mainCorner = Instance.new("UICorner", MainFrame)
mainCorner.CornerRadius = UDim.new(0, 12)

local mainStroke = Instance.new("UIStroke", MainFrame)
mainStroke.Thickness = 2
mainStroke.Color = Color3.fromRGB(255, 215, 0)

-- =================================================================
-- ?? ДИНАМИЧЕСКИЙ МАСШТАБ ПОД IPHONE PRO / HOME INDICATOR
-- =================================================================
local uiScale = Instance.new("UIScale", MainFrame)

local cameraConnection: RBXScriptConnection? = nil

local function UpdateScale()
	local camera = workspace.CurrentCamera
	if camera then
		local viewport = camera.ViewportSize

		-- Автоматически берем размер конкретного MainFrame + 45px отступа безопасности
		local requiredWidth = MainFrame.Size.X.Offset + 40
		local requiredHeight = MainFrame.Size.Y.Offset + 45

		local scaleX = viewport.X / requiredWidth
		local scaleY = viewport.Y / requiredHeight

		-- Берем наименьший масштаб и расширяем диапазон сжатия (от 0.35 до 1.0)
		local finalScale = math.min(scaleX, scaleY)
		uiScale.Scale = math.clamp(finalScale, 0.35, 1.0)
	end
end

-- Динамическое связывание с безопасной очисткой предыдущего слушателя
local function BindCamera(cam: Camera)
	if cameraConnection then
		cameraConnection:Disconnect()
		cameraConnection = nil
	end

	cameraConnection = cam:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale)
	UpdateScale()
end

if workspace.CurrentCamera then
	BindCamera(workspace.CurrentCamera)
end

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	if workspace.CurrentCamera then
		BindCamera(workspace.CurrentCamera)
	end
end)

-- Заголовок
local HeaderLabel = Instance.new("TextLabel")
HeaderLabel.Position = UDim2.new(0.05, 0, 0.04, 0)
HeaderLabel.Size = UDim2.new(0.9, 0, 0.08, 0)
HeaderLabel.Text = "CHOOSE YOUR CLASS"
HeaderLabel.Font = Enum.Font.GothamBold
HeaderLabel.TextSize = 20
HeaderLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
HeaderLabel.BackgroundTransparency = 1
HeaderLabel.Parent = MainFrame

-- Контейнер для 3 карточек
local CardsContainer = Instance.new("Frame")
CardsContainer.Position = UDim2.new(0.04, 0, 0.16, 0)
CardsContainer.Size = UDim2.new(0.92, 0, 0.78, 0)
CardsContainer.BackgroundTransparency = 1
CardsContainer.Parent = MainFrame

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 160, 0, 280)
gridLayout.CellPadding = UDim2.new(0, 16, 0, 0)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.Parent = CardsContainer

-- Данные для карточек выбора
local CLASSES_DISPLAY = {
	{
		Id = "Mage",
		Name = "MAGE",
		Desc = "Master of Arcane Magic\n\n• HP: 90\n• INT: 22\n• Weapon: Staff",
		Color = Color3.fromRGB(60, 140, 220),
		CardImage = "rbxassetid://108617644426277", -- Добавлено
	},
	{
		Id = "Rogue",
		Name = "ROGUE",
		Desc = "Agile & Lethal Striker\n\n• HP: 130\n• AGI: 20\n• Weapon: Daggers",
		Color = Color3.fromRGB(60, 200, 100),
		CardImage = "rbxassetid://127721562224542", -- Добавлено
	},
	{
		Id = "Warrior",
		Name = "WARRIOR",
		Desc = "Heavy Melee Specialist\n\n• HP: 186\n• STR: 18\n• Weapon: Sword",
		Color = Color3.fromRGB(200, 60, 60),
		CardImage = "rbxassetid://139718222051906", -- Добавлено
	},
}

local ClassEvents = ReplicatedStorage:WaitForChild("ClassEvents")
local SelectClassFunction = ClassEvents:WaitForChild("SelectClass") :: RemoteFunction
local GetClassDataFunction = ClassEvents:WaitForChild("GetClassData") :: RemoteFunction
local SyncClassDataEvent = ClassEvents:WaitForChild("SyncClassData") :: RemoteEvent

-- Генерируем 3 карточки
for _, info in ipairs(CLASSES_DISPLAY) do
	local card = Instance.new("Frame")
	card.Name = info.Id .. "_Card"
	card.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
	card.Parent = CardsContainer

	local cardCorner = Instance.new("UICorner", card)
	cardCorner.CornerRadius = UDim.new(0, 10)

	local cardStroke = Instance.new("UIStroke", card)
	cardStroke.Thickness = 1.5
	cardStroke.Color = info.Color
	
	-- Фоновый арт класса
	local cardImageId = info.CardImage

	if cardImageId then
		-- ?? Псевдо-блюр наложения слоев
		local blurOffsets = {
			Vector2.new(0, 0),
			Vector2.new(-1.5, -1.5),
			Vector2.new(1.5, 1.5),
			Vector2.new(-1.5, 1.5),
		}

		for _, offset in ipairs(blurOffsets) do
			local bgArt = Instance.new("ImageLabel")
			bgArt.Name = "ClassBackgroundArt_Blur"
			bgArt.Size = UDim2.new(1, 0, 1, 0)
			bgArt.Position = UDim2.new(0, offset.X, 0, offset.Y)
			bgArt.BackgroundTransparency = 1
			bgArt.Image = cardImageId
			bgArt.ScaleType = Enum.ScaleType.Crop
			bgArt.ImageTransparency = 0.72 -- Каждый слой очень прозрачный, вместе дают мягкое размытие
			bgArt.ZIndex = 1
			bgArt.Parent = card

			local artCorner = Instance.new("UICorner")
			artCorner.CornerRadius = UDim.new(0, 10)
			artCorner.Parent = bgArt
		end
	end
	
	

	-- Название класса
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
	nameLabel.Size = UDim2.new(0.9, 0, 0.12, 0)
	nameLabel.Text = info.Name
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 15
	nameLabel.TextColor3 = info.Color
	nameLabel.BackgroundTransparency = 1
	nameLabel.Parent = card
	nameLabel.ZIndex = 2
	local nameStroke = Instance.new("UIStroke")
	nameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	nameStroke.Color = Color3.fromRGB(10, 10, 15) -- Глубокий темный контур
	nameStroke.Thickness = 1.5
	nameStroke.Parent = nameLabel

	-- Описание и статы
	local descLabel = Instance.new("TextLabel")
	descLabel.Position = UDim2.new(0.08, 0, 0.2, 0)
	descLabel.Size = UDim2.new(0.84, 0, 0.55, 0)
	descLabel.Text = info.Desc
	descLabel.Font = Enum.Font.GothamMedium
	descLabel.TextSize = 11
	descLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextWrapped = true
	descLabel.BackgroundTransparency = 1
	descLabel.Parent = card
	descLabel.ZIndex = 2
	local descStroke = Instance.new("UIStroke")
	descStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	descStroke.Color = Color3.fromRGB(10, 10, 15)
	descStroke.Thickness = 1
	descStroke.Parent = descLabel

	-- Кнопка выбора
	local selectBtn = Instance.new("TextButton")
	selectBtn.Position = UDim2.new(0.08, 0, 0.8, 0)
	selectBtn.Size = UDim2.new(0.84, 0, 0.15, 0)
	selectBtn.Text = "SELECT"
	selectBtn.Font = Enum.Font.GothamBold
	selectBtn.TextSize = 12
	selectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	selectBtn.BackgroundColor3 = info.Color
	selectBtn.Parent = card
	selectBtn.ZIndex = 2
	local btnTextStroke = Instance.new("UIStroke")
	btnTextStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	btnTextStroke.Color = Color3.fromRGB(15, 15, 20)
	btnTextStroke.Thickness = 1.2
	btnTextStroke.Parent = selectBtn

	local btnCorner = Instance.new("UICorner", selectBtn)
	btnCorner.CornerRadius = UDim.new(0, 6)

	selectBtn.Activated:Connect(function()
		local success, msg = SelectClassFunction:InvokeServer(info.Id)
		if success then
			MainFrame.Visible = false
		else
			warn("[ClassSelection] " .. tostring(msg))
		end
	end)
end

-- =================================================================
-- ?? 2. РЕАКТИВНАЯ СИНХРОНИЗАЦИЯ
-- =================================================================
local function CheckVisibility(data)
	-- Окно открывается только если персонаж уже создан, но класс сброшен (!reset / /resetclass)
	-- При первом входе игрока встречает CharacterCreationController
	if data and data.SelectedClass == "None" and data.IsCharacterCreated ~= false then
		MainFrame.Visible = true
	else
		MainFrame.Visible = false
	end
end

-- Открываем окно при сбросе (!reset / /resetclass)
SyncClassDataEvent.OnClientEvent:Connect(CheckVisibility)

-- Проверяем сохраненный класс при запуске
task.spawn(function()
	local serverData = GetClassDataFunction:InvokeServer()
	CheckVisibility(serverData)
end)