--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local CombatConfig = require(ReplicatedStorage:WaitForChild("CombatConfig"))
local SkillGemConfig = require(ReplicatedStorage:WaitForChild("SkillGemConfig"))
local CombatNetwork = require(ReplicatedStorage:WaitForChild("CombatNetwork"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Отключение стандартного нижнего хотбара Roblox
task.spawn(function()
	local retries = 0
	while retries < 10 do
		local success = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if success then
			break
		end
		retries += 1
		task.wait(0.2)
	end
end)

--------------------------------------------------------------------------------
-- 1. Стили и цвета (Dark RPG Theme)
--------------------------------------------------------------------------------
local THEME = {
	Bg = Color3.fromRGB(20, 20, 24),
	PanelBg = Color3.fromRGB(28, 28, 35),
	SlotBg = Color3.fromRGB(15, 15, 18),
	Gold = Color3.fromRGB(255, 215, 0),
	TextMain = Color3.fromRGB(240, 240, 245),
	TextMuted = Color3.fromRGB(160, 160, 170),
	Highlight = Color3.fromRGB(45, 45, 55),
	FontBold = Enum.Font.GothamBold,
	FontMedium = Enum.Font.GothamMedium,
}

--------------------------------------------------------------------------------
-- 2. Базовый интерфейс и UIScale
--------------------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CombinedCharacterGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 860, 0, 480)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = THEME.Bg
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = THEME.Gold
mainStroke.Thickness = 2
mainStroke.Parent = mainFrame

local uiScale = Instance.new("UIScale", mainFrame)
local function updateScale()
	local camera = workspace.CurrentCamera
	if camera then
		local viewport = camera.ViewportSize
		local scaleX = viewport.X / (860 + 40)
		local scaleY = viewport.Y / (480 + 40)
		uiScale.Scale = math.clamp(math.min(scaleX, scaleY), 0.40, 1.0)
	end
end
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	updateScale()
end

-- Заголовок и кнопка закрытия
local headerLabel = Instance.new("TextLabel")
headerLabel.Size = UDim2.new(1, -60, 0, 40)
headerLabel.Position = UDim2.new(0, 20, 0, 5)
headerLabel.BackgroundTransparency = 1
headerLabel.Font = THEME.FontBold
headerLabel.TextSize = 18
headerLabel.TextColor3 = THEME.Gold
headerLabel.TextXAlignment = Enum.TextXAlignment.Left
headerLabel.Text = "CHARACTER & EQUIPMENT"
headerLabel.Parent = mainFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -40, 0, 10)
closeBtn.BackgroundColor3 = THEME.PanelBg
closeBtn.Font = THEME.FontBold
closeBtn.Text = "X"
closeBtn.TextColor3 = THEME.TextMain
closeBtn.TextSize = 14
closeBtn.Parent = mainFrame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

--------------------------------------------------------------------------------
-- 3. Левая колонка: Характеристики (Stats Panel)
--------------------------------------------------------------------------------
local statsPanel = Instance.new("Frame")
statsPanel.Size = UDim2.new(0, 250, 1, -65)
statsPanel.Position = UDim2.new(0, 20, 0, 50)
statsPanel.BackgroundColor3 = THEME.PanelBg
statsPanel.BorderSizePixel = 0
statsPanel.Parent = mainFrame
Instance.new("UICorner", statsPanel).CornerRadius = UDim.new(0, 8)

local statsList = Instance.new("UIListLayout")
statsList.Padding = UDim.new(0, 6)
statsList.HorizontalAlignment = Enum.HorizontalAlignment.Center
statsList.Parent = statsPanel

local statsPadding = Instance.new("UIPadding")
statsPadding.PaddingTop = UDim.new(0, 10)
statsPadding.PaddingBottom = UDim.new(0, 10)
statsPadding.PaddingLeft = UDim.new(0, 10)
statsPadding.PaddingRight = UDim.new(0, 10)
statsPadding.Parent = statsPanel

local classLabel = Instance.new("TextLabel")
classLabel.Size = UDim2.new(1, 0, 0, 22)
classLabel.BackgroundTransparency = 1
classLabel.Font = THEME.FontBold
classLabel.TextSize = 15
classLabel.TextColor3 = THEME.Gold
classLabel.Text = "Class: None"
classLabel.Parent = statsPanel

local statLabels: { [string]: TextLabel } = {}
local function createStatRow(id: string, defaultName: string)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 24)
	row.BackgroundColor3 = THEME.SlotBg
	row.BorderSizePixel = 0
	row.Parent = statsPanel
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(0.62, 0, 1, 0)
	nameLbl.Position = UDim2.new(0, 8, 0, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = THEME.FontMedium
	nameLbl.TextSize = 12
	nameLbl.TextColor3 = THEME.TextMuted
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Text = defaultName
	nameLbl.Parent = row

	local valLbl = Instance.new("TextLabel")
	valLbl.Size = UDim2.new(0.38, -12, 1, 0)
	valLbl.Position = UDim2.new(0.62, 0, 0, 0)
	valLbl.BackgroundTransparency = 1
	valLbl.Font = THEME.FontBold
	valLbl.TextSize = 12
	valLbl.TextColor3 = THEME.TextMain
	valLbl.TextXAlignment = Enum.TextXAlignment.Right
	valLbl.Text = "--"
	valLbl.Parent = row

	statLabels[id] = valLbl
end

createStatRow("HP", "Health")
createStatRow("Speed", "WalkSpeed")
createStatRow("STR", "Strength (STR)")
createStatRow("AGI", "Agility (AGI)")
createStatRow("INT", "Intelligence (INT)")
createStatRow("MeleeBonus", "Melee Bonus")
createStatRow("MagicBonus", "Magic Bonus")
createStatRow("CritBonus", "Crit Chance")

--------------------------------------------------------------------------------
-- 4. Центральная колонка: Кукла персонажа (Equip Silhouette)
--------------------------------------------------------------------------------
local dollPanel = Instance.new("Frame")
dollPanel.Name = "DollPanel"
dollPanel.Size = UDim2.new(0, 270, 1, -65)
dollPanel.Position = UDim2.new(0, 285, 0, 50)
dollPanel.BackgroundColor3 = THEME.PanelBg
dollPanel.BorderSizePixel = 0
dollPanel.Parent = mainFrame
Instance.new("UICorner", dollPanel).CornerRadius = UDim.new(0, 8)

local dollTitle = Instance.new("TextLabel")
dollTitle.Size = UDim2.new(1, 0, 0, 24)
dollTitle.Position = UDim2.new(0, 0, 0, 8)
dollTitle.BackgroundTransparency = 1
dollTitle.Font = THEME.FontBold
dollTitle.TextSize = 13
dollTitle.TextColor3 = THEME.Gold
dollTitle.Text = "EQUIPMENT"
dollTitle.Parent = dollPanel

-- Подложка-силуэт куклы
local silhouetteBg = Instance.new("Frame")
silhouetteBg.Size = UDim2.new(0, 100, 0, 220)
silhouetteBg.Position = UDim2.new(0.5, 0, 0.5, 10)
silhouetteBg.AnchorPoint = Vector2.new(0.5, 0.5)
silhouetteBg.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
silhouetteBg.BorderSizePixel = 0
silhouetteBg.Parent = dollPanel
Instance.new("UICorner", silhouetteBg).CornerRadius = UDim.new(0, 20)

type EquipSlotUI = {
	Frame: Frame,
	ItemLabel: TextLabel,
	Stroke: UIStroke,
	SocketIndicator: TextButton?,
}
local equipSlots: { [string]: EquipSlotUI } = {}
local cachedSockets: { [string]: string } = {}

--------------------------------------------------------------------------------
-- 4.1. Система всплывающих подсказок (Tooltips: Hover & Long Press)
--------------------------------------------------------------------------------
local tooltipFrame = Instance.new("Frame")
tooltipFrame.Name = "TooltipFrame"
tooltipFrame.Size = UDim2.new(0, 215, 0, 0)
tooltipFrame.AutomaticSize = Enum.AutomaticSize.Y
tooltipFrame.BackgroundColor3 = THEME.SlotBg
tooltipFrame.BackgroundTransparency = 0.05
tooltipFrame.BorderSizePixel = 0
tooltipFrame.Visible = false
tooltipFrame.ZIndex = 50
tooltipFrame.Parent = screenGui

Instance.new("UICorner", tooltipFrame).CornerRadius = UDim.new(0, 6)

local tooltipStroke = Instance.new("UIStroke")
tooltipStroke.Color = Color3.fromRGB(180, 150, 40)
tooltipStroke.Thickness = 1.5
tooltipStroke.Parent = tooltipFrame

local tooltipPadding = Instance.new("UIPadding")
tooltipPadding.PaddingTop = UDim.new(0, 8)
tooltipPadding.PaddingBottom = UDim.new(0, 8)
tooltipPadding.PaddingLeft = UDim.new(0, 10)
tooltipPadding.PaddingRight = UDim.new(0, 10)
tooltipPadding.Parent = tooltipFrame

local tooltipListLayout = Instance.new("UIListLayout")
tooltipListLayout.SortOrder = Enum.SortOrder.LayoutOrder
tooltipListLayout.Padding = UDim.new(0, 4)
tooltipListLayout.Parent = tooltipFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.LayoutOrder = 1
titleLabel.Size = UDim2.new(1, 0, 0, 0)
titleLabel.AutomaticSize = Enum.AutomaticSize.Y
titleLabel.BackgroundTransparency = 1
titleLabel.Font = THEME.FontBold
titleLabel.TextSize = 13
titleLabel.TextColor3 = THEME.Gold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextWrapped = true
titleLabel.Text = "Item Name"
titleLabel.ZIndex = 51
titleLabel.Parent = tooltipFrame

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Name = "SubtitleLabel"
subtitleLabel.LayoutOrder = 2
subtitleLabel.Size = UDim2.new(1, 0, 0, 0)
subtitleLabel.AutomaticSize = Enum.AutomaticSize.Y
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Font = THEME.FontMedium
subtitleLabel.TextSize = 10
subtitleLabel.TextColor3 = THEME.TextMuted
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
subtitleLabel.TextWrapped = true
subtitleLabel.Text = "Item Subtitle"
subtitleLabel.ZIndex = 51
subtitleLabel.Parent = tooltipFrame

local divider = Instance.new("Frame")
divider.Name = "Divider"
divider.LayoutOrder = 3
divider.Size = UDim2.new(1, 0, 0, 1)
divider.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
divider.BorderSizePixel = 0
divider.ZIndex = 51
divider.Parent = tooltipFrame

local statsContainer = Instance.new("Frame")
statsContainer.Name = "StatsContainer"
statsContainer.LayoutOrder = 4
statsContainer.Size = UDim2.new(1, 0, 0, 0)
statsContainer.AutomaticSize = Enum.AutomaticSize.Y
statsContainer.BackgroundTransparency = 1
statsContainer.ZIndex = 51
statsContainer.Parent = tooltipFrame

local statsList = Instance.new("UIListLayout")
statsList.SortOrder = Enum.SortOrder.LayoutOrder
statsList.Padding = UDim.new(0, 2)
statsList.Parent = statsContainer

local isTooltipVisible = false
local isTooltipPinned = false
local hoverDelayThread: thread? = nil
local suppressNextClick = false

local function positionTooltipNearMouse()
	if not isTooltipVisible or isTooltipPinned then return end
	local mousePos = UserInputService:GetMouseLocation()
	local camera = workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local ttSize = tooltipFrame.AbsoluteSize

	local targetX = mousePos.X + 16
	local targetY = mousePos.Y + 16

	if targetX + ttSize.X > vp.X - 10 then
		targetX = mousePos.X - ttSize.X - 12
	end
	if targetY + ttSize.Y > vp.Y - 10 then
		targetY = mousePos.Y - ttSize.Y - 12
	end

	targetX = math.clamp(targetX, 10, math.max(10, vp.X - ttSize.X - 10))
	targetY = math.clamp(targetY, 10, math.max(10, vp.Y - ttSize.Y - 10))

	tooltipFrame.Position = UDim2.new(0, targetX, 0, targetY)
end

local function positionTooltipNearObject(targetGui: GuiObject)
	local camera = workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local ttSize = tooltipFrame.AbsoluteSize
	local absPos = targetGui.AbsolutePosition
	local absSize = targetGui.AbsoluteSize

	local targetX = absPos.X + (absSize.X - ttSize.X) / 2
	local targetY = absPos.Y - ttSize.Y - 10

	if targetY < 20 then
		targetY = absPos.Y + absSize.Y + 10
	end

	targetX = math.clamp(targetX, 10, math.max(10, vp.X - ttSize.X - 10))
	targetY = math.clamp(targetY, 10, math.max(10, vp.Y - ttSize.Y - 10))

	tooltipFrame.Position = UDim2.new(0, targetX, 0, targetY)
end

local function hideTooltip()
	if hoverDelayThread then
		task.cancel(hoverDelayThread)
		hoverDelayThread = nil
	end
	isTooltipVisible = false
	isTooltipPinned = false
	tooltipFrame.Visible = false
end

local function clearTooltipStats()
	for _, child in ipairs(statsContainer:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function addStatRow(container: Instance, labelText: string, valueText: string, valueColor: Color3?)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 16)
	row.BackgroundTransparency = 1
	row.ZIndex = 52
	row.Parent = container

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.62, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = THEME.FontMedium
	lbl.TextSize = 10
	lbl.TextColor3 = THEME.TextMuted
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = labelText
	lbl.ZIndex = 52
	lbl.Parent = row

	local val = Instance.new("TextLabel")
	val.Size = UDim2.new(0.38, 0, 1, 0)
	val.Position = UDim2.new(0.62, 0, 0, 0)
	val.BackgroundTransparency = 1
	val.Font = THEME.FontBold
	val.TextSize = 10
	val.TextColor3 = valueColor or THEME.TextMain
	val.TextXAlignment = Enum.TextXAlignment.Right
	val.Text = valueText
	val.ZIndex = 52
	val.Parent = row
end

local function addDescriptionRow(container: Instance, text: string, color: Color3?)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 0)
	lbl.AutomaticSize = Enum.AutomaticSize.Y
	lbl.BackgroundTransparency = 1
	lbl.Font = THEME.FontMedium
	lbl.TextSize = 10
	lbl.TextColor3 = color or THEME.TextMuted
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextWrapped = true
	lbl.Text = text
	lbl.ZIndex = 52
	lbl.Parent = container
end

local SLOT_DESCRIPTIONS: { [string]: { Subtitle: string, Description: string } } = {
	Helmet = {
		Subtitle = "Head • Armor",
		Description = "Empty Helmet Slot — Place headwear or armor here to boost resilience and maximum health.",
	},
	Armor = {
		Subtitle = "Torso • Armor",
		Description = "Empty Chest Slot — Place armor or robes here for vital protection and defense.",
	},
	Boots = {
		Subtitle = "Feet • Armor",
		Description = "Empty Boots Slot — Place boots or greaves here to enhance mobility and defense.",
	},
	Weapon = {
		Subtitle = "Main Hand • Weapon",
		Description = "Empty Weapon Slot — Equip a sword, staff, or daggers to activate attacks and abilities.",
	},
	Ring = {
		Subtitle = "Finger • Accessory",
		Description = "Empty Ring Slot — Equip an enchanted ring for combat and attribute bonuses.",
	},
	OffHand = {
		Subtitle = "Off-Hand • Shield / Focus",
		Description = "Empty Off-Hand Slot — Place a shield, tome, or secondary focus here.",
	},
	Amulet = {
		Subtitle = "Neck • Accessory",
		Description = "Empty Amulet Slot — Equip an ancient amulet to channel powerful passive traits.",
	},
}

local function showItemTooltip(tool: Tool, sourceGui: GuiObject, isPinned: boolean?)
	clearTooltipStats()

	local toolName = tool.Name
	local isSkillGem = (tool:GetAttribute("ItemType") == "SkillGem") or (string.sub(toolName, 1, 4) == "Gem_")

	if isSkillGem then
		local gemId = tool:GetAttribute("GemId") or string.sub(toolName, 5)
		local gemData = SkillGemConfig.GetGem(tostring(gemId))
		if gemData then
			titleLabel.Text = gemData.Name
			subtitleLabel.Text = string.format("%s Skill Gem • %s Attribute", gemData.Color, gemData.RequiredAttribute)
			subtitleLabel.TextColor3 = SkillGemConfig.GetColorForGem(gemData.Color)

			addStatRow(statsContainer, "Gem Color", gemData.Color, SkillGemConfig.GetColorForGem(gemData.Color))
			addStatRow(statsContainer, "Required Stat", gemData.RequiredAttribute, THEME.Gold)
			addStatRow(statsContainer, "Cooldown", string.format("%.1fs", gemData.Cooldown), THEME.TextMain)
			addStatRow(statsContainer, "Mana Cost", string.format("%d MP", gemData.ManaCost), Color3.fromRGB(80, 160, 255))
			addStatRow(statsContainer, "Base Damage", tostring(gemData.BaseDamage), THEME.Gold)
			addDescriptionRow(statsContainer, gemData.Description, THEME.TextMain)
			addDescriptionRow(statsContainer, "Click gem in bag to socket into equipment.", THEME.Gold)

			if isPinned then
				addDescriptionRow(statsContainer, "Tap anywhere to close", Color3.fromRGB(130, 130, 145))
			end

			isTooltipVisible = true
			isTooltipPinned = isPinned or false
			tooltipFrame.Visible = true

			if isPinned then
				positionTooltipNearObject(sourceGui)
			else
				positionTooltipNearMouse()
			end
			return
		end
	end

	local profile = CombatConfig.GetWeaponProfile(toolName)
	local isWeapon = (profile ~= CombatConfig.DefaultProfile)
		or (tool:GetAttribute("IsStarterWeapon") == true)
		or (tool:GetAttribute("WeaponType") ~= nil)
		or (tool:GetAttribute("ItemType") == "Weapon")
		or (toolName == "StarterSword" or toolName == "StarterStaff" or toolName == "StarterDaggers")

	titleLabel.Text = toolName

	if isWeapon then
		local category = tool:GetAttribute("Category") or (profile and profile.Category) or tool:GetAttribute("DamageType") or "Melee"
		local subtype = tool:GetAttribute("Subtype") or (profile and profile.Subtype) or tool:GetAttribute("WeaponType") or "Sword"
		local isTwoHanded = false
		if tool:GetAttribute("IsTwoHanded") ~= nil then
			isTwoHanded = tool:GetAttribute("IsTwoHanded") == true
		elseif profile and profile.IsTwoHanded ~= nil then
			isTwoHanded = profile.IsTwoHanded == true
		end

		local subtypeDisplay: string
		if subtype == "Daggers" then
			subtypeDisplay = string.format("Dual Daggers • %s", tostring(category))
		elseif isTwoHanded then
			subtypeDisplay = string.format("Two-Handed %s • %s", tostring(subtype), tostring(category))
		else
			subtypeDisplay = string.format("One-Handed %s • %s", tostring(subtype), tostring(category))
		end
		subtitleLabel.Text = subtypeDisplay

		local baseDmg = tool:GetAttribute("BaseDamage") or profile.BaseDamage
		local atkCd = tool:GetAttribute("AttackCooldown") or profile.AttackCooldown
		local atkRange = tool:GetAttribute("AttackRange") or profile.AttackRange
		local critMult = profile.CritMultiplier
		local scalingStat = tool:GetAttribute("ScalingStat") or (profile and profile.ScalingStat) or "STR"
		local attackPattern = tool:GetAttribute("AttackPattern") or (profile and profile.AttackPattern) or "BoxSlash"

		addStatRow(statsContainer, "Base Damage", tostring(baseDmg), THEME.Gold)
		addStatRow(statsContainer, "Attack Speed", string.format("%.2fs", atkCd), THEME.TextMain)
		addStatRow(statsContainer, "Attack Range", string.format("%.1f st", atkRange), THEME.TextMain)
		addStatRow(statsContainer, "Scaling Stat", tostring(scalingStat), Color3.fromRGB(120, 200, 255))
		addStatRow(statsContainer, "Attack Pattern", tostring(attackPattern), Color3.fromRGB(200, 180, 255))
		addStatRow(statsContainer, "Crit Multiplier", string.format("x%.2f", critMult), Color3.fromRGB(240, 180, 50))

		if tool:GetAttribute("IsStarterWeapon") then
			addDescriptionRow(statsContainer, "Starter Equipment • Soulbound", Color3.fromRGB(150, 150, 165))
		end
	elseif toolName == "ResetTicket" or tool:GetAttribute("ItemType") == "Consumable" then
		subtitleLabel.Text = "Consumable Item"
		if toolName == "ResetTicket" then
			addDescriptionRow(statsContainer, "Used to reset all allocated skill points in the Skill Tree [K].", THEME.TextMain)
			addDescriptionRow(statsContainer, "Consumed upon respec.", THEME.Gold)
		else
			addDescriptionRow(statsContainer, "A consumable item.", THEME.TextMain)
		end
	else
		local equipSlot = tool:GetAttribute("EquipSlot")
		if equipSlot then
			subtitleLabel.Text = string.format("Equipment • %s", tostring(equipSlot))
		else
			subtitleLabel.Text = "Inventory Item"
		end
		addDescriptionRow(statsContainer, "Click to equip or interact.", THEME.TextMuted)
	end

	if isPinned then
		addDescriptionRow(statsContainer, "Tap anywhere to close", Color3.fromRGB(130, 130, 145))
	end

	isTooltipVisible = true
	isTooltipPinned = isPinned or false
	tooltipFrame.Visible = true

	if isPinned then
		positionTooltipNearObject(sourceGui)
		task.defer(function()
			if isTooltipVisible then positionTooltipNearObject(sourceGui) end
		end)
	else
		positionTooltipNearMouse()
		task.defer(function()
			if isTooltipVisible then positionTooltipNearMouse() end
		end)
	end
end

local function showSlotTooltip(slotId: string, slotName: string, sourceGui: GuiObject, isPinned: boolean?)
	local char = player.Character
	local activeTool: Tool? = nil
	if char then
		for _, item in ipairs(char:GetChildren()) do
			if item:IsA("Tool") and item:GetAttribute("ItemType") ~= "SkillGem" and string.sub(item.Name, 1, 4) ~= "Gem_" then
				activeTool = item
				break
			end
		end
	end

	if slotId == "Weapon" then
		if activeTool then
			showItemTooltip(activeTool, sourceGui, isPinned)
			return
		end
	elseif slotId == "OffHand" then
		if activeTool then
			local prof = CombatConfig.GetWeaponProfile(activeTool.Name)
			local is2H = false
			if activeTool:GetAttribute("IsTwoHanded") ~= nil then
				is2H = activeTool:GetAttribute("IsTwoHanded") == true
			elseif prof and prof.IsTwoHanded ~= nil then
				is2H = prof.IsTwoHanded == true
			end

			if is2H then
				clearTooltipStats()
				titleLabel.Text = "OFF-HAND SLOT"
				subtitleLabel.Text = "Off-Hand • Blocked (2H)"
				addDescriptionRow(statsContainer, string.format("This slot is blocked while wielding a two-handed weapon (%s).", activeTool.Name), Color3.fromRGB(235, 75, 75))
				addDescriptionRow(statsContainer, "Unequip your two-handed weapon to place a shield or secondary focus here.", THEME.TextMuted)
				if isPinned then
					addDescriptionRow(statsContainer, "Tap anywhere to close", Color3.fromRGB(130, 130, 145))
				end
				isTooltipVisible = true
				isTooltipPinned = isPinned or false
				tooltipFrame.Visible = true

				if isPinned then
					positionTooltipNearObject(sourceGui)
					task.defer(function()
						if isTooltipVisible then positionTooltipNearObject(sourceGui) end
					end)
				else
					positionTooltipNearMouse()
					task.defer(function()
						if isTooltipVisible then positionTooltipNearMouse() end
					end)
				end
				return
			end
		end
	end

	clearTooltipStats()
	titleLabel.Text = slotName .. " SLOT"

	local slotInfo = SLOT_DESCRIPTIONS[slotId] or {
		Subtitle = "Equipment Slot",
		Description = "Empty equipment slot.",
	}

	subtitleLabel.Text = slotInfo.Subtitle
	addDescriptionRow(statsContainer, slotInfo.Description, THEME.TextMuted)

	local socketedGemId = cachedSockets[slotId]
	if socketedGemId and socketedGemId ~= "" then
		local gemData = SkillGemConfig.GetGem(socketedGemId)
		if gemData then
			addStatRow(statsContainer, "Socketed Gem", gemData.Name, SkillGemConfig.GetColorForGem(gemData.Color))
			addDescriptionRow(statsContainer, string.format("Active Skill: %s • CD: %.1fs • %d MP", gemData.Name, gemData.Cooldown, gemData.ManaCost), SkillGemConfig.GetColorForGem(gemData.Color))
			addDescriptionRow(statsContainer, "Click socket circle to unsocket this gem.", THEME.Gold)
		end
	else
		addStatRow(statsContainer, "Socket", "Empty", Color3.fromRGB(130, 130, 145))
	end

	if isPinned then
		addDescriptionRow(statsContainer, "Tap anywhere to close", Color3.fromRGB(130, 130, 145))
	end

	isTooltipVisible = true
	isTooltipPinned = isPinned or false
	tooltipFrame.Visible = true

	if isPinned then
		positionTooltipNearObject(sourceGui)
		task.defer(function()
			if isTooltipVisible then positionTooltipNearObject(sourceGui) end
		end)
	else
		positionTooltipNearMouse()
		task.defer(function()
			if isTooltipVisible then positionTooltipNearMouse() end
		end)
	end
end

local function attachTooltipListeners(guiObj: GuiObject, onShowTooltip: (isPinned: boolean) -> ())
	-- 1. PC: MouseEnter / MouseLeave
	guiObj.MouseEnter:Connect(function()
		if isTooltipPinned then return end
		if hoverDelayThread then
			task.cancel(hoverDelayThread)
			hoverDelayThread = nil
		end
		hoverDelayThread = task.delay(0.15, function()
			hoverDelayThread = nil
			if not isTooltipPinned and guiObj.Parent ~= nil then
				onShowTooltip(false)
			end
		end)
	end)

	guiObj.MouseLeave:Connect(function()
		if hoverDelayThread then
			task.cancel(hoverDelayThread)
			hoverDelayThread = nil
		end
		if not isTooltipPinned then
			hideTooltip()
		end
	end)

	-- 2. Mobile / Touch: Long Press (0.35s)
	local touchTimerThread: thread? = nil
	local touchMovedFar = false
	local touchStartPos = Vector2.zero

	guiObj.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			touchMovedFar = false
			touchStartPos = Vector2.new(input.Position.X, input.Position.Y)

			if touchTimerThread then
				task.cancel(touchTimerThread)
				touchTimerThread = nil
			end

			touchTimerThread = task.delay(0.35, function()
				touchTimerThread = nil
				if not touchMovedFar and guiObj.Parent ~= nil then
					suppressNextClick = true
					onShowTooltip(true)
				end
			end)
		end
	end)

	guiObj.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			local currentPos = Vector2.new(input.Position.X, input.Position.Y)
			if (currentPos - touchStartPos).Magnitude > 15 then
				touchMovedFar = true
				if touchTimerThread then
					task.cancel(touchTimerThread)
					touchTimerThread = nil
				end
			end
		end
	end)

	guiObj.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			if touchTimerThread then
				task.cancel(touchTimerThread)
				touchTimerThread = nil
			end
		end
	end)
end

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		positionTooltipNearMouse()
	end
end)

UserInputService.InputBegan:Connect(function(input)
	if isTooltipPinned then
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			task.defer(function()
				hideTooltip()
			end)
		end
	end
end)

tooltipFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		hideTooltip()
	end
end)

local function createDollSlot(slotId: string, slotName: string, posX: number, posY: number, width: number?, height: number?)
	local slot = Instance.new("Frame")
	slot.Name = "Slot_" .. slotId
	slot.Size = UDim2.new(0, width or 62, 0, height or 62)
	slot.Position = UDim2.new(posX, 0, posY, 0)
	slot.AnchorPoint = Vector2.new(0.5, 0.5)
	slot.BackgroundColor3 = THEME.SlotBg
	slot.BorderSizePixel = 0
	slot.Parent = dollPanel
	Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 6)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(55, 55, 68)
	stroke.Thickness = 1.5
	stroke.Parent = slot

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, 0, 0, 14)
	titleLbl.Position = UDim2.new(0, 0, 0, 3)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = THEME.FontBold
	titleLbl.TextSize = 9
	titleLbl.TextColor3 = THEME.TextMuted
	titleLbl.Text = slotName
	titleLbl.Parent = slot

	local itemLbl = Instance.new("TextLabel")
	itemLbl.Size = UDim2.new(1, -6, 1, -18)
	itemLbl.Position = UDim2.new(0, 3, 0, 15)
	itemLbl.BackgroundTransparency = 1
	itemLbl.Font = THEME.FontMedium
	itemLbl.TextSize = 10
	itemLbl.TextColor3 = THEME.TextMuted
	itemLbl.TextWrapped = true
	itemLbl.Text = "Empty"
	itemLbl.Parent = slot

	-- Индикатор сокета для камней умений (кружок Red / Green / Blue)
	local socketBtn = Instance.new("TextButton")
	socketBtn.Name = "SocketIndicator"
	socketBtn.Size = UDim2.new(0, 16, 0, 16)
	socketBtn.Position = UDim2.new(1, -4, 1, -4)
	socketBtn.AnchorPoint = Vector2.new(1, 1)
	socketBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	socketBtn.Text = ""
	socketBtn.AutoButtonColor = false
	socketBtn.ZIndex = 6
	socketBtn.Parent = slot

	Instance.new("UICorner", socketBtn).CornerRadius = UDim.new(1, 0)
	local socketStroke = Instance.new("UIStroke")
	socketStroke.Color = Color3.fromRGB(70, 70, 85)
	socketStroke.Thickness = 1.5
	socketStroke.Parent = socketBtn

	equipSlots[slotId] = {
		Frame = slot,
		ItemLabel = itemLbl,
		Stroke = stroke,
		SocketIndicator = socketBtn,
	}

	socketBtn.MouseButton1Click:Connect(function()
		local currentGemId = cachedSockets[slotId]
		if currentGemId and currentGemId ~= "" then
			local socketFunc = CombatNetwork.GetSocketGemFunction()
			if socketFunc then
				pcall(function()
					socketFunc:InvokeServer("Unsocket", slotId)
				end)
			end
		end
	end)

	attachTooltipListeners(slot, function(isPinned)
		showSlotTooltip(slotId, slotName, slot, isPinned)
	end)
end

-- Анатомическое расположение слотов куклы:
-- Центральная ось (X = 0.5): Голова -> Тело -> Ноги
createDollSlot("Helmet",  "HELMET",   0.50, 0.20, 64, 58)
createDollSlot("Armor",   "CHEST",    0.50, 0.44, 68, 64)
createDollSlot("Boots",   "BOOTS",    0.50, 0.76, 64, 58)

-- Левая сторона (рука с оружием + кольцо)
createDollSlot("Weapon",  "WEAPON",   0.18, 0.44, 64, 64)
createDollSlot("Ring",    "RING",     0.18, 0.70, 56, 48)

-- Правая сторона (щит/вторая рука + амулет)
createDollSlot("OffHand", "OFF-HAND", 0.82, 0.44, 64, 64)
createDollSlot("Amulet",  "AMULET",   0.82, 0.22, 56, 48)

--------------------------------------------------------------------------------
-- 5. Правая колонка: Рюкзак (Bag Panel)
--------------------------------------------------------------------------------
local bagPanel = Instance.new("Frame")
bagPanel.Name = "BagPanel"
bagPanel.Size = UDim2.new(0, 270, 1, -65)
bagPanel.Position = UDim2.new(0, 570, 0, 50)
bagPanel.BackgroundColor3 = THEME.PanelBg
bagPanel.BorderSizePixel = 0
bagPanel.Parent = mainFrame
Instance.new("UICorner", bagPanel).CornerRadius = UDim.new(0, 8)

local bagTitle = Instance.new("TextLabel")
bagTitle.Size = UDim2.new(0, 116, 0, 24)
bagTitle.Position = UDim2.new(0, 10, 0, 8)
bagTitle.BackgroundTransparency = 1
bagTitle.Font = THEME.FontBold
bagTitle.TextSize = 12
bagTitle.TextColor3 = THEME.Gold
bagTitle.TextXAlignment = Enum.TextXAlignment.Left
bagTitle.TextTruncate = Enum.TextTruncate.AtEnd
bagTitle.Text = "BAG / BACKPACK"
bagTitle.Parent = bagPanel

--------------------------------------------------------------------------------
-- 5.1. Dropdown фильтрации инвентаря
--------------------------------------------------------------------------------
type CategoryInfo = {
	Id: string,
	Name: string,
}

local CATEGORIES: { CategoryInfo } = {
	{ Id = "ALL", Name = "ALL" },
	{ Id = "WEAPONS", Name = "WEAPONS" },
	{ Id = "ARMOR", Name = "ARMOR" },
	{ Id = "GEMS", Name = "SKILL GEMS" },
	{ Id = "CONSUMABLES", Name = "CONSUMABLES" },
}

local currentFilter = "ALL"
local isDropdownOpen = false

local dropdownBtn = Instance.new("TextButton")
dropdownBtn.Name = "FilterDropdownBtn"
dropdownBtn.Size = UDim2.new(0, 130, 0, 22)
dropdownBtn.Position = UDim2.new(1, -140, 0, 9)
dropdownBtn.BackgroundColor3 = THEME.SlotBg
dropdownBtn.Font = THEME.FontBold
dropdownBtn.TextSize = 10
dropdownBtn.TextColor3 = THEME.Gold
dropdownBtn.Text = "ALL  ▼"
dropdownBtn.AutoButtonColor = false
dropdownBtn.ZIndex = 15
dropdownBtn.Parent = bagPanel

Instance.new("UICorner", dropdownBtn).CornerRadius = UDim.new(0, 4)

local dropdownBtnStroke = Instance.new("UIStroke")
dropdownBtnStroke.Color = Color3.fromRGB(60, 60, 75)
dropdownBtnStroke.Thickness = 1
dropdownBtnStroke.Parent = dropdownBtn

local dropdownList = Instance.new("Frame")
dropdownList.Name = "FilterDropdownList"
dropdownList.Size = UDim2.new(0, 130, 0, 0)
dropdownList.Position = UDim2.new(1, -140, 0, 34)
dropdownList.BackgroundColor3 = THEME.PanelBg
dropdownList.BorderSizePixel = 0
dropdownList.ClipsDescendants = true
dropdownList.Visible = false
dropdownList.ZIndex = 25
dropdownList.Parent = bagPanel

Instance.new("UICorner", dropdownList).CornerRadius = UDim.new(0, 4)

local dropdownListStroke = Instance.new("UIStroke")
dropdownListStroke.Color = Color3.fromRGB(60, 60, 75)
dropdownListStroke.Thickness = 1
dropdownListStroke.Parent = dropdownList

local dropListLayout = Instance.new("UIListLayout")
dropListLayout.Padding = UDim.new(0, 2)
dropListLayout.SortOrder = Enum.SortOrder.LayoutOrder
dropListLayout.Parent = dropdownList

local dropPadding = Instance.new("UIPadding")
dropPadding.PaddingTop = UDim.new(0, 3)
dropPadding.PaddingBottom = UDim.new(0, 3)
dropPadding.PaddingLeft = UDim.new(0, 3)
dropPadding.PaddingRight = UDim.new(0, 3)
dropPadding.Parent = dropdownList

local emptyCategoryLabel = Instance.new("TextLabel")
emptyCategoryLabel.Name = "EmptyCategoryLabel"
emptyCategoryLabel.Size = UDim2.new(1, -20, 0, 40)
emptyCategoryLabel.Position = UDim2.new(0.5, 0, 0.5, 10)
emptyCategoryLabel.AnchorPoint = Vector2.new(0.5, 0.5)
emptyCategoryLabel.BackgroundTransparency = 1
emptyCategoryLabel.Font = THEME.FontMedium
emptyCategoryLabel.TextSize = 12
emptyCategoryLabel.TextColor3 = THEME.TextMuted
emptyCategoryLabel.TextWrapped = true
emptyCategoryLabel.Text = "No items in this category"
emptyCategoryLabel.Visible = false
emptyCategoryLabel.ZIndex = 5
emptyCategoryLabel.Parent = bagPanel

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -20, 1, -45)
scrollFrame.Position = UDim2.new(0, 10, 0, 36)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = THEME.Gold
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = bagPanel

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0, 54, 0, 54)
grid.CellPadding = UDim2.new(0, 8, 0, 8)
grid.SortOrder = Enum.SortOrder.Name
grid.Parent = scrollFrame

local refreshInventory: () -> ()

local function updateDropdownButtonText()
	local arrow = isDropdownOpen and "▲" or "▼"
	dropdownBtn.Text = string.format("%s  %s", currentFilter, arrow)
end

local function toggleDropdown(forceState: boolean?)
	local shouldOpen = if forceState ~= nil then forceState else not isDropdownOpen
	if isDropdownOpen == shouldOpen then return end
	isDropdownOpen = shouldOpen

	updateDropdownButtonText()

	local targetHeight = #CATEGORIES * 24 + 4
	if shouldOpen then
		dropdownList.Visible = true
		dropdownList.Size = UDim2.new(0, 130, 0, 0)
		local tween = TweenService:Create(
			dropdownList,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.new(0, 130, 0, targetHeight) }
		)
		tween:Play()
	else
		local tween = TweenService:Create(
			dropdownList,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Size = UDim2.new(0, 130, 0, 0) }
		)
		tween:Play()
		tween.Completed:Connect(function()
			if not isDropdownOpen then
				dropdownList.Visible = false
			end
		end)
	end
end

dropdownBtn.MouseEnter:Connect(function()
	dropdownBtn.BackgroundColor3 = THEME.Highlight
	dropdownBtnStroke.Color = THEME.Gold
end)

dropdownBtn.MouseLeave:Connect(function()
	dropdownBtn.BackgroundColor3 = THEME.SlotBg
	dropdownBtnStroke.Color = Color3.fromRGB(60, 60, 75)
end)

dropdownBtn.MouseButton1Click:Connect(function()
	toggleDropdown()
end)

local categoryButtons: { [string]: TextButton } = {}

local function updateCategoryButtonsUI()
	for id, btn in pairs(categoryButtons) do
		local isSelected = (id == currentFilter)
		btn.BackgroundColor3 = isSelected and THEME.Highlight or THEME.SlotBg
		btn.TextColor3 = isSelected and THEME.Gold or THEME.TextMuted
		btn.Font = isSelected and THEME.FontBold or THEME.FontMedium
	end
end

for i, cat in ipairs(CATEGORIES) do
	local btn = Instance.new("TextButton")
	btn.Name = "Category_" .. cat.Id
	btn.LayoutOrder = i
	btn.Size = UDim2.new(1, 0, 0, 22)
	btn.BackgroundColor3 = (cat.Id == currentFilter) and THEME.Highlight or THEME.SlotBg
	btn.Font = (cat.Id == currentFilter) and THEME.FontBold or THEME.FontMedium
	btn.TextSize = 10
	btn.TextColor3 = (cat.Id == currentFilter) and THEME.Gold or THEME.TextMuted
	btn.Text = cat.Name
	btn.AutoButtonColor = false
	btn.ZIndex = 26
	btn.Parent = dropdownList

	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

	btn.MouseEnter:Connect(function()
		if cat.Id ~= currentFilter then
			btn.BackgroundColor3 = THEME.Highlight
			btn.TextColor3 = THEME.TextMain
		end
	end)

	btn.MouseLeave:Connect(function()
		if cat.Id ~= currentFilter then
			btn.BackgroundColor3 = THEME.SlotBg
			btn.TextColor3 = THEME.TextMuted
		else
			btn.BackgroundColor3 = THEME.Highlight
			btn.TextColor3 = THEME.Gold
		end
	end)

	btn.MouseButton1Click:Connect(function()
		currentFilter = cat.Id
		updateCategoryButtonsUI()
		toggleDropdown(false)
		refreshInventory()
	end)

	categoryButtons[cat.Id] = btn
end

--------------------------------------------------------------------------------
-- 6. Логика обновления характеристик и экипировки
--------------------------------------------------------------------------------
local function updateStatsUI()
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	statLabels["HP"].Text = string.format("%d / %d", math.floor(hum.Health), math.floor(hum.MaxHealth))
	statLabels["Speed"].Text = tostring(math.floor(hum.WalkSpeed))
	statLabels["STR"].Text = tostring(char:GetAttribute("TotalSTR") or 0)
	statLabels["AGI"].Text = tostring(char:GetAttribute("TotalAGI") or 0)
	statLabels["INT"].Text = tostring(char:GetAttribute("TotalINT") or 0)

	statLabels["MeleeBonus"].Text = string.format("+%d%%", char:GetAttribute("BonusMeleeDamage") or 0)
	statLabels["MagicBonus"].Text = string.format("+%d%%", char:GetAttribute("BonusMagicDamage") or 0)
	statLabels["CritBonus"].Text = string.format("+%d%%", char:GetAttribute("BonusCritChance") or 0)
end

local function matchesFilter(tool: Tool, filter: string): boolean
	if filter == "ALL" then
		return true
	end

	local itemTypeAttr = tool:GetAttribute("ItemType")
	local equipSlotAttr = tool:GetAttribute("EquipSlot")
	local toolName = tool.Name

	if filter == "WEAPONS" then
		if itemTypeAttr == "Weapon" then
			return true
		end
		if tool:GetAttribute("IsStarterWeapon") == true then
			return true
		end
		if tool:GetAttribute("WeaponType") ~= nil then
			return true
		end
		if CombatConfig and CombatConfig.Weapons and CombatConfig.Weapons[toolName] ~= nil then
			return true
		end
		if toolName == "StarterSword" or toolName == "StarterStaff" or toolName == "StarterDaggers" then
			return true
		end
		local lowerName = string.lower(toolName)
		if string.find(lowerName, "sword") or string.find(lowerName, "staff") or string.find(lowerName, "dagger")
			or string.find(lowerName, "bow") or string.find(lowerName, "axe") or string.find(lowerName, "mace")
			or string.find(lowerName, "wand") or string.find(lowerName, "blade") or string.find(lowerName, "spear") then
			return true
		end
		return false

	elseif filter == "ARMOR" then
		if itemTypeAttr == "Armor" or itemTypeAttr == "Equipment" then
			return true
		end
		if equipSlotAttr and (equipSlotAttr == "Helmet" or equipSlotAttr == "Armor" or equipSlotAttr == "Chest"
			or equipSlotAttr == "Boots" or equipSlotAttr == "Ring" or equipSlotAttr == "Amulet" or equipSlotAttr == "OffHand" or equipSlotAttr == "Shield") then
			return true
		end
		local lowerName = string.lower(toolName)
		if string.find(lowerName, "helmet") or string.find(lowerName, "helm") or string.find(lowerName, "armor")
			or string.find(lowerName, "chest") or string.find(lowerName, "boots") or string.find(lowerName, "shield")
			or string.find(lowerName, "ring") or string.find(lowerName, "amulet") or string.find(lowerName, "necklace")
			or string.find(lowerName, "robe") or string.find(lowerName, "plate") or string.find(lowerName, "cap")
			or string.find(lowerName, "cuirass") or string.find(lowerName, "greaves") then
			return true
		end
		return false

	elseif filter == "GEMS" then
		if itemTypeAttr == "SkillGem" or string.sub(toolName, 1, 4) == "Gem_" then
			return true
		end
		return false

	elseif filter == "CONSUMABLES" then
		if itemTypeAttr == "Consumable" or itemTypeAttr == "Potion" or itemTypeAttr == "Scroll" then
			return true
		end
		if toolName == "ResetTicket" then
			return true
		end
		local lowerName = string.lower(toolName)
		if string.find(lowerName, "ticket") or string.find(lowerName, "potion") or string.find(lowerName, "scroll")
			or string.find(lowerName, "elixir") or string.find(lowerName, "flask") or string.find(lowerName, "food")
			or string.find(lowerName, "herb") or string.find(lowerName, "bandage") then
			return true
		end
		return false
	end

	return false
end

local activeSocketModal: Frame? = nil

local function closeSocketModal()
	if activeSocketModal then
		activeSocketModal:Destroy()
		activeSocketModal = nil
	end
end

-- Объявление функции обновления Action Bar HUD
local updateActionBarHUD: () -> ()

local function updateSocketsUI()
	for slotId, slotUI in pairs(equipSlots) do
		if slotUI.SocketIndicator then
			local gemId = cachedSockets[slotId]
			local gemData = if gemId and gemId ~= "" then SkillGemConfig.GetGem(gemId) else nil
			local socketStroke = slotUI.SocketIndicator:FindFirstChildOfClass("UIStroke")

			if gemData then
				slotUI.SocketIndicator.BackgroundColor3 = SkillGemConfig.GetColorForGem(gemData.Color)
				if socketStroke then
					socketStroke.Color = Color3.fromRGB(255, 255, 255)
					socketStroke.Thickness = 2
				end
			else
				slotUI.SocketIndicator.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
				if socketStroke then
					socketStroke.Color = Color3.fromRGB(65, 65, 80)
					socketStroke.Thickness = 1.5
				end
			end
		end
	end

	if updateActionBarHUD then
		updateActionBarHUD()
	end
end

local function syncSocketsFromAttributes()
	local jsonStr = player:GetAttribute("SocketedGemsJSON")
	if typeof(jsonStr) == "string" and jsonStr ~= "" then
		local ok, data = pcall(function()
			return HttpService:JSONDecode(jsonStr)
		end)
		if ok and type(data) == "table" then
			table.clear(cachedSockets)
			for slot, gId in pairs(data) do
				if type(gId) == "string" then
					cachedSockets[slot] = gId
				end
			end
			updateSocketsUI()
			return
		end
	end

	local slots = { "Weapon", "Armor", "Helmet", "OffHand", "Boots", "Amulet", "Ring" }
	local changed = false
	for _, sName in ipairs(slots) do
		local val = player:GetAttribute("Socket_" .. sName)
		if typeof(val) == "string" and val ~= "" then
			if cachedSockets[sName] ~= val then
				cachedSockets[sName] = val
				changed = true
			end
		else
			if cachedSockets[sName] ~= nil then
				cachedSockets[sName] = nil
				changed = true
			end
		end
	end
	if changed then
		updateSocketsUI()
	end
end

player.AttributeChanged:Connect(function(attr)
	if attr == "SocketedGemsJSON" or string.sub(attr, 1, 7) == "Socket_" then
		syncSocketsFromAttributes()
	end
end)

task.spawn(function()
	local syncSocketsEvent = CombatNetwork.GetSyncSocketsEvent()
	if syncSocketsEvent then
		syncSocketsEvent.OnClientEvent:Connect(function(socketsData)
			if type(socketsData) == "table" then
				table.clear(cachedSockets)
				for slot, sVal in pairs(socketsData) do
					local gId = if type(sVal) == "table" then sVal.GemId else tostring(sVal)
					if gId and gId ~= "" then
						cachedSockets[slot] = gId
					end
				end
				updateSocketsUI()
			end
		end)
	end
end)

local function showSocketGemModal(gemTool: Tool, gemData: SkillGemConfig.SkillGemData)
	closeSocketModal()

	local modal = Instance.new("Frame")
	modal.Name = "SocketGemModal"
	modal.Size = UDim2.new(0, 360, 0, 320)
	modal.Position = UDim2.new(0.5, 0, 0.5, 0)
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.BackgroundColor3 = THEME.Bg
	modal.BorderSizePixel = 0
	modal.ZIndex = 60
	modal.Parent = mainFrame

	Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 10)
	local modalStroke = Instance.new("UIStroke")
	modalStroke.Color = SkillGemConfig.GetColorForGem(gemData.Color)
	modalStroke.Thickness = 2
	modalStroke.Parent = modal

	local mTitle = Instance.new("TextLabel")
	mTitle.Size = UDim2.new(1, -20, 0, 26)
	mTitle.Position = UDim2.new(0, 10, 0, 8)
	mTitle.BackgroundTransparency = 1
	mTitle.Font = THEME.FontBold
	mTitle.TextSize = 14
	mTitle.TextColor3 = SkillGemConfig.GetColorForGem(gemData.Color)
	mTitle.Text = string.format("SOCKET GEM: %s", gemData.Name)
	mTitle.ZIndex = 61
	mTitle.Parent = modal

	local mSub = Instance.new("TextLabel")
	mSub.Size = UDim2.new(1, -20, 0, 18)
	mSub.Position = UDim2.new(0, 10, 0, 34)
	mSub.BackgroundTransparency = 1
	mSub.Font = THEME.FontMedium
	mSub.TextSize = 11
	mSub.TextColor3 = THEME.TextMuted
	mSub.Text = "Select an equipment slot to insert this gem into:"
	mSub.ZIndex = 61
	mSub.Parent = modal

	local slotListContainer = Instance.new("Frame")
	slotListContainer.Size = UDim2.new(1, -20, 0, 215)
	slotListContainer.Position = UDim2.new(0, 10, 0, 56)
	slotListContainer.BackgroundTransparency = 1
	slotListContainer.ZIndex = 61
	slotListContainer.Parent = modal

	local sList = Instance.new("UIListLayout")
	sList.Padding = UDim.new(0, 6)
	sList.Parent = slotListContainer

	local socketableSlots = { "Weapon", "Armor", "Helmet", "OffHand", "Boots" }
	local slotDisplayNames = {
		Weapon = "WEAPON (Main Hand)",
		Armor = "CHEST (Armor)",
		Helmet = "HELMET (Head)",
		OffHand = "OFF-HAND (Shield/Focus)",
		Boots = "BOOTS (Feet)",
	}

	for _, slotId in ipairs(socketableSlots) do
		local slotBtn = Instance.new("TextButton")
		slotBtn.Name = "SocketSlotBtn_" .. slotId
		slotBtn.Size = UDim2.new(1, 0, 0, 34)
		slotBtn.BackgroundColor3 = THEME.PanelBg
		slotBtn.AutoButtonColor = false
		slotBtn.Text = ""
		slotBtn.ZIndex = 62
		slotBtn.Parent = slotListContainer

		Instance.new("UICorner", slotBtn).CornerRadius = UDim.new(0, 6)
		local sStroke = Instance.new("UIStroke")
		sStroke.Color = Color3.fromRGB(55, 55, 68)
		sStroke.Thickness = 1
		sStroke.Parent = slotBtn

		local currentGemId = cachedSockets[slotId]
		local currentGem = if currentGemId and currentGemId ~= "" then SkillGemConfig.GetGem(currentGemId) else nil

		local slotNameLbl = Instance.new("TextLabel")
		slotNameLbl.Size = UDim2.new(0.55, 0, 1, 0)
		slotNameLbl.Position = UDim2.new(0, 10, 0, 0)
		slotNameLbl.BackgroundTransparency = 1
		slotNameLbl.Font = THEME.FontBold
		slotNameLbl.TextSize = 11
		slotNameLbl.TextColor3 = THEME.TextMain
		slotNameLbl.TextXAlignment = Enum.TextXAlignment.Left
		slotNameLbl.Text = slotDisplayNames[slotId] or slotId
		slotNameLbl.ZIndex = 63
		slotNameLbl.Parent = slotBtn

		local statusLbl = Instance.new("TextLabel")
		statusLbl.Size = UDim2.new(0.42, 0, 1, 0)
		statusLbl.Position = UDim2.new(0.56, 0, 0, 0)
		statusLbl.BackgroundTransparency = 1
		statusLbl.Font = THEME.FontMedium
		statusLbl.TextSize = 10
		statusLbl.TextXAlignment = Enum.TextXAlignment.Right
		statusLbl.ZIndex = 63
		statusLbl.Parent = slotBtn

		if currentGem then
			statusLbl.TextColor3 = SkillGemConfig.GetColorForGem(currentGem.Color)
			statusLbl.Text = string.format("[%s] (Replaces)", currentGem.Name)
		else
			statusLbl.TextColor3 = Color3.fromRGB(120, 220, 140)
			statusLbl.Text = "[Empty Socket]"
		end

		slotBtn.MouseEnter:Connect(function()
			slotBtn.BackgroundColor3 = THEME.Highlight
			sStroke.Color = THEME.Gold
		end)
		slotBtn.MouseLeave:Connect(function()
			slotBtn.BackgroundColor3 = THEME.PanelBg
			sStroke.Color = Color3.fromRGB(55, 55, 68)
		end)

		slotBtn.MouseButton1Click:Connect(function()
			local socketFunc = CombatNetwork.GetSocketGemFunction()
			if socketFunc then
				local ok, msg, newSockets = socketFunc:InvokeServer("Socket", slotId, gemData.Id)
				if ok and type(newSockets) == "table" then
					table.clear(cachedSockets)
					for s, v in pairs(newSockets) do
						local gid = if type(v) == "table" then v.GemId else tostring(v)
						if gid and gid ~= "" then cachedSockets[s] = gid end
					end
				end
			end
			closeSocketModal()
			refreshInventory()
			updateSocketsUI()
		end)
	end

	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Size = UDim2.new(1, -20, 0, 24)
	cancelBtn.Position = UDim2.new(0, 10, 1, -28)
	cancelBtn.BackgroundColor3 = THEME.PanelBg
	cancelBtn.Font = THEME.FontBold
	cancelBtn.TextSize = 11
	cancelBtn.TextColor3 = THEME.TextMuted
	cancelBtn.Text = "CANCEL"
	cancelBtn.ZIndex = 62
	cancelBtn.Parent = modal
	Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 6)

	cancelBtn.MouseButton1Click:Connect(closeSocketModal)

	activeSocketModal = modal
end

refreshInventory = function()
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("GuiObject") and not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end

	local char = player.Character
	local bp = player:FindFirstChildOfClass("Backpack")

	-- Поиск экипированного оружия в руках персонажа (исключая камни умений SkillGem)
	local activeTool: Tool? = nil
	if char then
		for _, item in ipairs(char:GetChildren()) do
			if item:IsA("Tool") and item:GetAttribute("ItemType") ~= "SkillGem" and string.sub(item.Name, 1, 4) ~= "Gem_" then
				activeTool = item
				break
			end
		end
	end

	-- Подсветка слота WEAPON на кукле при взятии оружия в руки (всегда актуальна)
	local isTwoHanded = false
	if activeTool then
		equipSlots["Weapon"].ItemLabel.Text = activeTool.Name
		equipSlots["Weapon"].ItemLabel.TextColor3 = THEME.Gold
		equipSlots["Weapon"].Stroke.Color = Color3.fromRGB(180, 150, 40)

		local profile = CombatConfig.GetWeaponProfile(activeTool.Name)
		if activeTool:GetAttribute("IsTwoHanded") ~= nil then
			isTwoHanded = activeTool:GetAttribute("IsTwoHanded") == true
		elseif profile and profile.IsTwoHanded ~= nil then
			isTwoHanded = profile.IsTwoHanded == true
		end
	else
		equipSlots["Weapon"].ItemLabel.Text = "Empty"
		equipSlots["Weapon"].ItemLabel.TextColor3 = THEME.TextMuted
		equipSlots["Weapon"].Stroke.Color = Color3.fromRGB(55, 55, 68)
	end

	-- Если экипирован двуручный инструмент (IsTwoHanded == true), слот OFF-HAND отображает статус Blocked (2H)
	if isTwoHanded then
		equipSlots["OffHand"].ItemLabel.Text = "Blocked (2H)"
		equipSlots["OffHand"].ItemLabel.TextColor3 = Color3.fromRGB(235, 75, 75)
		equipSlots["OffHand"].Stroke.Color = Color3.fromRGB(140, 45, 45)
	else
		equipSlots["OffHand"].ItemLabel.Text = "Empty"
		equipSlots["OffHand"].ItemLabel.TextColor3 = THEME.TextMuted
		equipSlots["OffHand"].Stroke.Color = Color3.fromRGB(55, 55, 68)
	end

	-- Обновляем индикаторы сокетов на кукле
	updateSocketsUI()

	local allTools: { Tool } = {}
	if bp then
		for _, item in ipairs(bp:GetChildren()) do
			if item:IsA("Tool") then table.insert(allTools, item) end
		end
	end
	if activeTool then
		table.insert(allTools, activeTool)
	end

	-- Фильтрация списка предметов по выбранной категории
	local filteredTools: { Tool } = {}
	for _, tool in ipairs(allTools) do
		if matchesFilter(tool, currentFilter) then
			table.insert(filteredTools, tool)
		end
	end

	if #filteredTools == 0 then
		emptyCategoryLabel.Visible = true
	else
		emptyCategoryLabel.Visible = false
	end

	for _, tool in ipairs(filteredTools) do
		local isSkillGem = (tool:GetAttribute("ItemType") == "SkillGem") or (string.sub(tool.Name, 1, 4) == "Gem_")
		local gemId = if isSkillGem then (tool:GetAttribute("GemId") or string.sub(tool.Name, 5)) else nil
		local gemData = if gemId then SkillGemConfig.GetGem(tostring(gemId)) else nil

		local btn = Instance.new("TextButton")
		btn.Name = tool.Name
		btn.BackgroundColor3 = (tool == activeTool) and THEME.Highlight or THEME.SlotBg
		btn.Font = THEME.FontMedium
		btn.TextSize = 11
		btn.TextWrapped = true

		if gemData then
			btn.TextColor3 = SkillGemConfig.GetColorForGem(gemData.Color)
			btn.Text = string.format("◆ %s\n(%s)", gemData.Name, gemData.Color)
		else
			btn.TextColor3 = (tool == activeTool) and THEME.Gold or THEME.TextMain
			btn.Text = tool.Name
		end

		btn.Parent = scrollFrame
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

		if gemData then
			local stroke = Instance.new("UIStroke")
			stroke.Color = SkillGemConfig.GetColorForGem(gemData.Color)
			stroke.Thickness = 1.5
			stroke.Parent = btn
		elseif tool == activeTool then
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(180, 150, 40)
			stroke.Thickness = 1.5
			stroke.Parent = btn
		end

		attachTooltipListeners(btn, function(isPinned)
			showItemTooltip(tool, btn, isPinned)
		end)

		btn.MouseButton1Click:Connect(function()
			if suppressNextClick then
				suppressNextClick = false
				return
			end

			hideTooltip()

			if gemData then
				showSocketGemModal(tool, gemData)
				return
			end

			local humanoid = char and char:FindFirstChildOfClass("Humanoid")
			if not humanoid then return end

			if tool.Parent == char then
				humanoid:UnequipTools()
			else
				humanoid:EquipTool(tool)
			end
			task.wait(0.05)
			refreshInventory()
			updateStatsUI()
		end)
	end
end

--------------------------------------------------------------------------------
-- 7. Подключение слушателей персонажа и рюкзака
--------------------------------------------------------------------------------
local backpackAddedConn: RBXScriptConnection? = nil
local backpackRemovedConn: RBXScriptConnection? = nil

local function hookBackpack(bp: Backpack)
	if backpackAddedConn then
		backpackAddedConn:Disconnect()
		backpackAddedConn = nil
	end
	if backpackRemovedConn then
		backpackRemovedConn:Disconnect()
		backpackRemovedConn = nil
	end

	backpackAddedConn = bp.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then
			refreshInventory()
			updateStatsUI()
			task.defer(function()
				refreshInventory()
				updateStatsUI()
			end)
		end
	end)

	backpackRemovedConn = bp.ChildRemoved:Connect(function(c)
		if c:IsA("Tool") then
			refreshInventory()
			updateStatsUI()
			task.defer(function()
				refreshInventory()
				updateStatsUI()
			end)
		end
	end)
end

local function hookCharacter(char: Model)
	-- Слушатели предметов на персонаже подключаются сразу (не блокируются ожиданием Humanoid)
	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then
			refreshInventory()
			updateStatsUI()
			task.defer(function()
				refreshInventory()
				updateStatsUI()
			end)
		end
	end)

	char.ChildRemoved:Connect(function(c)
		if c:IsA("Tool") then
			refreshInventory()
			updateStatsUI()
			task.defer(function()
				refreshInventory()
				updateStatsUI()
			end)
		end
	end)

	char.AttributeChanged:Connect(function()
		updateStatsUI()
		refreshInventory()
	end)

	-- Подключение слушателей Backpack (существующего или ожидаемого)
	local bp = player:FindFirstChildOfClass("Backpack")
	if bp then
		hookBackpack(bp)
	else
		task.spawn(function()
			local waitedBp = player:WaitForChild("Backpack", 5) :: Backpack?
			if waitedBp and waitedBp:IsA("Backpack") then
				hookBackpack(waitedBp)
				refreshInventory()
				updateStatsUI()
			end
		end)
	end

	-- Подключение слушателей Humanoid в отдельном потоке без блокировки
	task.spawn(function()
		local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
		if hum and char.Parent then
			hum.HealthChanged:Connect(updateStatsUI)
			hum:GetPropertyChangedSignal("MaxHealth"):Connect(updateStatsUI)
			hum:GetPropertyChangedSignal("WalkSpeed"):Connect(updateStatsUI)
			updateStatsUI()
		end
	end)

	updateStatsUI()
	refreshInventory()

	-- Синхронизация при спавне с учетом задержки StarterCharacter и автоэкипировки в WeaponService
	task.defer(function()
		refreshInventory()
		updateStatsUI()
	end)
	task.delay(0.1, function()
		refreshInventory()
		updateStatsUI()
	end)
	task.delay(0.2, function()
		refreshInventory()
		updateStatsUI()
	end)
	task.delay(0.35, function()
		refreshInventory()
		updateStatsUI()
	end)
end

player.ChildAdded:Connect(function(child)
	if child:IsA("Backpack") then
		hookBackpack(child)
		refreshInventory()
		updateStatsUI()
	end
end)

player.CharacterAdded:Connect(hookCharacter)
if player.Character then
	task.spawn(function() hookCharacter(player.Character) end)
end

-- Надежное получение и синхронизация выбранного класса
local function updateClassLabel(className: string?)
	if className and className ~= "None" and className ~= "" then
		classLabel.Text = "Class: " .. tostring(className)
	else
		classLabel.Text = "Class: None"
	end
end

-- Метод 1: Проверка атрибутов персонажа и игрока
local function checkClassFromAttributes()
	local char = player.Character
	local foundClass = (char and (char:GetAttribute("Class") or char:GetAttribute("SelectedClass")))
		or player:GetAttribute("Class")
		or player:GetAttribute("SelectedClass")

	if foundClass and foundClass ~= "" then
		updateClassLabel(foundClass)
		return foundClass ~= "None"
	else
		updateClassLabel("None")
	end
	return false
end

-- Слушаем установку атрибутов в реальном времени
player.AttributeChanged:Connect(checkClassFromAttributes)

local function hookCharAttributes(char: Model)
	char.AttributeChanged:Connect(checkClassFromAttributes)
	checkClassFromAttributes()
end

player.CharacterAdded:Connect(hookCharAttributes)
if player.Character then
	task.spawn(function() hookCharAttributes(player.Character) end)
end

-- Метод 2: Слушатель сетевых событий (поддержка любого имени: SyncClassDataEvent или SyncClassData)
task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("ClassEvents", 5) :: Folder?
	if not folder then return end

	local syncEvent = folder:FindFirstChild("SyncClassDataEvent") or folder:FindFirstChild("SyncClassData")
	if not syncEvent then
		syncEvent = folder:WaitForChild("SyncClassDataEvent", 3) or folder:WaitForChild("SyncClassData", 3)
	end

	if syncEvent and syncEvent:IsA("RemoteEvent") then
		syncEvent.OnClientEvent:Connect(function(data: any)
			if type(data) == "table" and data.SelectedClass then
				updateClassLabel(data.SelectedClass)
			elseif type(data) == "string" then
				updateClassLabel(data)
			end
		end)
	end

	-- Метод 3: Опрос RemoteFunction с защитой от подвисания
	local getFunc = folder:FindFirstChild("GetClassDataFunction") or folder:FindFirstChild("GetClassData") or folder:FindFirstChild("SelectClass")
	if getFunc and getFunc:IsA("RemoteFunction") then
		for _ = 1, 12 do
			if checkClassFromAttributes() then break end

			local ok, res = pcall(function()
				return (getFunc :: RemoteFunction):InvokeServer()
			end)

			if ok and res then
				local cls = (type(res) == "table" and res.SelectedClass) or (type(res) == "string" and res)
				if cls and cls ~= "None" and cls ~= "" then
					updateClassLabel(cls)
					break
				end
			end
			task.wait(0.5)
		end
	end
end)

--------------------------------------------------------------------------------
-- 8. Открытие/закрытие окна и HUD кнопка
--------------------------------------------------------------------------------
local function toggleWindow()
	mainFrame.Visible = not mainFrame.Visible
	if mainFrame.Visible then
		updateStatsUI()
		refreshInventory()
	else
		toggleDropdown(false)
		hideTooltip()
	end
end

closeBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	toggleDropdown(false)
	hideTooltip()
end)

local function handleAction(actionName: string, inputState: Enum.UserInputState, inputObject: InputObject): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end

	toggleWindow()
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("ToggleCombinedCharacter", handleAction, false, Enum.KeyCode.B, Enum.KeyCode.C)

local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local btnSize = isTouch and 44 or 58
local gap = isTouch and 8 or 10
local baseY = isTouch and 60 or 120
local index = 0

local hudBtn = Instance.new("TextButton")
hudBtn.Name = "CharacterHUDBtn"
hudBtn.AnchorPoint = Vector2.new(0, 0)
hudBtn.ZIndex = 10
hudBtn.Size = UDim2.new(0, btnSize, 0, btnSize)
hudBtn.Position = UDim2.new(0.015, 0, 0, baseY + index * (btnSize + gap))
hudBtn.BackgroundColor3 = THEME.Bg
hudBtn.Font = THEME.FontBold
hudBtn.TextSize = isTouch and 10 or 12
hudBtn.TextColor3 = THEME.Gold
hudBtn.Text = isTouch and "HERO" or "HERO\n[C]"
hudBtn.Parent = screenGui

Instance.new("UICorner", hudBtn).CornerRadius = UDim.new(0, 8)

local hudStroke = Instance.new("UIStroke")
hudStroke.Color = Color3.fromRGB(60, 60, 75)
hudStroke.Thickness = 2
hudStroke.Parent = hudBtn

hudBtn.Activated:Connect(toggleWindow)

--------------------------------------------------------------------------------
-- 9. Панель активных умений на экране (Action Bar HUD)
--------------------------------------------------------------------------------
type ActionBarSlotUI = {
	Button: TextButton,
	Stroke: UIStroke,
	HotkeyLabel: TextLabel,
	NameLabel: TextLabel,
	ManaLabel: TextLabel,
	CdOverlay: Frame,
	CdTimerLabel: TextLabel,
	GemData: SkillGemConfig.SkillGemData?,
	ActiveCooldownThread: thread?,
}

local actionSlots: { ActionBarSlotUI } = {}
local clientCooldowns: { [string]: number } = {}
local PRIORITY_SLOTS = { "Weapon", "Armor", "Helmet", "OffHand", "Boots", "Amulet", "Ring" }

-- Запуск локальной плавной анимации кулдауна (Clock / height wipe)
local function startCooldownAnimation(slotIndex: number, cooldownTime: number)
	local slotUI = actionSlots[slotIndex]
	if not slotUI then return end

	if slotUI.ActiveCooldownThread then
		task.cancel(slotUI.ActiveCooldownThread)
		slotUI.ActiveCooldownThread = nil
	end

	slotUI.CdOverlay.Size = UDim2.new(1, 0, 1, 0)
	slotUI.CdTimerLabel.Visible = true

	slotUI.ActiveCooldownThread = task.spawn(function()
		local startTime = os.clock()
		local endTime = startTime + cooldownTime
		while os.clock() < endTime do
			local remaining = math.max(0, endTime - os.clock())
			local progress = remaining / cooldownTime
			slotUI.CdOverlay.Size = UDim2.new(1, 0, progress, 0)

			if remaining >= 1 then
				slotUI.CdTimerLabel.Text = string.format("%.0fs", math.ceil(remaining))
			else
				slotUI.CdTimerLabel.Text = string.format("%.1fs", remaining)
			end
			RunService.Heartbeat:Wait()
		end

		slotUI.CdOverlay.Size = UDim2.new(1, 0, 0, 0)
		slotUI.CdTimerLabel.Visible = false
		slotUI.CdTimerLabel.Text = ""
		slotUI.ActiveCooldownThread = nil
	end)
end

-- Логика запроса каста умения из слота Action Bar
local function castSkillSlot(slotIndex: number)
	local slotUI = actionSlots[slotIndex]
	if not slotUI then return end

	local gemData = slotUI.GemData
	if not gemData then return end

	local now = os.clock()
	local lastExpire = clientCooldowns[gemData.Id] or 0
	if now < lastExpire then
		return
	end

	local char = player.Character
	if not char or not char:IsDescendantOf(workspace) then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or hum.Health <= 0 or not hrp then return end

	-- Запускаем мгновенную визуальную отдачу кулдауна на клиенте
	clientCooldowns[gemData.Id] = now + gemData.Cooldown
	startCooldownAnimation(slotIndex, gemData.Cooldown)

	-- Вычисление 3D-точки прицела
	local targetPos: Vector3
	if isTouch then
		targetPos = hrp.Position + hrp.CFrame.LookVector * 40
	else
		local mouse = player:GetMouse()
		local cam = workspace.CurrentCamera
		local ray = cam and cam:ScreenPointToRay(mouse.X, mouse.Y)
		if ray then
			local rayParams = RaycastParams.new()
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			rayParams.FilterDescendantsInstances = { char }
			local rayResult = workspace:Raycast(ray.Origin, ray.Direction * 500, rayParams)
			if rayResult then
				targetPos = rayResult.Position
			else
				targetPos = ray.Origin + ray.Direction * 100
			end
		else
			targetPos = hrp.Position + hrp.CFrame.LookVector * 40
		end
	end

	-- Отправляем запрос на сервер
	local castSkillEvent = CombatNetwork.GetCastSkillEvent()
	if castSkillEvent then
		castSkillEvent:FireServer(gemData.Id, targetPos)
	end
end

-- Определение функции синхронизации слотов Action Bar
updateActionBarHUD = function()
	local collectedGems: { SkillGemConfig.SkillGemData } = {}
	local usedGemIds: { [string]: boolean } = {}

	for _, slotName in ipairs(PRIORITY_SLOTS) do
		local gemId = cachedSockets[slotName]
		if gemId and gemId ~= "" and not usedGemIds[gemId] then
			local gemData = SkillGemConfig.GetGem(gemId)
			if gemData then
				usedGemIds[gemId] = true
				table.insert(collectedGems, gemData)
			end
		end
		if #collectedGems >= 3 then break end
	end

	for i = 1, 3 do
		local slotUI = actionSlots[i]
		if not slotUI then continue end

		local gemData = collectedGems[i]
		slotUI.GemData = gemData

		if gemData then
			slotUI.NameLabel.Text = gemData.Name
			slotUI.NameLabel.TextColor3 = THEME.TextMain
			slotUI.Stroke.Color = SkillGemConfig.GetColorForGem(gemData.Color)
			slotUI.Stroke.Thickness = 2
			slotUI.ManaLabel.Text = string.format("%d MP", gemData.ManaCost)
			slotUI.Button.AutoButtonColor = true
		else
			slotUI.NameLabel.Text = "Empty"
			slotUI.NameLabel.TextColor3 = THEME.TextMuted
			slotUI.Stroke.Color = Color3.fromRGB(45, 45, 55)
			slotUI.Stroke.Thickness = 1.5
			slotUI.ManaLabel.Text = ""
			slotUI.Button.AutoButtonColor = false
		end
	end
end

-- Построение Action Bar HUD UI
local actionBarFrame = Instance.new("Frame")
actionBarFrame.Name = "ActionBarHUD"
actionBarFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
actionBarFrame.BackgroundTransparency = 0.25
actionBarFrame.BorderSizePixel = 0
actionBarFrame.ZIndex = 20
actionBarFrame.Parent = screenGui

Instance.new("UICorner", actionBarFrame).CornerRadius = UDim.new(0, 10)
local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.fromRGB(50, 50, 65)
barStroke.Thickness = 1.5
barStroke.Parent = actionBarFrame

local slotSize = isTouch and 50 or 56
local slotGap = isTouch and 8 or 10
local barPadding = 8
local barWidth = 3 * slotSize + 2 * slotGap + 2 * barPadding
local barHeight = slotSize + 2 * barPadding

actionBarFrame.Size = UDim2.new(0, barWidth, 0, barHeight)

if isTouch then
	actionBarFrame.AnchorPoint = Vector2.new(1, 1)
	actionBarFrame.Position = UDim2.new(1, -20, 1, -110)
else
	actionBarFrame.AnchorPoint = Vector2.new(0.5, 1)
	actionBarFrame.Position = UDim2.new(0.5, 0, 1, -20)
end

local barLayout = Instance.new("UIListLayout")
barLayout.FillDirection = Enum.FillDirection.Horizontal
barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
barLayout.Padding = UDim.new(0, slotGap)
barLayout.Parent = actionBarFrame

local hotkeys = { "Q", "E", "R" }

for i = 1, 3 do
	local slotBtn = Instance.new("TextButton")
	slotBtn.Name = "SkillSlot_" .. i
	slotBtn.Size = UDim2.new(0, slotSize, 0, slotSize)
	slotBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
	slotBtn.AutoButtonColor = false
	slotBtn.Text = ""
	slotBtn.ClipsDescendants = true
	slotBtn.ZIndex = 21
	slotBtn.Parent = actionBarFrame

	Instance.new("UICorner", slotBtn).CornerRadius = UDim.new(0, 8)
	local slotStroke = Instance.new("UIStroke")
	slotStroke.Color = Color3.fromRGB(50, 50, 65)
	slotStroke.Thickness = 1.5
	slotStroke.Parent = slotBtn

	local hkLbl = Instance.new("TextLabel")
	hkLbl.Name = "HotkeyLabel"
	hkLbl.Size = UDim2.new(0, 20, 0, 14)
	hkLbl.Position = UDim2.new(0, 3, 0, 3)
	hkLbl.BackgroundTransparency = 1
	hkLbl.Font = THEME.FontBold
	hkLbl.TextSize = 9
	hkLbl.TextColor3 = THEME.Gold
	hkLbl.Text = isTouch and hotkeys[i] or string.format("[%s]", hotkeys[i])
	hkLbl.ZIndex = 22
	hkLbl.Parent = slotBtn

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "SkillNameLabel"
	nameLbl.Size = UDim2.new(1, -4, 0, 26)
	nameLbl.Position = UDim2.new(0, 2, 0.5, -13)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = THEME.FontBold
	nameLbl.TextSize = isTouch and 9 or 10
	nameLbl.TextColor3 = THEME.TextMuted
	nameLbl.TextWrapped = true
	nameLbl.Text = "Empty"
	nameLbl.ZIndex = 22
	nameLbl.Parent = slotBtn

	local manaLbl = Instance.new("TextLabel")
	manaLbl.Name = "ManaLabel"
	manaLbl.Size = UDim2.new(0, 30, 0, 12)
	manaLbl.Position = UDim2.new(1, -32, 1, -14)
	manaLbl.BackgroundTransparency = 1
	manaLbl.Font = THEME.FontMedium
	manaLbl.TextSize = 8
	manaLbl.TextColor3 = Color3.fromRGB(90, 175, 255)
	manaLbl.Text = ""
	manaLbl.ZIndex = 22
	manaLbl.Parent = slotBtn

	local cdOverlay = Instance.new("Frame")
	cdOverlay.Name = "CooldownOverlay"
	cdOverlay.Size = UDim2.new(1, 0, 0, 0)
	cdOverlay.Position = UDim2.new(0, 0, 1, 0)
	cdOverlay.AnchorPoint = Vector2.new(0, 1)
	cdOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	cdOverlay.BackgroundTransparency = 0.5
	cdOverlay.BorderSizePixel = 0
	cdOverlay.ZIndex = 24
	cdOverlay.Parent = slotBtn

	local cdTimerLbl = Instance.new("TextLabel")
	cdTimerLbl.Name = "CooldownTimerLabel"
	cdTimerLbl.Size = UDim2.new(1, 0, 1, 0)
	cdTimerLbl.Position = UDim2.new(0, 0, 0, 0)
	cdTimerLbl.BackgroundTransparency = 1
	cdTimerLbl.Font = THEME.FontBold
	cdTimerLbl.TextSize = 13
	cdTimerLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	cdTimerLbl.Text = ""
	cdTimerLbl.Visible = false
	cdTimerLbl.ZIndex = 25
	cdTimerLbl.Parent = slotBtn

	actionSlots[i] = {
		Button = slotBtn,
		Stroke = slotStroke,
		HotkeyLabel = hkLbl,
		NameLabel = nameLbl,
		ManaLabel = manaLbl,
		CdOverlay = cdOverlay,
		CdTimerLabel = cdTimerLbl,
		GemData = nil,
		ActiveCooldownThread = nil,
	}

	slotBtn.Activated:Connect(function()
		castSkillSlot(i)
	end)
end

-- Горячие клавиши [Q], [E], [R] на клавиатуре
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or UserInputService:GetFocusedTextBox() then return end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.Q then
			castSkillSlot(1)
		elseif input.KeyCode == Enum.KeyCode.E then
			castSkillSlot(2)
		elseif input.KeyCode == Enum.KeyCode.R then
			castSkillSlot(3)
		end
	end
end)

-- Первичная инициализация Action Bar
updateActionBarHUD()

--------------------------------------------------------------------------------
-- 10. Визуальные спецэффекты умений (Client VFX via SkillEffectEvent)
--------------------------------------------------------------------------------
task.spawn(function()
	local skillEffectEvent = CombatNetwork.GetSkillEffectEvent()
	if not skillEffectEvent then return end

	skillEffectEvent.OnClientEvent:Connect(function(effectName: string, p1: Vector3, p2: Vector3)
		if effectName == "GroundSlam" then
			-- Кольцевая волна по земле
			local wave = Instance.new("Part")
			wave.Name = "VFX_GroundSlam"
			wave.Shape = Enum.PartType.Cylinder
			wave.Size = Vector3.new(0.6, 6, 6)
			wave.Color = Color3.fromRGB(255, 120, 30)
			wave.Material = Enum.Material.Neon
			wave.Anchored = true
			wave.CanCollide = false
			wave.CFrame = CFrame.new(p1 + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
			wave.Parent = workspace

			local tween = TweenService:Create(wave, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(0.6, 26, 26),
				Transparency = 1,
			})
			tween:Play()
			Debris:AddItem(wave, 0.45)

		elseif effectName == "Fireball_Explode" then
			-- Взрывной огненный шар
			local blast = Instance.new("Part")
			blast.Name = "VFX_FireballBlast"
			blast.Shape = Enum.PartType.Ball
			blast.Size = Vector3.new(2, 2, 2)
			blast.Color = Color3.fromRGB(255, 90, 10)
			blast.Material = Enum.Material.Neon
			blast.Anchored = true
			blast.CanCollide = false
			blast.Position = p1
			blast.Parent = workspace

			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 130, 30)
			light.Range = 22
			light.Brightness = 4
			light.Parent = blast

			local tween = TweenService:Create(blast, TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
				Size = Vector3.new(16, 16, 16),
				Transparency = 1,
			})
			tween:Play()
			Debris:AddItem(blast, 0.4)

		elseif effectName == "DashStrike" then
			-- Быстрый зеленый след рывка
			local dist = (p2 - p1).Magnitude
			if dist > 0.5 then
				local dashBeam = Instance.new("Part")
				dashBeam.Name = "VFX_DashBeam"
				dashBeam.Size = Vector3.new(1.2, 1.2, dist)
				dashBeam.CFrame = CFrame.new((p1 + p2) * 0.5, p2)
				dashBeam.Color = Color3.fromRGB(50, 255, 120)
				dashBeam.Material = Enum.Material.Neon
				dashBeam.Anchored = true
				dashBeam.CanCollide = false
				dashBeam.Parent = workspace

				local tween = TweenService:Create(dashBeam, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = Vector3.new(0.1, 0.1, dist),
					Transparency = 1,
				})
				tween:Play()
				Debris:AddItem(dashBeam, 0.3)
			end
		end
	end)
end)