--!strict
-- CombatController.client.luau
-- Клиентский контроллер атаки, боевых эффектов и Dual Wield анимаций для Path of Roblox (PofR)
-- Zero Latency Client-side Prediction: 100% автономный процедурный взмах (Procedural Swing)
-- с полноценной поддержкой парного оружия (Dual Daggers): боевая стойка дуэлянта + 3-hit комбо.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local CombatConfig = require(ReplicatedStorage:WaitForChild("CombatConfig"))
local CombatNetwork = require(ReplicatedStorage:WaitForChild("CombatNetwork"))
local CombatAnimationConfig: any = CombatConfig.AnimationConfig
local animModule = ReplicatedStorage:FindFirstChild("CombatAnimationConfig")
if not animModule then
	local combatFolder = ReplicatedStorage:FindFirstChild("Combat")
	if combatFolder then
		animModule = combatFolder:FindFirstChild("CombatAnimationConfig")
	end
end
if not animModule then
	animModule = ReplicatedStorage:WaitForChild("CombatAnimationConfig", 1)
end
if animModule and animModule:IsA("ModuleScript") then
	local ok, res = pcall(require, animModule)
	if ok and typeof(res) == "table" then
		CombatAnimationConfig = res
	end
end
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

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local CombatController = {}

local currentTool: Tool? = nil
local toolActivatedConn: RBXScriptConnection? = nil
local toolUnequippedConn: RBXScriptConnection? = nil
local toolEquippedConn: RBXScriptConnection? = nil
local lastAttackTime = 0

-- Кэш треков для опциональных анимаций (если настроен собственный ассет)
local loadedAnimTracks: { [string]: AnimationTrack } = {}
local failedAnimIds: { [string]: boolean } = {}

-- Кэш исходных C0 суставов (до применения hold pose стойки)
local naturalBaseC0: { [JointInstance]: CFrame } = {}
-- Кэш целевых C0 для стойки (Dual Wield Hold Pose)
local currentHoldTargetC0: { [JointInstance]: CFrame } = {}

-- Кэш активных твинов и оригинальных C0 для защиты от спама кликов
local activeOriginalC0: { [JointInstance]: CFrame } = {}
local activeTweens: { [JointInstance]: Tween } = {}
local originalToolGrips: { [Tool]: CFrame } = {}

-- Dual Wield состояние
local isDualWieldActive = false
local toolHoldSuppressionConn: RBXScriptConnection? = nil
local gripAddedConn: RBXScriptConnection? = nil
local currentDualAnimTrack: AnimationTrack? = nil
local currentAttackTrack: AnimationTrack? = nil
local currentIdleTrack: AnimationTrack? = nil
local currentWalkTrack: AnimationTrack? = nil
local walkRunningConn: RBXScriptConnection? = nil
local walkMoveDirConn: RBXScriptConnection? = nil

-- Константа окна комбо (ровно 1.5 сек) и текущий шаг комбо-серии для StarterDaggers (1, 2 или 3)
local COMBO_RESET_DELAY = 1.5
local currentComboStep = 1

-- Проверка, является ли экипированный инструмент парным оружием (Dual Wield)
local function IsDualWieldWeapon(tool: Tool?): boolean
	if not tool then return false end
	if tool.Name == "StarterDaggers" then return true end
	if tool:GetAttribute("IsDualWield") == true then return true end
	if tool:GetAttribute("Subtype") == "Daggers" or tool:GetAttribute("WeaponType") == "Daggers" then return true end

	local lowerName = string.lower(tool.Name)
	if string.find(lowerName, "dagger") then return true end

	local profile = CombatConfig.GetWeaponProfile(tool.Name)
	if profile and (profile.Subtype == "Daggers" or profile.AttackPattern == "DualStab") then
		return true
	end

	local playerClass = Player:GetAttribute("SelectedClass") or Player:GetAttribute("Class")
	if playerClass == "Rogue" and (string.find(lowerName, "dagger") or string.find(lowerName, "blade")) then
		return true
	end

	return false
end

-- Поиск Motor6D плеча правой руки персонажа (поддержка R15 и R6)
local function GetRightShoulderMotor(character: Model): Motor6D?
	-- 1. R15: RightUpperArm -> RightShoulder
	local rightUpperArm = character:FindFirstChild("RightUpperArm")
	if rightUpperArm then
		local shoulder = rightUpperArm:FindFirstChild("RightShoulder")
		if shoulder and shoulder:IsA("Motor6D") then
			return shoulder
		end
	end

	-- 2. UpperTorso (альтернативная иерархия некоторых R15 ригов)
	local upperTorso = character:FindFirstChild("UpperTorso")
	if upperTorso then
		local shoulder = upperTorso:FindFirstChild("RightShoulder") or upperTorso:FindFirstChild("Right Shoulder")
		if shoulder and shoulder:IsA("Motor6D") then
			return shoulder
		end
	end

	-- 3. R6: Torso -> Right Shoulder
	local torso = character:FindFirstChild("Torso")
	if torso then
		local shoulder = torso:FindFirstChild("Right Shoulder") or torso:FindFirstChild("RightShoulder")
		if shoulder and shoulder:IsA("Motor6D") then
			return shoulder
		end
	end

	-- 4. Общий поиск по потомкам модели персонажа
	for _, child in ipairs(character:GetDescendants()) do
		if child:IsA("Motor6D") and (child.Name == "RightShoulder" or child.Name == "Right Shoulder") then
			return child
		end
	end

	return nil
end

-- Поиск Motor6D плеча левой руки персонажа (поддержка R15 и R6)
local function GetLeftShoulderMotor(character: Model): Motor6D?
	-- 1. R15: LeftUpperArm -> LeftShoulder
	local leftUpperArm = character:FindFirstChild("LeftUpperArm")
	if leftUpperArm then
		local shoulder = leftUpperArm:FindFirstChild("LeftShoulder")
		if shoulder and shoulder:IsA("Motor6D") then
			return shoulder
		end
	end

	-- 2. UpperTorso
	local upperTorso = character:FindFirstChild("UpperTorso")
	if upperTorso then
		local shoulder = upperTorso:FindFirstChild("LeftShoulder") or upperTorso:FindFirstChild("Left Shoulder")
		if shoulder and shoulder:IsA("Motor6D") then
			return shoulder
		end
	end

	-- 3. R6: Torso -> Left Shoulder
	local torso = character:FindFirstChild("Torso")
	if torso then
		local shoulder = torso:FindFirstChild("Left Shoulder") or torso:FindFirstChild("LeftShoulder")
		if shoulder and shoulder:IsA("Motor6D") then
			return shoulder
		end
	end

	-- 4. Общий поиск
	for _, child in ipairs(character:GetDescendants()) do
		if child:IsA("Motor6D") and (child.Name == "LeftShoulder" or child.Name == "Left Shoulder") then
			return child
		end
	end

	return nil
end

-- Поиск Motor6D правого локтя (R15)
local function GetRightElbowMotor(character: Model): Motor6D?
	local rightLowerArm = character:FindFirstChild("RightLowerArm")
	if rightLowerArm then
		local elbow = rightLowerArm:FindFirstChild("RightElbow")
		if elbow and elbow:IsA("Motor6D") then
			return elbow
		end
	end

	for _, child in ipairs(character:GetDescendants()) do
		if child:IsA("Motor6D") and (child.Name == "RightElbow" or child.Name == "Right Elbow") then
			return child
		end
	end

	return nil
end

-- Поиск Motor6D левого локтя (R15)
local function GetLeftElbowMotor(character: Model): Motor6D?
	local leftLowerArm = character:FindFirstChild("LeftLowerArm")
	if leftLowerArm then
		local elbow = leftLowerArm:FindFirstChild("LeftElbow")
		if elbow and elbow:IsA("Motor6D") then
			return elbow
		end
	end

	for _, child in ipairs(character:GetDescendants()) do
		if child:IsA("Motor6D") and (child.Name == "LeftElbow" or child.Name == "Left Elbow") then
			return child
		end
	end

	return nil
end

-- Поиск Motor6D правого запястья (R15)
local function GetRightWristMotor(character: Model): Motor6D?
	local rightHand = character:FindFirstChild("RightHand")
	if rightHand then
		local wrist = rightHand:FindFirstChild("RightWrist")
		if wrist and wrist:IsA("Motor6D") then
			return wrist
		end
	end

	for _, child in ipairs(character:GetDescendants()) do
		if child:IsA("Motor6D") and (child.Name == "RightWrist" or child.Name == "Right Wrist") then
			return child
		end
	end

	return nil
end

-- Поиск Motor6D левого запястья (R15)
local function GetLeftWristMotor(character: Model): Motor6D?
	local leftHand = character:FindFirstChild("LeftHand")
	if leftHand then
		local wrist = leftHand:FindFirstChild("LeftWrist")
		if wrist and wrist:IsA("Motor6D") then
			return wrist
		end
	end

	for _, child in ipairs(character:GetDescendants()) do
		if child:IsA("Motor6D") and (child.Name == "LeftWrist" or child.Name == "Left Wrist") then
			return child
		end
	end

	return nil
end

-- Поиск сустава хвата правого оружия (RightGrip) в руке персонажа (Motor6D или Weld)
local function GetRightGripMotor(character: Model): JointInstance?
	local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if rightHand then
		local grip = rightHand:FindFirstChild("RightGrip") or rightHand:FindFirstChild("RightGripMotor")
		if grip and (grip:IsA("Motor6D") or grip:IsA("Weld")) then
			return grip :: JointInstance
		end
		for _, child in ipairs(rightHand:GetChildren()) do
			if (child:IsA("Motor6D") or child:IsA("Weld")) and (string.find(child.Name, "Grip") or string.find(child.Name, "Weapon")) then
				return child :: JointInstance
			end
		end
	end

	for _, child in ipairs(character:GetDescendants()) do
		if (child:IsA("Motor6D") or child:IsA("Weld")) and (child.Name == "RightGrip" or child.Name == "RightGripMotor") then
			return child :: JointInstance
		end
	end

	return nil
end

-- Поиск сустава хвата левого оружия (LeftGrip) в руке персонажа (Motor6D или Weld)
local function GetLeftGripMotor(character: Model): JointInstance?
	local leftHand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	if leftHand then
		local grip = leftHand:FindFirstChild("LeftGrip") or leftHand:FindFirstChild("LeftGripMotor")
		if grip and (grip:IsA("Motor6D") or grip:IsA("Weld")) then
			return grip :: JointInstance
		end
		for _, child in ipairs(leftHand:GetChildren()) do
			if (child:IsA("Motor6D") or child:IsA("Weld")) and (string.find(child.Name, "Grip") or string.find(child.Name, "Dagger") or string.find(child.Name, "Weapon")) then
				return child :: JointInstance
			end
		end
	end

	for _, child in ipairs(character:GetDescendants()) do
		if (child:IsA("Motor6D") or child:IsA("Weld")) and (child.Name == "LeftGrip" or child.Name == "LeftGripMotor" or child.Name == "LeftHandGrip") then
			return child :: JointInstance
		end
	end

	return nil
end

-- Анимация сустава без накопления смещения при спаме кликов
local function AnimateJointC0(
	joint: JointInstance,
	targetOffset: CFrame,
	forwardDuration: number,
	returnDuration: number,
	easingStyle: Enum.EasingStyle?
)
	if not joint or not joint.Parent then return end

	-- Если сустав зафиксирован в боевой стойке дуэлянта (currentHoldTargetC0),
	-- возвращаемся точно в нее, иначе в запомненный начальный C0
	local baseTargetC0: CFrame
	if currentHoldTargetC0[joint] then
		baseTargetC0 = currentHoldTargetC0[joint]
	else
		if not activeOriginalC0[joint] then
			activeOriginalC0[joint] = joint.C0
		end
		baseTargetC0 = activeOriginalC0[joint]
	end

	if activeTweens[joint] then
		activeTweens[joint]:Cancel()
		activeTweens[joint] = nil
	end

	local targetC0 = baseTargetC0 * targetOffset
	local style = easingStyle or Enum.EasingStyle.Quad

	local forwardTween = TweenService:Create(
		joint,
		TweenInfo.new(forwardDuration, style, Enum.EasingDirection.Out),
		{ C0 = targetC0 }
	)
	activeTweens[joint] = forwardTween
	forwardTween:Play()

	task.delay(forwardDuration, function()
		pcall(function()
			if joint and joint.Parent then
				local returnTween = TweenService:Create(
					joint,
					TweenInfo.new(returnDuration, style, Enum.EasingDirection.In),
					{ C0 = baseTargetC0 }
				)
				activeTweens[joint] = returnTween
				returnTween:Play()
				returnTween.Completed:Connect(function()
					if activeTweens[joint] == returnTween then
						activeOriginalC0[joint] = nil
						activeTweens[joint] = nil
					end
				end)
			end
		end)
	end)
end

-- Применение офсета стойки к отдельному суставу
local function ApplyJointHoldPose(joint: JointInstance?, offset: CFrame, duration: number?)
	if not joint or not joint.Parent then return end

	if not naturalBaseC0[joint] then
		naturalBaseC0[joint] = joint.C0
	end

	local targetC0 = naturalBaseC0[joint] * offset
	currentHoldTargetC0[joint] = targetC0

	if activeTweens[joint] then
		activeTweens[joint]:Cancel()
		activeTweens[joint] = nil
	end

	local tweenDuration = duration or 0.15
	local tween = TweenService:Create(
		joint,
		TweenInfo.new(tweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ C0 = targetC0 }
	)
	activeTweens[joint] = tween
	tween:Play()
	tween.Completed:Connect(function()
		if activeTweens[joint] == tween then
			activeTweens[joint] = nil
		end
	end)
end

-- Включение полноценной боевой стойки дуэлянта (Dual Wield Hold Pose)
local function ApplyDualWieldHoldPose(character: Model)
	-- Если загружен и активен кастомный AnimationTrack стойки или движения, процедурный офсет суставов не требуется
	if currentIdleTrack or currentWalkTrack then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local isR15 = (humanoid and humanoid.RigType == Enum.HumanoidRigType.R15) or (character:FindFirstChild("UpperTorso") ~= nil)

	local rightShoulder = GetRightShoulderMotor(character)
	local leftShoulder = GetLeftShoulderMotor(character)
	local rightElbow = GetRightElbowMotor(character)
	local leftElbow = GetLeftElbowMotor(character)
	local rightWrist = GetRightWristMotor(character)
	local leftWrist = GetLeftWristMotor(character)
	local rightGrip = GetRightGripMotor(character)
	local leftGrip = GetLeftGripMotor(character)

	if isR15 then
		-- Стойка дуэлянта R15:
		-- 1. Плечи: выдвинуты вперед на ~46-48 градусов, локти слегка разведены
		if rightShoulder then
			ApplyJointHoldPose(rightShoulder, CFrame.Angles(math.rad(46), math.rad(-14), math.rad(-6)))
		end
		if leftShoulder then
			ApplyJointHoldPose(leftShoulder, CFrame.Angles(math.rad(46), math.rad(14), math.rad(6)))
		end

		-- 2. Локти: согнуты вперед-вверх на ~50 градусов, предплечья сведены к центру
		if rightElbow then
			ApplyJointHoldPose(rightElbow, CFrame.Angles(math.rad(50), 0, math.rad(-6)))
		end
		if leftElbow then
			ApplyJointHoldPose(leftElbow, CFrame.Angles(math.rad(50), 0, math.rad(6)))
		end

		-- 3. Запястья: кисти слегка довернуты внутрь, острия направлены вперед-вверх
		if rightWrist then
			ApplyJointHoldPose(rightWrist, CFrame.Angles(math.rad(-14), math.rad(-4), math.rad(6)))
		end
		if leftWrist then
			ApplyJointHoldPose(leftWrist, CFrame.Angles(math.rad(-14), math.rad(4), math.rad(-6)))
		end

		-- 4. Хваты кинжалов (Grip): согласованы, чтобы лезвия смотрели вперед-вверх, а не в землю
		if rightGrip then
			ApplyJointHoldPose(rightGrip, CFrame.Angles(math.rad(-16), 0, math.rad(4)))
		end
		if leftGrip then
			ApplyJointHoldPose(leftGrip, CFrame.Angles(math.rad(-16), 0, math.rad(-4)))
		end

	else
		-- Стойка дуэлянта R6 (без локтевых суставов):
		if rightShoulder then
			ApplyJointHoldPose(rightShoulder, CFrame.Angles(math.rad(65), math.rad(-16), math.rad(-10)))
		end
		if leftShoulder then
			ApplyJointHoldPose(leftShoulder, CFrame.Angles(math.rad(65), math.rad(16), math.rad(10)))
		end
		if rightGrip then
			ApplyJointHoldPose(rightGrip, CFrame.Angles(math.rad(-25), math.rad(-5), 0))
		end
		if leftGrip then
			ApplyJointHoldPose(leftGrip, CFrame.Angles(math.rad(-25), math.rad(5), 0))
		end
	end
end

-- Снятие боевой стойки и плавный возврат всех суставов в базовую позу
local function ClearDualWieldHoldPose(_character: Model?)
	for joint, baseC0 in pairs(naturalBaseC0) do
		if activeTweens[joint] then
			activeTweens[joint]:Cancel()
			activeTweens[joint] = nil
		end
		activeOriginalC0[joint] = nil

		if joint and joint.Parent then
			local restoreTween = TweenService:Create(
				joint,
				TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ C0 = baseC0 }
			)
			restoreTween:Play()
			task.delay(0.12, function()
				if joint and joint.Parent and not currentHoldTargetC0[joint] then
					joint.C0 = baseC0
				end
			end)
		end
	end

	table.clear(naturalBaseC0)
	table.clear(currentHoldTargetC0)
end

-- Отключение дефолтных треков toolhold/toolslash Roblox Animate скрипта
local function StopDefaultToolTracks(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		local name = string.lower(track.Name)
		local animId = track.Animation and string.lower(track.Animation.AnimationId) or ""
		if string.find(name, "tool") or string.find(name, "hold") or string.find(animId, "tool") or string.find(name, "slash") then
			if track ~= currentDualAnimTrack and track ~= currentIdleTrack and track ~= currentWalkTrack then
				track:Stop(0)
			end
		end
	end
end

local function StartToolHoldSuppression(humanoid: Humanoid)
	if toolHoldSuppressionConn then
		toolHoldSuppressionConn:Disconnect()
		toolHoldSuppressionConn = nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then return end

	StopDefaultToolTracks(humanoid)

	toolHoldSuppressionConn = animator.AnimationPlayed:Connect(function(track)
		if not isDualWieldActive then return end
		if track == currentDualAnimTrack or track == currentIdleTrack then return end

		local name = string.lower(track.Name)
		local animId = track.Animation and string.lower(track.Animation.AnimationId) or ""
		if string.find(name, "tool") or string.find(name, "hold") or string.find(animId, "tool") or string.find(name, "slash") then
			track:Stop(0)
		end
	end)
end

local function StopToolHoldSuppression()
	if toolHoldSuppressionConn then
		toolHoldSuppressionConn:Disconnect()
		toolHoldSuppressionConn = nil
	end
end

-- Отслеживание динамического создания RightGrip / LeftGrip (Roblox создает RightGrip асинхронно при экипировке)
local function MonitorGripMotors(character: Model)
	if gripAddedConn then
		gripAddedConn:Disconnect()
		gripAddedConn = nil
	end

	gripAddedConn = character.DescendantAdded:Connect(function(descendant)
		if not isDualWieldActive then return end
		if descendant:IsA("Motor6D") or descendant:IsA("Weld") then
			local name = descendant.Name
			if name == "RightGrip" or name == "RightGripMotor" or name == "LeftGrip" or name == "LeftGripMotor" then
				task.defer(function()
					if isDualWieldActive and descendant and descendant.Parent then
						local humanoid = character:FindFirstChildOfClass("Humanoid")
						local isR15 = (humanoid and humanoid.RigType == Enum.HumanoidRigType.R15)
						local offset: CFrame
						if string.find(name, "Right") then
							offset = isR15 and CFrame.Angles(math.rad(-16), 0, math.rad(4)) or CFrame.Angles(math.rad(-25), math.rad(-5), 0)
						else
							offset = isR15 and CFrame.Angles(math.rad(-16), 0, math.rad(-4)) or CFrame.Angles(math.rad(-25), math.rad(5), 0)
						end
						ApplyJointHoldPose(descendant, offset, 0.1)
					end
				end)
			end
		end
	end)
end

-- 3-Hit Combo атака парными кинжалами (Удар 1: Правый выпад, Удар 2: Левый выпад/порез, Удар 3: Финишер X-Slash)
local function PlayDualDaggerCombo(character: Model, overrideStep: number?)
	local step = overrideStep or daggerComboStep
	if not step or step <= 0 then
		step = 1
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local isR15 = (humanoid and humanoid.RigType == Enum.HumanoidRigType.R15) or (character:FindFirstChild("UpperTorso") ~= nil)

	local rightShoulder = GetRightShoulderMotor(character)
	local leftShoulder = GetLeftShoulderMotor(character)
	local rightElbow = GetRightElbowMotor(character)
	local leftElbow = GetLeftElbowMotor(character)
	local rightWrist = GetRightWristMotor(character)
	local leftWrist = GetLeftWristMotor(character)
	local rightGrip = GetRightGripMotor(character)
	local leftGrip = GetLeftGripMotor(character)

	if step == 1 then
		-- =========================================================================
		-- УДАР 1: Молниеносный выпад правым кинжалом вперед (Right Dagger Thrust)
		-- =========================================================================
		if isR15 then
			if rightShoulder then
				AnimateJointC0(rightShoulder, CFrame.Angles(math.rad(42), math.rad(10), math.rad(-8)), 0.05, 0.09, Enum.EasingStyle.Quad)
			end
			if rightElbow then
				AnimateJointC0(rightElbow, CFrame.Angles(math.rad(-22), 0, math.rad(-4)), 0.05, 0.09, Enum.EasingStyle.Quad)
			end
			if rightWrist then
				AnimateJointC0(rightWrist, CFrame.Angles(math.rad(-18), math.rad(6), 0), 0.05, 0.09, Enum.EasingStyle.Quad)
			end
			if rightGrip then
				AnimateJointC0(rightGrip, CFrame.Angles(math.rad(-15), 0, 0), 0.05, 0.09, Enum.EasingStyle.Quad)
			end
			-- Левая рука слегка отводится назад в защитную позицию
			if leftShoulder then
				AnimateJointC0(leftShoulder, CFrame.Angles(math.rad(-10), math.rad(-8), math.rad(6)), 0.05, 0.09, Enum.EasingStyle.Quad)
			end
			if leftElbow then
				AnimateJointC0(leftElbow, CFrame.Angles(math.rad(12), 0, 0), 0.05, 0.09, Enum.EasingStyle.Quad)
			end
		else
			-- R6
			if rightShoulder then
				AnimateJointC0(rightShoulder, CFrame.Angles(math.rad(36), math.rad(12), math.rad(-10)), 0.05, 0.09, Enum.EasingStyle.Quad)
			end
			if rightGrip then
				AnimateJointC0(rightGrip, CFrame.Angles(math.rad(-20), 0, 0), 0.05, 0.09, Enum.EasingStyle.Quad)
			end
			if leftShoulder then
				AnimateJointC0(leftShoulder, CFrame.Angles(math.rad(-10), math.rad(-8), math.rad(6)), 0.05, 0.09, Enum.EasingStyle.Quad)
			end
		end

	elseif step == 2 then
		-- =========================================================================
		-- УДАР 2: Резкий выпад/порез левым кинжалом (Left Dagger Thrust / Slash)
		-- Активно задействует LeftUpperArm, LeftLowerArm, LeftHand!
		-- =========================================================================
		if isR15 then
			if leftShoulder then
				AnimateJointC0(leftShoulder, CFrame.Angles(math.rad(44), math.rad(-16), math.rad(12)), 0.05, 0.09, Enum.EasingStyle.Quad)
			end
			if leftElbow then
				AnimateJointC0(leftElbow, CFrame.Angles(math.rad(-26), 0, math.rad(8)), 0.05, 0.09, Enum.EasingStyle.Quad)
			end
			if leftWrist then
				AnimateJointC0(leftWrist, CFrame.Angles(math.rad(-22), math.rad(-10), math.rad(-6)), 0.05, 0.09, Enum.EasingStyle.Quad)
			end
			if leftGrip then
				AnimateJointC0(leftGrip, CFrame.Angles(math.rad(-18), 0, 0), 0.05, 0.09, Enum.EasingStyle.Quad)
			end
			-- Правая рука возвращается в готовность к комбо-финишеру
			if rightShoulder then
				AnimateJointC0(rightShoulder, CFrame.Angles(math.rad(-10), math.rad(8), math.rad(-6)), 0.05, 0.09, Enum.EasingStyle.Quad)
			end
			if rightElbow then
				AnimateJointC0(rightElbow, CFrame.Angles(math.rad(10), 0, 0), 0.05, 0.09, Enum.EasingStyle.Quad)
			end
		else
			-- R6
			if leftShoulder then
				AnimateJointC0(leftShoulder, CFrame.Angles(math.rad(36), math.rad(-12), math.rad(10)), 0.05, 0.09, Enum.EasingStyle.Quad)
			end
			if leftGrip then
				AnimateJointC0(leftGrip, CFrame.Angles(math.rad(-20), 0, 0), 0.05, 0.09, Enum.EasingStyle.Quad)
			end
			if rightShoulder then
				AnimateJointC0(rightShoulder, CFrame.Angles(math.rad(-10), math.rad(8), math.rad(-6)), 0.05, 0.09, Enum.EasingStyle.Quad)
			end
		end

	else
		-- =========================================================================
		-- УДАР 3 (ФИНИШЕР): Одновременный скрестный рубящий удар крест-накрест (X-Slash)
		-- Обе руки синхронно наносят сокрушительный диагональный удар крестом
		-- =========================================================================
		if isR15 then
			-- Правая рука: рубит сверху-справа вниз-влево
			if rightShoulder then
				AnimateJointC0(rightShoulder, CFrame.Angles(math.rad(36), math.rad(28), math.rad(-42)), 0.08, 0.13, Enum.EasingStyle.Quad)
			end
			if rightElbow then
				AnimateJointC0(rightElbow, CFrame.Angles(math.rad(24), math.rad(12), 0), 0.08, 0.13, Enum.EasingStyle.Quad)
			end
			if rightWrist then
				AnimateJointC0(rightWrist, CFrame.Angles(math.rad(-26), math.rad(18), math.rad(-12)), 0.08, 0.13, Enum.EasingStyle.Quad)
			end
			if rightGrip then
				AnimateJointC0(rightGrip, CFrame.Angles(math.rad(-24), math.rad(12), 0), 0.08, 0.13, Enum.EasingStyle.Quad)
			end

			-- Левая рука: рубит сверху-слева вниз-вправо (перекрестный X-разрез)
			if leftShoulder then
				AnimateJointC0(leftShoulder, CFrame.Angles(math.rad(36), math.rad(-28), math.rad(42)), 0.08, 0.13, Enum.EasingStyle.Quad)
			end
			if leftElbow then
				AnimateJointC0(leftElbow, CFrame.Angles(math.rad(24), math.rad(-12), 0), 0.08, 0.13, Enum.EasingStyle.Quad)
			end
			if leftWrist then
				AnimateJointC0(leftWrist, CFrame.Angles(math.rad(-26), math.rad(-18), math.rad(12)), 0.08, 0.13, Enum.EasingStyle.Quad)
			end
			if leftGrip then
				AnimateJointC0(leftGrip, CFrame.Angles(math.rad(-24), math.rad(-12), 0), 0.08, 0.13, Enum.EasingStyle.Quad)
			end
		else
			-- R6
			if rightShoulder then
				AnimateJointC0(rightShoulder, CFrame.Angles(math.rad(28), math.rad(25), math.rad(-35)), 0.08, 0.13, Enum.EasingStyle.Quad)
			end
			if leftShoulder then
				AnimateJointC0(leftShoulder, CFrame.Angles(math.rad(28), math.rad(-25), math.rad(35)), 0.08, 0.13, Enum.EasingStyle.Quad)
			end
			if rightGrip then
				AnimateJointC0(rightGrip, CFrame.Angles(math.rad(-25), math.rad(10), 0), 0.08, 0.13, Enum.EasingStyle.Quad)
			end
			if leftGrip then
				AnimateJointC0(leftGrip, CFrame.Angles(math.rad(-25), math.rad(-10), 0), 0.08, 0.13, Enum.EasingStyle.Quad)
			end
		end
	end
end

-- Надежный процедурный замах руки (Procedural Swing) с дифференциацией по profile.Subtype:
-- - Меч: тяжелый срез плечом вниз-вперед.
-- - Посох: подъем руки для направления снаряда в точку курсора/камеры.
-- - Кинжалы: резкие выпады обеими руками и X-slash комбо.
local function PlayProceduralSwing(character: Model, tool: Tool?, profile: CombatConfig.WeaponProfile, comboStep: number?)
	pcall(function()
		local subtype = profile.Subtype

		if subtype == "Sword" or subtype == "Axe" or subtype == "Mace" then
			-- 1. МЕЧ: тяжелый срез плечом вниз-вперед (мощная диагональная дуга)
			local rightShoulder = GetRightShoulderMotor(character)
			local rightGrip = GetRightGripMotor(character)
			if rightShoulder then
				local slashAngle = CFrame.Angles(math.rad(78), math.rad(18), math.rad(-28))
				AnimateJointC0(rightShoulder, slashAngle, 0.09, 0.13, Enum.EasingStyle.Quad)
			end
			if rightGrip then
				local gripSlash = CFrame.Angles(math.rad(-42), 0, math.rad(14))
				AnimateJointC0(rightGrip, gripSlash, 0.09, 0.13, Enum.EasingStyle.Quad)
			end

		elseif subtype == "Staff" or subtype == "Wand" then
			-- 2. ПОСОХ: подъем руки для направления снаряда в точку курсора/камеры
			local rightShoulder = GetRightShoulderMotor(character)
			local rightGrip = GetRightGripMotor(character)
			if rightShoulder then
				local raiseAngle = CFrame.Angles(math.rad(92), math.rad(-4), math.rad(-6))
				AnimateJointC0(rightShoulder, raiseAngle, 0.12, 0.15, Enum.EasingStyle.Cubic)
			end
			if rightGrip then
				local staffGripAngle = CFrame.Angles(math.rad(-15), 0, 0)
				AnimateJointC0(rightGrip, staffGripAngle, 0.12, 0.15, Enum.EasingStyle.Cubic)
			end

		elseif subtype == "Daggers" or IsDualWieldWeapon(tool) then
			-- 3. КИНЖАЛЫ: 3-Hit Combo выпады обеими руками и X-Slash финишер
			PlayDualDaggerCombo(character, comboStep or currentComboStep)

		else
			-- Дефолтный рубящий взмах для прочих категорий
			local rightShoulder = GetRightShoulderMotor(character)
			local rightGrip = GetRightGripMotor(character)
			if rightShoulder then
				local swingAngle = CFrame.Angles(math.rad(70), math.rad(15), math.rad(-20))
				AnimateJointC0(rightShoulder, swingAngle, 0.08, 0.12, Enum.EasingStyle.Quad)
			end
			if rightGrip then
				local gripAngle = CFrame.Angles(math.rad(-35), 0, math.rad(10))
				AnimateJointC0(rightGrip, gripAngle, 0.08, 0.12, Enum.EasingStyle.Quad)
			end
		end

		-- 4. Fallback: если плечевые суставы временно недоступны — анимируем Grip инструмента
		local rightShoulderCheck = GetRightShoulderMotor(character)
		if not rightShoulderCheck and tool then
			local origGrip = originalToolGrips[tool]
			if not origGrip then
				origGrip = tool.Grip
				originalToolGrips[tool] = origGrip
			end

			tool.Grip = origGrip * CFrame.Angles(math.rad(30), 0, 0)
			task.delay(0.08, function()
				pcall(function()
					if tool and originalToolGrips[tool] then
						tool.Grip = origGrip
						originalToolGrips[tool] = nil
					end
				end)
			end)
		end
	end)
end

-- Локальное воспроизведение звука взмаха для мгновенного отклика (Zero Latency)
local function PlayLocalSwingSound(soundId: string)
	if not soundId or soundId == "" then return end
	pcall(function()
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = 0.6
		sound.Parent = workspace
		sound:Play()

		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		Debris:AddItem(sound, 1.5)
	end)
end

-- Загрузка и воспроизведение трека атаки через Animator:LoadAnimation с заданным приоритетом
local function PlayAttackAnimationTrack(
	humanoid: Humanoid,
	animId: string?,
	priority: Enum.AnimationPriority?,
	fadeTime: number?,
	weight: number?,
	speed: number?
): boolean
	if not animId or animId == "" or failedAnimIds[animId] then
		return false
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local track = loadedAnimTracks[animId]
	if not track or not track.Parent then
		local anim = Instance.new("Animation")
		anim.AnimationId = animId

		local success, trackOrErr = pcall(function()
			return animator:LoadAnimation(anim)
		end)

		pcall(function()
			anim:Destroy()
		end)

		if not success or not trackOrErr or typeof(trackOrErr) ~= "Instance" or not trackOrErr:IsA("AnimationTrack") then
			warn("[CombatController] Не удалось загрузить AnimationTrack для: " .. tostring(animId))
			failedAnimIds[animId] = true
			return false
		end

		track = trackOrErr :: AnimationTrack
		loadedAnimTracks[animId] = track
	end

	-- Строгая проверка существования трека
	if not track then
		return false
	end

	-- Выставляем приоритет (Enum.AnimationPriority.Action)
	pcall(function()
		if track then
			track.Priority = priority or Enum.AnimationPriority.Action
		end
	end)

	-- Остановка предыдущего активного трека атаки для четкого перехода
	if currentAttackTrack and currentAttackTrack ~= track then
		pcall(function()
			if currentAttackTrack and currentAttackTrack.IsPlaying then
				currentAttackTrack:Stop(0.05)
			end
		end)
	end

	-- Если трек уже играет, сбрасываем позицию в начало
	pcall(function()
		if track and track.IsPlaying then
			track.TimePosition = 0
		end
	end)

	local playOk = false
	if track then
		local pFade = fadeTime or 0.05
		local pWeight = weight or 1
		local pSpeed = speed or 1.0
		local success = pcall(function()
			track:Play(pFade, pWeight, pSpeed)
		end)
		playOk = success
	end

	if playOk and track then
		currentAttackTrack = track
		currentDualAnimTrack = track
		return true
	end

	return false
end

-- Обратная совместимость для вспомогательного вызова
local function TryLoadAndPlayAnimation(humanoid: Humanoid, animId: string, profile: CombatConfig.WeaponProfile, isDualWield: boolean): boolean
	local priority = isDualWield and Enum.AnimationPriority.Action2 or Enum.AnimationPriority.Action
	local animSpeed = math.clamp(0.6 / profile.AttackCooldown, 0.8, 2.2)
	return PlayAttackAnimationTrack(humanoid, animId, priority, 0.05, 1, animSpeed)
end

-- Остановка и уничтожение активных треков боевой стойки и передвижения (Idle & Walk)
local function StopCombatLocomotionTracks(fadeTime: number?)
	local fade = fadeTime or 0.2

	if walkRunningConn then
		walkRunningConn:Disconnect()
		walkRunningConn = nil
	end
	if walkMoveDirConn then
		walkMoveDirConn:Disconnect()
		walkMoveDirConn = nil
	end

	if currentWalkTrack then
		local track = currentWalkTrack
		currentWalkTrack = nil
		pcall(function()
			if track.IsPlaying then
				track:Stop(fade)
			end
			if fade > 0 then
				task.delay(fade, function()
					pcall(function()
						track:Destroy()
					end)
				end)
			else
				pcall(function()
					track:Destroy()
				end)
			end
		end)
	end

	if currentIdleTrack then
		local track = currentIdleTrack
		currentIdleTrack = nil
		pcall(function()
			if track.IsPlaying then
				track:Stop(fade)
			end
			if fade > 0 then
				task.delay(fade, function()
					pcall(function()
						track:Destroy()
					end)
				end)
			else
				pcall(function()
					track:Destroy()
				end)
			end
		end)
	end
end

-- Обратная совместимость для вызова остановки Idle-трека
local function StopCombatIdleTrack(fadeTime: number?)
	StopCombatLocomotionTracks(fadeTime)
end

-- Загрузка и запуск кастомных зацикленных треков: Idle (стойка) и Walk (боевой бег)
local function PlayCombatStanceTracks(character: Model, tool: Tool)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- Если трек стойки уже играет для этого оружия, повторная инициализация не требуется
	if currentTool == tool and currentIdleTrack and currentIdleTrack.IsPlaying then
		return
	end

	StopCombatLocomotionTracks(0.1)

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- 1. Определение ID анимации Idle (покой)
	local idleAnimId: string? = nil
	if typeof(CombatAnimationConfig) == "table" then
		if typeof(CombatAnimationConfig.GetIdleAnimation) == "function" then
			idleAnimId = CombatAnimationConfig.GetIdleAnimation(tool.Name)
		end
		if not idleAnimId or idleAnimId == "" then
			local data = CombatAnimationConfig[tool.Name]
			if typeof(data) == "table" and data.Idle and data.Idle ~= "" then
				idleAnimId = data.Idle
			end
		end
	end
	if (not idleAnimId or idleAnimId == "") and tool.Name == "StarterDaggers" then
		idleAnimId = "rbxassetid://106851671001027"
	end

	-- 2. Определение ID анимации Walk (боевой бег)
	local walkAnimId: string? = nil
	if typeof(CombatAnimationConfig) == "table" then
		if typeof(CombatAnimationConfig.GetWalkAnimation) == "function" then
			walkAnimId = CombatAnimationConfig.GetWalkAnimation(tool.Name)
		end
		if not walkAnimId or walkAnimId == "" then
			local data = CombatAnimationConfig[tool.Name]
			if typeof(data) == "table" and data.Walk and data.Walk ~= "" then
				walkAnimId = data.Walk
			end
		end
	end
	if (not walkAnimId or walkAnimId == "") and tool.Name == "StarterDaggers" then
		walkAnimId = "rbxassetid://85471543699921"
	end

	-- 3. Загрузка трека Idle (стойка покоя)
	if idleAnimId and idleAnimId ~= "" and not failedAnimIds[idleAnimId] then
		local anim = Instance.new("Animation")
		anim.AnimationId = idleAnimId

		local success, trackOrErr = pcall(function()
			return animator:LoadAnimation(anim)
		end)

		pcall(function()
			anim:Destroy()
		end)

		if success and trackOrErr and typeof(trackOrErr) == "Instance" and trackOrErr:IsA("AnimationTrack") then
			local track = trackOrErr :: AnimationTrack
			track.Priority = Enum.AnimationPriority.Idle
			track.Looped = true
			track:Play(0.2)
			currentIdleTrack = track
		else
			warn("[CombatController] Не удалось загрузить Idle AnimationTrack для: " .. tostring(idleAnimId))
			failedAnimIds[idleAnimId] = true
		end
	end

	-- 4. Загрузка трека Walk (боевой бег)
	if walkAnimId and walkAnimId ~= "" and not failedAnimIds[walkAnimId] then
		local anim = Instance.new("Animation")
		anim.AnimationId = walkAnimId

		local success, trackOrErr = pcall(function()
			return animator:LoadAnimation(anim)
		end)

		pcall(function()
			anim:Destroy()
		end)

		if success and trackOrErr and typeof(trackOrErr) == "Instance" and trackOrErr:IsA("AnimationTrack") then
			local track = trackOrErr :: AnimationTrack
			track.Priority = Enum.AnimationPriority.Movement
			track.Looped = true
			currentWalkTrack = track
		else
			warn("[CombatController] Не удалось загрузить Walk AnimationTrack для: " .. tostring(walkAnimId))
			failedAnimIds[walkAnimId] = true
		end
	end

	-- 5. Подключение слушателей перемещения (humanoid.Running и MoveDirection)
	if currentWalkTrack then
		local activeWalkTrack = currentWalkTrack

		local function updateMovementState(isMoving: boolean)
			if not currentWalkTrack or currentWalkTrack ~= activeWalkTrack then return end
			if isMoving then
				if not currentWalkTrack.IsPlaying then
					pcall(function()
						currentWalkTrack:Play(0.2)
					end)
				end
			else
				if currentWalkTrack.IsPlaying then
					pcall(function()
						currentWalkTrack:Stop(0.2)
					end)
				end
			end
		end

		walkRunningConn = humanoid.Running:Connect(function(speed: number)
			if speed > 0.5 then
				updateMovementState(true)
			else
				if humanoid.MoveDirection.Magnitude <= 0.05 then
					updateMovementState(false)
				end
			end
		end)

		walkMoveDirConn = humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
			if humanoid.MoveDirection.Magnitude > 0.05 then
				updateMovementState(true)
			else
				local rootPart = humanoid.RootPart
				local speed = rootPart and rootPart.AssemblyLinearVelocity.Magnitude or 0
				if speed <= 0.5 then
					updateMovementState(false)
				end
			end
		end)

		-- Начальная проверка: если персонаж уже двигался в момент экипировки
		local rootPart = humanoid.RootPart
		local currentSpeed = rootPart and rootPart.AssemblyLinearVelocity.Magnitude or 0
		if currentSpeed > 0.5 or humanoid.MoveDirection.Magnitude > 0.05 then
			updateMovementState(true)
		end
	end
end

-- Обратная совместимость для вызова стойки покоя
local function PlayCombatIdleTrack(character: Model, tool: Tool)
	PlayCombatStanceTracks(character, tool)
end

-- Создание всплывающего урона (Floating Combat Text) в стилистике Dark RPG
local function SpawnDamageNumber(hitPosition: Vector3, isCrit: boolean, damage: number)
	pcall(function()
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "DamageNumber"
		billboard.Size = UDim2.new(0, 110, 0, 36)
		billboard.Adornee = nil
		billboard.StudsOffsetWorldSpace = hitPosition + Vector3.new(
			math.random(-8, 8) / 10,
			1.5 + (math.random(-2, 2) / 10),
			math.random(-8, 8) / 10
		)
		billboard.AlwaysOnTop = true
		billboard.Parent = workspace.Terrain

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextSize = isCrit and 22 or 16
		label.TextColor3 = isCrit and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(255, 95, 80)
		label.Text = isCrit and string.format("CRIT! -%d", damage) or string.format("-%d", damage)
		label.Parent = billboard

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = isCrit and 2 or 1.5
		stroke.Color = isCrit and Color3.fromRGB(80, 50, 10) or Color3.fromRGB(30, 20, 20)
		stroke.Parent = label

		local startOffset = billboard.StudsOffsetWorldSpace
		local targetOffset = startOffset + Vector3.new(0, 2.5, 0)

		local tweenInfo = TweenInfo.new(0.75, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
		local tweenPos = TweenService:Create(billboard, tweenInfo, { StudsOffsetWorldSpace = targetOffset })
		local tweenFade = TweenService:Create(label, tweenInfo, { TextTransparency = 1 })
		local tweenStroke = TweenService:Create(stroke, tweenInfo, { Transparency = 1 })

		tweenPos:Play()
		tweenFade:Play()
		tweenStroke:Play()

		task.delay(0.75, function()
			billboard:Destroy()
		end)
	end)
end

-- Спавн искр и эффекта удара при попадании
local function SpawnHitEffect(hitPosition: Vector3, isCrit: boolean)
	pcall(function()
		local emitterPart = Instance.new("Part")
		emitterPart.Name = "HitEffectPart"
		emitterPart.Size = Vector3.new(0.5, 0.5, 0.5)
		emitterPart.Position = hitPosition
		emitterPart.Transparency = 1
		emitterPart.CanCollide = false
		emitterPart.CanQuery = false
		emitterPart.CanTouch = false
		emitterPart.Anchored = true
		emitterPart.Parent = workspace

		local attachment = Instance.new("Attachment", emitterPart)

		local particles = Instance.new("ParticleEmitter")
		particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		particles.Color = ColorSequence.new(
			isCrit and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(255, 120, 60),
			Color3.fromRGB(255, 60, 20)
		)
		particles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, isCrit and 1.2 or 0.7),
			NumberSequenceKeypoint.new(1, 0.1),
		})
		particles.Rate = 0
		particles.Speed = NumberRange.new(5, 12)
		particles.Lifetime = NumberRange.new(0.2, 0.45)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Parent = attachment

		particles:Emit(isCrit and 22 or 12)

		task.delay(0.6, function()
			emitterPart:Destroy()
		end)
	end)
end

-- Основная функция выполнения атаки
function CombatController.TriggerAttack(): boolean
	local character = Player.Character
	if not character or not character:IsDescendantOf(workspace) then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	local equipped = character:FindFirstChildOfClass("Tool")
	if not equipped then
		return false
	end

	local profile = CombatConfig.GetWeaponProfile(equipped.Name)
	local now = os.clock()

	-- Локальная проверка кулдауна (Client-side cooldown prediction)
	if (now - lastAttackTime) < profile.AttackCooldown then
		return false
	end

	-- Сброс по таймауту: если прошло больше COMBO_RESET_DELAY (1.5 сек), принудительно сбрасываем шаг комбо: currentComboStep = 1
	if (now - lastAttackTime) > COMBO_RESET_DELAY then
		currentComboStep = 1
	end

	-- Зафиксируй текущий шаг удара
	local attackStep = currentComboStep

	-- Обнови время последней атаки
	lastAttackTime = now

	local isDual = IsDualWieldWeapon(equipped)
	local isDaggers = (equipped.Name == "StarterDaggers") or (profile.Subtype == "Daggers")

	-- Переключи шаг на следующий для будущего клика:
	-- Если был шаг 1 -> переключи на 2.
	-- Если был шаг 2 -> переключи на 3.
	-- Если был шаг 3 -> верни на 1.
	if currentComboStep == 1 then
		currentComboStep = 2
	elseif currentComboStep == 2 then
		currentComboStep = 3
	else
		currentComboStep = 1
	end

	-- 1. Zero Latency: Запуск анимации замаха или процедурного взмаха
	local playedAnim = false

	-- Безопасное получение ID анимации из таблицы конфигурации для текущего шага комбо
	local animIdToPlay: string? = nil

	if typeof(CombatAnimationConfig) == "table" then
		if typeof(CombatAnimationConfig.GetComboAnimation) == "function" then
			animIdToPlay = CombatAnimationConfig.GetComboAnimation(equipped.Name, attackStep)
		else
			local weaponData = CombatAnimationConfig[equipped.Name]
			if typeof(weaponData) == "table" then
				if isDaggers then
					local comboKey = "Combo" .. tostring(attackStep)
					animIdToPlay = weaponData[comboKey] or weaponData.Attack
					if (not animIdToPlay or animIdToPlay == "") and weaponData.Combo1 then
						animIdToPlay = weaponData.Combo1
					end
				else
					animIdToPlay = weaponData.Attack or weaponData.Combo1
				end
			end
		end
	end

	-- Если не найдено в CombatAnimationConfig, проверяем CombatConfig
	if (not animIdToPlay or animIdToPlay == "") and not isDaggers then
		local animId = profile.AnimationId
		if profile.AnimationIds and profile.AnimationIds.R15 then
			local list = profile.AnimationIds.R15
			if #list > 0 then
				animId = list[1]
			end
		end

		local useProcedural = profile.UseProceduralSwing
		if useProcedural == nil then
			useProcedural = CombatConfig.Settings.UseProceduralSwing
		end

		if not useProcedural and animId and animId ~= "" then
			animIdToPlay = animId
		end
	end

	-- Запасной ID для кинжалов по шагам комбо, если в конфиге пусто
	if isDaggers and (not animIdToPlay or animIdToPlay == "") then
		if attackStep == 1 then
			animIdToPlay = "rbxassetid://132572831455697"
		elseif attackStep == 2 then
			animIdToPlay = "rbxassetid://76033308576777"
		else
			animIdToPlay = "rbxassetid://125299984017284"
		end
	end

	-- Воспроизведение соответствующего трека анимации (Combo1, Combo2 или Combo3)
	-- через Animator:LoadAnimation(...) с быстрым переходом (track:Play(0.05, 1, 1.0))
	-- и приоритетом Enum.AnimationPriority.Action
	if animIdToPlay and animIdToPlay ~= "" and not failedAnimIds[animIdToPlay] then
		local animOk = PlayAttackAnimationTrack(
			humanoid,
			animIdToPlay,
			Enum.AnimationPriority.Action,
			0.05,
			1,
			1.0
		)
		if animOk then
			playedAnim = true
		end
	end

	-- Если трек анимации не воспроизведен (ассет не прогрузился или процедурный режим) —
	-- запускаем процедурный замах
	if not playedAnim then
		pcall(function()
			PlayProceduralSwing(character, equipped, profile, attackStep)
		end)
	end

	-- 2. Локальный звук взмаха
	pcall(function()
		PlayLocalSwingSound(profile.SwingSound)
	end)

	-- 3. Гарантированный сетевой запрос на сервер (AttackRequestRemote) с шагом комбо comboStep
	local attackRemote: RemoteEvent? = CombatNetwork.GetAttackRequestRemote()
	if not attackRemote then
		local combatEvents = ReplicatedStorage:FindFirstChild("CombatEvents")
		if combatEvents then
			attackRemote = (combatEvents:FindFirstChild("AttackRequestRemote") or combatEvents:FindFirstChild("WeaponAttackEvent")) :: RemoteEvent?
		end
	end
	if not attackRemote then
		local combatFolder = ReplicatedStorage:FindFirstChild("Combat")
		if combatFolder then
			attackRemote = (combatFolder:FindFirstChild("AttackRequestRemote") or combatFolder:FindFirstChild("AttackRequestEvent")) :: RemoteEvent?
		end
	end
	if not attackRemote then
		attackRemote = CombatNetwork.GetAttackEvent()
	end

	if attackRemote and attackRemote:IsA("RemoteEvent") then
		local mouse = Player:GetMouse()
		local targetPos: Vector3 = Vector3.zero

		pcall(function()
			if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
				local char = Player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				targetPos = hrp and (hrp.Position + hrp.CFrame.LookVector * 50) or Vector3.zero
			else
				targetPos = mouse.Hit and mouse.Hit.Position or Vector3.zero
			end
		end)

		-- Передаем текущий шаг комбо attackStep (1, 2 или 3) и позицию прицеливания targetPos
		attackRemote:FireServer(attackStep, targetPos)
	else
		warn("[CombatController] RemoteEvent 'AttackRequestRemote' не найден для отправки на сервер")
	end

	return true
end

-- Проверка, наведен ли курсор/тап на интерактивные элементы UI
local function IsInteractingWithGui(pos: Vector2?): boolean
	if UserInputService:GetFocusedTextBox() ~= nil then
		return true
	end

	local targetPos = pos or UserInputService:GetMouseLocation()
	local guiObjects = PlayerGui:GetGuiObjectsAtPosition(targetPos.X, targetPos.Y)
	for _, guiObj in ipairs(guiObjects) do
		if guiObj:IsA("GuiButton") or guiObj:IsA("TextBox") then
			return true
		end
	end

	return false
end

-- Подключение инструмента
local function HookTool(tool: Tool)
	if toolActivatedConn then
		toolActivatedConn:Disconnect()
		toolActivatedConn = nil
	end
	if toolUnequippedConn then
		toolUnequippedConn:Disconnect()
		toolUnequippedConn = nil
	end
	if toolEquippedConn then
		toolEquippedConn:Disconnect()
		toolEquippedConn = nil
	end

	currentTool = tool

	local isDual = IsDualWieldWeapon(tool)
	local character = Player.Character
	if character and character:IsDescendantOf(workspace) then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if isDual then
			isDualWieldActive = true
			if humanoid then
				StartToolHoldSuppression(humanoid)
			end
			MonitorGripMotors(character)
		else
			if isDualWieldActive then
				isDualWieldActive = false
				StopToolHoldSuppression()
				ClearDualWieldHoldPose(character)
			end
		end

		-- Запуск кастомной боевой стойки покоя (Idle) и системы передвижения (Walk)
		PlayCombatStanceTracks(character, tool)

		if isDual then
			if not currentIdleTrack then
				ApplyDualWieldHoldPose(character)
				task.defer(function()
					if currentTool == tool and character and character.Parent and not currentIdleTrack then
						ApplyDualWieldHoldPose(character)
					end
				end)
			else
				ClearDualWieldHoldPose(character)
			end
		end
	end

	toolEquippedConn = tool.Equipped:Connect(function()
		local char = Player.Character
		if char and char:IsDescendantOf(workspace) then
			PlayCombatStanceTracks(char, tool)
		end
	end)

	toolActivatedConn = tool.Activated:Connect(function()
		if not IsInteractingWithGui() then
			CombatController.TriggerAttack()
		end
	end)

	toolUnequippedConn = tool.Unequipped:Connect(function()
		UnhookTool(tool)
	end)
end

local function UnhookTool(tool: Tool)
	if currentTool == tool then
		if toolActivatedConn then
			toolActivatedConn:Disconnect()
			toolActivatedConn = nil
		end
		if toolUnequippedConn then
			toolUnequippedConn:Disconnect()
			toolUnequippedConn = nil
		end
		if toolEquippedConn then
			toolEquippedConn:Disconnect()
			toolEquippedConn = nil
		end
		if gripAddedConn then
			gripAddedConn:Disconnect()
			gripAddedConn = nil
		end

		-- Плавно останавливаем боевую стойку покоя и бег за 0.2 сек, уничтожаем треки
		StopCombatLocomotionTracks(0.2)

		if isDualWieldActive then
			isDualWieldActive = false
			StopToolHoldSuppression()
			if Player.Character then
				ClearDualWieldHoldPose(Player.Character)
			end
			if currentDualAnimTrack then
				currentDualAnimTrack:Stop(0.1)
				currentDualAnimTrack = nil
			end
		end

		-- Очистка трека атаки при снятии оружия
		if currentAttackTrack then
			currentAttackTrack:Stop(0.08)
			currentAttackTrack = nil
		end
		for _, track in pairs(loadedAnimTracks) do
			if track.IsPlaying and track ~= currentIdleTrack and track ~= currentWalkTrack then
				track:Stop(0.08)
			end
		end

		-- Сброс комбо и остановка активных треков при деэкипировке
		currentComboStep = 1
		currentTool = nil
	end
end

-- Обработка спавна и экипировки персонажа
local function OnCharacterAdded(character: Model)
	-- Очистка и уничтожение всех треков предыдущего персонажа
	if currentAttackTrack then
		pcall(function()
			currentAttackTrack:Stop(0)
			currentAttackTrack:Destroy()
		end)
		currentAttackTrack = nil
	end
	StopCombatLocomotionTracks(0)
	for _, track in pairs(loadedAnimTracks) do
		pcall(function()
			track:Stop(0)
			track:Destroy()
		end)
	end
	table.clear(loadedAnimTracks)
	table.clear(failedAnimIds)
	table.clear(activeOriginalC0)
	table.clear(activeTweens)
	table.clear(originalToolGrips)
	table.clear(naturalBaseC0)
	table.clear(currentHoldTargetC0)

	isDualWieldActive = false
	currentDualAnimTrack = nil
	currentComboStep = 1
	currentTool = nil

	if toolActivatedConn then
		toolActivatedConn:Disconnect()
		toolActivatedConn = nil
	end
	if toolUnequippedConn then
		toolUnequippedConn:Disconnect()
		toolUnequippedConn = nil
	end
	if toolEquippedConn then
		toolEquippedConn:Disconnect()
		toolEquippedConn = nil
	end
	if gripAddedConn then
		gripAddedConn:Disconnect()
		gripAddedConn = nil
	end
	StopToolHoldSuppression()

	-- Сброс шага комбо и остановка треков при смерти персонажа
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if humanoid then
		humanoid.Died:Connect(function()
			currentComboStep = 1
			if currentAttackTrack then
				currentAttackTrack:Stop(0.05)
				currentAttackTrack = nil
			end
			-- Корректная очистка Idle и Walk треков через :Destroy() при смерти
			StopCombatLocomotionTracks(0.05)
			for _, track in pairs(loadedAnimTracks) do
				if track.IsPlaying then
					track:Stop(0.05)
				end
			end
		end)
	end

	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			HookTool(child)
		end
	end)

	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			UnhookTool(child)
		end
	end)

	local existingTool = character:FindFirstChildOfClass("Tool")
	if existingTool then
		HookTool(existingTool)
	end
end

-- Обработка общего клика мыши / тапа по экрану
local function OnInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		if currentTool and not IsInteractingWithGui(pos) then
			CombatController.TriggerAttack()
		end
	end
end

-- Инициализация контроллера
local isStarted = false
function CombatController.Start()
	if isStarted then return end
	isStarted = true

	Player.CharacterAdded:Connect(OnCharacterAdded)
	if Player.Character then
		OnCharacterAdded(Player.Character)
	end

	UserInputService.InputBegan:Connect(OnInputBegan)

	-- Безопасное подключение слушателя эффекта попадания
	task.spawn(function()
		local hitEffectEvent = CombatNetwork.GetHitEffectEvent()
		if hitEffectEvent and hitEffectEvent:IsA("RemoteEvent") then
			hitEffectEvent.OnClientEvent:Connect(function(hitPosition: Vector3, isCrit: boolean, damage: number)
				SpawnDamageNumber(hitPosition, isCrit, damage)
				SpawnHitEffect(hitPosition, isCrit)
			end)
		end
	end)

	print("[CombatController] Клиентский боевой контроллер успешно запущен (Dual Wield & Procedural Swing)")
end

-- Автозапуск при инициализации скрипта
task.spawn(CombatController.Start)

return CombatController
