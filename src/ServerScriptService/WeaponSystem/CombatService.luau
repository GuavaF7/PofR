--!strict
-- WeaponSystem/CombatService.luau
-- Перенаправление на центральный CombatService в ServerScriptService.Combat

local ServerScriptService = game:GetService("ServerScriptService")
local CombatFolder = ServerScriptService:WaitForChild("Combat")
local CombatService = require(CombatFolder:WaitForChild("CombatService"))

return CombatService
