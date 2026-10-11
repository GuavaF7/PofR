# Технический отчет о текущем состоянии проекта «Path of Roblox» (PofR)
**State of the Project Report • Единый источник правды (Single Source of Truth) и база знаний проекта**

| Параметр | Значение | Параметр | Значение |
| :--- | :--- | :--- | :--- |
| **Версия документа:** | **2.2-LTS (Character Creation, Combat Locomotion & Stash System)** | **Дата обновления:** | **Октябрь 2026** |
| **Архитектурная роль:** | **Senior Roblox / Luau Lead Architect** | **Среда сборки:** | **Rojo v7 • Luau Strict** |

---

## 1. Общая архитектура и среда разработки

### 1.1 Модель разработки: Code-First UI и Rojo v7
Проект Path of Roblox (PofR) строится по строгой парадигме **Code-First UI** и модульной сервис-ориентированной архитектуре. Все пользовательские интерфейсы:
- экран создания и глубокой кастомизации персонажа с 3D ViewportFrame превью (`CharacterCreationController`);
- быстрый экран выбора/смены класса (`ClassSelectionController`);
- комплексное окно персонажа, кукла экипировки с сокетами и инвентарь с Dropdown-фильтрацией (`CombinedCharacterController`);
- панель активных умений на экране (`Action Bar HUD` с горячими клавишами [Q], [E], [R]);
- модальное окно инкрустации камней (`SocketGemModal`);
- интерактивное древо пассивных умений с 2D-графом и Pan/Drag навигацией (`SkillTreeController`)

генерируются программно при старте сессии клиента без использования статических бинарных GUI-ассетов в StarterGui движка. Это полностью исключает мерж-конфликты при параллельной разработке, обеспечивает 100% переносимость кода и прозрачный версионный контроль через Git.

Сборка и синхронизация между локальной файловой системой и Roblox Studio осуществляется через утилиту **Rojo v7**. Конфигурация проекта в файле `default.project.json` связывает локальные директории с контейнерами DataModel движка:
```json
{
  "name": "PofR",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "$ignoreUnknownInstances": true,
      "$path": "src/ReplicatedStorage"
    },
    "ServerScriptService": {
      "$path": "src/ServerScriptService"
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "$path": "src/StarterPlayer/StarterPlayerScripts"
      }
    }
  }
}
```

### 1.2 Структура директорий `src/` и Rojo-модели
- **`ReplicatedStorage`**: Общедоступные конфигурации — редактор внешности (`CharacterCustomizationConfig`), классы (`ClassConfig`), боевые параметры оружия (`CombatConfig`), реестр боевых анимаций (`CombatAnimationConfig`), камни умений (`SkillGemConfig`), граф древа умений (`SkillTreeConfig`), сетевой шлюз (`CombatNetwork`), а также декларации удаленных событий в формате Rojo `.model.json` (`CombatEvents` и `Combat`).
- **`ServerScriptService`**: Серверные сервисы — сервис создания и спавна персонажа (`CharacterCustomizationService`), менеджер личного тайника игрока (`StashManager`), сохранение профилей DataStore (`ProfileService`, `ClassDataManager`), математический расчет статов (`StatCalculationService`), администрирование классов и сброса (`ClassService`, `ClassServerInit`), централизованный боевой авторитет (`Combat/CombatService`, инициализируемый `Combat/CombatInit`), серверный сервис активных умений (`ActiveSkillService`), выдача стартового снаряжения и сокетов (`WeaponService`), обработчик порталов данжей (`PortalHandlerDunAct1`).
- **`StarterPlayerScripts`**: Клиентские контроллеры — интерактивный редактор персонажа (`CharacterCreationController`), боевой контроллер с Dual Wield, 3-Hit комбо и боевой локомоцией (`CombatController`), главное окно персонажа, Action Bar и сокеты (`CombinedCharacterController`), интерактивное древо навыков (`SkillTreeController`), быстрый селектор классов (`ClassSelectionController`).
- **`ServerStorage`**: Изолированное серверное хранилище авторских 3D-моделей оружия (`StarterWeapons`: `StarterSword`, `StarterStaff`, `StarterDaggers`) и защищенных контейнеров тайников игроков (`PlayerStashes`).

### 1.3 Соглашения по типизации Luau и кодировка файлов
- **Строгая типизация (`--!strict`)**: Первая строка каждого модуля и скрипта содержит аннотацию `--!strict`. Экспортируются строгие типы данных (`AppearanceData`, `SkinColorOption`, `FaceOption`, `HairOption`, `HairColorOption`, `ClassOutfitOption`, `GemColor`, `SkillGemData`, `SocketData`, `WeaponProfile`, `PlayerProfileData`, `CombatAnimationConfigType`, `AttackSession`), исключающие непредвиденные рантайм-сбои.
- **Кодировка UTF-8 No BOM**: Все файлы строго нормализованы в UTF-8 без Byte Order Mark. Первые байты равны `2D 2D 21` (`--!`), что гарантирует корректный парсинг компилятором Luau в Studio.

### 1.4 Архитектура вселенной (Universe Architecture) и телепортация
Вселенная проекта разделена на социальный хаб и изолированные боевые данжи:
1. **Хаб (Hub World)**: Place ID `80652987687390` — безопасная зона для спавна, торговли, доступа к сундуку (Stash), выбора классов и прокачки.
2. **Данж Акта 1 (Act 1 Dungeon)**: Place ID `87893523248425` — боевой инстанс PvE.
3. **Логика приватных серверов (`PortalHandlerDunAct1`)**: При касании портала в Workspace сервер инициирует телепортацию через `TeleportService:TeleportAsync()` с флагом `TeleportOptions.ShouldReserveServer = true`, гарантируя выделение индивидуального инстанса (Solo Instance).

---

## 2. Серверная часть, данные и безопасность (Server Authority)

### 2.1 ProfileService и персистентность профилей (`ClassDataManager`)
Управление постоянными данными игроков базируется на библиотеке `ProfileService` (хранилище `PlayerData_ClassSystem_v1`). Шаблон профиля расширен для поддержки создания персонажа и внешности:
```lua
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
```
- **Session Locking**: Метод `LoadProfileAsync` предотвращает порчу и дублирование данных при одновременных сессиях. При отзыве сессии (`ListenToRelease`) игрок принудительно отключается.
- **Защита от Race Condition**: Барьер ожидания `ClassDataManager.WaitUntilLoaded(player, 10)` блокирует прикладную логику спавна до окончания десериализации данных из DataStore.
- **Персистентность внешности (`Appearance` & `IsCharacterCreated`)**: Сохраняет выбранный оттенок кожи, индекс и текстуру лица, стиль и меш прически, цвет волос, а также признак завершения создания.
- **Персистентность сокетов экипировки (`SocketedGems`)**: Состояние инкрустированных камней надежно сохраняется в профиле и мгновенно реплицируется клиенту через атрибуты `Socket_<SlotName>`, JSON-строку `SocketedGemsJSON` и событие `SyncSocketsEvent`.
- **Персистентность активного оружия (`LastEquippedWeapon`)**: Восстанавливает выбранное оружие при респавне, исключая камни умений (`ItemType == "SkillGem"`).

### 2.2 Сервис создания и кастомизации персонажа (`CharacterCustomizationService`)
Серверный авторитет управляет жизненным циклом создания персонажа:
1. **Заморозка спавна при первом входе**: Если `ClassDataManager.IsCharacterCreated(player) == false`, сервер блокирует перемещение аватара (`WalkSpeed = 0`, `JumpPower = 0`, `JumpHeight = 0`) и отправляет клиенту событие `OpenCharacterCreation`.
2. **Серверная валидация создания**: При получении пакета через `SubmitCharacterCreationRemote` или `SubmitCharacterCreationFunction` сервер проверяет границы индексов кожи, лиц, волос, цветов и допустимость выбранного класса по `ClassConfig`.
3. **Нативный спавн через `player:LoadCharacter()`**: После сохранения профиля сервер вызывает нативный метод движка `player:LoadCharacter()`. Это полностью устраняет баги с зависанием в воздухе или проваливанием под землю, автоматически рассчитывает физику SpawnLocation и восстанавливает `HipHeight = 2.0`.
4. **Применение сохраненной внешности**: При каждом последующем спавне (`OnCharacterSpawned`) вызывается `CharacterCustomizationConfig.ApplyAppearanceToCharacter()`, одеваются классовые вещи (`Shirt`/`Pants`), пересчитываются статы и выдается стартовое вооружение.

### 2.3 Менеджер личного тайника / сундука (`StashManager`)
`StashManager.server.luau` реализует серверный авторитет взаимодействия с сундуками в игровом мире:
- **Хранилище сессии**: В `ServerStorage.PlayerStashes` для каждого игрока создается изолированная папка `[UserId]`.
- **Интеракция через ProximityPrompt**: Динамически отслеживает все объекты `ProximityPrompt` в `workspace` (включая создаваемые на лету через `workspace.DescendantAdded`). При активации сундука клиенту отправляется список предметов через `ToggleChestGui`.
- **Транзакционный перенос предметов (`TransferItem`)**:
  - `Deposit`: Перемещает предмет Tool из `Backpack` (или экипированный из `Character`) в личный тайник игрока на сервере;
  - `Withdraw`: Извлекает предмет Tool из хранилища и безопасно возвращает в `Backpack` игрока;
  - Мгновенная синхронизация обновленного содержимого тайника с клиентом.
- **Очистка данных**: При `PlayerRemoving` временный контейнер сессии корректно уничтожается.

### 2.4 Статы и математика характеристик (`StatCalculationService`)
- **Здоровье**: `MaxHealth = BaseClassHP + Σ NodeHealth + (TotalSTR × 2)`.
- **Melee урон**: `RawDamage = (BaseDamage + TotalSTR × 0.4) × (1 + BonusMeleeDamage / 100)`.
- **Magic урон**: `RawDamage = (BaseDamage + TotalINT × 0.55) × (1 + BonusMagicDamage / 100)`.
- **Крит**: `CritChance = clamp(5 + floor(TotalAGI × 0.25) + BonusCritChance, 0, 85)`.
- **Anti-Heal Exploit**: Сохранение процента текущего HP при смене снаряжения или узлов дерева в бою.

### 2.5 Централизованный боевой авторитет (`CombatService` & `CombatInit`)
Боевая логика вынесена в специализированную директорию `ServerScriptService.Combat`:
- `CombatInit.server.luau`: Серверная точка входа, запускающая `CombatService.Start()`.
- `CombatService.luau`: Полный Server Authority атак — проверка кулдаунов (с компенсацией пинга), валидация экипированного оружия, пространственный запрос хитбокса `workspace:GetPartBoundsInBox`, расчет урона, критов, звуки ударов (3D Sound) и репликация эффектов попадания `WeaponHitEffectEvent`.
- Поддержка отладки: Флаг `CombatService.DebugHitboxes` для визуализации серверных хитбоксов в виде полупрозрачных неоновых боксов.
- Обратная совместимость: `ServerScriptService.WeaponSystem.CombatService` является легким прокси-модулем, перенаправляющим вызовы на центральный сервис.

### 2.6 Активные умения и сокеты (`ActiveSkillService`)
- Проверка сокетов через `ClassDataManager.IsGemSocketed` перед кастом.
- Валидация кулдаунов способностей на сервере.
- Механики навыков: `GroundSlam` (конусное AOE 18 st), `Fireball` (физический снаряд 100 st/s на Heartbeat с взрывом 8 st), `DashStrike` (мгновенный рейкаст-рывок 25 st).
- Транзакционная инкрустация (`SocketGemFunction`): защита от дюпа и рассинхронизации.

### 2.7 Универсальный сброс персонажа (`PerformFullCharacterReset`)
В проекте реализован пайплайн полного сброса персонажа для повторного прохождения редактора:
- Поддерживаемые команды: `/reset`, `/resetchar`, `/resetclass`, `!reset`, `!resetchar`, `!resetclass`, `/recreate`, `!recreate`, `/customization`, `!customization`.
- Полная совместимость с двумя системами чата: современной `TextChatService` (автоматическая регистрация `TextChatCommand`) и классической `Legacy Chatted`.
- Функция `ClassService.PerformFullCharacterReset(player)`: сбрасывает класс, очищает прокачку дерева навыков, возвращает очки прокачки, снимает и уничтожает экипированное оружие, удаляет аксессуары и одежду, замораживает персонажа и открывает экран создания.

---

## 3. Боевая система, анимации и боевая локомоция (Combat Architecture)

### 3.1 Конфигурация анимаций и реестр (`CombatAnimationConfig`)
Реестр анимаций вынесен в независимый модуль `ReplicatedStorage.CombatAnimationConfig` (с дубликатом в `Combat/` для гарантии разрешения путей Rojo):
```lua
local CombatAnimationConfig = {
    StarterDaggers = {
        Idle   = "rbxassetid://106851671001027", -- Боевая стойка покоя
        Walk   = "rbxassetid://85471543699921",  -- Боевой бег
        Combo1 = "rbxassetid://132572831455697", -- Удар 1 (Правый выпад)
        Combo2 = "rbxassetid://76033308576777",  -- Удар 2 (Левый порез)
        Combo3 = "rbxassetid://125299984017284", -- Удар 3 (Скрестный X-Slash)
    },
    StarterSword = {
        Attack = "rbxassetid://111581047807750",
    },
    StarterStaff = {
        Attack = "rbxassetid://111581047807750",
    },
}
```

### 3.2 Боевая локомоция (Combat Locomotion: Idle / Walk System)
В `CombatController.client.luau` внедрен специализированный менеджер локомоции при экипированном оружии:
- **Подавление стандартных анимаций**: Динамически глушит дефолтные треки `toolhold`, `toolslash` и `toolnone` из Roblox-скрипта `Animate`.
- **Динамический переключатель стойки и бега**: Контроллер опрашивает `Humanoid.MoveDirection.Magnitude`.
  - При `Magnitude <= 0.05` воспроизводится трек боевой стойки (`Idle`);
  - При `Magnitude > 0.05` происходит плавный кроссфейд (0.1–0.15с) в трек боевого бега (`Walk`);
- **Очистка при смене оружия**: При событии `Tool.Unequipped` вызывается `StopCombatLocomotionTracks(0.1)`, восстанавливая нейтральное состояние персонажа без зависших поз.

### 3.3 Кинематика парных кинжалов (Dual Wield & 3-Hit Combo)
- **Боевая стойка дуэлянта (Duelist Hold Pose)**: Процедурная фиксация суставов плеч, локтей, запястий и хватов (`RightGrip`, `LeftGrip`) для R15 и R6.
- **Динамический мониторинг хватов (`MonitorGripMotors`)**: Слушатель `DescendantAdded` мгновенно ориентирует хваты при их создании движком.
- **3-Hit Dual Combo**:
  - Удар 1: Выпад правым кинжалом вперед;
  - Удар 2: Диагональный порез левым кинжалом;
  - Удар 3 (Финишер X-Slash): Синхронный рубящий удар обеими руками крест-накрест.
- **Автоматический сброс серии**: Таймер комбо сбрасывается на Удар 1 при паузе свыше 1.1с–1.5с.
- **Zero Latency Fallback**: Если ассет анимации не загружается (например, ошибка доступа 10943728529), мгновенно срабатывает процедурная кинематика Motor6D.

### 3.4 Сводная таблица параметров стартового оружия (`CombatConfig`)

| Оружие | Тип | Урон | КД (с) | Дальность | Хитбокс | Смещение | Крит |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **StarterSword** | Melee (1H) | 25 | 0.75 | 6.5 st | 5.5x4.5x6.5 | (0, 0, -3.5) | x1.75 |
| **StarterStaff** | Magic (2H) | 22 | 0.85 | 60.0 st | Raycast Projectile | LookVector | x1.60 |
| **StarterDaggers** | Melee (Dual) | 14 | 0.38 | 5.0 st | 4.5x4.0x5.0 | (0, 0, -3.0) | x2.00 |

---

## 4. Клиентский интерфейс (Code-First UI)

### 4.1 Редактор создания и кастомизации персонажа (`CharacterCreationController`)
Масштабный автономный клиентский модуль (1594 строки), реализующий полноценный редактор персонажа:
- **3D ViewportFrame в реальном времени**:
  - Индивидуальная камера ViewportFrame, сфокусированная на аватаре;
  - Интерактивное вращение персонажа (drag-вращение мышью/тачем и плавный автоповорот);
  - Точечное освещение `LightColor` и `LightDirection` для подчеркивания рельефа брони.
- **Палитра оттенков кожи**: 6 натуральных оттенков (`Pale`, `Fair`, `Warm Tan`, `Olive`, `Bronze`, `Deep Dark`). Окрашивает все конечности аватара в реальном времени.
- **Каталог лиц**: Выбор между стилизованными лицами (`Classic`, `Friendly`, `Stoic`, `Chill`, `Fierce`, `Smirk`) с превью на декали головы.
- **Каталог причесок и головных уборов**: 6 базовых причесок (`Bald`, `Adventurer`, `Slick`, `Ponytail`, `Wanderer`, `Mystic Bob`) с поддержкой динамической подгрузки мешей из папки `CustomizationHairs` (`Hair1`..`Hair10`).
- **Палитра цветов волос**: 6 оттенков (`Raven Black`, `Dark Brown`, `Chestnut`, `Golden`, `Silver`, `Crimson`) с окрашиванием меша прически.
- **Выбор стартового класса с экипировкой**:
  - Карточки `Warrior`, `Mage`, `Rogue` с отображением архетипа, роли и базовых атрибутов;
  - Мгновенная примерка классового костюма (`Shirt` и `Pants`) на 3D-модели во ViewportFrame.
- **Адаптивный интерфейс под мобильные экраны**:
  - Автоматический расчет `UIScale` от 0.35 до 1.0;
  - Учет Safe Area и Home Indicator на экранах современных смартфонов (iPhone Pro и др.).

### 4.2 Окно выбора класса (`ClassSelectionController`)
Служит для быстрой смены класса после сброса (`SelectedClass == "None" and IsCharacterCreated ~= false`). При первом входе игрока управление полностью передается `CharacterCreationController`.

### 4.3 Окно персонажа, кукла экипировки и рюкзак (`CombinedCharacterController`)
Трехколоночный интерфейс 860x480 px:
- **Панель характеристик (Stats Panel)**: Класс, здоровье, скорость, сила, ловкость, интеллект, бонусы физического/магического урона, шанс крита.
- **Кукла снаряжения (Paperdoll)**: 7 слотов (`Helmet`, `Chest Armor`, `Boots`, `Weapon`, `OffHand`, `Ring`, `Amulet`). Круглые сокеты (16x16 px) с цветовой индикацией камней (`Red`, `Green`, `Blue`). Клик по сокету извлекает камень. Для двуручного посоха слот Off-Hand автоматически блокируется статусом `"Blocked (2H)"`.
- **Рюкзак с Dropdown-фильтрацией**: Категории `ALL`, `WEAPONS`, `ARMOR`, `GEMS`, `CONSUMABLES` с плавной анимацией TweenService и правильной иерархией ZIndex.
- **Модальное окно инкрустации (`SocketGemModal`)**: Выбор слота экипировки в 1 клик при нажатии на камень в рюкзаке.
- **PoE-стилизованные тултипы**: Описание камней и экипировки, Long Press (0.35с) для мобильных устройств с подавлением случайных кликов.

### 4.4 Панель активных умений (Action Bar HUD)
- Слоты горячих клавиш **[Q]**, **[E]**, **[R]**.
- Адаптивное расположение: внизу по центру для ПК, в нижнем правом углу над кнопкой прыжка для мобильных устройств.
- Анимация перезарядки: локальное затемнение сверху вниз (Height Wipe Cooldown) с крупным таймером обратного отсчета в секундах (Zero Latency отклик).
- Клиентские спецэффекты умений (`SkillEffectEvent` VFX).

### 4.5 Древо пассивных умений (`SkillTreeController`)
- Интерактивный 2D-граф навыков на холсте `ScrollingFrame` (650x650 px).
- Свободная навигация жестами Pan/Drag на ПК и сенсорных экранах.
- Нижняя панель действий (Action Bar) с изучением узлов (LEARN) и сбросом древа (Respec) за билеты сброса.

---

## 5. Реестр файлов проекта и статус готовности

### 5.1 Полная карта активных файлов проекта

| Путь к файлу в репозитории | Роль в архитектуре проекта |
| :--- | :--- |
| `default.project.json` | Манифест сборки Rojo v7 для компиляции проекта в DataModel Roblox Studio |
| `sourcemap.json` | Карта соответствия исходных файлов виртуальной иерархии DataModel движка |
| `ANTIGRAVITY.md` | Архитектурные стандарты: Code-First UI, Dark RPG палитра, Luau Strict |
| `src/ReplicatedStorage/CharacterCustomizationConfig.luau` | Конфигурация редактора персонажа: палитры кожи, лиц, волос, цвета волос и одежда классов |
| `src/ReplicatedStorage/ClassConfig.luau` | Конфигурация классов (Warrior, Mage, Rogue): базовые статы, описания, цвета |
| `src/ReplicatedStorage/CombatAnimationConfig.luau` | Реестр анимаций боя: атаки, 3-Hit комбо, боевая стойка Idle и боевой бег Walk |
| `src/ReplicatedStorage/CombatConfig.luau` | Параметры оружия: хитбоксы, урон, кулдауны, задержка замаха, дальность, двуручность |
| `src/ReplicatedStorage/CombatNetwork.luau` | Сетевой шлюз: события атак (WeaponAttack), кастов умений (CastSkill), спецэффектов и сокетов |
| `src/ReplicatedStorage/SkillGemConfig.luau` | Реестр камней умений (GroundSlam, Fireball, DashStrike): цвета, статы, скалирование |
| `src/ReplicatedStorage/SkillTreeConfig.luau` | Конфигурация графа древа умений: узлы, координаты на холсте, связи ParentNode, бонусы |
| `src/ReplicatedStorage/Combat/CombatAnimationConfig.luau` | Зеркальный модуль конфигурации анимаций для безопасного разрешения путей в Rojo |
| `src/ReplicatedStorage/Combat/AttackRequestEvent.model.json` | Декларация удаленного события AttackRequestEvent для компилятора Rojo |
| `src/ReplicatedStorage/Combat/AttackRequestRemote.model.json` | Декларация удаленного события AttackRequestRemote для компилятора Rojo |
| `src/ReplicatedStorage/CombatEvents/AttackRequestRemote.model.json` | Декларация события запроса атаки в сетевой папке CombatEvents |
| `src/ReplicatedStorage/CombatEvents/WeaponAttackEvent.model.json` | Декларация сетевого события атаки оружием WeaponAttackEvent |
| `src/ReplicatedStorage/CombatEvents/WeaponHitEffectEvent.model.json` | Декларация сетевого события эффекта попадания WeaponHitEffectEvent |
| `src/ServerScriptService/CharacterCustomizationService.server.luau` | Серверный сервис создания персонажа: заморозка, валидация, спавн через LoadCharacter, сброс |
| `src/ServerScriptService/ClassSystem/ClassDataManager.luau` | Менеджер профилей DataStore: сокеты, LastEquippedWeapon, флаг создания IsCharacterCreated, внешность |
| `src/ServerScriptService/ClassSystem/ClassServerInit.server.luau` | Серверный bootstrap классов: спавн персонажа, TextChatService, Chatted, выдача оружия и камней |
| `src/ServerScriptService/ClassSystem/ClassService.luau` | Серверная логика классов: SetPlayerClass, PerformFullCharacterReset (универсальный сброс) |
| `src/ServerScriptService/ClassSystem/StatCalculationService.luau` | Авторитетный расчет статов (STR->HP, Melee/Magic scaling) и защита от отхила |
| `src/ServerScriptService/Combat/CombatInit.server.luau` | Серверная точка входа, инициализирующая центральный CombatService |
| `src/ServerScriptService/Combat/CombatService.luau` | Центральный боевой сервис: Server Authority хитбоксов, дистанции, урона, 3D-звуков, VFX |
| `src/ServerScriptService/PortalHandlerDunAct1.server.luau` | Обработчик входа в портал и телепортации в приватный Solo-инстанс Данжа Акта 1 |
| `src/ServerScriptService/ProfileService.luau` | Библиотека безопасного управления DataStore с поддержкой Session Locking |
| `src/ServerScriptService/SkillSystem/ActiveSkillService.luau` | Серверный авторитет умений: проверка сокетов, кулдауны, физика (AOE, снаряды, рывок) |
| `src/ServerScriptService/SkillTreeSystem/SkillTreeInit.server.luau` | Серверная инициализация RemoteFunction/RemoteEvent для древа умений |
| `src/ServerScriptService/SkillTreeSystem/SkillTreeService.luau` | Серверная валидация изучения узлов графа, проверка ParentNode, списание очков, Respec |
| `src/ServerScriptService/StashManager.server.luau` | Менеджер личного сундука/тайника: ProximityPrompt, изоляция в ServerStorage, Deposit/Withdraw |
| `src/ServerScriptService/WeaponSystem/CombatService.luau` | Модуль обратной совместимости, перенаправляющий вызовы в ServerScriptService.Combat |
| `src/ServerScriptService/WeaponSystem/WeaponService.luau` | Выдача 3D-оружия, выдача стартовых камней умений (GiveStarterGems), автоэкипировка и fallback |
| `src/StarterPlayer/StarterPlayerScripts/CharacterCreationController.client.luau` | 3D ViewportFrame редактор создания персонажа: кожа, лица, прически, цвета, одежда классов |
| `src/StarterPlayer/StarterPlayerScripts/ClassSelectionController.client.luau` | Окно быстрого выбора класса после сброса (при уже созданной внешности персонажа) |
| `src/StarterPlayer/StarterPlayerScripts/CombatController.client.luau` | Клиентский комбат: Dual Wield кинжалов, 3-Hit комбо, боевая локомоция Idle/Walk, Heartbeat-прицел |
| `src/StarterPlayer/StarterPlayerScripts/CombinedCharacterController.client.luau` | UI персонажа: кукла с сокетами, меню инкрустации, Action Bar HUD, фильтр инвентаря, тултипы |
| `src/StarterPlayer/StarterPlayerScripts/SkillTreeController.client.luau` | Интерактивный UI древа умений: 2D-граф, Pan/Drag навигация, Action Bar, изучение узлов |

### 5.2 Статус готовности подсистем
```
[====================] 100%  Система классов и DataStore (ProfileService, сессии, сохранность)
[====================] 100%  Редактор создания персонажа (3D ViewportFrame, кожа, лица, волосы, наряды)
[====================] 100%  Формулы характеристик (STR->HP, Melee/Magic scaling, Anti-Heal)
[====================] 100%  Интерфейс персонажа (Характеристики, кукла сокетов, рюкзак, Dropdown)
[====================] 100%  Система фильтрации инвентаря (ALL, WEAPONS, ARMOR, GEMS, CONSUMABLES)
[====================] 100%  Интерактивные тултипы экипировки и камней (Hover / Long Press / Stats)
[====================] 100%  Автоэкипировка и персистентность оружия (LastEquippedWeapon)
[====================] 100%  Система камней умений и сокетов (PoE-Style Sockets & Skill Gems)
[====================] 100%  Панель активных умений Action Bar HUD ([Q], [E], [R], Cooldown Wipe)
[====================] 100%  Боевой серверный авторитет навыков (ActiveSkillService, Raycast/AOE)
[====================] 100%  Интерфейс древа умений (2D-граф, Pan/Drag, Respec)
[====================] 100%  Централизованный боевой авторитет (CombatService, хитбоксы, звуки, расчет урона)
[====================] 100%  Боевая локомоция и анимации (CombatAnimationConfig, Idle/Walk переключение)
[====================] 100%  Клиентский комбат-слой (Zero-Latency, Dual Wield стойка дуэлянта, 3-Hit комбо)
[====================] 100%  Стартовое оружие (Sword, Staff, Daggers полностью интегрированы)
[====================] 100%  Универсальный сброс персонажа (/reset, TextChatService + Chatted)
[=================== -]  95%  Система личного тайника / сундука (Сервер StashManager готов, интеграция UI)
[==================--]  90%  Инстансы данжей (Портал хаба готов, логика боев внутри данжа в разработке)
```

### 5.3 Выявленные и устраненные технические риски

> [!TIP]
> **Риск 1: UTF-8 BOM в файлах проекта**: Наличие невидимых байтов `EF BB BF` ломало компиляцию Rojo и вызывало синтаксические ошибки в Studio. Все файлы строго переведены в UTF-8 без BOM (первые байты `2D 2D 21`).

> [!TIP]
> **Риск 2: Race Condition данных при первом спавне**: Персонаж появлялся до вычитки DataStore, что сбрасывало класс в 'None'. Внедрен барьер ожидания `ClassDataManager.WaitUntilLoaded(player, 10)`.

> [!TIP]
> **Риск 3: Эксплойт мгновенного полного отхила (Heal Exploit)**: Смена снаряжения в бою восстанавливала HP до максимума. Введена двухфазная логика: при первом спавне HP заполняется полностью, при повторных перерасчетах сохраняется процент текущего HP.

> [!TIP]
> **Риск 4: Ошибки доступа к ассетам анимаций (Asset Permission 10943728529)**: Сторонние ассеты без прав доступа блокировали атаку. Вызов `LoadAnimation` изолирован в `pcall`, внедрен автоматический процедурный замах плеча `RightShoulder` на 0.20с с гарантированной отправкой атаки на сервер.

> [!TIP]
> **Риск 5: Засорение ServerStorage процедурными инструментами**: Ранее процедурный Tool сохранялся в папку шаблонов, мешая обновлению авторских 3D-моделей. Шаблоны изолированы в локальной оперативной памяти модуля `WeaponService`.

> [!TIP]
> **Риск 6: Потеря активного оружия при перезаходе или телепортации**: При выходе из игры или перемещении в данж оружие оказывалось убранным в рюкзак. Введено поле `LastEquippedWeapon` в профиле DataStore с отложенным вызовом `humanoid:EquipTool()` при появлении персонажа.

> [!TIP]
> **Риск 7: Стирание сохраненного оружия при гибели персонажа**: При смерти персонажа движок Roblox автоматически отсоединяет экипированные инструменты, что приводило к ложному срабатыванию `ChildRemoved` и затиранию данных. Введена строгая серверная проверка `humanoid.Health > 0`, сохраняющая оружие активным при возрождении.

> [!TIP]
> **Риск 8: Конфликт слоев и перекрытие сетки инвентаря выпадающим списком**: При добавлении Dropdown списка категорий элементы сетки ScrollingFrame и кнопки перехватывали клики. Решено четкой иерархией ZIndex (кнопка 15, меню 25, предметы сетки 2), плавной анимацией через TweenService со свойством ClipsDescendants и автозакрытием при потере фокуса.

> [!TIP]
> **Риск 9: Конфликт между долгим нажатием (Long Press) и кликом экипировки**: При отпускании пальца после длительного удержания для осмотра тултипа генерировалось событие MouseButton1Click. Решено флагом подавления `suppressNextClick`, который активируется по таймеру 0.35с и блокирует немедленный клик.

> [!TIP]
> **Риск 10: Зависание серверных снарядов мага на точке спавна**: Физические силы (`BodyVelocity`/`AssemblyLinearVelocity`) на сервере иногда не обновляли позицию снаряда при сетевых лагах. Реализована детерминированная пошаговая симуляция на `RunService.Heartbeat` с локальными рейкастами и валидацией 3D-точки прицела.

> [!TIP]
> **Риск 11: Ошибочное сохранение камней умений в качестве экипированного оружия**: При взятии в руку Tool камня умения (`Gem_...`) система трекинга оружия ошибочно записывала его имя в `LastEquippedWeapon`. Внедрена проверка атрибута `ItemType ~= "SkillGem"` в обработчиках `ChildAdded`/`ChildRemoved`.

> [!TIP]
> **Риск 12: Защита от дюпа и рассинхронизации при инкрустации камней в сокеты**: Быстрый клик по слоту мог вызвать рассинхронизацию между инвентарем и сокетами ProfileService. Решено строгой транзакционной последовательностью: предварительное удаление Tool из Backpack с гарантированным fallback-восстановлением при ошибке сохранения в профиль.

> [!TIP]
> **Риск 13: Отзывчивость кулдаунов в Action Bar HUD при сетевой задержке**: Ожидание подтверждения кулдауна от сервера приводило к визуальному лагу нажатия кнопок [Q], [E], [R]. Реализовано немедленное локальное предсказание анимации затемнения (height wipe) с параллельной авторитетной серверной валидацией кулдауна.

> [!TIP]
> **Риск 14: Блокировка слота второй руки при двуручном оружии**: Экипировка двуручного посоха (`StarterStaff`) позволяла визуально экипировать щит во второй слот. Внедрена проверка `IsTwoHanded` в `CombinedCharacterController` с динамическим переводом слота Off-Hand в статус `"Blocked (2H)"` и запретом инкрустации щитов.

> [!TIP]
> **Риск 15: Свисание левой руки с кинжалом при экипировке парного оружия (Dual Wield Hold Conflict)**: Стандартный скрипт Roblox `Animate` запускает трек `toolhold` только для правой руки, оставляя левую руку пассивной. Решено динамическим перехватом и остановкой треков `toolhold`/`toolslash` через `animator.AnimationPlayed` и выставлением процедурной стойки дуэлянта (Duelist Hold Pose) на суставах и хватах оружия.

> [!TIP]
> **Риск 16: Одноручные атаки кинжалами без участия левой руки (Single-arm Attack Disparity)**: Ранее для кинжалов воспроизводился только одноручный выпад правой рукой. Решено внедрением 3-фазного комбо (`daggerComboStep`) с независимым управлением суставами левой руки во втором ударе и синхронным скрестным ударом обеими руками крест-накрест (X-Slash) в третьем ударе.

> [!TIP]
> **Риск 17: Накопление смещения суставов (Offset Drift) при быстром спаме атак в стойке**: При высокой частоте кликов промежуточное положение C0 во время твина могло перезаписаться как базовое. Решено строгим разделением `naturalBaseC0` (нейтральная поза), `currentHoldTargetC0` (стойка дуэлянта) и кэшированием `baseTargetC0` в `AnimateJointC0`.

> [!TIP]
> **Риск 18: Асинхронное появление RightGrip/LeftGrip в DataModel движка Roblox**: Движок Roblox создает `RightGrip` с задержкой в несколько миллисекунд после добавления Tool в персонажа. Внедрен слушатель `MonitorGripMotors` (`character.DescendantAdded`), мгновенно выставляющий правильный боевой наклон хватов при их создании.

> [!TIP]
> **Риск 19: Зависание персонажа в воздухе или проваливание под землю после кастомизации (HipHeight & Spawn Glitch)**: При программном изменении мешей и аксессуаров движок Roblox мог зафиксировать некорректный параметр `HipHeight` или точку коллизии с полом. Решено вызовом нативного серверного метода `player:LoadCharacter()` после завершения создания персонажа с последующей принудительной валидацией `humanoid.HipHeight = 2.0` и `humanoid.PlatformStand = false`.

> [!TIP]
> **Риск 20: Конфликт экрана выбора класса и редактора персонажа при первом спавне (UI Overlap & Race Condition)**: Если оба экрана открывались одновременно при `SelectedClass == "None"`, происходило наложение интерфейсов. Решено введением флага `IsCharacterCreated` в `ClassDataManager` и проверкой `data.IsCharacterCreated ~= false` в `ClassSelectionController`, передающей исключительный приоритет редактору персонажа.

> [!TIP]
> **Риск 21: Рассинхронизация боевой стойки и анимации бега при экипированном оружии (Locomotion Stance Desync)**: Трек боевой стойки покоя перекрывал стандартную анимацию бега, вызывая неестественное скольжение ног аватара по земле. Решено подсистемой боевой локомоции в `CombatController`, динамически переключающей анимационные треки `Idle` и `Walk` из `CombatAnimationConfig` на основе анализа вектора движения `Humanoid.MoveDirection.Magnitude > 0.05`.

> [!TIP]
> **Риск 22: Изоляция личных тайников и предотвращение потери предметов (Stash Security & Isolation)**: Перемещение предметов в общий контейнер могло привести к дублированию предметов или доступу посторонних игроков. Решено выделением изолированных контейнеров в `ServerStorage.PlayerStashes[UserId]` и строгой серверной транзакцией переноса Tool между инвентарем и тайником под контролем `StashManager`.

> [!TIP]
> **Риск 23: Несовместимость версий чата Roblox при вызове команд сброса (TextChatService vs Legacy Chatted)**: В современных версиях движка Roblox активен `TextChatService`, где классический обработчик `player.Chatted` не перехватывает слэш-команды. Решено двухконтурной регистрацией: создание объектов `TextChatCommand` (`ResetCommand`, `ResetClassCommand`) в `TextChatService` и сохранение слушателя `player.Chatted` для обратной совместимости со старыми серверами.

> [!TIP]
> **Риск 24: Отсутствие сетевых папок при раздельной компиляции модулей (Rojo Remote Declarations)**: Клиентские контроллеры могли вызывать `WaitForChild` для папок `CombatEvents` или `CharacterCreationEvents` до их инициализации серверными скриптами. Решено внедрением декларативных `.model.json` файлов в манифест Rojo в сочетании с серверными хелперами `GetOrCreateFolder` / `GetOrCreateRemoteEvent` / `GetOrCreateRemoteFunction`.

