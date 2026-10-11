local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui", 10)
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- =================================================================
-- ??? 1. СОЗДАНИЕ ИНТЕРФЕЙСА ДРЕВА НАВЫКОВ
-- =================================================================
local SkillTreeGui = Instance.new("ScreenGui")
SkillTreeGui.Name = "SkillTreeGui"
SkillTreeGui.ResetOnSpawn = false
SkillTreeGui.Parent = PlayerGui

-- ?? Адаптивная кнопка SKILLS [K] (Индекс 1)
local btnSize = isMobile and 44 or 58
local gap = isMobile and 8 or 10
local baseY = isMobile and 60 or 120

local OpenSkillBtn = Instance.new("TextButton")
OpenSkillBtn.Name = "OpenSkillTreeHUD"
OpenSkillBtn.AnchorPoint = Vector2.new(0, 0)
OpenSkillBtn.ZIndex = 10
OpenSkillBtn.Position = UDim2.new(0.015, 0, 0, baseY + 1 * (btnSize + gap))
OpenSkillBtn.Size = UDim2.new(0, btnSize, 0, btnSize)
OpenSkillBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
OpenSkillBtn.Font = Enum.Font.GothamBold
OpenSkillBtn.TextSize = isMobile and 10 or 12
OpenSkillBtn.TextColor3 = Color3.fromRGB(255, 215, 0)
OpenSkillBtn.Text = isMobile and "SKILLS" or "SKILLS\n[K]"
OpenSkillBtn.Parent = SkillTreeGui

local hudCorner = Instance.new("UICorner", OpenSkillBtn)
hudCorner.CornerRadius = UDim.new(0, 8)

local hudStroke = Instance.new("UIStroke", OpenSkillBtn)
hudStroke.Thickness = 2
hudStroke.Color = Color3.fromRGB(60, 60, 75)

-- Главный фрейм
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.Size = UDim2.new(0, 580, 0, 490)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
MainFrame.Visible = false
MainFrame.Parent = SkillTreeGui

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

-- -----------------------------------------------------------------
-- ШАПКА ОКНА (HEADER)
-- -----------------------------------------------------------------
local HeaderLabel = Instance.new("TextLabel")
HeaderLabel.Position = UDim2.new(0.04, 0, 0.02, 0)
HeaderLabel.Size = UDim2.new(0.35, 0, 0.06, 0)
HeaderLabel.Text = "PASSIVE SKILL TREE"
HeaderLabel.Font = Enum.Font.GothamBold
HeaderLabel.TextSize = 14
HeaderLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
HeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
HeaderLabel.BackgroundTransparency = 1
HeaderLabel.Parent = MainFrame

local PointsLabel = Instance.new("TextLabel")
PointsLabel.Position = UDim2.new(0.38, 0, 0.02, 0)
PointsLabel.Size = UDim2.new(0.28, 0, 0.06, 0)
PointsLabel.Text = "Points: 0"
PointsLabel.Font = Enum.Font.GothamBold
PointsLabel.TextSize = 13
PointsLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
PointsLabel.TextXAlignment = Enum.TextXAlignment.Right
PointsLabel.BackgroundTransparency = 1
PointsLabel.Parent = MainFrame

local ResetTreeBtn = Instance.new("TextButton")
ResetTreeBtn.Name = "ResetTreeBtn"
ResetTreeBtn.Position = UDim2.new(0.68, 0, 0.02, 0)
ResetTreeBtn.Size = UDim2.new(0, 105, 0, 26)
ResetTreeBtn.Text = "RESET TREE"
ResetTreeBtn.Font = Enum.Font.GothamBold
ResetTreeBtn.TextSize = 10
ResetTreeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ResetTreeBtn.BackgroundColor3 = Color3.fromRGB(160, 60, 60)
ResetTreeBtn.Parent = MainFrame

local resetBtnCorner = Instance.new("UICorner", ResetTreeBtn)
resetBtnCorner.CornerRadius = UDim.new(0, 6)

local CloseBtn = Instance.new("TextButton")
CloseBtn.AnchorPoint = Vector2.new(1, 0)
CloseBtn.Position = UDim2.new(0.96, 0, 0.02, 0)
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
CloseBtn.Parent = MainFrame

local closeCorner = Instance.new("UICorner", CloseBtn)
closeCorner.CornerRadius = UDim.new(0, 6)

-- -----------------------------------------------------------------
-- ХОЛСТ ДРЕВА (CANVAS AREA)
-- -----------------------------------------------------------------
local TreeCanvas = Instance.new("ScrollingFrame")
TreeCanvas.Name = "TreeCanvas"
TreeCanvas.Position = UDim2.new(0.03, 0, 0.09, 0)
TreeCanvas.Size = UDim2.new(0.94, 0, 0.76, 0) -- Высота 76%, снизу панель действий
TreeCanvas.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
TreeCanvas.CanvasSize = UDim2.new(0, 650, 0, 650)
TreeCanvas.ScrollBarThickness = 2
TreeCanvas.ScrollBarImageTransparency = 0.5
TreeCanvas.Active = true
TreeCanvas.Parent = MainFrame

local canvasCorner = Instance.new("UICorner", TreeCanvas)
canvasCorner.CornerRadius = UDim.new(0, 8)

-- -----------------------------------------------------------------
-- ?? НИЖНЯЯ ПАНЕЛЬ ДЕЙСТВИЙ (ACTION BAR - LEARN BUTTON)
-- -----------------------------------------------------------------
local ActionBar = Instance.new("Frame")
ActionBar.Name = "ActionBar"
ActionBar.Position = UDim2.new(0.03, 0, 0.86, 0)
ActionBar.Size = UDim2.new(0.94, 0, 0.11, 0)
ActionBar.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
ActionBar.Parent = MainFrame

local barCorner = Instance.new("UICorner", ActionBar)
barCorner.CornerRadius = UDim.new(0, 8)

local barStroke = Instance.new("UIStroke", ActionBar)
barStroke.Thickness = 1
barStroke.Color = Color3.fromRGB(50, 50, 65)

local SelectedSkillInfo = Instance.new("TextLabel")
SelectedSkillInfo.Name = "SelectedSkillInfo"
SelectedSkillInfo.Position = UDim2.new(0.04, 0, 0.15, 0)
SelectedSkillInfo.Size = UDim2.new(0.6, 0, 0.7, 0)
SelectedSkillInfo.Text = "Select a skill node on the tree"
SelectedSkillInfo.Font = Enum.Font.GothamMedium
SelectedSkillInfo.TextSize = 11
SelectedSkillInfo.TextColor3 = Color3.fromRGB(180, 180, 200)
SelectedSkillInfo.TextXAlignment = Enum.TextXAlignment.Left
SelectedSkillInfo.BackgroundTransparency = 1
SelectedSkillInfo.Parent = ActionBar

-- ОТДЕЛЬНАЯ КНОПКА ПРОКАЧКИ НАВЫКА
local LearnSkillBtn = Instance.new("TextButton")
LearnSkillBtn.Name = "LearnSkillBtn"
LearnSkillBtn.Position = UDim2.new(0.66, 0, 0.15, 0)
LearnSkillBtn.Size = UDim2.new(0.3, 0, 0.7, 0)
LearnSkillBtn.Text = "SELECT SKILL"
LearnSkillBtn.Font = Enum.Font.GothamBold
LearnSkillBtn.TextSize = 11
LearnSkillBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
LearnSkillBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
LearnSkillBtn.AutoButtonColor = false
LearnSkillBtn.Parent = ActionBar

local learnBtnCorner = Instance.new("UICorner", LearnSkillBtn)
learnBtnCorner.CornerRadius = UDim.new(0, 6)

-- =================================================================
-- ?? 2. ИНФОРМАЦИОННАЯ ПОДСКАЗКА (TOOLTIP)
-- =================================================================
local SkillTooltip = Instance.new("Frame")
SkillTooltip.Name = "SkillTooltip"
SkillTooltip.Size = UDim2.new(0, 210, 0, 95)
SkillTooltip.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
SkillTooltip.Visible = false
SkillTooltip.ZIndex = 20
SkillTooltip.Parent = SkillTreeGui

local tooltipCorner = Instance.new("UICorner", SkillTooltip)
tooltipCorner.CornerRadius = UDim.new(0, 8)

local tooltipStroke = Instance.new("UIStroke", SkillTooltip)
tooltipStroke.Thickness = 1.5
tooltipStroke.Color = Color3.fromRGB(255, 215, 0)

local TooltipTitle = Instance.new("TextLabel")
TooltipTitle.Position = UDim2.new(0.06, 0, 0.1, 0)
TooltipTitle.Size = UDim2.new(0.88, 0, 0.25, 0)
TooltipTitle.Text = "Node Name"
TooltipTitle.Font = Enum.Font.GothamBold
TooltipTitle.TextSize = 12
TooltipTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
TooltipTitle.TextXAlignment = Enum.TextXAlignment.Left
TooltipTitle.BackgroundTransparency = 1
TooltipTitle.ZIndex = 21
TooltipTitle.Parent = SkillTooltip

local TooltipDesc = Instance.new("TextLabel")
TooltipDesc.Position = UDim2.new(0.06, 0, 0.38, 0)
TooltipDesc.Size = UDim2.new(0.88, 0, 0.52, 0)
TooltipDesc.Text = "Description details..."
TooltipDesc.Font = Enum.Font.GothamMedium
TooltipDesc.TextSize = 10
TooltipDesc.TextColor3 = Color3.fromRGB(200, 200, 215)
TooltipDesc.TextXAlignment = Enum.TextXAlignment.Left
TooltipDesc.TextYAlignment = Enum.TextYAlignment.Top
TooltipDesc.TextWrapped = true
TooltipDesc.BackgroundTransparency = 1
TooltipDesc.ZIndex = 21
TooltipDesc.Parent = SkillTooltip

local function HideTooltip()
	SkillTooltip.Visible = false
end

-- =================================================================
-- ?? 3. МОДАЛЬНОЕ ОКНО СБРОСА (RESET MODAL)
-- =================================================================
local ResetModal = Instance.new("Frame")
ResetModal.Name = "ResetModal"
ResetModal.AnchorPoint = Vector2.new(0.5, 0.5)
ResetModal.Position = UDim2.new(0.5, 0, 0.5, 0)
ResetModal.Size = UDim2.new(0, 320, 0, 180)
ResetModal.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
ResetModal.Visible = false
ResetModal.ZIndex = 30
ResetModal.Parent = SkillTreeGui

local modalCorner = Instance.new("UICorner", ResetModal)
modalCorner.CornerRadius = UDim.new(0, 10)

local modalStroke = Instance.new("UIStroke", ResetModal)
modalStroke.Thickness = 2
modalStroke.Color = Color3.fromRGB(255, 80, 80)

local ModalTitle = Instance.new("TextLabel")
ModalTitle.Position = UDim2.new(0.05, 0, 0.08, 0)
ModalTitle.Size = UDim2.new(0.9, 0, 0.18, 0)
ModalTitle.Text = "RESET SKILL TREE?"
ModalTitle.Font = Enum.Font.GothamBold
ModalTitle.TextSize = 14
ModalTitle.TextColor3 = Color3.fromRGB(255, 80, 80)
ModalTitle.BackgroundTransparency = 1
ModalTitle.ZIndex = 31
ModalTitle.Parent = ResetModal

local ModalText = Instance.new("TextLabel")
ModalText.Position = UDim2.new(0.08, 0, 0.28, 0)
ModalText.Size = UDim2.new(0.84, 0, 0.38, 0)
ModalText.Text = "Cost: 1x Reset Ticket\n(Defeat Bosses to obtain tickets)\nAll spent points will be refunded."
ModalText.Font = Enum.Font.GothamMedium
ModalText.TextSize = 11
ModalText.TextColor3 = Color3.fromRGB(220, 220, 235)
ModalText.TextWrapped = true
ModalText.BackgroundTransparency = 1
ModalText.ZIndex = 31
ModalText.Parent = ResetModal

local ConfirmResetBtn = Instance.new("TextButton")
ConfirmResetBtn.Position = UDim2.new(0.08, 0, 0.7, 0)
ConfirmResetBtn.Size = UDim2.new(0.42, 0, 0.22, 0)
ConfirmResetBtn.Text = "RESET"
ConfirmResetBtn.Font = Enum.Font.GothamBold
ConfirmResetBtn.TextSize = 11
ConfirmResetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ConfirmResetBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
ConfirmResetBtn.ZIndex = 31
ConfirmResetBtn.Parent = ResetModal

local confirmResetCorner = Instance.new("UICorner", ConfirmResetBtn)
confirmResetCorner.CornerRadius = UDim.new(0, 6)

local CancelResetBtn = Instance.new("TextButton")
CancelResetBtn.Position = UDim2.new(0.54, 0, 0.7, 0)
CancelResetBtn.Size = UDim2.new(0.38, 0, 0.22, 0)
CancelResetBtn.Text = "CANCEL"
CancelResetBtn.Font = Enum.Font.GothamBold
CancelResetBtn.TextSize = 11
CancelResetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CancelResetBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
CancelResetBtn.ZIndex = 31
CancelResetBtn.Parent = ResetModal

local cancelResetCorner = Instance.new("UICorner", CancelResetBtn)
cancelResetCorner.CornerRadius = UDim.new(0, 6)

-- =================================================================
-- ?? 4. ТАЧ-ПЕРЕТАСКИВАНИЕ И АВТО-ФОКУС (Touch Drag / Pan)
-- =================================================================
local isDragging = false
local dragStart = Vector2.new()
local startCanvasPos = Vector2.new()

TreeCanvas.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isDragging = true
		dragStart = input.Position
		startCanvasPos = TreeCanvas.CanvasPosition
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		TreeCanvas.CanvasPosition = startCanvasPos - Vector2.new(delta.X, delta.Y)
	end

	if SkillTooltip.Visible and input.UserInputType == Enum.UserInputType.MouseMovement then
		SkillTooltip.Position = UDim2.new(0, input.Position.X + 15, 0, input.Position.Y + 15)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isDragging = false
	end
end)

local function CenterOnCore()
	task.defer(function()
		local windowSize = TreeCanvas.AbsoluteWindowSize
		local corePos = Vector2.new(300, 300)
		local targetX = math.clamp(corePos.X - windowSize.X / 2, 0, TreeCanvas.CanvasSize.X.Offset - windowSize.X)
		local targetY = math.clamp(corePos.Y - windowSize.Y / 2, 0, TreeCanvas.CanvasSize.Y.Offset - windowSize.Y)
		TreeCanvas.CanvasPosition = Vector2.new(targetX, targetY)
	end)
end

-- =================================================================
-- ?? 5. РЕНДЕРИНГ ДРЕВА И ВЫБОР УЗЛА
-- =================================================================
local SkillTreeEvents = ReplicatedStorage:WaitForChild("SkillTreeEvents")
local AllocateNodeFunction = SkillTreeEvents:WaitForChild("AllocateNode") :: RemoteFunction
local ResetSkillTreeFunction = SkillTreeEvents:WaitForChild("ResetSkillTree") :: RemoteFunction
local SyncSkillDataEvent = SkillTreeEvents:WaitForChild("SyncSkillData") :: RemoteEvent
local SkillTreeConfig = require(ReplicatedStorage:WaitForChild("SkillTreeConfig"))

local selectedNodeId = nil
local currentPlayerData = nil

local function DrawLine(p1: Vector2, p2: Vector2, isActive: boolean)
	local distance = (p1 - p2).Magnitude
	local center = (p1 + p2) / 2
	local angle = math.deg(math.atan2(p2.Y - p1.Y, p2.X - p1.X))

	local line = Instance.new("Frame")
	line.Name = "ConnectionLine"
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.new(0, center.X, 0, center.Y)
	line.Size = UDim2.new(0, distance, 0, isActive and 3 or 2)
	line.Rotation = angle
	line.BackgroundColor3 = isActive and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(50, 50, 65)
	line.BorderSizePixel = 0
	line.ZIndex = 1
	line.Parent = TreeCanvas
end

-- Обновление состояния нижней кнопки LEARN SKILL
local function UpdateLearnButtonState()
	if not selectedNodeId or not currentPlayerData then
		SelectedSkillInfo.Text = "Select a skill node on the tree"
		LearnSkillBtn.Text = "SELECT SKILL"
		LearnSkillBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
		LearnSkillBtn.TextColor3 = Color3.fromRGB(150, 150, 160)
		LearnSkillBtn.AutoButtonColor = false
		return
	end

	local nodeData = SkillTreeConfig.Nodes[selectedNodeId]
	if not nodeData then
		return
	end

	local allocated = currentPlayerData.AllocatedNodes or {}
	local isAllocated = allocated[selectedNodeId] == true
	local hasParent = (nodeData.ParentNode == nil) or (allocated[nodeData.ParentNode] == true)
	local cost = nodeData.Cost or 1
	local canLearn = hasParent and not isAllocated and (currentPlayerData.SkillPoints or 0) >= cost

	SelectedSkillInfo.Text = nodeData.Name .. " (" .. (nodeData.Description or "") .. ")"

	if isAllocated then
		LearnSkillBtn.Text = "LEARNED"
		LearnSkillBtn.BackgroundColor3 = Color3.fromRGB(40, 90, 50)
		LearnSkillBtn.TextColor3 = Color3.fromRGB(150, 255, 180)
		LearnSkillBtn.AutoButtonColor = false
	elseif canLearn then
		LearnSkillBtn.Text = "LEARN (" .. tostring(cost) .. " Pt)"
		LearnSkillBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
		LearnSkillBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		LearnSkillBtn.AutoButtonColor = true
	elseif not hasParent then
		LearnSkillBtn.Text = "LOCKED"
		LearnSkillBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
		LearnSkillBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
		LearnSkillBtn.AutoButtonColor = false
	else
		LearnSkillBtn.Text = "NO POINTS"
		LearnSkillBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 60)
		LearnSkillBtn.TextColor3 = Color3.fromRGB(200, 150, 150)
		LearnSkillBtn.AutoButtonColor = false
	end
end

local function RenderSkillTree(playerData)
	currentPlayerData = playerData

	for _, child in ipairs(TreeCanvas:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextButton") then
			child:Destroy()
		end
	end

	if not playerData then
		return
	end

	PointsLabel.Text = "Points: " .. tostring(playerData.SkillPoints or 0)

	local allocated = playerData.AllocatedNodes or {}
	local nodes = SkillTreeConfig.Nodes

	-- 1. Связывающие линии
	for nodeId, nodeData in pairs(nodes) do
		if nodeData.ParentNode and nodes[nodeData.ParentNode] then
			local parentPos = nodes[nodeData.ParentNode].Position
			local currentPos = nodeData.Position
			local isActive = allocated[nodeId] and allocated[nodeData.ParentNode]
			DrawLine(parentPos, currentPos, isActive)
		end
	end

	-- 2. Интерактивные узлы
	for nodeId, nodeData in pairs(nodes) do
		local isAllocated = allocated[nodeId] == true
		local hasParent = (nodeData.ParentNode == nil) or (allocated[nodeData.ParentNode] == true)
		local canLearn = hasParent and not isAllocated and (playerData.SkillPoints or 0) >= nodeData.Cost
		local isSelected = (selectedNodeId == nodeId)

		local nodeBtn = Instance.new("TextButton")
		nodeBtn.Name = "Node_" .. nodeId
		nodeBtn.AnchorPoint = Vector2.new(0.5, 0.5)
		nodeBtn.Position = UDim2.new(0, nodeData.Position.X, 0, nodeData.Position.Y)
		nodeBtn.Size = UDim2.new(0, 52, 0, 52)
		nodeBtn.Text = ""
		nodeBtn.ZIndex = 2
		nodeBtn.Parent = TreeCanvas

		local nodeCorner = Instance.new("UICorner", nodeBtn)
		nodeCorner.CornerRadius = UDim.new(1, 0)

		local nodeStroke = Instance.new("UIStroke", nodeBtn)
		nodeStroke.Thickness = isSelected and 3.5 or 2

		if isSelected then
			nodeStroke.Color = Color3.fromRGB(255, 215, 0) -- Золотое выделение выбранного узла
		elseif isAllocated then
			nodeStroke.Color = Color3.fromRGB(0, 255, 150)
		elseif canLearn then
			nodeStroke.Color = Color3.fromRGB(0, 220, 255)
		else
			nodeStroke.Color = Color3.fromRGB(70, 70, 85)
		end

		if isAllocated then
			nodeBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
		elseif canLearn then
			nodeBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 180)
		else
			nodeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
		end

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.Text = string.sub(nodeData.Name, 1, 8) .. ".."
		label.Font = Enum.Font.GothamBold
		label.TextSize = 9
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.BackgroundTransparency = 1
		label.Parent = nodeBtn

		-- Наведение мыши — ВСПЛЫВАЮЩИЙ TOOLTIP
		nodeBtn.MouseEnter:Connect(function(x, y)
			TooltipTitle.Text = nodeData.Name
			TooltipDesc.Text = nodeData.Description or ""
			SkillTooltip.Position = UDim2.new(0, x + 15, 0, y + 15)
			SkillTooltip.Visible = true
		end)

		nodeBtn.MouseLeave:Connect(HideTooltip)

		-- КЛИК / ТАП ПО УЗЛУ — ВЫБОР УЗЛА (SELECTION)
		nodeBtn.Activated:Connect(function()
			selectedNodeId = nodeId
			UpdateLearnButtonState()
			RenderSkillTree(currentPlayerData)
		end)
	end

	UpdateLearnButtonState()
end

-- КЛИК ПО НИЖНЕЙ КНОПКЕ LEARN SKILL
LearnSkillBtn.Activated:Connect(function()
	if selectedNodeId and currentPlayerData then
		local nodeData = SkillTreeConfig.Nodes[selectedNodeId]
		if not nodeData then
			return
		end

		local allocated = currentPlayerData.AllocatedNodes or {}
		local isAllocated = allocated[selectedNodeId] == true
		local hasParent = (nodeData.ParentNode == nil) or (allocated[nodeData.ParentNode] == true)
		local cost = nodeData.Cost or 1
		local canLearn = hasParent and not isAllocated and (currentPlayerData.SkillPoints or 0) >= cost

		if canLearn then
			local success, msg = AllocateNodeFunction:InvokeServer(selectedNodeId)
			if success then
				HideTooltip()
			elseif msg then
				warn("[SkillTree] " .. tostring(msg))
			end
		end
	end
end)

-- СБРОС ДРЕВА
ResetTreeBtn.Activated:Connect(function()
	HideTooltip()
	ResetModal.Visible = true
end)

CancelResetBtn.Activated:Connect(function()
	ResetModal.Visible = false
end)

ConfirmResetBtn.Activated:Connect(function()
	local success, msg = ResetSkillTreeFunction:InvokeServer()
	ResetModal.Visible = false
	if success then
		selectedNodeId = nil
		HideTooltip()
	elseif msg then
		warn("[SkillTree Reset] " .. tostring(msg))
	end
end)

-- =================================================================
-- ?? 6. ХОТКЕЙ [K] И ИНИЦИАЛИЗАЦИЯ
-- =================================================================
local function ToggleWindow()
	MainFrame.Visible = not MainFrame.Visible
	HideTooltip()
	ResetModal.Visible = false
	if MainFrame.Visible then
		CenterOnCore()
	end
end

OpenSkillBtn.Activated:Connect(ToggleWindow)
CloseBtn.Activated:Connect(function()
	MainFrame.Visible = false
	HideTooltip()
	ResetModal.Visible = false
end)

local function HandleSkillAction(actionName, inputState, inputObject)
	if inputState == Enum.UserInputState.Begin then
		if UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		ToggleWindow()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("ToggleSkillTreeAction", HandleSkillAction, false, Enum.KeyCode.K)

SyncSkillDataEvent.OnClientEvent:Connect(RenderSkillTree)

task.spawn(function()
	local ClassEvents = ReplicatedStorage:WaitForChild("ClassEvents")
	local GetClassDataFunction = ClassEvents:WaitForChild("GetClassData") :: RemoteFunction
	local data = GetClassDataFunction:InvokeServer()
	if data then
		RenderSkillTree(data)
	end
end)