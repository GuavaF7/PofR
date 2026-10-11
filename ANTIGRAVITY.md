# Path of Roblox — Архитектура и стандарты разработки

- Язык: Luau со строгой типизацией (`!strict`).
- UI Парадигма: Code-First UI (интерфейсы создаются программно, без статических объектов в StarterGui).
- Стилистика: Dark RPG Theme (Bg: Color3.fromRGB(20, 20, 24), PanelBg: Color3.fromRGB(28, 28, 35), Gold: Color3.fromRGB(255, 215, 0), Accent Stroke: Color3.fromRGB(180, 150, 40)).
- Безопасность (Server Authority): Расчет статов, выдача экипировки и модификация параметров Humanoid выполняются строго на сервере.