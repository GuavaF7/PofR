--!strict
-- CombatNetwork.luau
-- Сетевой протокол для боевой системы Path of Roblox (PofR)
-- Гарантированная пред-инициализация на сервере без зависаний клиентов.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatNetwork = {}

local FOLDER_NAME = "CombatEvents"
local ATTACK_EVENT_NAME = "WeaponAttackEvent"
local HIT_EFFECT_EVENT_NAME = "WeaponHitEffectEvent"
local CAST_SKILL_EVENT_NAME = "CastSkillEvent"
local SKILL_EFFECT_EVENT_NAME = "SkillEffectEvent"
local SOCKET_GEM_FUNCTION_NAME = "SocketGemFunction"
local SYNC_SOCKETS_EVENT_NAME = "SyncSocketsEvent"

local function GetOrCreateFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		if RunService:IsServer() then
			local newFolder = Instance.new("Folder")
			newFolder.Name = FOLDER_NAME
			newFolder.Parent = ReplicatedStorage
			return newFolder
		else
			folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 5)
			if not folder then
				warn("[CombatNetwork] Внимание: папка " .. FOLDER_NAME .. " еще не создана на сервере.")
				return nil :: any
			end
		end
	end
	return folder :: Folder
end

local function GetOrCreateRemoteEvent(name: string): RemoteEvent?
	local folder = GetOrCreateFolder()
	if not folder then
		return nil
	end

	local remote = folder:FindFirstChild(name)
	if not remote or not remote:IsA("RemoteEvent") then
		if RunService:IsServer() then
			if remote then remote:Destroy() end
			local newRemote = Instance.new("RemoteEvent")
			newRemote.Name = name
			newRemote.Parent = folder
			return newRemote
		else
			remote = folder:WaitForChild(name, 5)
			if not remote or not remote:IsA("RemoteEvent") then
				warn("[CombatNetwork] RemoteEvent " .. name .. " не найден вовремя.")
				return nil
			end
		end
	end
	return remote :: RemoteEvent
end

local function GetOrCreateRemoteFunction(name: string): RemoteFunction?
	local folder = GetOrCreateFolder()
	if not folder then
		return nil
	end

	local remote = folder:FindFirstChild(name)
	if not remote or not remote:IsA("RemoteFunction") then
		if RunService:IsServer() then
			if remote then remote:Destroy() end
			local newRemote = Instance.new("RemoteFunction")
			newRemote.Name = name
			newRemote.Parent = folder
			return newRemote
		else
			remote = folder:WaitForChild(name, 5)
			if not remote or not remote:IsA("RemoteFunction") then
				warn("[CombatNetwork] RemoteFunction " .. name .. " не найден вовремя.")
				return nil
			end
		end
	end
	return remote :: RemoteFunction
end

local COMBAT_FOLDER_NAME = "Combat"
local ATTACK_REQUEST_REMOTE_NAME = "AttackRequestRemote"
local ATTACK_REQUEST_EVENT_NAME = "AttackRequestEvent"

local function GetOrCreateCombatFolder(): Folder?
	local folder = ReplicatedStorage:FindFirstChild(COMBAT_FOLDER_NAME)
	if not folder or not folder:IsA("Folder") then
		if RunService:IsServer() then
			if folder then folder:Destroy() end
			local newFolder = Instance.new("Folder")
			newFolder.Name = COMBAT_FOLDER_NAME
			newFolder.Parent = ReplicatedStorage
			return newFolder
		else
			folder = ReplicatedStorage:WaitForChild(COMBAT_FOLDER_NAME, 5)
			if not folder or not folder:IsA("Folder") then
				warn("[CombatNetwork] Внимание: папка " .. COMBAT_FOLDER_NAME .. " еще не найдена на сервере.")
				return nil
			end
		end
	end
	return folder :: Folder
end

local function GetOrCreateCombatRemoteEvent(name: string): RemoteEvent?
	local folder = GetOrCreateCombatFolder()
	if not folder then
		return nil
	end

	local remote = folder:FindFirstChild(name)
	if not remote or not remote:IsA("RemoteEvent") then
		if RunService:IsServer() then
			if remote then remote:Destroy() end
			local newRemote = Instance.new("RemoteEvent")
			newRemote.Name = name
			newRemote.Parent = folder
			return newRemote
		else
			remote = folder:WaitForChild(name, 5)
			if not remote or not remote:IsA("RemoteEvent") then
				return nil
			end
		end
	end
	return remote :: RemoteEvent
end

-- Немедленная серверная пред-инициализация:
if RunService:IsServer() then
	local folder = GetOrCreateFolder()
	if folder then
		GetOrCreateRemoteEvent(ATTACK_REQUEST_REMOTE_NAME)
		GetOrCreateRemoteEvent(ATTACK_EVENT_NAME)
		GetOrCreateRemoteEvent(HIT_EFFECT_EVENT_NAME)
		GetOrCreateRemoteEvent(CAST_SKILL_EVENT_NAME)
		GetOrCreateRemoteEvent(SKILL_EFFECT_EVENT_NAME)
		GetOrCreateRemoteFunction(SOCKET_GEM_FUNCTION_NAME)
		GetOrCreateRemoteEvent(SYNC_SOCKETS_EVENT_NAME)
	end

	local combatFolder = GetOrCreateCombatFolder()
	if combatFolder then
		GetOrCreateCombatRemoteEvent(ATTACK_REQUEST_REMOTE_NAME)
		GetOrCreateCombatRemoteEvent(ATTACK_REQUEST_EVENT_NAME)
	end
end

function CombatNetwork.GetAttackRequestRemote(): RemoteEvent?
	local remote = GetOrCreateRemoteEvent(ATTACK_REQUEST_REMOTE_NAME)
	if not remote then
		remote = GetOrCreateCombatRemoteEvent(ATTACK_REQUEST_REMOTE_NAME)
	end
	if not remote then
		remote = GetOrCreateCombatRemoteEvent(ATTACK_REQUEST_EVENT_NAME)
	end
	if not remote then
		remote = GetOrCreateRemoteEvent(ATTACK_EVENT_NAME)
	end
	return remote
end

function CombatNetwork.GetAttackEvent(): RemoteEvent?
	return CombatNetwork.GetAttackRequestRemote()
end

function CombatNetwork.GetHitEffectEvent(): RemoteEvent?
	return GetOrCreateRemoteEvent(HIT_EFFECT_EVENT_NAME)
end

function CombatNetwork.GetCastSkillEvent(): RemoteEvent?
	return GetOrCreateRemoteEvent(CAST_SKILL_EVENT_NAME)
end

function CombatNetwork.GetSkillEffectEvent(): RemoteEvent?
	return GetOrCreateRemoteEvent(SKILL_EFFECT_EVENT_NAME)
end

function CombatNetwork.GetSocketGemFunction(): RemoteFunction?
	return GetOrCreateRemoteFunction(SOCKET_GEM_FUNCTION_NAME)
end

function CombatNetwork.GetSyncSocketsEvent(): RemoteEvent?
	return GetOrCreateRemoteEvent(SYNC_SOCKETS_EVENT_NAME)
end

return CombatNetwork
