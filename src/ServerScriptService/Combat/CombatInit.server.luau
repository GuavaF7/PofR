--!strict
-- CombatInit.server.luau
-- Серверная точка входа для CombatService

local ServerScriptService = game:GetService("ServerScriptService")
local CombatFolder = ServerScriptService:WaitForChild("Combat")
local CombatService = require(CombatFolder:WaitForChild("CombatService"))

CombatService.Start()
