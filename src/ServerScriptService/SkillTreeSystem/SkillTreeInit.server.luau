local ServerScriptService = game:GetService("ServerScriptService")

local SkillTreeSystem = ServerScriptService:WaitForChild("SkillTreeSystem")

-- Инициализация сервиса Древа Навыков
local SkillTreeService = require(SkillTreeSystem:WaitForChild("SkillTreeService"))

print("[SkillTreeSystem] Сервер Древа Навыков успешно запущен")