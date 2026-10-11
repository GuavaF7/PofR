--!strict
local ClassDataManager = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ProfileService = require(ServerScriptService:WaitForChild("ProfileService"))

export type SocketData = {
	GemId: string,
}

export type CharacterAppearanceData = {
	SkinColorIndex: number,
	FaceIndex: number,
	HairIndex: number,
	HairColorIndex: number?,
	HairName: string?,
	FaceName: string?,
	IsCreated: boolean?,
}

export type PlayerProfileData = {
	SelectedClass: string,
	Level: number,
	Gold: number,
	SkillPoints: number?,
	AllocatedNodes: { [string]: boolean }?,
	ResetTickets: number?,
	LastEquippedWeapon: string,
	SocketedGems: { [string]: SocketData }?,
	IsCharacterCreated: boolean?,
	Appearance: CharacterAppearanceData?,
}

local ProfileTemplate: PlayerProfileData = {
	SelectedClass = "None", -- Default value if not chosen yet
	Level = 1,
	Gold = 100,
	LastEquippedWeapon = "",
	SocketedGems = {},
	IsCharacterCreated = false,
	Appearance = {
		SkinColorIndex = 1,
		FaceIndex = 1,
		HairIndex = 1,
		HairColorIndex = 1,
		HairName = "None",
		FaceName = "Face1",
	},
}

local ProfileStore = ProfileService.GetProfileStore(
	"PlayerData_ClassSystem_v1",
	ProfileTemplate
)

local Profiles: { [Player]: any } = {}

function ClassDataManager.PlayerAdded(player: Player)
	local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)

	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()
		profile:ListenToRelease(function()
			Profiles[player] = nil
			player:Kick("Session closed. Please rejoin.")
		end)

		if player:IsDescendantOf(game.Players) then
			Profiles[player] = profile
			print("[ClassDataManager] Loaded data for " .. player.Name .. ". Class: " .. tostring(profile.Data.SelectedClass))
			ClassDataManager.SyncSocketsToAttributes(player)
		else
			profile:Release()
		end
	else
		player:Kick("Failed to load player data. Please try again.")
	end
end

function ClassDataManager.PlayerRemoving(player: Player)
	local profile = Profiles[player]
	if profile ~= nil then
		profile:Release()
	end
end

function ClassDataManager.Get(player: Player): any
	local profile = Profiles[player]
	return profile and profile.Data or nil
end

function ClassDataManager.GetProfile(player: Player): any
	return Profiles[player]
end

function ClassDataManager.SetLastEquippedWeapon(player: Player, weaponName: string)
	local data = ClassDataManager.Get(player)
	if data then
		data.LastEquippedWeapon = weaponName
	end
end

function ClassDataManager.GetLastEquippedWeapon(player: Player): string
	local data = ClassDataManager.Get(player)
	return (data and data.LastEquippedWeapon) or ""
end

function ClassDataManager.IsCharacterCreated(player: Player): boolean
	local data = ClassDataManager.Get(player)
	if not data then return false end
	if data.IsCharacterCreated == nil then
		return data.SelectedClass ~= "None" and data.SelectedClass ~= ""
	end
	return data.IsCharacterCreated == true
end

function ClassDataManager.SetCharacterCreated(player: Player, created: boolean)
	local data = ClassDataManager.Get(player)
	if data then
		data.IsCharacterCreated = created
	end
end

function ClassDataManager.GetAppearance(player: Player): CharacterAppearanceData?
	local data = ClassDataManager.Get(player)
	return data and data.Appearance or nil
end

function ClassDataManager.SetAppearance(player: Player, appearance: CharacterAppearanceData)
	local data = ClassDataManager.Get(player)
	if data then
		data.Appearance = appearance
	end
end

-- Ожидание загрузки данных профиля из ProfileService
function ClassDataManager.WaitUntilLoaded(player: Player, timeout: number?): any
	local start = os.clock()
	timeout = timeout or 10

	while os.clock() - start < timeout do
		local data = ClassDataManager.Get(player)
		if data then
			return data
		end
		task.wait(0.1)
	end

	return nil
end

local HttpService = game:GetService("HttpService")

function ClassDataManager.SyncSocketsToAttributes(player: Player)
	local data = ClassDataManager.Get(player)
	if not data then return end
	local socketed = data.SocketedGems or {}
	local cleanMap: { [string]: string } = {}
	for slotName, sData in pairs(socketed) do
		local gId = if type(sData) == "table" then sData.GemId else tostring(sData)
		if gId and gId ~= "" then
			cleanMap[slotName] = gId
			player:SetAttribute("Socket_" .. slotName, gId)
		else
			player:SetAttribute("Socket_" .. slotName, nil)
		end
	end

	local standardSlots = { "Weapon", "Armor", "Helmet", "OffHand", "Boots", "Amulet", "Ring" }
	for _, slotName in ipairs(standardSlots) do
		if not cleanMap[slotName] then
			player:SetAttribute("Socket_" .. slotName, nil)
		end
	end

	pcall(function()
		player:SetAttribute("SocketedGemsJSON", HttpService:JSONEncode(cleanMap))
	end)
end

function ClassDataManager.GetSocketedGems(player: Player): { [string]: SocketData }
	local data = ClassDataManager.Get(player)
	if not data then return {} end
	if not data.SocketedGems then
		data.SocketedGems = {}
	end
	return data.SocketedGems
end

function ClassDataManager.SocketGem(player: Player, slotName: string, gemId: string): (boolean, string?)
	local data = ClassDataManager.Get(player)
	if not data then return false, "No player data" end
	if not data.SocketedGems then
		data.SocketedGems = {}
	end

	local oldGemId: string? = nil
	if data.SocketedGems[slotName] then
		oldGemId = if type(data.SocketedGems[slotName]) == "table" then data.SocketedGems[slotName].GemId else tostring(data.SocketedGems[slotName])
	end

	data.SocketedGems[slotName] = { GemId = gemId }
	ClassDataManager.SyncSocketsToAttributes(player)
	return true, oldGemId
end

function ClassDataManager.UnsocketGem(player: Player, slotName: string): string?
	local data = ClassDataManager.Get(player)
	if not data or not data.SocketedGems then return nil end

	local oldData = data.SocketedGems[slotName]
	if not oldData then return nil end

	local oldGemId = if type(oldData) == "table" then oldData.GemId else tostring(oldData)
	data.SocketedGems[slotName] = nil
	ClassDataManager.SyncSocketsToAttributes(player)
	return oldGemId
end

function ClassDataManager.IsGemSocketed(player: Player, gemId: string): (boolean, string?)
	local data = ClassDataManager.Get(player)
	if not data or not data.SocketedGems then return false, nil end

	for slotName, sData in pairs(data.SocketedGems) do
		local currentId = if type(sData) == "table" then sData.GemId else tostring(sData)
		if currentId == gemId then
			return true, slotName
		end
	end
	return false, nil
end

return ClassDataManager