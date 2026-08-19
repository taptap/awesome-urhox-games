-- Climb And Jump Tower (UrhoX Lua Implementation)
-- 基于 scaffold-3d-scene.lua 和 NanoVG 示例
-- 玩法：靠近塔自动攀爬，按空格跳下结算金币

require "LuaScripts/Utilities/Sample"

-- ============================================================================
-- 1. 全局变量声明
-- ============================================================================
---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil
local yaw_ = 0.0
local pitch_ = 0.0

-- 游戏对象
---@type Node
local playerNode_ = nil
---@type Node
local towerNode_ = nil
---@type Node
local platformNode_ = nil
---@type Node
local trophyNode_ = nil
local trophyActive = false

-- NanoVG 上下文
local vg = nil
local fontNormal = -1

-- 游戏状态
local GameState = {
    Idle = 1,
    Climbing = 2,
    Falling = 3,
    OnTop = 4
}
local currentState = GameState.Idle
local ShowCheatMenu = false -- 作弊菜单显示状态

-- 纪念品融合临时状态
local SouvenirFuseState = {
    targetUUID = nil,   -- 被升级的目标纪念品
    materialUUIDs = {}, -- 用于提升成功率的材料纪念品集合: [uuid] = true
    lastResult = nil    -- 上一次融合结果提示
}

-- 纪念品宝箱开箱动画状态（CSGO 风格滚动）
local ChestRollState = {
    active = false,
    chestIndex = nil,      -- 当前正在打开的宝箱在 SouvenirChests 中的下标
    chestId = nil,
    rewardId = nil,        -- 这次动画对应的中奖纪念品 configId
    elapsed = 0.0,
    duration = 3.0,        -- 动画时长，可被 CONFIG 覆盖
    reel = nil,            -- 滚动序列（纪念品 configId 数组）
    targetIndex = nil,     -- reel 中中奖格子的索引
    cellW = 120,           -- 每个格子的宽度（像素）
    totalScroll = 0.0,     -- 需要滚动的总距离
    scroll = 0.0,          -- 当前滚动距离
    skipRequested = false, -- 是否请求跳过动画
    isFinished = false,    -- 动画是否已播放完毕，等待领取
}

local StartChestRoll
local UpdateChestRoll
local FinishChestRoll

-- 纪念品融合相关辅助函数（在后面定义）
local ResetSouvenirFuseState
local OpenSouvenirFuse
local CloseSouvenirFuse
local FindSouvenirByUUID
local CalcSouvenirFuseChance
local PerformSouvenirFuse

-- 数值格式化 helper
local function FormatNumber(n)
    if n >= 1000000000 then
        return string.format("%.2fB", n / 1000000000)
    elseif n >= 1000000 then
        return string.format("%.2fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.2fK", n / 1000)
    else
        return tostring(n)
    end
end

-- 玩家数据
local PlayerData = {
    Altitude = 0.0,
    MaxAltitude = 0.0,
    GoldAccumulated = 0,
    GoldTotal = 0,
    VelocityY = 0.0,
    VelocityH = Vector2(0, 0), -- 水平速度
    Trophies = 0,
    CanAirAttach = false,      -- 是否允许空中吸附
    CurrentGravity = -20.0,    -- 当前重力加速度

    -- 疲劳状态
    ClimbTimer = 0.0,       -- 攀爬时间计时器
    FatigueLevel = 0,       -- 疲劳等级
    FatigueTextTimer = 0.0, -- 疲劳文字显示计时

    -- 翅膀系统
    WingLevel = 0, -- 当前翅膀等级 (0表示无翅膀)

    -- 交互系统
    CurrentInteractable = nil, -- 当前可交互对象
    IsShopOpen = false,        -- 翅膀商店界面是否打开
    IsPetShopOpen = false,     -- 宠物商店界面是否打开
    PetInventory = {},         -- 宠物背包 {petObject}
    BagScrollY = 0,            -- 背包滚动条位置
    IsBagOpen = false,         -- 背包界面是否打开
    CurrentBagTab = 1,         -- 1: Pet, 2: Souvenir
    SelectedPetUUID = nil,     -- 当前选中的宠物UUID
    SouvenirInventory = {},    -- 纪念品背包
    SouvenirSlots = {},        -- 纪念品装备栏 (index 1-8)
    UnlockedSouvenirSlots = 2, -- 已解锁的纪念品栏位数量 (默认2个)
    Diamonds = 0,              -- 钻石数量
    TrophyProgress = 0.0,      -- 奖杯进度（用于处理奖杯加成产生的小数部分）
    ActiveDialog = nil,        -- 当前激活的模态对话框 { title, message, onConfirm, onCancel }

    -- 纪念品融合界面
    IsSouvenirFuseOpen = false, -- 是否打开纪念品融合界面
    SouvenirFuseScrollY = 0,    -- 融合界面纪念品列表滚动位置

    -- 宝箱库存
    SouvenirChests = {},      -- { {id=1, count=10}, ... }
    SelectedChestIndex = nil, -- 当前选中的宝箱索引
}

-- 可交互对象列表
local Interactables = {}

-- NPC 列表
local NPCs = {}

-- 纪念品配置
local SOUVENIR_CONFIG = {
    -- 1. 法棍：落地金币 +5%，稀有度 1
    [1] = {
        name = "法棍",
        color = Color(0.9, 0.7, 0.3),
        rarity = 1,
        goldBonusPct = 0.05,
        weight = 600,
    },
    -- 2. 马卡龙：攀爬速度 +5%，稀有度 2
    [2] = {
        name = "马卡龙",
        color = Color(1.0, 0.6, 0.8),
        rarity = 2,
        climbSpeedPct = 0.05,
        weight = 300
    },
    -- 3. 红酒：幸运 +5%，稀有度 3
    --    幸运值目前只做汇总，未来可用于各种概率事件（如暴击、掉落等）
    [3] = {
        name = "红酒",
        color = Color(0.6, 0.0, 0.0),
        rarity = 3,
        luckPct = 0.05,
        weight = 70
    },
    -- 4. 皮包：奖杯获得率 +5%，稀有度 4
    [4] = {
        name = "皮包",
        color = Color(0.2, 0.6, 0.4),
        rarity = 4,
        trophyRatePct = 0.05,
        weight = 25
    },
    -- 5. 香水：稀有宠物概率 +100%，稀有度 5
    --    效果：将 3 级以上（不含 3 级，这里对应 configId >= 4）的宠物权重乘以 (1 + rarePetWeightBonus)
    [5] = {
        name = "香水",
        color = Color(0.5, 0.3, 0.1),
        rarity = 5,
        rarePetWeightBonus = 1.0, -- +100% 权重
        weight = 5
    }
}

-- 纪念品宝箱配置
local SOUVENIR_CHEST_CONFIG = {
    [1] = {
        name = "法国纪念品宝箱",
        desc = "可能获得：法棍、马卡龙、红酒、皮包、香水",
        pool = { 1, 2, 3, 4, 5 } -- 包含的纪念品ID，权重读取 SOUVENIR_CONFIG
    }
}

-- 纪念品栏位解锁消耗
local SOUVENIR_UNLOCK_COSTS = {
    [3] = { type = "Trophies", amount = 100 },
    [4] = { type = "Trophies", amount = 2000 },
    [5] = { type = "Trophies", amount = 50000 },
    [6] = { type = "Trophies", amount = 100000 },
    [7] = { type = "Diamonds", amount = 20 },
    [8] = { type = "Diamonds", amount = 500 }
}

-- 宠物配置
local PET_CONFIG = {
    [1] = { name = "史莱姆", chance = 50, color = Color(0.2, 0.8, 0.2), scale = 0.5, baseBonus = 1 },
    [2] = { name = "小石怪", chance = 30, color = Color(0.5, 0.5, 0.5), scale = 0.6, baseBonus = 3 },
    [3] = { name = "火精灵", chance = 15, color = Color(1.0, 0.4, 0.2), scale = 0.7, baseBonus = 8 },
    [4] = { name = "独角兽", chance = 4, color = Color(0.9, 0.9, 1.0), scale = 0.8, baseBonus = 20 },
    [5] = { name = "巨龙", chance = 1, color = Color(1.0, 0.8, 0.0), scale = 1.0, baseBonus = 100 }
}
local GACHA_PRICE = 500

-- 翅膀配置 (10级)
local WING_LEVELS = {
    [1] = { cost = 100, speedMult = 2, color = Color(0.9, 0.9, 0.9), name = "纸翅膀", scale = 1.0 },
    [2] = { cost = 300, speedMult = 4, color = Color(0.6, 0.8, 0.6), name = "木制翅膀", scale = 1.1 },
    [3] = { cost = 600, speedMult = 8, color = Color(0.4, 0.6, 1.0), name = "轻羽之翼", scale = 1.2 },
    [4] = { cost = 1200, speedMult = 16, color = Color(0.6, 0.2, 0.8), name = "魔法之翼", scale = 1.3 },
    [5] = { cost = 2500, speedMult = 32, color = Color(1.0, 0.5, 0.0), name = "火焰之翼", scale = 1.4 },
    [6] = { cost = 5000, speedMult = 64, color = Color(0.8, 0.0, 0.0), name = "恶魔之翼", scale = 1.5 },
    [7] = { cost = 10000, speedMult = 128, color = Color(0.0, 0.8, 1.0), name = "水晶之翼", scale = 1.6 },
    [8] = { cost = 20000, speedMult = 256, color = Color(1.0, 0.84, 0.0), name = "黄金之翼", scale = 1.8 },
    [9] = { cost = 40000, speedMult = 512, color = Color(1.0, 0.4, 0.7), name = "光辉之翼", scale = 2.0 },
    [10] = { cost = 80000, speedMult = 1024, color = Color(0.0, 0.0, 0.0), name = "虚空之翼", scale = 2.5 }
}

-- 特效状态
local shakeTimer = 0.0
local shakePower = 0.0
local activeCoins = {} -- {node, vel, timer, state}
local Effects = {}     -- {node, velocity, life, gravity, rotSpeed}

-- NPC 系统
local NPCs = {} -- list of {node, state, timer, speed, angle, velocityY, velocityH}

-- 配置
local CONFIG = {
    TowerHeight = 3000.0,      -- 塔高 (米)
    SnapRange = 0.5,           -- 吸附范围 (米)
    ClimbSpeed = 10.0,         -- 攀爬速度 (米/秒)
    GoldPerMeter = 10,         -- 每米金币
    Gravity = -20.0,           -- 普通重力 (平地跳跃)
    FallGravity = -100.0,      -- 高空下落重力
    JumpImpulse = 8.0,         -- 跳下时的向上冲量
    PushForce = 5.0,           -- 跳下时的水平推力
    MaxJumpDistance = 10.0,    -- 最大水平跳跃距离
    TowerSegmentHeight = 50.0, -- 塔分段高度

    -- 疲劳机制配置
    FatigueInterval = 10.0,    -- 疲劳触发间隔(秒)
    FatigueDuration = 3.0,     -- 疲劳持续时间(秒)
    FatigueSpeedFactor = 0.5,  -- 疲劳时的速度倍率

    MaxPetCount = 50,          -- 宠物背包上限
    SynthesisMultiplier = 2.0, -- 合成后金币加成倍率
    CameraDistance = 15.0,
    CameraHeight = 5.0,

    -- NPC 配置
    NPCCount = 20,              -- NPC 数量
    NPCMinSpeedMult = 1.0,      -- 攀爬速度下限倍数（相对于 ClimbSpeed）
    NPCMaxSpeedMult = 6.0,      -- 攀爬速度上限倍数
    NPCMinClimbDuration = 10.0, -- 每次攀爬最短时间（秒）
    NPCMaxClimbDuration = 30.0, -- 每次攀爬最长时间（秒）
    NPCJumpAngleRange = 60.0,   -- 从塔上跳下时，左右偏转角度范围（度），默认 ±60°
    NPCSpawnMinRadius = 6.0,    -- NPC 出生时距离塔中心最小半径
    NPCSpawnMaxRadius = 14.0,   -- NPC 出生时距离塔中心最大半径
    NPCLandIdleMin = 0.0,       -- NPC 落地后最小发呆时间（秒）
    NPCLandIdleMax = 3.0,       -- NPC 落地后最大发呆时间（秒）

    -- 纪念品融合相关配置
    SouvenirFuseBaseChance = 0.0,         -- 基础成功率（0%）
    SouvenirFusePerMaterialChance = 0.10, -- 每消耗 1 个额外纪念品增加的成功率（10%）
    SouvenirFuseMaxChance = 1.00,         -- 最高成功率（100%）
    SouvenirFuseLuckFactor = 1.0,         -- 幸运值对融合成功率的影响系数

    -- 星级与属性加成（线性：每升 1 星，属性加成额外 +100%）
    SouvenirStarBaseMult = 1.0,    -- 1 星倍率
    SouvenirStarPerLevelAdd = 1.0, -- 每升 1 星额外增加的倍率（1.0 = +100%）
    SouvenirMaxStar = 5,           -- 纪念品最大星级

    -- 爬塔限制
    MaxClimbSpeedPct = 0.10, -- 爬塔最大速度比例（相对于塔高，0.10 = 10% 塔高/秒）
    MinClimbAltitude = 1.0,  -- 向下爬时触发落地的最小高度
    PushAwayDistance = 3.0,  -- 落地时推开的距离

    -- NPC 碰撞
    EnableNPCCollision = true,       -- 是否开启玩家与 NPC 在攀爬时的碰撞
    NPCCollisionRadius = 1.0,        -- 碰撞检测半径（米）
    CollisionHigherFallsOnly = true, -- 是否仅击落高度更高的一方（若为true，则位置低的一方获胜）

    -- NPC 行为倾向权重 (总和不需要为1，只是相对权重)
    NPCBehaviorWeights = {
        Straight = 40,   -- 直线攀爬
        Random = 30,     -- 随机左右移动
        Aggressive = 15, -- 攻击型 (主动去撞上方的人)
        Defensive = 15,  -- 防御型 (主动避开下方的人)
        AvoidUpper = 10  -- 避让型 (避开上方的人，防止被撞)
    },

    NPCBehaviorIntervalMin = 0.5, -- NPC 行为决策间隔最小时间（秒）
    NPCBehaviorIntervalMax = 1.0, -- NPC 行为决策间隔最大时间（秒）

    -- 特效配置
    EffectSparkColor = Color(1.0, 0.5, 0.2), -- 火花颜色
    EffectSparkCount = 20,                   -- 火花数量

    -- 昼夜循环
    EnableDayNightCycle = true, -- 是否开启昼夜交替
    DayLength = 300.0,          -- 一天时长（秒）
}

-- ============================================================================
-- 2. 生命周期函数
-- ============================================================================

local dayTime = 0.0
local sunNode_ = nil
local sunLight_ = nil
local sunModelNode_ = nil
local moonNode_ = nil
local moonShadowMat_ = nil -- 用于实时更新月亮遮挡球的颜色
local zone_ = nil

function Start()
    SampleStart()
    graphics.windowTitle = "Climb And Jump Tower"

    CreateScene()
    SetupCamera()
    CreateGameContent()
    SetupNanoVG()

    SubscribeToEvents()

    -- 初始化玩家数据与位置同步
    PlayerData.Altitude = playerNode_.position.y

    print("=== Climb And Jump Tower Started ===")

    -- 锁定鼠标模式
    input.mouseVisible = false
    input.mouseMode = MM_RELATIVE
end

function Stop()
    if vg ~= nil then
        nvgDelete(vg)
    end
end

-- ============================================================================
-- 3. 初始化
-- ============================================================================

function CreateScene()
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("DebugRenderer")

    if CONFIG.EnableDayNightCycle then
        -- 昼夜系统：手动创建 Zone 和 Sun
        -- 1. 环境光 Zone
        local zoneNode = scene_:CreateChild("Zone")
        zone_ = zoneNode:CreateComponent("Zone")
        zone_.boundingBox = BoundingBox(Vector3(-5000, -5000, -5000), Vector3(5000, 5000, 5000))
        zone_.ambientColor = Color(0.1, 0.1, 0.1)
        zone_.fogColor = Color(0.5, 0.6, 0.7)
        zone_.fogStart = 500.0
        zone_.fogEnd = 3000.0

        -- 2. 太阳节点 (位于原点，只旋转)
        sunNode_ = scene_:CreateChild("Sun")
        -- 初始方向稍后在 UpdateDayNightCycle 中设置

        -- 3. 太阳光
        sunLight_ = sunNode_:CreateComponent("Light")
        sunLight_.lightType = LIGHT_DIRECTIONAL
        sunLight_.color = Color(1.0, 0.9, 0.8)
        sunLight_.castShadows = true
        sunLight_.shadowBias = BiasParameters(0.00025, 0.5)
        sunLight_.shadowCascade = CascadeParameters(10, 50, 200, 0, 0.8)

        -- 4. 太阳模型 (挂在 sunNode 下，位于后方)
        -- 注意：DirectionalLight 的 Forward (+Z) 是光照方向
        -- 所以太阳本体应该在 -Z 方向
        sunModelNode_ = sunNode_:CreateChild("SunVisual")
        -- 稍微往东偏移 (X+ 方向是右/东，但在 sunNode_ 局部坐标系中需要根据旋转理解)
        -- 这里我们直接调整 sunModelNode_ 的局部位置
        -- 原始逻辑：sunNode_ 旋转， sunModelNode_ 在 -Z 处。
        -- 要让太阳看上去偏移，可以在局部坐标系偏移。
        -- 假设初始朝向东，如果要在视觉上偏一点，可以修改 offset
        sunModelNode_.position = Vector3(100, 0, -800) -- X+100 (局部偏移)，避免正午撞塔
        sunModelNode_.scale = Vector3(100, 100, 100)   -- 放大到 2 倍 (原 50 -> 100)

        local sunModel = sunModelNode_:CreateComponent("StaticModel")
        sunModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))

        local sunMat = Material:new()
        sunMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffUnlit.xml")) -- 不受光照影响
        sunMat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 0.6, 0.1, 1.0)))      -- 橙色
        sunModel:SetMaterial(sunMat)

        -- 5. 月亮 (固定在夜空)
        local moonNode = scene_:CreateChild("Moon")
        -- 固定位置：高空，避开塔 (塔在 0,0)
        -- 放在 (-100, 1000, 100) 这样的位置，靠近塔，方便看见
        moonNode.position = Vector3(-100, 1000, 100)
        moonNode.scale = Vector3(60, 60, 60) -- 放大到 1.5 倍 (原 40 -> 60)
        -- 让月亮朝向原点(大概方向)，方便调整遮挡位置
        moonNode:LookAt(Vector3(0, 0, 0))

        local moonModel = moonNode:CreateComponent("StaticModel")
        moonModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))

        local moonMat = Material:new()
        moonMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffUnlit.xml"))
        moonMat:SetShaderParameter("MatDiffColor", Variant(Color(0.9, 0.9, 1.0, 1.0))) -- 冷白色
        moonModel:SetMaterial(moonMat)

        -- 5.1 月芽遮挡球 (通过遮挡模拟月芽形状)
        local moonShadowNode = moonNode:CreateChild("MoonShadow")
        -- 增加偏移量，使月芽更细 (X 越大，剩下的亮面越少)
        -- 将 Z 轴微调到 -0.1 (向月亮内部/背面方向)，防止 Z-fighting 或渲染层级问题，
        -- 但 StaticModel 默认不透明，所以要放在靠近摄像机的一侧 (Z+ 是指向摄像机/原点的)
        -- 之前的 -0.1 其实是远离摄像机，可能被月亮挡住。应该用 Z+0.1 或更多。
        moonShadowNode.position = Vector3(0.5, 0.2, 0.5) -- 加大 X 偏移，调整 Z 确保覆盖
        moonShadowNode.scale = Vector3(1.1, 1.1, 1.1)    -- 稍微大一点，覆盖边缘

        local moonShadowModel = moonShadowNode:CreateComponent("StaticModel")
        moonShadowModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))

        moonShadowMat_ = Material:new()
        moonShadowMat_:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffUnlit.xml"))
        -- 颜色将在 Update 中实时同步为 Fog 颜色，以融入天空背景
        moonShadowMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.0, 0.0, 0.0, 1.0)))
        moonShadowModel:SetMaterial(moonShadowMat_)

        moonNode_ = moonNode

        dayTime = 0.0
    else
        -- 旧方案：使用 LightGroup 或默认光照
        local lightGroupFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
        if lightGroupFile then
            local lightGroup = scene_:CreateChild("LightGroup")
            lightGroup:LoadXML(lightGroupFile:GetRoot())
        else
            -- 回退方案：创建基本光照
            local zoneNode = scene_:CreateChild("Zone")
            local zone = zoneNode:CreateComponent("Zone")
            zone.boundingBox = BoundingBox(Vector3(-1000, -1000, -1000), Vector3(1000, 1000, 1000))
            zone.ambientColor = Color(0.4, 0.4, 0.4)

            local lightNode = scene_:CreateChild("DirectionalLight")
            lightNode.direction = Vector3(-1, -1, -1)
            local light = lightNode:CreateComponent("Light")
            light.lightType = LIGHT_DIRECTIONAL
            light.color = Color(1, 0.9, 0.8)
        end
    end
end

function SetupCamera()
    cameraNode_ = scene_:CreateChild("Camera")
    local camera = cameraNode_:CreateComponent("Camera")
    camera.farClip = 1000.0 -- 增加远裁剪面以适应大场景

    local viewport = Viewport:new(scene_, camera)
    renderer:SetViewport(0, viewport)
end

function SetupNanoVG()
    vg = nvgCreate(1)
    if vg then
        fontNormal = nvgCreateFont(vg, "sans", "Fonts/MiSans-Regular.ttf")
    else
        print("Error: Failed to create NanoVG context")
    end
end

function CreateGameContent()
    -- 1. 地面 (扩大5倍，绿色草地)
    local floorNode = scene_:CreateChild("Floor")
    floorNode.scale = Vector3(500, 1, 500) -- 扩大5倍 (原100 -> 500)
    local floorModel = floorNode:CreateComponent("StaticModel")
    floorModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

    local floorMat = Material:new()
    -- ⚠️ PBR材质必须设置Technique
    floorMat:SetTechnique(0,
        cache:GetResource("Technique", "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    floorMat:SetShaderParameter("ColorFactor", Variant(Color(0.1, 0.6, 0.1))) -- 鲜艳的草地绿
    floorMat:SetShaderParameter("RoughnessFactor", Variant(0.9))              -- 粗糙度高，模拟草地
    floorModel:SetMaterial(floorMat)

    -- 2. 塔 (圆柱体) - 分段创建以显示高度变化
    towerNode_ = scene_:CreateChild("Tower")
    towerNode_.position = Vector3(0, 0, 0) -- 父节点原点

    local segmentHeight = CONFIG.TowerSegmentHeight or 50.0
    local totalHeight = CONFIG.TowerHeight
    local currentY = 0
    local segmentCount = math.ceil(totalHeight / segmentHeight)

    -- 彩虹色循环
    local colors = {
        Color(0.8, 0.2, 0.2), -- 红
        Color(0.8, 0.5, 0.2), -- 橙
        Color(0.8, 0.8, 0.2), -- 黄
        Color(0.2, 0.8, 0.2), -- 绿
        Color(0.2, 0.8, 0.8), -- 青
        Color(0.2, 0.2, 0.8), -- 蓝
        Color(0.5, 0.2, 0.8)  -- 紫
    }

    for i = 1, segmentCount do
        local h = segmentHeight
        -- 处理最后一段可能不足 segmentHeight 的情况
        if currentY + h > totalHeight then
            h = totalHeight - currentY
        end

        local segmentNode = towerNode_:CreateChild("TowerSegment")
        -- 圆柱体中心在(0,0,0)，所以位置是 currentY + h/2
        segmentNode.position = Vector3(0, currentY + h / 2, 0)
        segmentNode.scale = Vector3(4, h, 4) -- 宽4米

        local model = segmentNode:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))

        local mat = Material:new()
        mat:SetTechnique(0,
            cache:GetResource("Technique", "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))

        -- 循环颜色
        local colorIdx = ((i - 1) % #colors) + 1
        mat:SetShaderParameter("ColorFactor", Variant(colors[colorIdx]))
        mat:SetShaderParameter("RoughnessFactor", Variant(0.7))
        mat:SetShaderParameter("MetallicFactor", Variant(0.1))

        model:SetMaterial(mat)

        currentY = currentY + h
    end

    -- 2.1 平台 (塔顶圆柱)
    -- 塔半径 = 2 (Scale 4/2)
    -- 平台半径 = 5 (Scale 10)
    platformNode_ = scene_:CreateChild("Platform")
    platformNode_.position = Vector3(0, CONFIG.TowerHeight, 0)
    platformNode_.scale = Vector3(10, 1, 10) -- 半径5米，厚1米
    local platformModel = platformNode_:CreateComponent("StaticModel")
    platformModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))

    local platformMat = Material:new()
    platformMat:SetTechnique(0,
        cache:GetResource("Technique", "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    platformMat:SetShaderParameter("ColorFactor", Variant(Color(0.4, 0.4, 0.45)))
    platformMat:SetShaderParameter("RoughnessFactor", Variant(0.5))
    platformModel:SetMaterial(platformMat)

    -- 2.2 奖杯
    trophyNode_ = scene_:CreateChild("Trophy")
    trophyNode_.position = Vector3(0, CONFIG.TowerHeight + 1.0, 0)
    trophyNode_.scale = Vector3(0.5, 0.5, 0.5)
    local trophyModel = trophyNode_:CreateComponent("StaticModel")
    trophyModel:SetModel(cache:GetResource("Model", "Models/Pyramid.mdl"))

    local trophyMat = Material:new()
    trophyMat:SetTechnique(0,
        cache:GetResource("Technique", "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    trophyMat:SetShaderParameter("ColorFactor", Variant(Color(1.0, 0.84, 0.0))) -- 金色
    trophyMat:SetShaderParameter("MetallicFactor", Variant(1.0))
    trophyMat:SetShaderParameter("RoughnessFactor", Variant(0.1))
    trophyModel:SetMaterial(trophyMat)
    trophyActive = true

    -- 3. 玩家
    playerNode_ = scene_:CreateChild("Player")
    playerNode_.position = Vector3(10, 1, 10)                             -- 初始位置在塔外
    local playerModel = playerNode_:CreateComponent("StaticModel")
    playerModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl")) -- 用球代表玩家

    local playerMat = Material:new()
    playerMat:SetTechnique(0,
        cache:GetResource("Technique", "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    playerMat:SetShaderParameter("ColorFactor", Variant(Color(1.0, 0.2, 0.2))) -- 红色
    playerMat:SetShaderParameter("MetallicFactor", Variant(0.0))               -- 非金属
    playerMat:SetShaderParameter("RoughnessFactor", Variant(0.5))              -- 半光滑
    playerModel:SetMaterial(playerMat)

    -- 4. 装饰物 (树木和房屋)
    CreateDecorations()

    -- 5. 翅膀商店
    CreateWingShop()

    -- 6. 宠物商店
    CreatePetShop()

    -- 7. 创建NPC
    CreateNPCs()

    -- 8. 创建云朵
    CreateClouds()
end

function CreateNPCs()
    local npcCount = CONFIG.NPCCount or 8
    for i = 1, npcCount do
        -- 随机角度 & 随机半径，让 NPC 出生分布更自然
        local angle = math.random() * 360.0
        local minR = CONFIG.NPCSpawnMinRadius or 6.0
        local maxR = CONFIG.NPCSpawnMaxRadius or 14.0
        local dist = minR + math.random() * (maxR - minR)
        local x = math.cos(math.rad(angle)) * dist
        local z = math.sin(math.rad(angle)) * dist

        local npcNode = scene_:CreateChild("NPC_" .. i)
        npcNode.position = Vector3(x, 1.0, z)

        local model = npcNode:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))

        local mat = Material:new()
        mat:SetTechnique(0,
            cache:GetResource("Technique", "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
        -- 随机颜色
        local r, g, b = math.random(), math.random(), math.random()
        mat:SetShaderParameter("ColorFactor", Variant(Color(r, g, b)))
        mat:SetShaderParameter("RoughnessFactor", Variant(0.6))
        model:SetMaterial(mat)

        -- 为每个 NPC 在翅膀商店附近预生成一个稍微不同的停靠偏移，避免挤在同一点
        local shopOffsetAngle = math.rad(math.random() * 360)
        local shopRange = CONFIG.ShopRange or 8.0
        -- 让停靠点一定落在商店“内部”：半径略小于交互半径
        local minOff = 0.5
        local maxOff = math.max(1.5, shopRange - 1.5)
        local shopOffsetRadius = minOff + math.random() * (maxOff - minOff)

        -- 随机分配行为模式
        local behavior = "Straight"
        local weights = CONFIG.NPCBehaviorWeights or {}

        -- 计算总权重
        local totalWeight = 0
        local weightList = {}
        for k, v in pairs(weights) do
            totalWeight = totalWeight + v
            table.insert(weightList, { key = k, val = v })
        end

        if totalWeight > 0 then
            local rnd = math.random() * totalWeight
            local acc = 0
            for _, item in ipairs(weightList) do
                acc = acc + item.val
                if rnd <= acc then
                    behavior = item.key
                    break
                end
            end
        else
            behavior = "Straight" -- 默认兜底
        end

        table.insert(NPCs, {
            node = npcNode,
            color = Color(r, g, b),      -- 记录颜色以便 UI 使用
            state = "Idle",
            behavior = behavior,         -- 行为模式
            behaviorTimer = 0.0,         -- 行为决策计时器
            rotateDir = 0,               -- 当前旋转意图 (-1, 0, 1)
            targetRotateDir = 0,         -- 目标旋转意图
            timer = math.random() * 5.0, -- 初始随机等待
            baseClimbSpeed = 0,          -- 基础爬升速度 (原有 climbSpeed 改名)
            climbSpeed = 0,              -- 实际爬升速度 (受疲劳影响)
            climbDuration = 0,
            fatigueLevel = 0,            -- 疲劳等级
            climbTimer = 0.0,            -- 攀爬计时器 (用于疲劳计算)
            velocityY = 0,
            velocityH = Vector2(0, 0),
            walkSpeed = 8.0,              -- 与玩家平地移动速度一致
            walkPhase = 0.0,
            jumpWhileWalk = (i % 2 == 0), -- 一半 NPC 边跳边走（仅视觉）
            startFallY = 0.0,
            currentGravity = CONFIG.FallGravity or -200.0,
            finalFallTime = 0.0,
            shopOffsetAngle = shopOffsetAngle,
            shopOffsetRadius = shopOffsetRadius
        })
    end
end

function CreateClouds()
    -- 如果已有云朵节点，先清理
    local existClouds = scene_:GetChild("Clouds")
    if existClouds then
        existClouds:Remove()
    end

    local cloudsNode = scene_:CreateChild("Clouds")
    local cloudCount = 80
    local towerHeight = CONFIG.TowerHeight or 1500

    for i = 1, cloudCount do
        local cloudNode = cloudsNode:CreateChild("Cloud_" .. i)

        -- 随机位置：围绕塔分布
        local angle = math.random() * 360
        local dist = 50 + math.random() * 200 -- 距离塔中心 50~250 米

        local x = math.cos(math.rad(angle)) * dist
        local z = math.sin(math.rad(angle)) * dist
        local y = 50 + math.random() * (towerHeight + 100) -- 高度从 50 米到塔顶上空

        cloudNode.position = Vector3(x, y, z)

        -- 随机形状（扁平椭球体）
        local sx = 25 + math.random() * 30
        local sy = 8 + math.random() * 10
        local sz = 20 + math.random() * 25
        cloudNode.scale = Vector3(sx, sy, sz)

        local model = cloudNode:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl")) -- 改为球体

        local mat = Material:new()
        -- 使用支持透明的 Technique (DiffAlpha)
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffAlpha.xml"))
        -- 半透明白色
        mat:SetShaderParameter("MatDiffColor", Variant(Color(0.95, 0.95, 1.0, 0.5)))
        model:SetMaterial(mat)
    end
end

function UpdateNPCs(dt)
    for _, npc in ipairs(NPCs) do
        if npc.state == "Idle" then
            npc.timer = npc.timer - dt
            if npc.timer <= 0 then
                -- 先走向塔
                npc.state = "WalkToTower"
                npc.timer = 0
                npc.walkPhase = 0.0
            end
        elseif npc.state == "WalkToTower" then
            local pos = npc.node.position
            -- 始终在地面附近行走
            pos.y = 1.0

            -- 朝塔中心移动
            local dirToCenter = Vector3(-pos.x, 0, -pos.z)
            local dist = dirToCenter:Length()
            if dist > 0.001 then
                dirToCenter:Normalize()
                local move = Vector3(dirToCenter.x * npc.walkSpeed * dt, 0, dirToCenter.z * npc.walkSpeed * dt)
                pos.x = pos.x + move.x
                pos.z = pos.z + move.z

                -- 让 NPC 朝移动方向旋转
                local moveLen = Vector3(move.x, 0, move.z):Length()
                if moveLen > 0.0001 then
                    local yaw = math.deg(math.atan2(move.x, move.z))
                    npc.node.rotation = Quaternion(0, yaw, 0)
                end
            end

            -- 边跳边走的效果：用近似 -20 重力的一段抛物线节奏来模拟
            if npc.jumpWhileWalk then
                -- 设想一个类似玩家平地跳的周期：单次起跳+落地约 0.8s，这里用 0.8s 的半周期
                local halfPeriod = 0.8
                local omega = math.pi / halfPeriod -- 使 0~halfPeriod 对应 sin(0~π)
                npc.walkPhase = npc.walkPhase + dt * omega

                -- 高度曲线：h(t) ≈ A * sin(phase)，只取正半波，A 根据 v0=8, g=-20 的理想顶点 ~1.6 取 1.5
                local s = math.sin(npc.walkPhase)
                if s < 0 then s = 0 end
                local jumpHeight = 1.5 * s
                pos.y = 1.0 + jumpHeight
            end

            npc.node.position = pos

            -- 走到塔边就开始攀爬
            if dist <= 3.0 then
                npc.state = "Climbing"
                local minMult = CONFIG.NPCMinSpeedMult or 1.0
                local maxMult = CONFIG.NPCMaxSpeedMult or 10.0
                local speedMult = minMult + math.random() * (maxMult - minMult)
                local calcSpeed = CONFIG.ClimbSpeed * speedMult

                -- 速度限制：每秒不超过塔高的 10%
                local maxSpeed = CONFIG.TowerHeight * (CONFIG.MaxClimbSpeedPct or 0.10)
                if calcSpeed > maxSpeed then
                    calcSpeed = maxSpeed
                end
                npc.baseClimbSpeed = calcSpeed
                npc.climbSpeed = calcSpeed
                npc.climbTimer = 0.0
                npc.fatigueLevel = 0

                local minDur = CONFIG.NPCMinClimbDuration or 10.0
                local maxDur = CONFIG.NPCMaxClimbDuration or 40.0
                npc.climbDuration = minDur + math.random() * (maxDur - minDur)

                local dir = Vector3(pos.x, 0, pos.z)
                if dir:Length() > 0.001 then
                    dir:Normalize()
                    npc.node.position = Vector3(dir.x * 2.5, pos.y, dir.z * 2.5)
                end
            end
        elseif npc.state == "WalkToWingShop" then
            local target = CONFIG.ShopPosition
            local range = CONFIG.ShopRange or 8.0
            if not target then
                -- 如果没有记录商店位置，直接转去塔
                npc.state = "WalkToTower"
            else
                local pos = npc.node.position
                pos.y = 1.0

                -- 目标点 = 商店位置 + 每个 NPC 自己的随机偏移
                local offsetAngle = npc.shopOffsetAngle or 0.0
                local offsetRadius = npc.shopOffsetRadius or 1.5
                local targetPos = Vector3(
                    target.x + math.cos(offsetAngle) * offsetRadius,
                    0,
                    target.z + math.sin(offsetAngle) * offsetRadius
                )

                local dir = Vector3(targetPos.x - pos.x, 0, targetPos.z - pos.z)
                local dist = dir:Length()

                -- 走到自己目标点附近就停下（这里用较小距离，避免散在圈外）
                local stopDist = 0.8
                if dist > stopDist then
                    dir:Normalize()
                    local move = Vector3(dir.x * npc.walkSpeed * dt, 0, dir.z * npc.walkSpeed * dt)
                    pos.x = pos.x + move.x
                    pos.z = pos.z + move.z

                    -- 让 NPC 朝移动方向旋转
                    local moveLen = Vector3(move.x, 0, move.z):Length()
                    if moveLen > 0.0001 then
                        local yaw = math.deg(math.atan2(move.x, move.z))
                        npc.node.rotation = Quaternion(0, yaw, 0)
                    end
                end

                if npc.jumpWhileWalk then
                    local halfPeriod = 0.8
                    local omega = math.pi / halfPeriod
                    npc.walkPhase = npc.walkPhase + dt * omega
                    local s = math.sin(npc.walkPhase)
                    if s < 0 then s = 0 end
                    local jumpHeight = 1.5 * s
                    pos.y = 1.0 + jumpHeight
                end

                npc.node.position = pos

                -- 到达目标点附近，进入“停顿购买”状态
                if dist <= stopDist then
                    npc.state = "BuyingWing"
                    npc.timer = 1.0 + math.random() * 4.0 -- 停顿 1~5 秒
                end
            end
        elseif npc.state == "BuyingWing" then
            -- 模拟在商店前停顿思考 / 购买
            npc.timer = npc.timer - dt
            local pos = npc.node.position
            pos.y = 1.0
            npc.node.position = pos

            if npc.timer <= 0 then
                -- 停顿结束，换上翅膀，再回塔
                local level = 1 + math.random(0, 2)
                AttachWingsToNode(npc.node, level)
                npc.hasWings = true
                npc.state = "WalkToTower"
                npc.timer = 0
            end
        elseif npc.state == "Climbing" then
            npc.climbDuration = npc.climbDuration - dt
            local pos = npc.node.position

            -- 更新疲劳逻辑
            npc.climbTimer = (npc.climbTimer or 0) + dt
            local fatigueTime = CONFIG.FatigueTime or 10.0
            if npc.climbTimer >= fatigueTime then
                npc.climbTimer = npc.climbTimer - fatigueTime
                npc.fatigueLevel = (npc.fatigueLevel or 0) + 1
            end

            -- 应用疲劳减速
            local speedFactor = (CONFIG.FatigueSpeedFactor or 0.8) ^ (npc.fatigueLevel or 0)
            npc.climbSpeed = (npc.baseClimbSpeed or 50) * speedFactor

            -- 更新行为决策
            npc.behaviorTimer = (npc.behaviorTimer or 0) - dt
            if npc.behaviorTimer <= 0 then
                local minT = CONFIG.NPCBehaviorIntervalMin or 1.0
                local maxT = CONFIG.NPCBehaviorIntervalMax or 3.0
                npc.behaviorTimer = minT + math.random() * (maxT - minT)

                -- 获取最近的上方和下方目标
                local nearUpper = nil
                local nearLower = nil
                local minDistUp = 999
                local minDistDown = 999

                -- 扫描所有其他攀爬者 (包括玩家)
                local climbers = {}
                for otherIdx, other in ipairs(NPCs) do
                    if npc ~= other and other.state == "Climbing" then
                        table.insert(climbers, { pos = other.node.position, type = "npc" })
                    end
                end
                -- 加入玩家
                if currentState == GameState.Climbing then
                    table.insert(climbers, { pos = playerNode_.position, type = "player" })
                end

                for _, other in ipairs(climbers) do
                    local dy = other.pos.y - pos.y
                    local dist = (other.pos - pos):Length()

                    if dist < 8.0 then   -- 只关注附近的
                        if dy > 0.5 then -- 上方
                            if dist < minDistUp then
                                minDistUp = dist; nearUpper = other
                            end
                        elseif dy < -0.5 then -- 下方
                            if dist < minDistDown then
                                minDistDown = dist; nearLower = other
                            end
                        end
                    end
                end

                -- 根据行为模式决定旋转意图
                npc.targetRotateDir = 0

                if npc.behavior == "Straight" then
                    npc.targetRotateDir = 0
                elseif npc.behavior == "Random" then
                    local r = math.random()
                    if r < 0.33 then
                        npc.targetRotateDir = -1
                    elseif r < 0.66 then
                        npc.targetRotateDir = 1
                    else
                        npc.targetRotateDir = 0
                    end
                elseif npc.behavior == "Aggressive" and nearUpper then
                    -- 尝试追逐上方目标
                    local toTarget = nearUpper.pos - pos
                    local crossY = pos.z * toTarget.x - pos.x * toTarget.z
                    if crossY > 0 then
                        npc.targetRotateDir = 1 -- 逆时针/右
                    else
                        npc.targetRotateDir = -1
                    end -- 顺时针/左
                elseif npc.behavior == "Defensive" and nearLower then
                    -- 尝试避开下方目标
                    local toTarget = nearLower.pos - pos
                    local crossY = pos.z * toTarget.x - pos.x * toTarget.z
                    if crossY > 0 then
                        npc.targetRotateDir = -1 -- 反向避开
                    else
                        npc.targetRotateDir = 1
                    end
                elseif npc.behavior == "AvoidUpper" and nearUpper then
                    -- 尝试避开上方目标
                    local toTarget = nearUpper.pos - pos
                    local crossY = pos.z * toTarget.x - pos.x * toTarget.z
                    if crossY > 0 then
                        npc.targetRotateDir = -1
                    else
                        npc.targetRotateDir = 1
                    end
                end
            end

            -- 执行圆周运动
            npc.rotateDir = npc.targetRotateDir
            if npc.rotateDir ~= 0 then
                local rotateSpeed = 60.0 -- NPC 转得慢一点
                local currentAngle = math.deg(math.atan2(pos.x, pos.z))
                local nextAngle = currentAngle + npc.rotateDir * rotateSpeed * dt
                local rad = math.rad(nextAngle)
                local r = 2.5
                pos.x = math.sin(rad) * r
                pos.z = math.cos(rad) * r
                -- 更新旋转
                local yaw = math.deg(math.atan2(-pos.x, -pos.z))
                npc.node.rotation = Quaternion(0, yaw, 0)
            end

            -- 向上爬
            pos.y = pos.y + npc.climbSpeed * dt

            -- 如果到达塔顶
            if pos.y >= CONFIG.TowerHeight then
                pos.y = CONFIG.TowerHeight
                npc.node.position = pos

                -- 到达塔顶，先发呆
                npc.state = "OnTopIdle"
                npc.timer = math.random() * 3.0 -- 0~3秒

                -- 重置到塔顶边缘
                local dir = Vector3(pos.x, 0, pos.z)
                dir:Normalize()
                npc.node.position = Vector3(dir.x * 2.5, pos.y, dir.z * 2.5)

                -- 如果只是时间到了没到顶，则直接跳下
            elseif npc.climbDuration <= 0 then
                -- 跳下逻辑 (复用下面的 Falling 切换)
                npc.state = "Falling"
                npc.velocityY = CONFIG.JumpImpulse

                local dir = Vector3(pos.x, 0, pos.z)
                dir:Normalize()

                -- 随机偏转角度
                local angle = (math.random() - 0.5) * (CONFIG.NPCJumpAngleRange or 60.0) * 2
                local rot = Quaternion(0, angle, 0)
                dir = rot * dir

                local pushForce = CONFIG.PushForce
                npc.velocityH = Vector2(dir.x * pushForce, dir.z * pushForce)

                -- 重力计算
                local h = pos.y
                local v0 = CONFIG.JumpImpulse
                local g = CONFIG.FallGravity
                local targetY = 1.0
                local a = 0.5 * g
                local b = v0
                local c = h - targetY
                local delta = b * b - 4 * a * c
                local finalT = 0.0
                if delta >= 0 then
                    local t = (-b - math.sqrt(delta)) / (2 * a)
                    finalT = t
                    if t > 5.0 then
                        local t_limit = 5.0
                        local g_new = 2 * (targetY - h - v0 * t_limit) / (t_limit * t_limit)
                        npc.currentGravity = g_new
                        finalT = t_limit
                    else
                        npc.currentGravity = g
                    end
                else
                    npc.currentGravity = g
                end
                if finalT > 0 then
                    local maxDist = CONFIG.MaxJumpDistance
                    local maxSpeed = maxDist / finalT
                    local currentSpeed = npc.velocityH:Length()
                    if currentSpeed > maxSpeed then
                        npc.velocityH:Normalize()
                        npc.velocityH = npc.velocityH * maxSpeed
                    end
                end
                npc.startFallY = pos.y
            else
                -- 保持贴着塔 (如果没旋转，确保贴合)
                local dir = Vector3(pos.x, 0, pos.z)
                dir:Normalize()
                npc.node.position = Vector3(dir.x * 2.5, pos.y, dir.z * 2.5)
            end

            -- NPC 碰撞检测
            if CONFIG.EnableNPCCollision and npc.state == "Climbing" then
                for otherIdx, other in ipairs(NPCs) do
                    if npc ~= other and other.state == "Climbing" then
                        -- 圆柱体碰撞检测 (只检测 "我撞他"，即我在下他在上)
                        local hitDist = CONFIG.NPCCollisionRadius or 1.0
                        local myHeight = hitDist + math.max(0, (npc.climbSpeed or 0) * dt)

                        local hDist = Vector2(pos.x - other.node.position.x, pos.z - other.node.position.z):Length()

                        if hDist < hitDist then
                            -- 只判定我撞到了上方的他
                            if other.node.position.y >= pos.y and other.node.position.y <= pos.y + myHeight then
                                -- 发生碰撞
                                local meFall = true
                                local otherFall = true

                                -- 播放火花特效
                                SpawnSparks((pos + other.node.position) * 0.5, 20)

                                if CONFIG.CollisionHigherFallsOnly then
                                    if pos.y > other.node.position.y then
                                        otherFall = false
                                    else
                                        meFall = false
                                    end
                                end

                                if meFall then
                                    npc.state = "Falling"
                                    npc.velocityY = CONFIG.JumpImpulse
                                    npc.startFallY = pos.y
                                    npc.currentGravity = CONFIG.FallGravity
                                    local dir = Vector3(pos.x, 0, pos.z)
                                    dir:Normalize()
                                    npc.velocityH = Vector2(dir.x, dir.z) * CONFIG.PushForce
                                end

                                if otherFall then
                                    other.state = "Falling"
                                    other.velocityY = CONFIG.JumpImpulse
                                    other.startFallY = other.node.position.y
                                    other.currentGravity = CONFIG.FallGravity
                                    local dir = Vector3(other.node.position.x, 0, other.node.position.z)
                                    dir:Normalize()
                                    other.velocityH = Vector2(dir.x, dir.z) * CONFIG.PushForce
                                end

                                -- 播放火花 (只要有碰撞就播放)
                                local hitPos = (pos + other.node.position) * 0.5
                                local dirOut = Vector3(hitPos.x, 0, hitPos.z)
                                dirOut:Normalize()
                                hitPos = hitPos + dirOut * 0.5
                                SpawnSparks(hitPos, 15)

                                if meFall then break end
                            end
                        end
                    end
                end
            end

            if npc.state ~= "Falling" and npc.state ~= "OnTopIdle" then
                npc.node.position = pos
            end
        elseif npc.state == "OnTopIdle" then
            npc.timer = npc.timer - dt
            local pos = npc.node.position
            pos.y = CONFIG.TowerHeight + 0.5 -- 站在平台上
            npc.node.position = pos

            if npc.timer <= 0 then
                npc.state = "WalkToCenter"
                npc.walkSpeed = 5.0 -- 塔顶行走速度
            end
        elseif npc.state == "WalkToCenter" then
            local pos = npc.node.position
            pos.y = CONFIG.TowerHeight + 0.5

            -- 向中心移动
            local dirToCenter = Vector3(-pos.x, 0, -pos.z)
            local dist = dirToCenter:Length()

            if dist < 0.2 then
                -- 到达中心
                npc.state = "CenterIdle"
                npc.timer = math.random() * 2.0 -- 0~2秒
            else
                dirToCenter:Normalize()
                local move = Vector3(dirToCenter.x * npc.walkSpeed * dt, 0, dirToCenter.z * npc.walkSpeed * dt)
                pos.x = pos.x + move.x
                pos.z = pos.z + move.z
                npc.node.position = pos

                -- 朝向
                if move:LengthSquared() > 0.0001 then
                    local yaw = math.deg(math.atan2(move.x, move.z))
                    npc.node.rotation = Quaternion(0, yaw, 0)
                end
            end
        elseif npc.state == "CenterIdle" then
            npc.timer = npc.timer - dt
            local pos = npc.node.position
            pos.y = CONFIG.TowerHeight + 0.5
            npc.node.position = pos

            if npc.timer <= 0 then
                -- 准备走向边缘
                npc.state = "WalkToEdge"

                -- 随机选一个边缘方向
                local angle = math.random() * math.pi * 2
                npc.edgeDir = Vector3(math.sin(angle), 0, math.cos(angle))

                -- 朝向该方向
                local yaw = math.deg(math.atan2(npc.edgeDir.x, npc.edgeDir.z))
                npc.node.rotation = Quaternion(0, yaw, 0)
            end
        elseif npc.state == "WalkToEdge" then
            local pos = npc.node.position
            pos.y = CONFIG.TowerHeight + 0.5

            -- 沿选定方向移动
            local moveSpeed = npc.walkSpeed or 5.0
            local move = Vector3(npc.edgeDir.x * moveSpeed * dt, 0, npc.edgeDir.z * moveSpeed * dt)
            pos.x = pos.x + move.x
            pos.z = pos.z + move.z
            npc.node.position = pos

            -- 检查是否到达边缘 (平台半径约 5.0)
            local distFromCenter = Vector3(pos.x, 0, pos.z):Length()
            if distFromCenter > 5.0 then
                -- 到达边缘，跳下
                npc.state = "Falling"
                npc.velocityY = CONFIG.JumpImpulse

                local pushForce = CONFIG.PushForce
                npc.velocityH = Vector2(npc.edgeDir.x * pushForce, npc.edgeDir.z * pushForce)

                -- 重力计算
                local h = CONFIG.TowerHeight
                local v0 = CONFIG.JumpImpulse
                local g = CONFIG.FallGravity
                local targetY = 1.0
                local a = 0.5 * g
                local b = v0
                local c = h - targetY
                local delta = b * b - 4 * a * c
                local finalT = 0.0
                if delta >= 0 then
                    local t = (-b - math.sqrt(delta)) / (2 * a)
                    finalT = t
                    if t > 5.0 then
                        local t_limit = 5.0
                        local g_new = 2 * (targetY - h - v0 * t_limit) / (t_limit * t_limit)
                        npc.currentGravity = g_new
                        finalT = t_limit
                    else
                        npc.currentGravity = g
                    end
                else
                    npc.currentGravity = g
                end
                if finalT > 0 then
                    local maxDist = CONFIG.MaxJumpDistance
                    local maxSpeed = maxDist / finalT
                    local currentSpeed = npc.velocityH:Length()
                    if currentSpeed > maxSpeed then
                        npc.velocityH:Normalize()
                        npc.velocityH = npc.velocityH * maxSpeed
                    end
                end
                npc.startFallY = CONFIG.TowerHeight
            end
        elseif npc.state == "Falling" then
            -- 重力（使用与玩家相同的数值逻辑）
            local g = npc.currentGravity or CONFIG.FallGravity
            npc.velocityY = npc.velocityY + g * dt
            local pos = npc.node.position
            pos.y = pos.y + npc.velocityY * dt

            -- 水平移动
            pos.x = pos.x + npc.velocityH.x * dt
            pos.z = pos.z + npc.velocityH.y * dt


            -- 落地检测
            if pos.y <= 1.0 then
                pos.y = 1.0
                npc.velocityY = 0

                -- 落地时播放金币爆炸效果（只做视觉，不加玩家金币）
                local fallHeight = math.max(0.0, (npc.startFallY or 0) - 1.0)
                local coinCount = math.min(25, math.max(8, math.floor(fallHeight / 12)))
                if coinCount > 0 then
                    SpawnGoldCoins(pos, coinCount, npc.node)
                end

                -- 落地后决定下一步行为：有概率先去翅膀商店，再回塔；否则直接去塔
                local goShop = (not npc.hasWings) and (math.random() < 0.5) and CONFIG.ShopPosition ~= nil
                if goShop then
                    npc.state = "WalkToWingShop"
                    npc.timer = 0
                else
                    npc.state = "Idle"
                    local tMin = CONFIG.NPCLandIdleMin or 0.0
                    local tMax = CONFIG.NPCLandIdleMax or 3.0
                    npc.timer = tMin + math.random() * (tMax - tMin) -- 休息 tMin~tMax 秒
                end
            end
            npc.node.position = pos
        end
    end
end

function CreatePetShop()
    local shopNode = scene_:CreateChild("PetShop")
    -- 放在塔的另一侧 (-15, 0, 15)
    shopNode.position = Vector3(-15, 0, 15)
    shopNode.rotation = Quaternion(0, 135, 0) -- 朝向塔

    -- 商店主体 (圆柱)
    local body = shopNode:CreateChild("Body")
    body.position = Vector3(0, 2.5, 0)
    body.scale = Vector3(6, 5, 6)
    local bodyModel = body:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    local bodyMat = Material:new()
    bodyMat:SetTechnique(0,
        cache:GetResource("Technique", "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    bodyMat:SetShaderParameter("ColorFactor", Variant(Color(0.2, 0.6, 0.8))) -- 蓝色调
    bodyMat:SetShaderParameter("RoughnessFactor", Variant(0.5))
    bodyModel:SetMaterial(bodyMat)

    -- 商店圆顶 (半球，用Sphere压扁)
    local roof = shopNode:CreateChild("Roof")
    roof.position = Vector3(0, 5.0, 0)
    roof.scale = Vector3(5.5, 3, 5.5)
    local roofModel = roof:CreateComponent("StaticModel")
    roofModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    local roofMat = Material:new()
    roofMat:SetTechnique(0,
        cache:GetResource("Technique", "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    roofMat:SetShaderParameter("ColorFactor", Variant(Color(0.8, 0.9, 1.0))) -- 浅蓝
    roofModel:SetMaterial(roofMat)

    -- 招牌 (悬浮的球)
    local sign = shopNode:CreateChild("Sign")
    sign.position = Vector3(0, 7.5, 0)
    sign.scale = Vector3(1.5, 1.5, 1.5)
    local signModel = sign:CreateComponent("StaticModel")
    signModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    local signMat = Material:new()
    signMat:SetTechnique(0,
        cache:GetResource("Technique", "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    signMat:SetShaderParameter("ColorFactor", Variant(Color(1.0, 0.4, 0.6))) -- 粉色
    signMat:SetShaderParameter("EmissiveFactor", Variant(Color(1.0, 0.4, 0.6) * 2.0))
    signModel:SetMaterial(signMat)

    -- 注册到交互系统
    table.insert(Interactables, {
        position = shopNode.position,
        range = 8.0,
        name = "宠物商店",
        onInteract = function()
            PlayerData.IsPetShopOpen = true
        end
    })
end

function CreateWingShop()
    local shopNode = scene_:CreateChild("WingShop")
    -- 放在塔的一侧 (x=15, z=15)
    shopNode.position = Vector3(15, 0, 15)
    shopNode.rotation = Quaternion(0, 225, 0) -- 朝向塔

    -- 商店主体
    local body = shopNode:CreateChild("Body")
    body.position = Vector3(0, 2.5, 0)
    body.scale = Vector3(6, 5, 6)
    local bodyModel = body:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    local bodyMat = Material:new()
    bodyMat:SetTechnique(0,
        cache:GetResource("Technique", "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    bodyMat:SetShaderParameter("ColorFactor", Variant(Color(0.8, 0.2, 0.8))) -- 紫色调
    bodyMat:SetShaderParameter("RoughnessFactor", Variant(0.5))
    bodyModel:SetMaterial(bodyMat)

    -- 商店屋顶
    local roof = shopNode:CreateChild("Roof")
    roof.position = Vector3(0, 6.0, 0)
    roof.scale = Vector3(7, 3, 7)
    local roofModel = roof:CreateComponent("StaticModel")
    roofModel:SetModel(cache:GetResource("Model", "Models/Pyramid.mdl"))
    local roofMat = Material:new()
    roofMat:SetTechnique(0,
        cache:GetResource("Technique", "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    roofMat:SetShaderParameter("ColorFactor", Variant(Color(0.2, 0.1, 0.3))) -- 深紫色
    roofModel:SetMaterial(roofMat)

    -- 招牌 (悬浮的翅膀模型)
    local sign = shopNode:CreateChild("Sign")
    sign.position = Vector3(0, 8.5, 0)
    sign.scale = Vector3(3, 0.5, 1)
    local signModel = sign:CreateComponent("StaticModel")
    signModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    local signMat = Material:new()
    signMat:SetTechnique(0,
        cache:GetResource("Technique", "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    signMat:SetShaderParameter("ColorFactor", Variant(Color(1.0, 0.8, 0.0)))          -- 金色
    signMat:SetShaderParameter("EmissiveFactor", Variant(Color(1.0, 0.8, 0.0) * 2.0)) -- 发光
    signModel:SetMaterial(signMat)

    -- 记录商店位置供交互检测
    CONFIG.ShopPosition = shopNode.position
    CONFIG.ShopRange = 8.0

    -- 注册到交互系统
    table.insert(Interactables, {
        position = shopNode.position,
        range = 8.0,
        name = "翅膀商店",
        onInteract = function()
            -- 打开商店
            PlayerData.IsShopOpen = true
        end
    })
end

function CreateDecorations()
    -- 随机种子
    math.randomseed(os.time())

    -- 随机生成树木 (100棵)
    for i = 1, 100 do
        local angle = math.random() * 360
        local dist = 20 + math.random() * 200 -- 分布在塔周围 20-220 米处
        local x = math.cos(math.rad(angle)) * dist
        local z = math.sin(math.rad(angle)) * dist
        CreateTree(x, z)
    end

    -- 随机生成房屋 (20座)
    for i = 1, 20 do
        local angle = math.random() * 360
        local dist = 30 + math.random() * 150 -- 分布在塔周围 30-180 米处
        local x = math.cos(math.rad(angle)) * dist
        local z = math.sin(math.rad(angle)) * dist
        CreateHouse(x, z)
    end
end

function CreateTree(x, z)
    local treeNode = scene_:CreateChild("Tree")
    treeNode.position = Vector3(x, 0, z)
    -- 随机缩放
    local scale = 0.8 + math.random() * 0.4
    treeNode.scale = Vector3(scale, scale, scale)

    -- 树干
    local trunkNode = treeNode:CreateChild("Trunk")
    trunkNode.position = Vector3(0, 1.0, 0)
    trunkNode.scale = Vector3(0.6, 2, 0.6)
    local trunkModel = trunkNode:CreateComponent("StaticModel")
    trunkModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    local trunkMat = Material:new()
    trunkMat:SetTechnique(0,
        cache:GetResource("Technique", "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    trunkMat:SetShaderParameter("ColorFactor", Variant(Color(0.45, 0.3, 0.15))) -- 深棕色
    trunkMat:SetShaderParameter("RoughnessFactor", Variant(0.9))
    trunkModel:SetMaterial(trunkMat)

    -- 树冠 (圆锥)
    local leavesNode = treeNode:CreateChild("Leaves")
    leavesNode.position = Vector3(0, 3.0, 0)
    leavesNode.scale = Vector3(2.5, 3.5, 2.5)
    local leavesModel = leavesNode:CreateComponent("StaticModel")
    leavesModel:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
    local leavesMat = Material:new()
    leavesMat:SetTechnique(0,
        cache:GetResource("Technique", "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    -- 随机一点绿色变化
    local g = 0.4 + math.random() * 0.2
    leavesMat:SetShaderParameter("ColorFactor", Variant(Color(0.1, g, 0.1))) -- 丰富的绿色
    leavesMat:SetShaderParameter("RoughnessFactor", Variant(0.8))
    leavesModel:SetMaterial(leavesMat)
end

function CreateHouse(x, z)
    local houseNode = scene_:CreateChild("House")
    houseNode.position = Vector3(x, 0, z)
    -- 随机朝向
    houseNode.rotation = Quaternion(0, math.random() * 360, 0)

    -- 房子主体 (盒子)
    local bodyNode = houseNode:CreateChild("Body")
    bodyNode.position = Vector3(0, 1.5, 0) -- 高度的一半
    bodyNode.scale = Vector3(4, 3, 4)
    local bodyModel = bodyNode:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    local bodyMat = Material:new()
    bodyMat:SetTechnique(0,
        cache:GetResource("Technique", "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    -- 随机墙体颜色 (米色、浅蓝、浅粉)
    local colors = { Color(0.9, 0.8, 0.7), Color(0.8, 0.9, 1.0), Color(1.0, 0.9, 0.9) }
    bodyMat:SetShaderParameter("ColorFactor", Variant(colors[math.random(1, #colors)]))
    bodyMat:SetShaderParameter("RoughnessFactor", Variant(0.6))
    bodyModel:SetMaterial(bodyMat)

    -- 屋顶 (四棱锥)
    local roofNode = houseNode:CreateChild("Roof")
    roofNode.position = Vector3(0, 3.5, 0) -- 房体高度3 + 屋顶一半高度
    roofNode.scale = Vector3(5, 2, 5)      -- 比房体略宽
    local roofModel = roofNode:CreateComponent("StaticModel")
    roofModel:SetModel(cache:GetResource("Model", "Models/Pyramid.mdl"))
    local roofMat = Material:new()
    roofMat:SetTechnique(0,
        cache:GetResource("Technique", "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    -- 随机屋顶颜色 (红、蓝、深灰)
    local roofColors = { Color(0.8, 0.2, 0.2), Color(0.2, 0.3, 0.7), Color(0.3, 0.3, 0.35) }
    roofMat:SetShaderParameter("ColorFactor", Variant(roofColors[math.random(1, #roofColors)]))
    roofMat:SetShaderParameter("RoughnessFactor", Variant(0.5))
    roofModel:SetMaterial(roofMat)
end

-- ============================================================================
-- 纪念品开箱系统
-- ============================================================================

local function GenerateUUID()
    return os.time() .. math.random(1000, 9999)
end

-- 从宝箱池中随机抽取一个纪念品
local function RollSouvenirFromChest(chestCfg)
    local totalWeight = 0
    local pool = {} -- {id, weight}

    for _, sId in ipairs(chestCfg.pool) do
        local cfg = SOUVENIR_CONFIG[sId]
        if cfg and cfg.weight then
            table.insert(pool, { id = sId, weight = cfg.weight })
            totalWeight = totalWeight + cfg.weight
        end
    end

    if totalWeight <= 0 then return nil end

    local rnd = math.random() * totalWeight
    local current = 0
    for _, item in ipairs(pool) do
        current = current + item.weight
        if rnd <= current then
            return item.id
        end
    end
    return pool[#pool].id
end

function StartChestRoll()
    if not PlayerData.SelectedChestIndex then return end
    local chestInfo = PlayerData.SouvenirChests[PlayerData.SelectedChestIndex]
    if not chestInfo or chestInfo.count <= 0 then return end

    local chestCfg = SOUVENIR_CHEST_CONFIG[chestInfo.id]
    if not chestCfg then return end

    local rewardId = RollSouvenirFromChest(chestCfg)
    if not rewardId then return end

    ChestRollState.active = true
    ChestRollState.chestIndex = PlayerData.SelectedChestIndex
    ChestRollState.chestId = chestInfo.id
    ChestRollState.rewardId = rewardId
    ChestRollState.elapsed = 0.0
    ChestRollState.duration = 3.0 -- 3秒滚动
    ChestRollState.skipRequested = false
    ChestRollState.isFinished = false

    -- 生成滚动序列 (Reel)
    -- 构造：[随机]...[随机][中奖][随机]...
    -- 比如总共 40 个，中奖在第 35 个
    ChestRollState.reel = {}
    local reelLen = 40
    local targetIdx = 35
    ChestRollState.targetIndex = targetIdx

    local pool = chestCfg.pool
    for i = 1, reelLen do
        if i == targetIdx then
            table.insert(ChestRollState.reel, rewardId)
        else
            -- 随机填充
            local randId = pool[math.random(#pool)]
            table.insert(ChestRollState.reel, randId)
        end
    end
end

function UpdateChestRoll(dt)
    if not ChestRollState.active then return end
    if ChestRollState.isFinished then return end -- 等待领取，不更新动画

    ChestRollState.elapsed = ChestRollState.elapsed + dt

    if ChestRollState.skipRequested or ChestRollState.elapsed >= ChestRollState.duration then
        ChestRollState.elapsed = ChestRollState.duration -- 确保停在最后
        ChestRollState.isFinished = true
    end
end

function FinishChestRoll()
    if not ChestRollState.active then return end

    local cIdx = ChestRollState.chestIndex
    local chest = PlayerData.SouvenirChests[cIdx]

    if chest and chest.count > 0 then
        chest.count = chest.count - 1
        if chest.count <= 0 then
            table.remove(PlayerData.SouvenirChests, cIdx)
            PlayerData.SelectedChestIndex = nil
        end

        -- 发放奖励
        local rewardId = ChestRollState.rewardId
        local newSouvenir = {
            uuid = GenerateUUID(),
            configId = rewardId,
            star = 1, -- 初始1星
            obtainedTime = os.time()
        }
        table.insert(PlayerData.SouvenirInventory, newSouvenir)

        -- 打印结果日志
        print("开箱获得: " .. tostring(SOUVENIR_CONFIG[rewardId].name))
    end
    ChestRollState.active = false
    ChestRollState.isFinished = false
end

-- ============================================================================
-- 4. 事件处理
-- ============================================================================

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PreRenderUI", "HandleNanoVGRender")
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 1. 玩家控制与状态机
    UpdatePlayer(dt)

    -- 2. 相机跟随
    UpdateCamera(dt)

    -- 3. 更新特效 (金币、震屏)
    UpdateEffects(dt)

    -- 4. NPC行为
    UpdateNPCs(dt)

    -- 5. 商店购买逻辑
    UpdateInteraction(dt)
    UpdateShop()
    UpdatePetShop(dt)
    UpdateBag(dt)
    UpdateCheats(dt)
    UpdateChestRoll(dt)
    UpdateDayNightCycle(dt)
end

function CreatePet(configId)
    local cfg = PET_CONFIG[configId]
    if not cfg then return nil end

    return {
        uuid = os.time() .. math.random(1000, 9999), -- 简单生成唯一ID
        configId = configId,
        star = 1,
        name = cfg.name,
        bonus = cfg.baseBonus or 1, -- 初始加成
        isEquipped = false          -- 是否已装备
    }
end

function GachaPull(times)
    -- 检查背包容量
    local currentCount = #PlayerData.PetInventory
    if currentCount + times > CONFIG.MaxPetCount then
        print("Inventory is full! Cannot pull.")
        return
    end

    local cost = times * GACHA_PRICE
    if PlayerData.GoldTotal < cost then
        print("Not enough gold!")
        return
    end

    PlayerData.GoldTotal = PlayerData.GoldTotal - cost

    print(string.format("Gacha Pull x%d (Cost: %d)", times, cost))

    -- 计算纪念品对稀有宠物概率的加成
    local souvenirBonuses = GetSouvenirBonuses()
    local rareMult = souvenirBonuses.rarePetWeightMult or 1.0

    -- 预计算权重表（考虑稀有宠物概率加成），并得到总权重
    local weightCache = {}
    local totalWeight = 0
    for id, cfg in ipairs(PET_CONFIG) do
        local w = cfg.chance
        -- 将“3级以上（不含3级）”理解为配置中较稀有的宠物，这里对应 id >= 4
        if id >= 4 then
            w = w * rareMult
        end
        weightCache[id] = w
        totalWeight = totalWeight + w
    end
    if totalWeight <= 0 then
        totalWeight = 1 -- 兜底，防止除零
    end

    for i = 1, times do
        -- 在 [0, totalWeight) 区间内随机抽取
        local r = math.random() * totalWeight
        local current = 0
        local resultId = nil

        -- 计算掉落（使用调整后的权重）
        for id, cfg in ipairs(PET_CONFIG) do
            local w = weightCache[id] or cfg.chance
            current = current + w
            if r <= current then
                resultId = id
                break
            end
        end

        -- 添加到背包
        if resultId then
            local newPet = CreatePet(resultId)
            if newPet then
                table.insert(PlayerData.PetInventory, newPet)
                print("Got Pet: " .. newPet.name)
            end
        end
    end
end

function UpdateBag(dt)
    -- B 键切换背包
    if input:GetKeyPress(KEY_B) then
        PlayerData.IsBagOpen = not PlayerData.IsBagOpen
        SetMouseMode(PlayerData.IsBagOpen)

        -- 如果打开背包，关闭其他界面
        if PlayerData.IsBagOpen then
            PlayerData.IsShopOpen = false
            PlayerData.IsPetShopOpen = false
        end
    end

    if PlayerData.IsBagOpen then
        -- ESC 或 X 关闭
        if input:GetKeyPress(KEY_ESCAPE) or input:GetKeyPress(KEY_X) then
            PlayerData.IsBagOpen = false
            SetMouseMode(false)
        end
    end
end

function UpdatePetShop(dt)
    -- 商店逻辑主要由 UI 驱动
end

function UpdateCheats(dt)
    -- F3 切换显示
    if input:GetKeyPress(KEY_F3) then
        ShowCheatMenu = not ShowCheatMenu
    end

    if not ShowCheatMenu then return end

    -- [1] 速度 +100
    if input:GetKeyPress(KEY_1) then
        CONFIG.ClimbSpeed = CONFIG.ClimbSpeed + 100
    end
    -- [2] 速度 -100
    if input:GetKeyPress(KEY_2) then
        CONFIG.ClimbSpeed = math.max(100, CONFIG.ClimbSpeed - 100)
    end
    -- [3] 金币 +100000
    if input:GetKeyPress(KEY_3) then
        PlayerData.GoldTotal = PlayerData.GoldTotal + 100000
    end
    -- [4] 重置疲劳
    if input:GetKeyPress(KEY_4) then
        PlayerData.ClimbTimer = 0
        PlayerData.FatigueLevel = 0
    end
    -- [5] 奖杯 +10000
    if input:GetKeyPress(KEY_5) then
        PlayerData.Trophies = PlayerData.Trophies + 10000
    end
    -- [6] 钻石 +500
    if input:GetKeyPress(KEY_6) then
        PlayerData.Diamonds = PlayerData.Diamonds + 500
    end
    -- [7] +10 法国纪念品宝箱
    if input:GetKeyPress(KEY_7) then
        local id = 1
        local found = false
        for _, chest in ipairs(PlayerData.SouvenirChests) do
            if chest.id == id then
                chest.count = chest.count + 10
                found = true
                break
            end
        end
        if not found then
            table.insert(PlayerData.SouvenirChests, { id = id, count = 10 })
        end
        print("Cheat: Added 10 French Souvenir Chests")
    end
end

function SetMouseMode(visible)
    input.mouseVisible = visible
    if visible then
        input.mouseMode = MM_FREE
    else
        input.mouseMode = MM_RELATIVE
    end
end

function SetMouseMode(visible)
    input.mouseVisible = visible
    if visible then
        input.mouseMode = MM_FREE
    else
        input.mouseMode = MM_RELATIVE
    end
end

function UpdateInteraction(dt)
    -- 检测最近的交互对象
    local playerPos = playerNode_.position
    local nearest = nil
    local minDst = 9999

    for _, obj in ipairs(Interactables) do
        local dist = (playerPos - obj.position):Length()
        if dist <= obj.range then
            if dist < minDst then
                minDst = dist
                nearest = obj
            end
        end
    end

    PlayerData.CurrentInteractable = nearest

    -- 如果离开了交互范围，自动关闭商店
    if not nearest then
        if PlayerData.IsShopOpen then
            PlayerData.IsShopOpen = false
            SetMouseMode(false)
        end
        if PlayerData.IsPetShopOpen then
            PlayerData.IsPetShopOpen = false
            SetMouseMode(false)
        end
    else
        -- 如果当前有最近对象，但不是对应的商店，也应该关闭另一个
        -- 这里简单处理：如果最近的是A，那么B肯定远了（假设商店不重叠），所以可以依赖上面的 not nearest 逻辑
        -- 但为了更严谨，如果 nearest.name 不匹配，也应该关闭对应的
        if nearest.name ~= "翅膀商店" and PlayerData.IsShopOpen then
            PlayerData.IsShopOpen = false
            SetMouseMode(false)
        end
        if nearest.name ~= "宠物商店" and PlayerData.IsPetShopOpen then
            PlayerData.IsPetShopOpen = false
            SetMouseMode(false)
        end
    end

    -- 按 F 键交互
    if nearest and input:GetKeyPress(KEY_F) then
        if nearest.onInteract then
            nearest.onInteract()
            SetMouseMode(true)
        end
    end
end

function UpdateShop()
    -- 只有当商店界面打开时，才允许操作
    if not PlayerData.IsShopOpen then return end
    -- 移除键盘快捷键，全靠鼠标操作
end

function AttachWingsToNode(targetNode, level)
    -- 移除旧翅膀
    local leftWing = targetNode:GetChild("LeftWing", true)
    if leftWing then leftWing:Remove() end
    local rightWing = targetNode:GetChild("RightWing", true)
    if rightWing then rightWing:Remove() end

    if level <= 0 then return end

    local config = WING_LEVELS[level]
    if not config then return end

    -- 创建翅膀几何体 (用Box模拟)
    local createWing = function(name, dir)
        local wingNode = targetNode:CreateChild(name)
        -- 翅膀位置：在身后(Z-0.5)，向两侧延伸(X)，略微向上(Y)
        wingNode.position = Vector3(0.6 * dir, 0.5, -0.4)
        -- 旋转：向后倾斜
        wingNode.rotation = Quaternion(0, -30 * dir, -15 * dir)
        wingNode.scale = Vector3(0.8 * config.scale, 0.1, 0.4 * config.scale)

        local model = wingNode:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

        local mat = Material:new()
        mat:SetTechnique(0,
            cache:GetResource("Technique", "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
        mat:SetShaderParameter("ColorFactor", Variant(config.color))
        mat:SetShaderParameter("RoughnessFactor", Variant(0.3))
        mat:SetShaderParameter("MetallicFactor", Variant(0.8)) -- 翅膀稍微有点金属质感
        model:SetMaterial(mat)

        -- 增加第二层羽毛细节
        local subWing = wingNode:CreateChild("Sub")
        subWing.position = Vector3(0.5 * dir, 0, 0.2)
        subWing.scale = Vector3(0.8, 1, 0.8)
        subWing.rotation = Quaternion(0, 15 * dir, 0)
        local subModel = subWing:CreateComponent("StaticModel")
        subModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        subModel:SetMaterial(mat)
    end

    createWing("LeftWing", -1)
    createWing("RightWing", 1)
end

function UpdateWingVisuals()
    AttachWingsToNode(playerNode_, PlayerData.WingLevel)
end

function UpdatePlayer(dt)
    -- 预先计算当前所有已装备纪念品的属性加成
    local souvenirBonuses = GetSouvenirBonuses()

    -- 更新嘲讽文字倒计时 (全局更新，不依赖状态)
    if PlayerData.FallMessageTimer and PlayerData.FallMessageTimer > 0 then
        PlayerData.FallMessageTimer = PlayerData.FallMessageTimer - dt
    end

    -- 奖杯旋转动画
    if trophyNode_ and trophyActive then
        trophyNode_:Rotate(Quaternion(90 * dt, 0, 0))
    end

    if currentState == GameState.Idle then
        -- WASD 移动 (相对于相机 Yaw)
        local speed = 8.0
        local moveDir = Vector3(0, 0, 0)

        -- 获取相机水平朝向
        local cameraRot = Quaternion(0, yaw_, 0)

        if input:GetKeyDown(KEY_W) then moveDir = moveDir + Vector3(0, 0, 1) end
        if input:GetKeyDown(KEY_S) then moveDir = moveDir + Vector3(0, 0, -1) end
        if input:GetKeyDown(KEY_A) then moveDir = moveDir + Vector3(-1, 0, 0) end
        if input:GetKeyDown(KEY_D) then moveDir = moveDir + Vector3(1, 0, 0) end

        if moveDir:LengthSquared() > 0 then
            moveDir:Normalize()
            -- 变换方向
            local worldDir = cameraRot * moveDir
            playerNode_:Translate(worldDir * speed * dt, TS_WORLD)
        end

        -- 玩家旋转跟随相机，这样翅膀才能显示在背面
        local targetRot = Quaternion(0, yaw_, 0)
        -- 平滑旋转
        playerNode_.rotation = playerNode_.rotation:Slerp(targetRot, 10.0 * dt)

        -- 检测是否靠近塔
        local dist = Vector3(playerNode_.position.x, 0, playerNode_.position.z):Length()
        -- 塔半径约2米(scale 4/2)，加上玩家半径0.5，加上吸附范围
        local towerRadius = 2.0
        if dist < (towerRadius + CONFIG.SnapRange) then
            StartClimbing()
        end

        -- 地面跳跃
        if input:GetKeyPress(KEY_SPACE) then
            StartFalling(true) -- true 表示从地面起跳
        end
    elseif currentState == GameState.Climbing then
        -- 输入控制方向
        local inputDir = 0
        if input:GetKeyDown(KEY_W) then inputDir = 1 end
        if input:GetKeyDown(KEY_S) then inputDir = -1 end

        -- 左右圆周运动 (围绕塔身旋转)
        -- 按住 A 向左转，D 向右转
        local rotateDir = 0
        if input:GetKeyDown(KEY_A) then rotateDir = 1 end  -- 原 -1，改为 1
        if input:GetKeyDown(KEY_D) then rotateDir = -1 end -- 原 1，改为 -1

        -- 只有在移动（上下或左右）时才更新疲劳时间
        if inputDir ~= 0 or rotateDir ~= 0 then
            -- 更新攀爬时间
            PlayerData.ClimbTimer = PlayerData.ClimbTimer + dt

            -- 计算疲劳等级 (每 FatigueInterval 增加一级)
            local newLevel = math.floor(PlayerData.ClimbTimer / CONFIG.FatigueInterval)

            -- 检测等级变化，触发提示
            if newLevel > PlayerData.FatigueLevel then
                PlayerData.FatigueLevel = newLevel
                PlayerData.FatigueTextTimer = CONFIG.FatigueDuration -- 显示文字的时间
            end
        end

        -- 更新文字倒计时
        if PlayerData.FatigueTextTimer > 0 then
            PlayerData.FatigueTextTimer = PlayerData.FatigueTextTimer - dt
        end

        -- 计算当前速度 (随疲劳等级指数衰减)
        local speedFactor = CONFIG.FatigueSpeedFactor ^ PlayerData.FatigueLevel
        local wingFactor = 1.0
        if PlayerData.WingLevel > 0 and WING_LEVELS[PlayerData.WingLevel] then
            wingFactor = WING_LEVELS[PlayerData.WingLevel].speedMult
        end

        -- 纪念品：攀爬速度加成（如“马卡龙”）
        local climbBonus = souvenirBonuses.climbSpeedMult or 1.0

        local speedMagnitude = CONFIG.ClimbSpeed * speedFactor * wingFactor * climbBonus

        -- 速度限制：每秒不超过塔高的 10% (CONFIG.MaxClimbSpeedPct)
        local maxSpeed = CONFIG.TowerHeight * (CONFIG.MaxClimbSpeedPct or 0.10)
        if speedMagnitude > maxSpeed then
            speedMagnitude = maxSpeed
        end

        -- 应用方向
        local velocity = speedMagnitude * inputDir
        PlayerData.Altitude = PlayerData.Altitude + velocity * dt

        -- 左右圆周运动 (围绕塔身旋转)
        -- 按住 A 向左转，D 向右转
        -- 塔半径 attachRadius = 2.5，圆周长 = 2 * pi * 2.5 ≈ 15.7m
        -- 每秒 90度 = 1/4 圈
        local rotateSpeed = 90.0 -- 度/秒
        -- rotateDir 在上面已经获取过了
        -- local rotateDir = 0
        -- if input:GetKeyDown(KEY_A) then rotateDir = 1 end
        -- if input:GetKeyDown(KEY_D) then rotateDir = -1 end

        if rotateDir ~= 0 then
            -- 当前位置相对于塔中心(0,0,0)的角度
            local currentPos = playerNode_.position
            local currentAngle = math.deg(math.atan2(currentPos.x, currentPos.z))

            -- 更新角度 (注意 atan2 的角度方向，通常逆时针为正)
            -- 我们希望 A(左) 逆时针转，D(右) 顺时针转
            -- 但屏幕上的左右取决于相机视角。假设相机在玩家背后。
            -- 玩家面向塔时，左手边是圆切线逆时针方向（俯视）。
            -- 简单处理：直接修改角度
            local nextAngle = currentAngle + rotateDir * rotateSpeed * dt

            -- 计算新位置 (保持高度不变)
            -- 塔半径在后面会统一修正为 attachRadius，这里先算方向
            -- 注意：playerNode_.position 在后面会被吸附逻辑覆盖 X/Z，
            -- 但吸附逻辑依赖于当前位置的 X/Z 来计算方向。
            -- 所以我们只需要旋转当前位置向量即可。

            local rad = math.rad(nextAngle)
            -- 临时半径，稍后吸附会修正
            local r = 2.5
            playerNode_.position = Vector3(
                math.sin(rad) * r, -- 注意 atan2(x, z) 对应的还原是 x=sin, z=cos
                PlayerData.Altitude,
                math.cos(rad) * r
            )

            -- 同时更新相机 Yaw，让相机跟随玩家旋转，保持玩家在屏幕中心
            -- 这样操作才符合直觉 (一直按A一直转)
            yaw_ = yaw_ + rotateDir * rotateSpeed * dt
        end

        -- NPC 碰撞检测
        if CONFIG.EnableNPCCollision then
            local pPos = playerNode_.position
            local hitDist = CONFIG.NPCCollisionRadius or 1.0

            for _, npc in ipairs(NPCs) do
                -- 只有当 NPC 也在攀爬状态时才检测碰撞
                if npc.state == "Climbing" then
                    local nPos = npc.node.position
                    -- 圆柱体碰撞检测
                    local pHeight = hitDist + math.max(0, velocity * dt)              -- 玩家向上判定高度 (基础 + 速度延伸)
                    local nHeight = hitDist + math.max(0, (npc.climbSpeed or 0) * dt) -- NPC 向上判定高度

                    local hDist = Vector2(pPos.x - nPos.x, pPos.z - nPos.z):Length()

                    if hDist < hitDist then
                        local isHit = false

                        -- 1. 玩家撞 NPC (玩家在下，NPC在上)
                        if nPos.y >= pPos.y and nPos.y <= pPos.y + pHeight then
                            isHit = true
                        end

                        -- 2. NPC 撞 玩家 (NPC在下，玩家在上)
                        if not isHit and pPos.y >= nPos.y and pPos.y <= nPos.y + nHeight then
                            isHit = true
                        end

                        if isHit then
                            -- 默认双方都掉落
                            local playerFalls = true
                            local npcFalls = true

                            -- 播放火花特效
                            SpawnSparks((pPos + nPos) * 0.5, 20)

                            -- 如果开启了“仅高处掉落”规则
                            if CONFIG.CollisionHigherFallsOnly then
                                if pPos.y > nPos.y then
                                    -- 玩家在上方，玩家掉落，NPC 幸存
                                    npcFalls = false
                                else
                                    -- NPC 在上方，NPC 掉落，玩家幸存
                                    playerFalls = false
                                end
                            end

                            if playerFalls then
                                -- 触发碰撞：玩家跳下
                                StartFalling(false)

                                -- 显示嘲讽文字
                                local msgs = { "Man!", "What can i say?" }
                                PlayerData.FallMessage = msgs[math.random(1, #msgs)]
                                PlayerData.FallMessageTimer = 1.0
                            end

                            if npcFalls then
                                -- NPC 也跳下
                                npc.state = "Falling"
                                npc.velocityY = CONFIG.JumpImpulse
                                npc.currentGravity = CONFIG.FallGravity
                                npc.startFallY = nPos.y

                                -- NPC 随机水平散开
                                local dir = Vector3(nPos.x, 0, nPos.z)
                                dir:Normalize()
                                npc.velocityH = Vector2(dir.x, dir.z) * CONFIG.PushForce
                            end

                            -- 播放震屏或其他反馈
                            shakeTimer = 0.2
                            shakePower = 0.5

                            -- 播放火花特效 (在碰撞点)
                            -- 简单计算碰撞中点：(pPos + nPos) / 2
                            local hitPos = (pPos + nPos) * 0.5
                            -- 稍微向塔外偏移一点，避免被塔遮挡
                            local dirOut = Vector3(hitPos.x, 0, hitPos.z)
                            dirOut:Normalize()
                            hitPos = hitPos + dirOut * 0.5

                            -- 复用爆金币的逻辑，或者新建一个 SpawnSparks 函数
                            SpawnSparks(hitPos, 15) -- 产生15个火花粒子

                            -- print("Crashed with NPC!")
                            break -- 一次只撞一个
                        end
                    end
                end
            end
        end

        -- 向下爬且高度过低时的特殊处理
        local minAlt = CONFIG.MinClimbAltitude or 1.0
        if inputDir < 0 and PlayerData.Altitude <= minAlt then
            -- 强制回到地面
            currentState = GameState.Idle
            PlayerData.Altitude = 1.0
            PlayerData.GoldAccumulated = 0
            PlayerData.VelocityY = 0

            -- 位移防止吸附 (塔半径2 + 吸附2.5 = 4.5，推到 6.0 处)
            local currentPos = playerNode_.position
            local dir = Vector3(currentPos.x, 0, currentPos.z)
            if dir:LengthSquared() > 0.001 then
                dir:Normalize()
            else
                dir = Vector3(1, 0, 0)
            end

            local pushDist = CONFIG.PushAwayDistance or 6.0
            playerNode_.position = Vector3(dir.x * pushDist, 1.0, dir.z * pushDist)

            return
        end

        -- 到达塔顶
        if PlayerData.Altitude >= CONFIG.TowerHeight then
            PlayerData.Altitude = CONFIG.TowerHeight
            EnterTopState()
        else
            -- 更新位置：吸附在塔表面
            local currentPos = playerNode_.position
            local dirToTower = Vector3(currentPos.x, 0, currentPos.z)
            dirToTower:Normalize()
            local attachRadius = 2.5 -- 塔半径2 + 玩家0.5

            playerNode_.position = Vector3(
                dirToTower.x * attachRadius,
                PlayerData.Altitude,
                dirToTower.z * attachRadius
            )

            -- 计算金币
            local totalBonus = 0
            for _, pet in ipairs(PlayerData.PetInventory) do
                if pet.isEquipped then
                    totalBonus = totalBonus + (pet.bonus or 0)
                end
            end
            PlayerData.GoldAccumulated = math.floor(PlayerData.Altitude * (CONFIG.GoldPerMeter + totalBonus))

            -- 检测跳下
            if input:GetKeyPress(KEY_SPACE) then
                -- 检测左右偏移
                local jumpAngleBias = 0.0
                if input:GetKeyDown(KEY_A) then
                    jumpAngleBias = 60.0  -- 原 -60，对调为 60
                elseif input:GetKeyDown(KEY_D) then
                    jumpAngleBias = -60.0 -- 原 60，对调为 -60
                end

                StartFalling(false, jumpAngleBias)
            end
        end
    elseif currentState == GameState.OnTop then
        -- 塔顶自由移动逻辑
        local speed = 8.0
        local moveDir = Vector3(0, 0, 0)
        local cameraRot = Quaternion(0, yaw_, 0)

        if input:GetKeyDown(KEY_W) then moveDir = moveDir + Vector3(0, 0, 1) end
        if input:GetKeyDown(KEY_S) then moveDir = moveDir + Vector3(0, 0, -1) end
        if input:GetKeyDown(KEY_A) then moveDir = moveDir + Vector3(-1, 0, 0) end
        if input:GetKeyDown(KEY_D) then moveDir = moveDir + Vector3(1, 0, 0) end

        if moveDir:LengthSquared() > 0 then
            moveDir:Normalize()
            local worldDir = cameraRot * moveDir
            playerNode_:Translate(worldDir * speed * dt, TS_WORLD)
        end

        -- 限制高度在平台表面
        local pos = playerNode_.position
        pos.y = CONFIG.TowerHeight + 0.5
        playerNode_.position = pos

        -- 检测是否掉出平台边缘 (平台半径约5米)
        local distH = Vector3(pos.x, 0, pos.z):Length()
        if distH > 5.2 then -- 稍微宽一点
            StartFalling()
        end

        -- 检测是否按空格跳下
        if input:GetKeyPress(KEY_SPACE) then
            -- 在平台上跳跃，当作地面跳跃处理
            StartFalling(true)
        end

        -- 检测拾取奖杯
        if trophyActive then
            local distTrophy = (pos - trophyNode_.position):Length()
            if distTrophy < 1.5 then
                CollectTrophy()
            end
        end
    elseif currentState == GameState.Falling then
        -- 动态检查：如果玩家在高处，且已经离开平台范围（水平距离 > 5.5米），但尚未应用加速重力（当前重力接近默认值），
        -- 则说明玩家是从平台上跳下来并离开了平台，需要立即重新计算重力以确保快速落地。
        local isHigh = PlayerData.Altitude > 100.0
        if isHigh then
            local distH = Vector3(playerNode_.position.x, 0, playerNode_.position.z):Length()
            local isOutsidePlatform = distH > 5.5 -- 平台半径约5米，加点余量
            local isDefaultGravity = math.abs(PlayerData.CurrentGravity - CONFIG.Gravity) < 0.01

            if isOutsidePlatform and isDefaultGravity then
                -- 重新计算加速重力
                local h = PlayerData.Altitude
                local v0 = PlayerData.VelocityY
                local targetY = 1.0
                local t_limit = 5.0 -- 限制剩余落地时间为5秒

                -- 解方程: 0.5*g*t^2 + v0*t + (h - targetY) = 0
                -- 反推 g_new: targetY = h + v0*t + 0.5*g_new*t^2
                -- 0.5*g_new*t^2 = targetY - h - v0*t
                -- g_new = 2*(targetY - h - v0*t) / t^2
                local g_new = 2 * (targetY - h - v0 * t_limit) / (t_limit * t_limit)

                -- 只有当新重力比默认重力更强（更负）时才应用
                if g_new < CONFIG.Gravity then
                    PlayerData.CurrentGravity = g_new
                    -- print("Dynamic Gravity Adjustment: " .. g_new)

                    -- 重新计算水平速度上限
                    if PlayerData.VelocityH:Length() > 0 then
                        local maxDist = CONFIG.MaxJumpDistance
                        local maxSpeed = maxDist / t_limit
                        local currentSpeed = PlayerData.VelocityH:Length()
                        if currentSpeed > maxSpeed then
                            PlayerData.VelocityH:Normalize()
                            PlayerData.VelocityH = PlayerData.VelocityH * maxSpeed
                        end
                    end
                end
            end
        end

        -- 应用重力
        PlayerData.VelocityY = PlayerData.VelocityY + PlayerData.CurrentGravity * dt

        -- 更新高度
        PlayerData.Altitude = PlayerData.Altitude + PlayerData.VelocityY * dt

        -- 应用水平速度
        local pos = playerNode_.position
        pos.x = pos.x + PlayerData.VelocityH.x * dt
        pos.z = pos.z + PlayerData.VelocityH.y * dt -- VelocityH.y 存储的是 Z 轴速度
        playerNode_.position = pos

        -- 同步 Y 轴
        local newPos = playerNode_.position
        newPos.y = PlayerData.Altitude
        playerNode_.position = newPos

        -- 空中吸附检测：如果在空中靠近塔，重新开始攀爬
        -- 只有当高度低于平台高度一定值时才触发吸附，避免在平台上跳跃被吸附
        if PlayerData.CanAirAttach and PlayerData.Altitude < (CONFIG.TowerHeight - 1.0) then
            local dist = Vector3(newPos.x, 0, newPos.z):Length()
            local towerRadius = 2.0
            if dist < (towerRadius + CONFIG.SnapRange) and PlayerData.Altitude > 1.0 then
                StartClimbing()
                return
            end
        end

        -- 落地检测 (增加垂直速度判断，防止刚起跳时误判落地)
        if PlayerData.VelocityY <= 0 and PlayerData.Altitude <= 1.0 then
            FinishFalling()
        end

        -- 平台落地检测：如果落在平台上
        -- 1. 垂直速度向下或为0
        -- 2. 高度在平台高度附近 (150 ~ 150.5)
        -- 3. 水平距离在平台半径内 (5.2)
        if PlayerData.VelocityY <= 0 and PlayerData.Altitude >= CONFIG.TowerHeight and PlayerData.Altitude <= (CONFIG.TowerHeight + 0.5) then
            local distH = Vector3(newPos.x, 0, newPos.z):Length()
            if distH < 5.2 then
                -- 落回平台
                EnterTopState()
            end
        end
    end

    -- 记录最高高度
    if PlayerData.Altitude > PlayerData.MaxAltitude then
        PlayerData.MaxAltitude = PlayerData.Altitude
    end
end

function StartClimbing()
    currentState = GameState.Climbing
    PlayerData.Altitude = playerNode_.position.y
    PlayerData.VelocityY = 0
    PlayerData.GoldAccumulated = 0

    -- 重置疲劳状态
    PlayerData.ClimbTimer = 0.0
    PlayerData.FatigueLevel = 0
    PlayerData.FatigueTextTimer = 0.0

    -- 刷新奖杯
    if trophyNode_ then
        trophyNode_.enabled = true
        trophyActive = true
    end
end

function EnterTopState()
    currentState = GameState.OnTop
    -- 确保在平台上
    local pos = playerNode_.position
    pos.y = CONFIG.TowerHeight + 0.5
    playerNode_.position = pos
end

function CollectTrophy()
    if not trophyActive then return end
    trophyActive = false
    trophyNode_.enabled = false

    -- 纪念品：奖杯获得率加成（如“皮包”）
    local bonuses = GetSouvenirBonuses()
    local gain = 1.0 * (bonuses.trophyMult or 1.0)
    PlayerData.TrophyProgress = (PlayerData.TrophyProgress or 0.0) + gain
    local intGain = math.floor(PlayerData.TrophyProgress)
    if intGain > 0 then
        PlayerData.Trophies = PlayerData.Trophies + intGain
        PlayerData.TrophyProgress = PlayerData.TrophyProgress - intGain
    end
    -- 可以加点特效
    SpawnGoldCoins(playerNode_.position, 10, playerNode_) -- 捡到奖杯爆点金币庆祝
end

function StartFalling(isGroundJump, jumpAngleBias)
    currentState = GameState.Falling
    PlayerData.VelocityY = CONFIG.JumpImpulse -- 向上起跳
    PlayerData.CanAirAttach = isGroundJump    -- 记录是否允许空中吸附

    -- 初始化文字计时器（防止残留）
    PlayerData.FallMessageTimer = 0.0

    -- jumpAngleBias: 默认为 0，单位为度，用于从塔上跳下时控制左右偏移

    -- 设置重力：地面跳跃用普通重力，高空下落用大重力
    if isGroundJump then
        PlayerData.CurrentGravity = CONFIG.Gravity
    else
        PlayerData.CurrentGravity = CONFIG.FallGravity
    end

    -- 计算预计落地时间，如果超过5秒则调整重力
    local h = PlayerData.Altitude
    local v0 = CONFIG.JumpImpulse
    local g = PlayerData.CurrentGravity -- 使用当前选定的重力
    local targetY = 1.0                 -- 地面高度 (地板表面0.5 + 玩家半径0.5)

    -- 解方程: 0.5*g*t^2 + v0*t + (h - targetY) = 0
    -- a=0.5g, b=v0, c=h-targetY
    -- t = (-b - sqrt(b^2 - 4ac)) / 2a  (取落地时间解)
    local a = 0.5 * g
    local b = v0
    local c = h - targetY
    local delta = b * b - 4 * a * c

    -- 修正：如果在高处（如塔顶平台）进行地面跳跃，不要应用加速重力，否则会导致瞬间速度向下而无法跳起
    local isHighPlatformJump = isGroundJump and (h > CONFIG.TowerHeight - 5.0)

    -- 记录最终的预计落地时间，用于限制水平位移
    local finalT = 0.0

    if delta >= 0 and not isHighPlatformJump then
        local t = (-b - math.sqrt(delta)) / (2 * a)
        -- print("Estimated fall time: " .. t)
        finalT = t

        if t > 5.0 then
            -- 限制落地时间为 5秒
            local t_limit = 5.0
            -- 反推 g_new: targetY = h + v0*t + 0.5*g_new*t^2
            -- 0.5*g_new*t^2 = targetY - h - v0*t
            -- g_new = 2*(targetY - h - v0*t) / t^2
            local g_new = 2 * (targetY - h - v0 * t_limit) / (t_limit * t_limit)
            PlayerData.CurrentGravity = g_new
            -- print("Adjusted Gravity: " .. g_new)
            finalT = t_limit
        end
    end

    -- 计算水平推力
    if isGroundJump then
        -- 地面起跳：继承当前的移动方向，但稍微减弱
        local cameraRot = Quaternion(0, yaw_, 0)
        local moveDir = Vector3(0, 0, 0)
        if input:GetKeyDown(KEY_W) then moveDir = moveDir + Vector3(0, 0, 1) end
        if input:GetKeyDown(KEY_S) then moveDir = moveDir + Vector3(0, 0, -1) end
        if input:GetKeyDown(KEY_A) then moveDir = moveDir + Vector3(-1, 0, 0) end
        if input:GetKeyDown(KEY_D) then moveDir = moveDir + Vector3(1, 0, 0) end

        if moveDir:LengthSquared() > 0 then
            moveDir:Normalize()
            local worldDir = cameraRot * moveDir
            -- 地面移动速度是 8.0，这里保持这个速度
            PlayerData.VelocityH = Vector2(worldDir.x, worldDir.z) * 8.0
        else
            PlayerData.VelocityH = Vector2(0, 0)
        end
    else
        -- 从塔上跳下：远离塔中心
        local currentPos = playerNode_.position
        local dirOut = Vector3(currentPos.x, 0, currentPos.z)
        dirOut:Normalize()

        -- 应用偏移角度 (如果按了A/D)
        if jumpAngleBias and jumpAngleBias ~= 0 then
            local rot = Quaternion(0, jumpAngleBias, 0)
            dirOut = rot * dirOut
        end

        PlayerData.VelocityH = Vector2(dirOut.x, dirOut.z) * CONFIG.PushForce
    end

    -- 限制最大水平推动距离 (20米)
    -- 只在计算了预计落地时间的情况下限制（即非塔顶平台起跳）
    if finalT > 0 then
        local maxDist = CONFIG.MaxJumpDistance
        local maxSpeed = maxDist / finalT
        local currentSpeed = PlayerData.VelocityH:Length()

        if currentSpeed > maxSpeed then
            -- 保持方向，缩减速度
            PlayerData.VelocityH:Normalize()
            PlayerData.VelocityH = PlayerData.VelocityH * maxSpeed
        end
    end
end

function FinishFalling()
    currentState = GameState.Idle
    PlayerData.Altitude = 1.0 -- 回到地面高度 (地板0.5 + 半径0.5)
    playerNode_.position = Vector3(playerNode_.position.x, 1.0, playerNode_.position.z)

    -- 触发落地表现 (只有在积累了金币/爬塔后才触发)
    if PlayerData.GoldAccumulated > 0 then
        shakeTimer = 0.4 -- 震屏 0.4秒
        shakePower = 1.0 -- 震动强度

        -- 金币爆散特效
        SpawnGoldCoins(playerNode_.position, math.min(PlayerData.GoldAccumulated, 30), playerNode_) -- 最多30个视觉金币

        -- 结算金币（纪念品“法棍”加成只影响最终实际获得的金币数量）
        local bonuses = GetSouvenirBonuses()
        local goldMult = bonuses.goldMult or 1.0
        local baseGold = PlayerData.GoldAccumulated
        local finalGold = baseGold
        if goldMult ~= 1.0 then
            finalGold = math.floor(baseGold * goldMult + 0.5)
        end

        PlayerData.GoldTotal = PlayerData.GoldTotal + finalGold
        PlayerData.GoldAccumulated = 0
    end
end

function UpdateCamera(dt)
    -- 只有当鼠标被锁定/隐藏时才允许旋转视角
    if not input.mouseVisible then
        -- 1. 鼠标控制旋转 (直接跟随鼠标)
        local sensitivity = 0.1
        yaw_ = yaw_ + input.mouseMoveX * sensitivity
        pitch_ = pitch_ + input.mouseMoveY * sensitivity
        pitch_ = Clamp(pitch_, -80, 80)
    end

    -- 2. 计算目标位置 (看向玩家头部)
    local targetHeight = 1.5 -- 看向玩家上方一点
    local targetPos = playerNode_.position + Vector3(0, targetHeight, 0)

    -- 3. 计算相机位置（带简易“弹簧臂”防穿地）
    local dist = CONFIG.CameraDistance or 15.0
    local rotation = Quaternion(pitch_, yaw_, 0)
    local offset = rotation * Vector3(0, 0, -dist)

    local desiredPos = targetPos + offset

    -- 简易弹簧臂：如果期望位置在地面以下，则沿着射线推回到地面高度附近
    local groundY = 1.0 -- 与玩家落地高度一致
    local finalPos = desiredPos
    if desiredPos.y < groundY + 0.5 then
        -- 线性插值：targetPos + t * offset，使得 y = groundY + 0.5
        local dy = desiredPos.y - targetPos.y
        if math.abs(dy) > 0.001 then
            local t = (groundY + 0.5 - targetPos.y) / dy
            t = Clamp(t, 0.0, 1.0)
            finalPos = targetPos + offset * t
        else
            finalPos.y = groundY + 0.5
        end
    end

    -- 4. 应用

    -- 应用震屏偏移
    if shakeTimer > 0 then
        local damping = shakeTimer / 0.4
        local offset = Vector3(
            (math.random() - 0.5) * shakePower * damping,
            (math.random() - 0.5) * shakePower * damping,
            (math.random() - 0.5) * shakePower * damping
        )
        finalPos = finalPos + offset
    end

    cameraNode_.position = finalPos
    cameraNode_.rotation = rotation
end

function Clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

-- ============================================================================
-- 5. 特效系统 (Effects)
-- ============================================================================

function SpawnGoldCoins(pos, count, targetNode)
    for i = 1, count do
        local coinNode = scene_:CreateChild("VisualCoin")
        coinNode.position = pos + Vector3(0, 1, 0) -- 从身体中心爆出
        coinNode.scale = Vector3(0.3, 0.05, 0.3)   -- 扁平圆柱

        local model = coinNode:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))

        local mat = Material:new()
        mat:SetTechnique(0,
            cache:GetResource("Technique", "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
        mat:SetShaderParameter("ColorFactor", Variant(Color(1.0, 0.8, 0.0))) -- 金色
        mat:SetShaderParameter("MetallicFactor", Variant(1.0))
        mat:SetShaderParameter("RoughnessFactor", Variant(0.2))
        model:SetMaterial(mat)

        -- 随机爆出速度
        local angle = math.random() * 360
        local speedH = 2.0 + math.random() * 4.0
        local vy = 5.0 + math.random() * 8.0 -- 向上高抛

        local vel = Vector3(
            math.cos(math.rad(angle)) * speedH,
            vy,
            math.sin(math.rad(angle)) * speedH
        )

        table.insert(activeCoins, {
            node = coinNode,
            velocity = vel,
            timer = 0.0,
            state = "pop", -- pop -> ground -> suck
            targetNode = targetNode
        })
    end
end

function SpawnSparks(position, count)
    -- 简单的火花粒子效果
    local sparkCount = count or 10
    for i = 1, sparkCount do
        local sparkNode = scene_:CreateChild("Spark")
        sparkNode.position = position
        local s = 0.1 + math.random() * 0.2
        sparkNode.scale = Vector3(s, s, s)

        local model = sparkNode:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

        local mat = Material:new()
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/DiffUnlit.xml"))
        mat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 0.5 + math.random() * 0.5, 0.0, 1.0)))
        model:SetMaterial(mat)

        local angle = math.random() * 360
        local vSpeed = math.random() * 10.0 + 4.0 -- 速度翻倍 (原 5.0+2.0)
        local hSpeed = math.random() * 6.0 + 2.0  -- 速度翻倍 (原 3.0+1.0)
        local vx = math.cos(math.rad(angle)) * hSpeed
        local vz = math.sin(math.rad(angle)) * hSpeed

        table.insert(Effects, {
            node = sparkNode,
            velocity = Vector3(vx, vSpeed, vz),
            timer = 0.5 + math.random() * 0.3,
            life = 0.5 + math.random() * 0.3,
            gravity = Vector3(0, -15.0, 0),
            type = "spark"
        })
    end
end

local function LerpColor(c1, c2, t)
    return Color(
        c1.r + (c2.r - c1.r) * t,
        c1.g + (c2.g - c1.g) * t,
        c1.b + (c2.b - c1.b) * t,
        c1.a + (c2.a - c1.a) * t
    )
end

function UpdateDayNightCycle(dt)
    if not CONFIG.EnableDayNightCycle then return end
    if not sunNode_ or not sunLight_ or not zone_ then return end

    local dayLen   = CONFIG.DayLength or 240.0
    dayTime        = (dayTime + dt) % dayLen
    local progress = dayTime / dayLen -- 0.0 ~ 1.0

    -- 太阳和月亮跟随玩家（模拟无穷远天体）
    if playerNode_ then
        local pPos = playerNode_.position
        -- 太阳跟随（太阳本身通过旋转来移动视觉位置，所以基准点跟人走即可）
        sunNode_.position = pPos

        -- 月亮跟随与显隐控制
        if moonNode_ then
            -- 仅在夜晚 (progress > 0.55 and progress < 0.95) 显示并跟随
            if progress > 0.55 and progress < 0.95 then
                moonNode_.enabled = true
                -- 月亮稍微调高一点，确保在头顶上方
                moonNode_.position = pPos + Vector3(-100, 800, 100)
            else
                moonNode_.enabled = false
                -- 双重保险：白天把月亮移到地底，防止 enabled 失效导致看到黑球
                moonNode_.position = pPos + Vector3(0, -5000, 0)
            end
        end
    end

    -- 1. 太阳位置旋转
    -- 0.0 (日出) -> 0 deg (East in Logic) -> Light points West (-X)
    -- 0.25 (正午) -> 90 deg (Top) -> Light points Down (-Y)
    -- 0.5 (日落) -> 180 deg (West) -> Light points East (+X)
    -- 0.75 (午夜) -> 270 deg (Bottom) -> Light points Up (+Y)

    -- 初始旋转：Forward = (-1, 0, 0) 即 Quaternion(0, -90, 0)
    -- 绕 Z 轴旋转：Quaternion(0, 0, angle)

    local rotZ        = progress * 360.0
    sunNode_.rotation = Quaternion(0, 0, rotZ) * Quaternion(0, -90, 0)

    -- 2. 颜色变化
    -- 定义关键帧颜色 (正午亮度增强)
    local c_sunrise   = { light = Color(1.0, 0.6, 0.3), ambient = Color(0.3, 0.2, 0.2), fog = Color(0.4, 0.3, 0.3) }
    local c_noon      = { light = Color(1.3, 1.25, 1.2), ambient = Color(0.6, 0.6, 0.65), fog = Color(0.6, 0.7, 0.8) }
    local c_sunset    = { light = Color(1.0, 0.5, 0.2), ambient = Color(0.3, 0.2, 0.3), fog = Color(0.5, 0.3, 0.4) }
    local c_night     = { light = Color(0.1, 0.1, 0.2), ambient = Color(0.05, 0.05, 0.1), fog = Color(0.05, 0.05, 0.1) }

    local currentLight, currentAmbient, currentFog
    local t_sub       = 0.0

    if progress < 0.25 then -- Sunrise -> Noon
        t_sub = progress / 0.25
        currentLight = LerpColor(c_sunrise.light, c_noon.light, t_sub)
        currentAmbient = LerpColor(c_sunrise.ambient, c_noon.ambient, t_sub)
        currentFog = LerpColor(c_sunrise.fog, c_noon.fog, t_sub)
    elseif progress < 0.5 then -- Noon -> Sunset
        t_sub = (progress - 0.25) / 0.25
        currentLight = LerpColor(c_noon.light, c_sunset.light, t_sub)
        currentAmbient = LerpColor(c_noon.ambient, c_sunset.ambient, t_sub)
        currentFog = LerpColor(c_noon.fog, c_sunset.fog, t_sub)
    elseif progress < 0.75 then -- Sunset -> Night
        t_sub = (progress - 0.5) / 0.25
        currentLight = LerpColor(c_sunset.light, c_night.light, t_sub)
        currentAmbient = LerpColor(c_sunset.ambient, c_night.ambient, t_sub)
        currentFog = LerpColor(c_sunset.fog, c_night.fog, t_sub)
    else -- Night -> Sunrise
        t_sub = (progress - 0.75) / 0.25
        currentLight = LerpColor(c_night.light, c_sunrise.light, t_sub)
        currentAmbient = LerpColor(c_night.ambient, c_sunrise.ambient, t_sub)
        currentFog = LerpColor(c_night.fog, c_sunrise.fog, t_sub)
    end

    sunLight_.color = currentLight

    -- 夜晚降低亮度，白天正常 (正午亮度提升至 1.5)
    local maxBrightness = 1.5
    local minBrightness = 0.1
    local brightness = maxBrightness

    if progress > 0.6 and progress < 0.9 then
        brightness = minBrightness -- 深夜
    elseif progress > 0.5 and progress <= 0.6 then
        -- 日落后渐暗
        local t = (progress - 0.5) / 0.1
        brightness = maxBrightness - t * (maxBrightness - minBrightness)
    elseif progress >= 0.9 then
        -- 日出前渐亮
        local t = (progress - 0.9) / 0.1
        brightness = minBrightness + t * (maxBrightness - minBrightness)
    end
    sunLight_.brightness = brightness

    zone_.ambientColor = currentAmbient
    zone_.fogColor = currentFog

    -- 更新月亮遮挡球颜色 (如果在夜晚显示)
    if moonNode_ and moonNode_.enabled and moonShadowMat_ then
        moonShadowMat_:SetShaderParameter("MatDiffColor", Variant(currentFog))
    end
end

function UpdateEffects(dt)
    -- 更新震屏计时
    if shakeTimer > 0 then
        shakeTimer = shakeTimer - dt
        if shakeTimer < 0 then shakeTimer = 0 end
    end

    -- 更新通用特效 (如火花)
    for i = #Effects, 1, -1 do
        local e = Effects[i]
        e.life = e.life - dt
        if e.life <= 0 then
            e.node:Remove()
            table.remove(Effects, i)
        else
            -- 物理运动
            e.velocity = e.velocity + e.gravity * dt
            e.node:Translate(e.velocity * dt, TS_WORLD)

            -- 旋转
            if e.rotSpeed then
                e.node:Rotate(Quaternion(e.rotSpeed.x * dt, e.rotSpeed.y * dt, e.rotSpeed.z * dt))
            end

            -- 简单的淡出 (缩小)
            local scale = e.life -- 剩余寿命作为缩放参考 (简化)
            if scale < 0.2 then scale = 0.2 end
            -- 这里只是简单的生命周期结束删除，不根据生命周期缩放了，因为 scale 已经被初始化了
            -- 如果想做淡出，需要改材质参数或者缩放
            local initialScale = e.node.scale.x -- 假设xyz一样
            -- 线性缩小
            if e.life < 0.3 then
                local s = initialScale * (e.life / 0.3)
                e.node.scale = Vector3(s, s, s)
            end
        end
    end

    -- 更新金币物理

    for i = #activeCoins, 1, -1 do
        local c = activeCoins[i]
        c.timer = c.timer + dt

        if c.state == "pop" then
            -- 应用重力
            c.velocity = c.velocity + Vector3(0, -25.0, 0) * dt
            c.node:Translate(c.velocity * dt, TS_WORLD)

            -- 旋转特效
            c.node:Rotate(Quaternion(720 * dt, 360 * dt, 0))

            -- 落地反弹/停止
            if c.node.position.y < 0.1 then
                local pos = c.node.position
                pos.y = 0.1
                c.node.position = pos
                c.velocity = Vector3(0, 0, 0)
                c.state = "ground"
                c.timer = 0
            end
        elseif c.state == "ground" then
            -- 地面停留一小会
            if c.timer > 0.3 then
                c.state = "suck"
                c.timer = 0.0 -- 从进入吸附开始重新计时，用于 2 秒超时判断
            end
        elseif c.state == "suck" then
            -- 飞向目标（玩家或 NPC）
            local targetPos
            if c.targetNode ~= nil and c.targetNode.position ~= nil then
                targetPos = c.targetNode.position + Vector3(0, 1, 0)
            else
                targetPos = playerNode_.position + Vector3(0, 1, 0)
            end

            local dir = targetPos - c.node.position
            local dist = dir:Length()

            if dist > 0.001 then
                -- 基础速度维持之前的手感：20 + timer * 10
                local baseSpeed = 20.0 + c.timer * 10.0
                -- 新逻辑：至少保持 baseSpeed，同时在较远距离时仍按“距离/秒”快速逼近
                local suckSpeed = math.max(dist, baseSpeed)
                dir:Normalize()
                c.node:Translate(dir * suckSpeed * dt, TS_WORLD)
            end

            -- 吸收判断：足够接近则删除
            if dist < 0.3 then
                c.node:Remove()
                table.remove(activeCoins, i)
                -- 超时 2 秒仍未到达，也强制删除，防止内存泄漏
            elseif c.timer >= 2.0 then
                c.node:Remove()
                table.remove(activeCoins, i)
            end
        end
    end
end

-- ============================================================================
-- 6. NanoVG UI 渲染
-- ============================================================================

function GetSmartSynthMaterials(mainPet)
    if mainPet.star >= 5 then return nil end

    local petsToDelete = {}
    local usedUUIDs = {}
    usedUUIDs[mainPet.uuid] = true

    -- `needed` tracks the deficit at the current star level.
    -- We start needing 2 pets of `mainPet.star`.
    -- If we can't find them, the deficit multiplies by 3 for the next lower star level.
    local needed = 2

    for s = mainPet.star, 1, -1 do
        -- 1. Find available candidates at this star level
        local available = {}
        for _, p in ipairs(PlayerData.PetInventory) do
            if p.configId == mainPet.configId and p.star == s and not usedUUIDs[p.uuid] and not p.isEquipped then
                table.insert(available, p)
            end
        end

        -- 2. Consume available candidates to reduce deficit
        for _, p in ipairs(available) do
            if needed > 0 then
                table.insert(petsToDelete, p)
                usedUUIDs[p.uuid] = true
                needed = needed - 1
            else
                break
            end
        end

        -- 3. If still needed, multiply deficit for the next lower level
        if needed > 0 then
            if s > 1 then
                needed = needed * 3
            else
                -- We are at star 1 and still have a deficit -> Failure
                return nil
            end
        end
    end

    return petsToDelete
end

-- 计算当前已装备纪念品所提供的所有属性加成
-- 仅统计已放入 PlayerData.SouvenirSlots 中的纪念品
function GetSouvenirBonuses()
    local bonus = {
        goldMult = 1.0,         -- 落地金币结算倍率
        climbSpeedMult = 1.0,   -- 攀爬速度倍率
        luckBonus = 0.0,        -- 幸运总加成（目前仅汇总，暂未实际使用）
        trophyMult = 1.0,       -- 奖杯获得倍率
        rarePetWeightMult = 1.0 -- 稀有宠物权重乘数
    }

    if not PlayerData or not PlayerData.SouvenirSlots then
        return bonus
    end

    local maxSlots = PlayerData.UnlockedSouvenirSlots or #PlayerData.SouvenirSlots
    for i = 1, maxSlots do
        local item = PlayerData.SouvenirSlots[i]
        if item and item.configId then
            local cfg = SOUVENIR_CONFIG[item.configId]
            if cfg then
                -- 星级倍率：1 星 = 基础倍率，之后线性增加
                local star = item.star or 1
                local starMult = CONFIG.SouvenirStarBaseMult +
                    (math.max(star, 1) - 1) * CONFIG.SouvenirStarPerLevelAdd

                if cfg.goldBonusPct then
                    bonus.goldMult = bonus.goldMult + cfg.goldBonusPct * starMult
                end
                if cfg.climbSpeedPct then
                    bonus.climbSpeedMult = bonus.climbSpeedMult + cfg.climbSpeedPct * starMult
                end
                if cfg.luckPct then
                    bonus.luckBonus = bonus.luckBonus + cfg.luckPct * starMult
                end
                if cfg.trophyRatePct then
                    bonus.trophyMult = bonus.trophyMult + cfg.trophyRatePct * starMult
                end
                if cfg.rarePetWeightBonus then
                    bonus.rarePetWeightMult = bonus.rarePetWeightMult + cfg.rarePetWeightBonus * starMult
                end
            end
        end
    end

    return bonus
end

-- ============================================================================
-- 纪念品融合辅助函数
-- ============================================================================

function ResetSouvenirFuseState()
    SouvenirFuseState.targetUUID = nil
    SouvenirFuseState.materialUUIDs = {}
    SouvenirFuseState.lastResult = nil
end

function OpenSouvenirFuse()
    ResetSouvenirFuseState()
    PlayerData.IsSouvenirFuseOpen = true
end

function CloseSouvenirFuse()
    ResetSouvenirFuseState()
    PlayerData.IsSouvenirFuseOpen = false
end

function FindSouvenirByUUID(uuid)
    if not uuid or not PlayerData or not PlayerData.SouvenirInventory then
        return nil, nil
    end
    for i, item in ipairs(PlayerData.SouvenirInventory) do
        if item.uuid == uuid then
            return i, item
        end
    end
    return nil, nil
end

function CalcSouvenirFuseChance()
    if not SouvenirFuseState.targetUUID then
        return 0.0
    end

    local base = CONFIG.SouvenirFuseBaseChance or 0.0
    local perAdd = CONFIG.SouvenirFusePerMaterialChance or 0.0
    local maxChance = CONFIG.SouvenirFuseMaxChance or 1.0

    local materialCount = 0
    for _ in pairs(SouvenirFuseState.materialUUIDs) do
        materialCount = materialCount + 1
    end

    local chance = base + materialCount * perAdd

    -- 幸运值加成（来自已装备纪念品）
    local bonuses = GetSouvenirBonuses()
    if bonuses and bonuses.luckBonus and bonuses.luckBonus > 0 then
        local factor = 1.0 + bonuses.luckBonus * (CONFIG.SouvenirFuseLuckFactor or 1.0)
        chance = chance * factor
    end

    if chance > maxChance then chance = maxChance end
    if chance < 0 then chance = 0 end

    return chance
end

function PerformSouvenirFuse()
    if not SouvenirFuseState.targetUUID then
        SouvenirFuseState.lastResult = "请先选择一个要提升的纪念品。"
        return
    end

    local idx, target = FindSouvenirByUUID(SouvenirFuseState.targetUUID)
    if not target then
        SouvenirFuseState.lastResult = "找不到目标纪念品。"
        return
    end

    local chance = CalcSouvenirFuseChance()
    if chance <= 0 then
        SouvenirFuseState.lastResult = "当前成功率为 0%，无法融合。"
        return
    end

    -- 重建背包，移除被消耗的材料纪念品
    local newInv = {}
    local materialsUsed = 0
    local targetRef = nil

    for _, item in ipairs(PlayerData.SouvenirInventory) do
        if item.uuid == SouvenirFuseState.targetUUID then
            table.insert(newInv, item)
            targetRef = item
        elseif SouvenirFuseState.materialUUIDs[item.uuid] then
            materialsUsed = materialsUsed + 1
            -- 消耗：不加入 newInv
        else
            table.insert(newInv, item)
        end
    end

    PlayerData.SouvenirInventory = newInv

    local roll = math.random()
    local success = roll < chance

    if success and targetRef then
        local oldStar = targetRef.star or 1
        local maxStar = CONFIG.SouvenirMaxStar or 5
        local newStar = math.min(oldStar + 1, maxStar)
        targetRef.star = newStar

        SouvenirFuseState.lastResult = string.format("融合成功！星级提升到 %d★。", newStar)
    else
        SouvenirFuseState.lastResult = string.format("融合失败，消耗了 %d 个纪念品。", materialsUsed)
    end

    -- 清空材料选择，但保留目标
    SouvenirFuseState.materialUUIDs = {}
end

function HandleNanoVGRender(eventType, eventData)
    if vg == nil then return end

    local graphics = GetGraphics()
    local w = graphics:GetWidth()
    local h = graphics:GetHeight()

    nvgBeginFrame(vg, w, h, 1.0)

    -- 设置字体
    nvgFontFace(vg, "sans")

    -- 绘制左上角信息板 (已弃用，拆分为顶部 TopBar 和右侧跳跃奖励提示)
    -- nvgBeginPath(vg)
    -- nvgRoundedRect(vg, 20, 20, 200, 150, 10)
    -- nvgFillColor(vg, nvgRGBA(0, 0, 0, 150))
    -- nvgFill(vg)
    -- nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    -- nvgFontSize(vg, 20)
    -- nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    -- nvgText(vg, 40, 40, string.format("Height: %.1f m", PlayerData.Altitude))
    -- nvgText(vg, 40, 70, string.format("Gold Acc: %d", PlayerData.GoldAccumulated))
    -- nvgText(vg, 40, 100, string.format("Total Gold: %d", PlayerData.GoldTotal))
    -- nvgText(vg, 40, 130, string.format("Trophies: %d", PlayerData.Trophies))
    -- nvgText(vg, 40, 160, string.format("Diamonds: %d", PlayerData.Diamonds or 0))

    -- 绘制顶部资源条 (Top Bar: Trophies & Total Gold)
    local topBarH = 50
    local topBarY = 20
    local barWidth = 220
    local barSpacing = 20
    local topCenterX = w / 2

    -- Helper: 绘制单个资源胶囊 (Icon + Value)
    local function DrawResourcePill(x, y, w, h, iconType, value, color)
        -- 背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x, y, w, h, h / 2)
        nvgFillColor(vg, nvgRGBA(30, 40, 50, 220)) -- 深色半透明背景
        nvgFill(vg)

        -- 边框 (可选)
        nvgStrokeWidth(vg, 2)
        nvgStrokeColor(vg, nvgRGBA(0, 0, 0, 100))
        nvgStroke(vg)

        -- 图标 (简单绘制)
        local iconX = x + h / 2 + 5
        local iconY = y + h / 2

        if iconType == "trophy" then
            -- 简单的奖杯图标
            nvgBeginPath(vg)
            nvgMoveTo(vg, iconX - 10, iconY - 8)
            nvgBezierTo(vg, iconX - 10, iconY + 5, iconX + 10, iconY + 5, iconX + 10, iconY - 8)
            nvgClosePath(vg)
            nvgFillColor(vg, nvgRGBA(255, 215, 0, 255)) -- 金色
            nvgFill(vg)
            -- 底座
            nvgBeginPath(vg)
            nvgRect(vg, iconX - 6, iconY + 6, 12, 3)
            nvgRect(vg, iconX - 8, iconY + 9, 16, 3)
            nvgFill(vg)
        elseif iconType == "gold" then
            -- 简单的金币图标
            nvgBeginPath(vg)
            nvgCircle(vg, iconX, iconY, 12)
            nvgFillColor(vg, nvgRGBA(255, 215, 0, 255))
            nvgFill(vg)
            -- 内圈/符号
            nvgBeginPath(vg)
            nvgCircle(vg, iconX, iconY, 8)
            nvgStrokeColor(vg, nvgRGBA(255, 240, 150, 255))
            nvgStrokeWidth(vg, 2)
            nvgStroke(vg)

            nvgFontSize(vg, 16)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(200, 150, 0, 255))
            nvgText(vg, iconX, iconY, "$")
        end

        -- 数值
        nvgFontSize(vg, 28)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        -- 描边提升清晰度
        -- nvgStrokeWidth(vg, 1) -- NanoVG text stroke is expensive/complex, skip for now
        nvgText(vg, x + w - 20, y + h / 2, FormatNumber(value))
    end

    -- 绘制 Trophies 条 (左侧)
    DrawResourcePill(topCenterX - barWidth - barSpacing / 2, topBarY, barWidth, topBarH, "trophy", PlayerData.Trophies)

    -- 绘制 Total Gold 条 (右侧)
    DrawResourcePill(topCenterX + barSpacing / 2, topBarY, barWidth, topBarH, "gold", PlayerData.GoldTotal)

    -- 绘制嘲讽文字 (被击落时显示)
    if PlayerData.FallMessageTimer and PlayerData.FallMessageTimer > 0 and PlayerData.FallMessage then
        nvgFontSize(vg, 80)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        -- 黑色描边
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 255))
        nvgText(vg, w / 2 + 4, h / 2 - 146, PlayerData.FallMessage)
        -- 红色字
        nvgFillColor(vg, nvgRGBA(255, 50, 50, 255))
        nvgText(vg, w / 2, h / 2 - 150, PlayerData.FallMessage)
    end

    -- 绘制“跳下获得金币”提示 (仅当 Accumulated > 0 时)
    if PlayerData.GoldAccumulated > 0 then
        local accX = w * 0.75 -- 屏幕右侧 3/4 处
        local accY = h * 0.2  -- 屏幕上方 1/5 处

        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)

        -- 标题文字 "Jump down to get:"
        nvgFontSize(vg, 32)
        -- 黑色描边效果 (通过绘制多次实现简单的描边)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 255))
        for ox = -2, 2, 2 do for oy = -2, 2, 2 do nvgText(vg, accX + ox, accY + oy - 10, "Jump down to get:") end end

        nvgFillColor(vg, nvgRGBA(255, 255, 0, 255)) -- 黄色字
        nvgText(vg, accX, accY - 10, "Jump down to get:")

        -- 金币数值
        nvgFontSize(vg, 60)
        local valueStr = FormatNumber(PlayerData.GoldAccumulated)

        -- 绘制金币图标 (大)
        local iconSize = 50
        -- 估算文字宽度 (无法使用 nvgTextBounds)
        local estimatedTextW = #valueStr * 60 * 0.55
        local totalW = estimatedTextW + iconSize + 10
        local startX = accX - totalW / 2

        -- Icon
        local iconCX = startX + iconSize / 2
        local iconCY = accY + 50
        nvgBeginPath(vg)
        nvgCircle(vg, iconCX, iconCY, iconSize / 2)
        nvgFillColor(vg, nvgRGBA(255, 215, 0, 255))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgCircle(vg, iconCX, iconCY, iconSize / 2 - 5)
        nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 100))
        nvgStrokeWidth(vg, 3)
        nvgStroke(vg)
        nvgFontSize(vg, 30)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(200, 150, 0, 255))
        nvgText(vg, iconCX, iconCY, "$")

        -- Value Text
        nvgFontSize(vg, 60)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

        -- 黑色描边
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 255))
        for ox = -3, 3, 3 do for oy = -3, 3, 3 do nvgText(vg, iconCX + iconSize / 2 + 10 + ox, iconCY + oy, valueStr) end end

        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, iconCX + iconSize / 2 + 10, iconCY, valueStr)
    end

    -- 绘制右上角作弊菜单
    if ShowCheatMenu then
        local cx = w - 220
        local cy = 20
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx, cy, 200, 230, 10)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 180))
        nvgFill(vg)

        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 100, 100, 255))
        nvgText(vg, cx + 10, cy + 10, "-- CHEAT MENU --")

        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgFontSize(vg, 16)
        nvgText(vg, cx + 10, cy + 40, string.format("[1] Speed + (%.0f)", CONFIG.ClimbSpeed))
        nvgText(vg, cx + 10, cy + 65, string.format("[2] Speed -"))
        nvgText(vg, cx + 10, cy + 90, string.format("[3] Gold +100000"))
        nvgText(vg, cx + 10, cy + 115, string.format("[4] Reset Fatigue"))
        nvgText(vg, cx + 10, cy + 140, string.format("[5] Trophies +10000"))
        nvgText(vg, cx + 10, cy + 165, string.format("[6] Diamonds +500"))
        nvgText(vg, cx + 10, cy + 190, string.format("[7] +10 Chests"))
    else
        -- 提示按 F3
        nvgFontSize(vg, 14)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 100))
        nvgText(vg, w - 10, 10, "[F3] Cheats")
    end

    -- 绘制塔进度条 (左侧)
    local barW = 60
    local targetBarH = 800
    local barH = math.min(targetBarH, h - 80) -- 高度提升，同时自适应屏幕
    local barX = 30
    local barY = (h - barH) / 2               -- 垂直居中

    -- 背景槽
    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX, barY, barW, barH, 10)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 150))
    nvgFill(vg)

    -- 塔身线条
    nvgBeginPath(vg)
    nvgMoveTo(vg, barX + barW / 2, barY + 5)
    nvgLineTo(vg, barX + barW / 2, barY + barH - 5)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 50))
    nvgStrokeWidth(vg, 4) -- 线条稍微加粗
    nvgStroke(vg)

    local towerH = CONFIG.TowerHeight or 15000.0

    -- 刻度线 (每20%)
    nvgFontSize(vg, 18)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    for i = 1, 5 do
        local pct = i * 0.2
        local tickY = barY + barH - 5 - (barH - 10) * pct

        -- 线
        nvgBeginPath(vg)
        nvgMoveTo(vg, barX + 10, tickY)
        nvgLineTo(vg, barX + barW - 10, tickY)
        nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 100))
        nvgStrokeWidth(vg, 2)
        nvgStroke(vg)

        -- 文字
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 180))
        nvgText(vg, barX + barW + 5, tickY, string.format("%.0fm", towerH * pct))
    end

    -- 顶部奖杯 (简单绘制)
    local trophyY = barY - 25
    local tX = barX + barW / 2

    -- 杯身
    nvgBeginPath(vg)
    nvgMoveTo(vg, tX - 15, trophyY)
    nvgBezierTo(vg, tX - 15, trophyY + 20, tX + 15, trophyY + 20, tX + 15, trophyY)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(255, 215, 0, 255))
    nvgFill(vg)
    -- 底座
    nvgBeginPath(vg)
    nvgRect(vg, tX - 10, trophyY + 20, 20, 5)
    nvgRect(vg, tX - 15, trophyY + 25, 30, 5)
    nvgFill(vg)

    -- 绘制 NPC
    for _, npc in ipairs(NPCs) do
        if npc.node then
            local y = npc.node.position.y
            local progress = math.max(0, math.min(1, y / towerH))
            local dotY = barY + barH - 5 - (barH - 10) * progress

            -- Falling offset
            local dotX = barX + barW / 2
            if npc.state == "Falling" then
                dotX = dotX + (npc.uiFallOffset or 0)
            end

            nvgBeginPath(vg)
            nvgCircle(vg, dotX, dotY, 8) -- 半径放大到2倍 (4 -> 8)

            -- 获取 NPC 颜色
            local color = npc.color
            if not color and npc.configId and PET_CONFIG[npc.configId] then
                color = PET_CONFIG[npc.configId].color
            end

            if color then
                nvgFillColor(vg, nvgRGBAf(color.r, color.g, color.b, 0.9))
            else
                -- 简单伪随机颜色 (Fallback)
                local seed = tonumber(tostring(npc):sub(-4)) or 0
                local r = (seed * 123) % 200 + 55
                local g = (seed * 456) % 200 + 55
                local b = (seed * 789) % 200 + 55
                nvgFillColor(vg, nvgRGBA(r, g, b, 200))
            end
            nvgFill(vg)
        end
    end

    -- 绘制玩家 (YOU)
    local pProgress = math.max(0, math.min(1, PlayerData.Altitude / towerH))
    local pDotY = barY + barH - 5 - (barH - 10) * pProgress
    local pDotX = barX + barW / 2
    if currentState == GameState.Falling then
        pDotX = pDotX + (PlayerData.uiFallOffset or 0)
    end

    -- 玩家光晕
    nvgBeginPath(vg)
    nvgCircle(vg, pDotX, pDotY, 16) -- 光晕半径放大 (8 -> 16)
    nvgFillColor(vg, nvgRGBA(255, 200, 0, 100))
    nvgFill(vg)

    -- 玩家点
    nvgBeginPath(vg)
    nvgCircle(vg, pDotX, pDotY, 10) -- 玩家点半径放大 (5 -> 10)
    nvgFillColor(vg, nvgRGBA(255, 215, 0, 255))
    nvgFill(vg)

    -- YOU 文字 + 高度
    nvgFontSize(vg, 24) -- 字体稍微放大
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 215, 0, 255))
    nvgText(vg, barX + barW + 10, pDotY, "YOU " .. math.floor(PlayerData.Altitude) .. "m")

    -- 绘制操作提示
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)

    -- 1. 交互提示按钮 (屏幕中央偏右)
    if PlayerData.CurrentInteractable and not PlayerData.IsShopOpen and not PlayerData.IsPetShopOpen then
        local btnX = w / 2 + 150
        local btnY = h / 2

        -- 按钮背景
        nvgBeginPath(vg)
        nvgRoundedRect(vg, btnX, btnY - 25, 200, 50, 5)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 180))
        nvgFill(vg)

        -- 按钮文字
        nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, btnX + 100, btnY, "[F] " .. (PlayerData.CurrentInteractable.name or "Interaction"))
    end

    -- 2. 商店详情界面 (打开后显示)
    -- 如果有更高优先级的模态 UI（例如纪念品融合），则商店不处理点击
    if PlayerData.IsShopOpen then
        -- 获取鼠标状态
        local mousePos = input.mousePosition
        local mx, my = mousePos.x, mousePos.y
        -- 若融合界面打开，则商店不响应点击
        local isClick = (not PlayerData.IsSouvenirFuseOpen) and input:GetMouseButtonPress(MOUSEB_LEFT) or false

        -- 背景遮罩
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, w, h)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 100))
        nvgFill(vg)

        -- 商店窗口背景
        local shopW, shopH = 800, 500
        local shopX, shopY = (w - shopW) / 2, (h - shopH) / 2
        nvgBeginPath(vg)
        nvgRoundedRect(vg, shopX, shopY, shopW, shopH, 10)
        nvgFillColor(vg, nvgRGBA(30, 30, 40, 240))
        nvgFill(vg)

        -- 标题
        nvgFontSize(vg, 40)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 215, 0, 255))
        nvgText(vg, w / 2, shopY + 20, "WING SHOP")

        -- 关闭按钮 (右上角 X)
        local closeSize = 30
        local closeX = shopX + shopW - 40
        local closeY = shopY + 10

        nvgBeginPath(vg)
        nvgRoundedRect(vg, closeX, closeY, closeSize, closeSize, 5)
        if mx >= closeX and mx <= closeX + closeSize and my >= closeY and my <= closeY + closeSize then
            nvgFillColor(vg, nvgRGBA(255, 50, 50, 255)) -- 悬停红
            if isClick then
                PlayerData.IsShopOpen = false
                SetMouseMode(false)
            end
        else
            nvgFillColor(vg, nvgRGBA(200, 50, 50, 200)) -- 普通红
        end
        nvgFill(vg)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(vg, closeX + closeSize / 2, closeY + closeSize / 2, "X")

        -- 商品网格 (2行5列)
        local gridStartX = shopX + 50
        local gridStartY = shopY + 100
        local cellSize = 130
        local padding = 10

        for i = 1, 10 do
            local row = math.floor((i - 1) / 5)
            local col = (i - 1) % 5
            local x = gridStartX + col * (cellSize + padding)
            local y = gridStartY + row * (cellSize + padding)

            local config = WING_LEVELS[i]
            local isOwned = PlayerData.WingLevel >= i
            local isNext = PlayerData.WingLevel == i - 1

            -- 格子背景
            nvgBeginPath(vg)
            nvgRoundedRect(vg, x, y, cellSize, cellSize, 5)
            if isOwned then
                nvgFillColor(vg, nvgRGBA(50, 150, 50, 200))   -- 已拥有(绿)
            elseif isNext then
                nvgFillColor(vg, nvgRGBA(100, 100, 120, 200)) -- 可购买(亮灰)
                -- 高亮边框
                nvgStrokeWidth(vg, 3)
                nvgStrokeColor(vg, nvgRGBA(255, 215, 0, 255))
                nvgStroke(vg)
            else
                nvgFillColor(vg, nvgRGBA(50, 50, 50, 150)) -- 未解锁(暗灰)
            end
            nvgFill(vg)

            -- 翅膀名称
            nvgFontSize(vg, 18)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, x + cellSize / 2, y + 10, config.name)

            -- 速度加成
            nvgFontSize(vg, 14)
            nvgFillColor(vg, nvgRGBA(200, 200, 200, 255))
            nvgText(vg, x + cellSize / 2, y + 35, string.format("Speed x%.1f", config.speedMult))

            -- 状态/价格/购买按钮
            nvgFontSize(vg, 16)
            if isOwned then
                nvgFillColor(vg, nvgRGBA(100, 255, 100, 255))
                nvgText(vg, x + cellSize / 2, y + 80, "OWNED")
            elseif isNext then
                -- 显示价格
                if PlayerData.GoldTotal >= config.cost then
                    nvgFillColor(vg, nvgRGBA(100, 255, 100, 255)) -- 钱够(绿)
                else
                    nvgFillColor(vg, nvgRGBA(255, 100, 100, 255)) -- 钱不够(红)
                end
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
                nvgText(vg, x + cellSize / 2, y + 60, string.format("$ %d", config.cost))

                -- 购买按钮绘制
                local btnW, btnH = 80, 25
                local btnX = x + (cellSize - btnW) / 2
                local btnY = y + 90

                nvgBeginPath(vg)
                nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 4)

                -- 按钮交互
                if mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH then
                    nvgFillColor(vg, nvgRGBA(255, 200, 0, 255)) -- 悬停高亮
                    if isClick then
                        -- 触发购买逻辑
                        if PlayerData.GoldTotal >= config.cost then
                            PlayerData.GoldTotal = PlayerData.GoldTotal - config.cost
                            PlayerData.WingLevel = i
                            print("Upgrade Success! Level: " .. i)
                            UpdateWingVisuals()
                        else
                            print("Not enough gold!")
                        end
                    end
                else
                    nvgFillColor(vg, nvgRGBA(200, 150, 0, 255)) -- 普通黄
                end
                nvgFill(vg)

                nvgFillColor(vg, nvgRGBA(0, 0, 0, 255))
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgText(vg, btnX + btnW / 2, btnY + btnH / 2, "BUY")
            else
                -- 锁定
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(150, 150, 150, 255))
                nvgText(vg, x + cellSize / 2, y + 80, "LOCKED")
            end
        end

        -- 底部提示 (已删除)
    end

    -- 3. 宠物商店界面
    -- 同理：若有模态 UI 打开，则不响应点击
    if PlayerData.IsPetShopOpen then
        -- 获取鼠标状态
        local mousePos = input.mousePosition
        local mx, my = mousePos.x, mousePos.y
        -- 若融合界面打开，则宠物商店不响应点击
        local isClick = (not PlayerData.IsSouvenirFuseOpen) and input:GetMouseButtonPress(MOUSEB_LEFT) or false

        -- 背景遮罩
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, w, h)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 100))
        nvgFill(vg)

        -- 窗口
        local shopW, shopH = 800, 500
        local shopX, shopY = (w - shopW) / 2, (h - shopH) / 2
        nvgBeginPath(vg)
        nvgRoundedRect(vg, shopX, shopY, shopW, shopH, 10)
        nvgFillColor(vg, nvgRGBA(40, 30, 50, 240))
        nvgFill(vg)

        -- 标题
        nvgFontSize(vg, 40)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 100, 200, 255))
        nvgText(vg, w / 2, shopY + 20, "PET GACHA SHOP")

        -- 关闭按钮 (右上角 X)
        local closeSize = 30
        local closeX = shopX + shopW - 40
        local closeY = shopY + 10

        nvgBeginPath(vg)
        nvgRoundedRect(vg, closeX, closeY, closeSize, closeSize, 5)
        if mx >= closeX and mx <= closeX + closeSize and my >= closeY and my <= closeY + closeSize then
            nvgFillColor(vg, nvgRGBA(255, 50, 50, 255)) -- 悬停红
            if isClick then
                PlayerData.IsPetShopOpen = false
                SetMouseMode(false)
            end
        else
            nvgFillColor(vg, nvgRGBA(200, 50, 50, 200)) -- 普通红
        end
        nvgFill(vg)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(vg, closeX + closeSize / 2, closeY + closeSize / 2, "X")

        -- 左侧：宠物概率展示
        local startX = shopX + 50
        local startY = shopY + 100
        local itemH = 60

        nvgFontSize(vg, 24)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(200, 200, 200, 255))
        nvgText(vg, startX, startY - 30, "Probabilities:")

        for i, cfg in ipairs(PET_CONFIG) do
            local y = startY + (i - 1) * itemH

            -- 颜色块
            nvgBeginPath(vg)
            nvgRect(vg, startX, y, 20, 20)
            local c = cfg.color
            nvgFillColor(vg, nvgRGBAf(c.r, c.g, c.b, 1.0))
            nvgFill(vg)

            -- 名字和概率
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, startX + 30, y, string.format("%s (Rate: %d%%)", cfg.name, cfg.chance))
        end

        -- 右侧：背包展示 (简略版，只显示数量)
        local invX = shopX + 450
        nvgFillColor(vg, nvgRGBA(200, 200, 200, 255))
        nvgText(vg, invX, startY - 30, "Owned Count:")

        -- 统计数量
        local counts = {}
        for _, pet in ipairs(PlayerData.PetInventory) do
            counts[pet.configId] = (counts[pet.configId] or 0) + 1
        end

        for i, cfg in ipairs(PET_CONFIG) do
            local count = counts[i] or 0
            local y = startY + (i - 1) * itemH

            if count > 0 then
                nvgFillColor(vg, nvgRGBA(100, 255, 100, 255))
            else
                nvgFillColor(vg, nvgRGBA(100, 100, 100, 255))
            end
            nvgText(vg, invX, y, string.format("x%d", count))
        end

        -- 底部操作区
        local actionY = shopY + shopH - 80

        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)

        -- 按钮样式函数
        local drawBtn = function(bx, by, bw, bh, label, price, action)
            nvgBeginPath(vg)
            nvgRoundedRect(vg, bx, by, bw, bh, 5)
            local isHover = mx >= bx and mx <= bx + bw and my >= by and my <= by + bh

            local canAfford = PlayerData.GoldTotal >= price
            local baseColor = canAfford and nvgRGBA(255, 200, 0, 255) or nvgRGBA(150, 50, 50, 255)

            if isHover and canAfford then
                nvgFillColor(vg, nvgRGBA(255, 230, 50, 255)) -- 高亮黄
                if isClick then action() end
            else
                if canAfford then
                    nvgFillColor(vg, nvgRGBA(200, 150, 0, 255)) -- 普通黄
                else
                    nvgFillColor(vg, nvgRGBA(100, 50, 50, 255)) -- 没钱红
                end
            end
            nvgFill(vg)

            -- 文字
            nvgFillColor(vg, nvgRGBA(0, 0, 0, 255))
            nvgText(vg, bx + bw / 2, by + 10, label)
            nvgFontSize(vg, 16)
            nvgText(vg, bx + bw / 2, by + 35, string.format("$ %d", price))
            nvgFontSize(vg, 20) -- 恢复字体
        end

        -- 单抽按钮
        drawBtn(w / 2 - 160, actionY, 140, 60, "Pull x1", GACHA_PRICE, function() GachaPull(1) end)

        -- 十连按钮
        drawBtn(w / 2 + 20, actionY, 140, 60, "Pull x10", GACHA_PRICE * 10, function() GachaPull(10) end)

        -- 关闭提示 (已删除)
    end

    -- 4. Unified Bag Interface
    -- 4. Unified Bag Interface
    if PlayerData.IsBagOpen then
        nvgResetScissor(vg) -- 强制重置裁剪，防止外部影响

        local mousePos = input.mousePosition
        local mx, my = mousePos.x, mousePos.y
        -- 若融合界面打开，则统一背包不响应点击（包括 PET / Souvenir 页签和按钮）
        local isClick = (not PlayerData.IsSouvenirFuseOpen) and input:GetMouseButtonPress(MOUSEB_LEFT) or false

        -- Style Constants
        local C_BG_DIM = nvgRGBA(0, 0, 0, 150)
        local C_WIN_BG = nvgRGBA(15, 25, 45, 255)
        local C_TAB_BG = nvgRGBA(10, 20, 35, 255)
        local C_HEADER = nvgRGBA(0, 120, 255, 255)
        local C_HEADER_SOUV = nvgRGBA(0, 100, 200, 255)
        local C_SIDEBAR = nvgRGBA(255, 105, 180, 255)
        local C_BTN_GREEN = nvgRGBA(50, 205, 50, 255)
        local C_BTN_RED = nvgRGBA(220, 50, 50, 255)
        local C_BTN_BLUE = nvgRGBA(0, 180, 255, 255)
        local C_BTN_YELLOW = nvgRGBA(255, 215, 0, 255)
        local C_TEXT_W = nvgRGBA(255, 255, 255, 255)
        local C_STROKE = nvgRGBA(0, 0, 0, 255)

        -- Main Layout
        -- 动态计算缩放比例，适配低分辨率窗口
        local baseW, baseH = 1120, 650
        local safeW, safeH = w * 0.95, h * 0.95
        local BAG_SCALE = math.min(1.5, safeW / baseW, safeH / baseH)

        -- 统一的背包字体缩放方法（所有背包内字号按 BAG_SCALE 倍放大）
        local function BagFont(size)
            nvgFontSize(vg, size * BAG_SCALE)
        end

        local totalW, totalH = baseW * BAG_SCALE, baseH * BAG_SCALE
        local winX, winY = (w - totalW) / 2, (h - totalH) / 2
        local tabW = 120 * BAG_SCALE -- tabW 也要随比例缩放，或者保持固定？这里随比例缩放比较协调
        local contentX = winX + tabW
        local contentW = totalW - tabW
        local contentY = winY
        local contentH = totalH

        -- 1. Dim Background
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, w, h)
        nvgFillColor(vg, C_BG_DIM)
        nvgFill(vg)

        -- 2. Tab Bar Background (Left Strip)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, winX, winY, tabW, totalH, 12)
        nvgFillColor(vg, C_TAB_BG)
        nvgFill(vg)
        -- Square off right side to merge
        nvgBeginPath(vg)
        nvgRect(vg, winX + tabW - 10, winY, 10, totalH)
        nvgFillColor(vg, C_TAB_BG)
        nvgFill(vg)

        -- 3. Content Background
        nvgBeginPath(vg)
        nvgRoundedRect(vg, contentX, contentY, contentW, contentH, 12)
        nvgFillColor(vg, C_WIN_BG)
        nvgFill(vg)
        -- Square off left side to merge with tabs
        nvgBeginPath(vg)
        nvgRect(vg, contentX, contentY, 10, contentH)
        nvgFillColor(vg, C_WIN_BG)
        nvgFill(vg)

        -- 3.1 Bag Close Button 基础坐标（供后续多处使用）
        local closeSize = 44
        local closeX = contentX + contentW - 55
        local closeY = contentY + 12

        -- 4. Draw Tabs
        local drawTab = function(idx, label, y)
            local isActive = PlayerData.CurrentBagTab == idx
            local btnH = 80

            nvgBeginPath(vg)
            -- If active, merge with content bg
            if isActive then
                nvgRoundedRect(vg, winX, y, tabW + 10, btnH, 12) -- Extend into content
                nvgFillColor(vg, C_WIN_BG)
            else
                nvgRoundedRect(vg, winX + 10, y, tabW - 20, btnH, 12)
                nvgFillColor(vg, nvgRGBA(255, 255, 255, 20))
            end
            nvgFill(vg)

            BagFont(20)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, isActive and C_BTN_YELLOW or nvgRGBA(150, 150, 150, 255))
            nvgText(vg, winX + tabW / 2, y + btnH / 2, label)

            if mx >= winX and mx <= winX + tabW and my >= y and my <= y + btnH and isClick then
                PlayerData.CurrentBagTab = idx
            end
        end

        drawTab(1, "PET", winY + 20)
        drawTab(2, "SOUVENIR", winY + 110)
        drawTab(3, "开箱", winY + 200)

        -- ====================================================================
        -- TAB 1: PET UI
        -- ====================================================================
        if PlayerData.CurrentBagTab == 1 then
            -- Map to existing variables for compatibility
            local bagX, bagY, bagW, bagH = contentX, contentY, contentW, contentH
            local headerH = 70

            -- Header
            nvgBeginPath(vg)
            nvgRoundedRect(vg, bagX, bagY, bagW, headerH, 12)
            nvgFillColor(vg, C_HEADER)
            nvgFill(vg)
            -- Fix corners
            nvgBeginPath(vg)
            nvgRect(vg, bagX, bagY + headerH - 12, bagW, 12)
            nvgFillColor(vg, C_HEADER)
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgRect(vg, bagX, bagY, 12, headerH) -- Left square for tab merge
            nvgFillColor(vg, C_HEADER)
            nvgFill(vg)

            -- Title
            BagFont(48)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(0, 0, 0, 100))
            nvgText(vg, bagX + 24, bagY + headerH / 2 + 4, "PET")
            nvgFillColor(vg, C_TEXT_W)
            nvgText(vg, bagX + 20, bagY + headerH / 2, "PET")

            -- Stats
            local drawHeaderStat = function(x, icon, curr, max)
                local pillW = 160
                local pillH = 44
                local py = bagY + (headerH - pillH) / 2
                nvgBeginPath(vg)
                nvgRoundedRect(vg, x, py, pillW, pillH, 8)
                nvgFillColor(vg, nvgRGBA(0, 0, 0, 80))
                nvgFill(vg)
                BagFont(22)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, C_TEXT_W)
                nvgText(vg, x + 10, py + pillH / 2, string.format("%s %d/%d", icon, curr, max))
                local plusS = 36
                local plusX = x + pillW + 5
                local plusY = py + (pillH - plusS) / 2
                nvgBeginPath(vg)
                nvgRoundedRect(vg, plusX, plusY, plusS, plusS, 6)
                nvgFillColor(vg, C_BTN_GREEN)
                nvgStrokeWidth(vg, 2)
                nvgStrokeColor(vg, C_STROKE)
                nvgStroke(vg)
                nvgFill(vg)
                BagFont(26)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, C_TEXT_W)
                nvgText(vg, plusX + plusS / 2, plusY + plusS / 2 - 2, "+")
            end

            local eqCount = 0
            for _, p in ipairs(PlayerData.PetInventory) do if p.isEquipped then eqCount = eqCount + 1 end end
            local statEnd = closeX - 20
            drawHeaderStat(statEnd - 220, "Bag", #PlayerData.PetInventory, CONFIG.MaxPetCount)
            drawHeaderStat(statEnd - 460, "Eqp", eqCount, 3)

            -- Sidebar Logic
            local showSidebar = false
            local selectedPet = nil
            if PlayerData.SelectedPetUUID then
                for _, pet in ipairs(PlayerData.PetInventory) do
                    if pet.uuid == PlayerData.SelectedPetUUID then
                        selectedPet = pet
                        showSidebar = true
                        break
                    end
                end
            end

            local sidebarW = showSidebar and 320 or 0
            local listAreaX = bagX + sidebarW
            local listAreaW = bagW - sidebarW
            local listAreaY = bagY + headerH
            local listAreaH = bagH - headerH

            -- SIDEBAR
            if showSidebar and selectedPet then
                local pCfg = PET_CONFIG[selectedPet.configId]
                local qualityColor = pCfg and pCfg.color or { r = 0.5, g = 0.5, b = 0.5 }
                local sidebarColor = nvgRGBAf(qualityColor.r, qualityColor.g, qualityColor.b, 1.0)
                local sbH = listAreaH
                local sbY = listAreaY

                nvgBeginPath(vg)
                nvgRoundedRect(vg, bagX, sbY, sidebarW, sbH, 12)
                nvgFillColor(vg, sidebarColor)
                nvgFill(vg)
                -- Square fix
                nvgBeginPath(vg)
                nvgRect(vg, bagX + sidebarW - 10, sbY, 10, sbH)
                nvgFillColor(vg, sidebarColor)
                nvgFill(vg)
                nvgBeginPath(vg)
                nvgRect(vg, bagX, sbY, 10, 10)
                nvgFillColor(vg, sidebarColor)
                nvgFill(vg)

                local cx = bagX + sidebarW / 2
                local topY = sbY + 30

                -- Info
                BagFont(32)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
                nvgFillColor(vg, C_STROKE)
                nvgText(vg, cx + 2, topY + 2, selectedPet.name)
                nvgFillColor(vg, C_TEXT_W)
                nvgText(vg, cx, topY, selectedPet.name)

                local starStr = ""
                for i = 1, selectedPet.star do starStr = starStr .. "★" end
                BagFont(24)
                nvgFillColor(vg, C_BTN_YELLOW)
                nvgText(vg, cx, topY + 40, starStr)

                -- Avatar
                local avSize = 160
                local avY = topY + 80
                nvgBeginPath(vg)
                nvgRoundedRect(vg, cx - avSize / 2, avY, avSize, avSize, 10)
                nvgFillColor(vg, sidebarColor)
                nvgStrokeWidth(vg, 4)
                nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 100))
                nvgStroke(vg)
                nvgFill(vg)

                -- Bonus
                BagFont(36)
                nvgFillColor(vg, C_STROKE)
                nvgText(vg, cx + 2, avY + avSize + 22, string.format("x%dM", selectedPet.bonus or 0))
                nvgFillColor(vg, C_BTN_YELLOW)
                nvgText(vg, cx, avY + avSize + 20, string.format("x%dM", selectedPet.bonus or 0))

                -- Buttons
                local btnW, btnH = 240, 60
                local btnGap = 20
                local startBtnY = avY + avSize + 80

                local drawSideBtn = function(idx, label, color, onClick)
                    local by = startBtnY + (idx - 1) * (btnH + btnGap)
                    local bx = cx - btnW / 2
                    nvgBeginPath(vg)
                    nvgRoundedRect(vg, bx, by, btnW, btnH, 10)
                    nvgFillColor(vg, color)
                    nvgStrokeWidth(vg, 3)
                    nvgStrokeColor(vg, C_STROKE)
                    nvgStroke(vg)
                    nvgFill(vg)
                    nvgFontSize(vg, 28)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, C_TEXT_W)
                    nvgText(vg, cx, by + btnH / 2 - 2, label)
                    if mx >= bx and mx <= bx + btnW and my >= by and my <= by + btnH then
                        nvgFillColor(vg, nvgRGBA(255, 255, 255, 50))
                        nvgFill(vg)
                        if isClick then onClick() end
                    end
                end

                local eqTxt = selectedPet.isEquipped and "UNEQUIP" or "EQUIP"
                drawSideBtn(1, eqTxt, C_BTN_GREEN, function()
                    if selectedPet.isEquipped then
                        selectedPet.isEquipped = false
                    elseif eqCount < 3 then
                        selectedPet.isEquipped = true
                    end
                end)

                local synText = (selectedPet.star >= 5) and "MAX STAR" or "SYNTHESIS"
                local synthCost = GetSmartSynthMaterials(selectedPet)
                local canSynth = (synthCost ~= nil) and (selectedPet.star < 5)
                local btnCol2 = canSynth and C_BTN_BLUE or nvgRGBA(100, 100, 100, 255)
                drawSideBtn(2, synText, btnCol2, function()
                    if canSynth then
                        selectedPet.star = selectedPet.star + 1
                        selectedPet.bonus = math.floor(selectedPet.bonus * CONFIG.SynthesisMultiplier)
                        local delMap = {}
                        for _, p in ipairs(synthCost) do delMap[p.uuid] = true end
                        local newInv = {}
                        for _, p in ipairs(PlayerData.PetInventory) do
                            if not delMap[p.uuid] then table.insert(newInv, p) end
                        end
                        PlayerData.PetInventory = newInv
                    end
                end)

                drawSideBtn(3, "DELETE", C_BTN_RED, function()
                    local msg = "确定要删除这个宠物吗？"
                    if selectedPet.isEquipped then
                        msg = "该宠物已装备，是否删除？"
                    elseif selectedPet.configId >= 4 then
                        msg = "该宠物稀有度较高，是否删除？"
                    elseif selectedPet.star >= 3 then
                        msg = "该宠物星级较高，是否删除？"
                    end
                    PlayerData.ActiveDialog = {
                        title = "Delete Pet",
                        message = msg,
                        onConfirm = function()
                            local newInv = {}
                            for _, p in ipairs(PlayerData.PetInventory) do
                                if p.uuid ~= selectedPet.uuid then table.insert(newInv, p) end
                            end
                            PlayerData.PetInventory = newInv
                            PlayerData.SelectedPetUUID = nil
                        end
                    }
                end)
            end

            local cardSize = 140
            local cardGap = 15
            local listX = listAreaX + 20
            local listY = listAreaY + 20
            local listW = listAreaW - 40
            local listH = listAreaH - 100 -- space for buttons

            local cols = math.floor(listW / (cardSize + cardGap))
            if cols < 1 then cols = 1 end
            local totalRows = math.ceil(#PlayerData.PetInventory / cols)
            local totalH_list = totalRows * (cardSize + cardGap) + 20
            local maxScroll = math.max(0, totalH_list - listH)

            -- 滚轮处理 (PET TAB)
            if not PlayerData.IsSouvenirFuseOpen then
                local wheel = input.mouseMoveWheel
                if wheel ~= 0 then
                    -- 同样加入区域判断
                    if mx >= listAreaX and mx <= listAreaX + listAreaW and my >= listAreaY and my <= listAreaY + listAreaH then
                        PlayerData.BagScrollY = PlayerData.BagScrollY - wheel * 60
                    end
                end
            end

            if PlayerData.BagScrollY < 0 then PlayerData.BagScrollY = 0 end
            if PlayerData.BagScrollY > maxScroll then PlayerData.BagScrollY = maxScroll end

            nvgScissor(vg, listX, listY, listW, listH)

            for i, pet in ipairs(PlayerData.PetInventory) do
                local r = math.floor((i - 1) / cols)
                local c = (i - 1) % cols
                local cx = listX + c * (cardSize + cardGap)
                local cy = listY + r * (cardSize + cardGap) - PlayerData.BagScrollY

                if cy + cardSize > listY and cy < listY + listH then
                    nvgBeginPath(vg)
                    nvgRoundedRect(vg, cx, cy, cardSize, cardSize, 10)
                    local pCfg = PET_CONFIG[pet.configId]
                    local pc = pCfg and pCfg.color or { r = 0.5, g = 0.5, b = 0.5 }
                    nvgFillColor(vg, nvgRGBAf(pc.r * 0.6, pc.g * 0.6, pc.b * 0.6, 1.0))
                    nvgFill(vg)

                    local isSel = (pet.uuid == PlayerData.SelectedPetUUID)
                    nvgStrokeWidth(vg, isSel and 5 or 2)
                    nvgStrokeColor(vg, isSel and C_BTN_GREEN or nvgRGBA(0, 0, 0, 100))
                    nvgStroke(vg)

                    local innerS = cardSize - 40
                    nvgBeginPath(vg)
                    nvgRect(vg, cx + 20, cy + 20, innerS, innerS)
                    nvgFillColor(vg, nvgRGBAf(pc.r, pc.g, pc.b, 1.0))
                    nvgFill(vg)

                    nvgFontSize(vg, 22)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(0, 0, 0, 200))
                    nvgText(vg, cx + cardSize / 2 + 1, cy + cardSize / 2 + 1, pet.name)
                    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
                    nvgText(vg, cx + cardSize / 2, cy + cardSize / 2, pet.name)

                    if pet.isEquipped then
                        nvgFontSize(vg, 20)
                        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, C_BTN_GREEN)
                        nvgText(vg, cx + cardSize / 2, cy + 30, "EQUIPPED")
                    end

                    local stripH = 36
                    nvgBeginPath(vg)
                    nvgRoundedRect(vg, cx, cy + cardSize - stripH, cardSize, stripH, 0)
                    nvgFillColor(vg, nvgRGBA(0, 0, 0, 180))
                    nvgFill(vg)
                    nvgFontSize(vg, 20)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, C_BTN_YELLOW)
                    nvgText(vg, cx + cardSize / 2, cy + cardSize - stripH / 2, string.format("x%d", pet.bonus))

                    if mx >= cx and mx <= cx + cardSize and my >= cy and my <= cy + cardSize and isClick then
                        PlayerData.SelectedPetUUID = pet.uuid
                    end
                end
            end
            nvgResetScissor(vg)

            local bY = listAreaY + listAreaH - 70
            local bH = 50
            local bW = 200
            local drawBottomBtn = function(label, color, bx, action)
                nvgBeginPath(vg)
                nvgRoundedRect(vg, bx, bY, bW, bH, 10)
                nvgFillColor(vg, color)
                nvgStrokeWidth(vg, 3)
                nvgStrokeColor(vg, C_STROKE)
                nvgStroke(vg)
                nvgFill(vg)
                nvgFontSize(vg, 24)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, C_TEXT_W)
                nvgText(vg, bx + bW / 2, bY + bH / 2 - 2, label)
                if mx >= bx and mx <= bx + bW and my >= bY and my <= bY + bH then
                    nvgFillColor(vg, nvgRGBA(255, 255, 255, 50))
                    nvgFill(vg)
                    if isClick then action() end
                end
            end

            local cCX = listAreaX + listAreaW / 2
            drawBottomBtn("EQUIP BEST", C_BTN_GREEN, cCX - bW - 20, function()
                for _, p in ipairs(PlayerData.PetInventory) do p.isEquipped = false end
                table.sort(PlayerData.PetInventory, function(a, b) return (a.bonus or 0) > (b.bonus or 0) end)
                for i = 1, 3 do if PlayerData.PetInventory[i] then PlayerData.PetInventory[i].isEquipped = true end end
            end)
            drawBottomBtn("DELETE ALL", C_BTN_RED, cCX + 20, function()
                PlayerData.ActiveDialog = {
                    title = "Delete All Pets?",
                    message = "(Only unequipped pets will be deleted)",
                    onConfirm = function()
                        local kept = {}
                        local delSel = false
                        for _, p in ipairs(PlayerData.PetInventory) do
                            if p.isEquipped then table.insert(kept, p) else if p.uuid == PlayerData.SelectedPetUUID then delSel = true end end
                        end
                        PlayerData.PetInventory = kept
                        if delSel then PlayerData.SelectedPetUUID = nil end
                    end
                }
            end)

            -- ====================================================================
            -- TAB 2: SOUVENIR UI
            -- ====================================================================
        elseif PlayerData.CurrentBagTab == 2 then
            local souvW, souvH = contentW, contentH
            local souvX, souvY = contentX, contentY
            local headerH = 70

            -- Header
            nvgBeginPath(vg)
            nvgRoundedRect(vg, souvX, souvY, souvW, headerH, 12)
            nvgFillColor(vg, C_HEADER_SOUV)
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgRect(vg, souvX, souvY + headerH - 12, souvW, 12)
            nvgFillColor(vg, C_HEADER_SOUV)
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgRect(vg, souvX, souvY, 12, headerH) -- Left square
            nvgFillColor(vg, C_HEADER_SOUV)
            nvgFill(vg)

            -- Title
            nvgFontSize(vg, 48)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(0, 0, 0, 100))
            nvgText(vg, souvX + 24, souvY + headerH / 2 + 4, "Souvenir")
            nvgFillColor(vg, C_TEXT_W)
            nvgText(vg, souvX + 20, souvY + headerH / 2, "Souvenir")

            -- Stats
            nvgFontSize(vg, 24)
            nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
            nvgText(vg, souvX + souvW - 80, souvY + headerH / 2,
                string.format("Bag %d/%d", #PlayerData.SouvenirInventory, 100))

            -- Helper: 纪念品属性描述（带星级倍率）
            local function GetSouvenirAttrText(cfg, star)
                if not cfg then return "" end

                local s = math.max(star or 1, 1)
                local starMult = (CONFIG.SouvenirStarBaseMult or 1.0) +
                    (s - 1) * (CONFIG.SouvenirStarPerLevelAdd or 0.0)

                local function fmt(pct, label)
                    if not pct then return "" end
                    local total = pct * starMult
                    return string.format("%s+%d%%", label, math.floor(total * 100 + 0.5))
                end

                if cfg.goldBonusPct then
                    return fmt(cfg.goldBonusPct, "金币")
                elseif cfg.climbSpeedPct then
                    return fmt(cfg.climbSpeedPct, "速度")
                elseif cfg.luckPct then
                    return fmt(cfg.luckPct, "幸运")
                elseif cfg.trophyRatePct then
                    return fmt(cfg.trophyRatePct, "奖杯")
                elseif cfg.rarePetWeightBonus then
                    return fmt(cfg.rarePetWeightBonus, "稀有宠物")
                end
                return ""
            end

            -- Helper: 在统一布局下绘制纪念品图标 + 名字 + 属性 + 星级
            local function DrawSouvenirIconBox(x, y, size, cfg, star)
                if not cfg then return end
                local cc = cfg.color or { r = 1, g = 1, b = 1 }
                local s = math.max(star or 1, 1)

                local margin = 10
                local innerSize = size - margin * 2
                local innerX = x + margin
                local innerY = y + margin

                -- Icon 方块
                nvgBeginPath(vg)
                nvgRoundedRect(vg, innerX, innerY, innerSize, innerSize, 5)
                nvgFillColor(vg, nvgRGBAf(cc.r, cc.g, cc.b, 1.0))
                nvgFill(vg)

                -- 星级（显示在上方）
                local starStr = ""
                for i = 1, s do starStr = starStr .. "★" end
                nvgFillColor(vg, nvgRGBA(255, 215, 0, 255))
                nvgFontSize(vg, 26)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
                nvgText(vg, x + size / 2, y + 6, starStr)

                -- 名字：居中显示（横向居中，纵向在底部预留区域中间）
                nvgFillColor(vg, C_TEXT_W)
                nvgFontSize(vg, 36) -- 原 18，放大到 2 倍
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                local nameY = y + size - 40
                nvgText(vg, x + size / 2, nameY, cfg.name or "")

                -- 属性说明：稍微往上挪一点，字体同样放大 2 倍，已带星级倍率
                local attrText = GetSouvenirAttrText(cfg, s)
                if attrText ~= "" then
                    nvgFontSize(vg, 28) -- 原 14
                    nvgFillColor(vg, nvgRGBA(230, 230, 230, 255))
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    local attrY = y + size - 12
                    nvgText(vg, x + size / 2, attrY, attrText)
                end
            end

            -- Layout: Left Cabinet (400px), Right Inventory (Rest)
            local cabW = 400 * BAG_SCALE
            local cabX = souvX
            local cabY = souvY + headerH
            local cabH = souvH - headerH

            local invX = souvX + cabW
            local invY = cabY
            local invW = souvW - cabW
            local invH = cabH

            -- Cabinet Background
            nvgBeginPath(vg)
            nvgRect(vg, cabX, cabY, cabW, cabH)
            nvgFillColor(vg, nvgRGBA(0, 150, 255, 50)) -- Light blue tint
            nvgFill(vg)

            -- Cabinet Header
            nvgFontSize(vg, 22)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, C_TEXT_W)
            nvgText(vg, cabX + 10, cabY + 10, "Souvenir collection cabinet")

            -- Draw 8 slots (2 cols x 4 rows)
            local slotSize = 108 * BAG_SCALE
            local slotGap = 20 * BAG_SCALE
            local startSlotX = cabX + (cabW - (slotSize * 2 + slotGap)) / 2
            local startSlotY = cabY + 50

            for i = 1, 8 do
                local r = math.floor((i - 1) / 2)
                local c = (i - 1) % 2
                local sx = startSlotX + c * (slotSize + slotGap)
                local sy = startSlotY + r * (slotSize + slotGap)

                nvgBeginPath(vg)
                nvgRoundedRect(vg, sx, sy, slotSize, slotSize, 8)
                nvgFillColor(vg, nvgRGBA(0, 0, 0, 100))
                nvgStrokeWidth(vg, 2)
                nvgStrokeColor(vg, nvgRGBA(0, 100, 200, 255))
                nvgStroke(vg)
                nvgFill(vg)

                -- Check unlocked state
                local isUnlocked = i <= (PlayerData.UnlockedSouvenirSlots or 2)

                if not isUnlocked then
                    -- Locked state
                    local cost = SOUVENIR_UNLOCK_COSTS[i]
                    nvgFillColor(vg, nvgRGBA(0, 0, 0, 150)) -- Dark overlay
                    nvgFill(vg)

                    -- Lock Icon (Simple text for now)
                    nvgFontSize(vg, 40)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(150, 150, 150, 255))
                    nvgText(vg, sx + slotSize / 2, sy + slotSize / 2 - 10, "🔒")

                    if cost then
                        nvgFontSize(vg, 16)
                        nvgText(vg, sx + slotSize / 2, sy + slotSize / 2 + 25,
                            string.format("%d %s", cost.amount, cost.type == "Trophies" and "🏆" or "💎"))
                    end

                    -- Unlock interaction
                    if mx >= sx and mx <= sx + slotSize and my >= sy and my <= sy + slotSize and isClick then
                        if i == (PlayerData.UnlockedSouvenirSlots or 2) + 1 then
                            if cost then
                                PlayerData.ActiveDialog = {
                                    title = "Unlock Slot " .. i,
                                    message = string.format("Consume %d %s to unlock 1 souvenir slot?", cost.amount,
                                        cost.type),
                                    onConfirm = function()
                                        local canAfford = false
                                        if cost.type == "Trophies" then
                                            canAfford = PlayerData.Trophies >= cost.amount
                                            if canAfford then PlayerData.Trophies = PlayerData.Trophies - cost.amount end
                                        elseif cost.type == "Diamonds" then
                                            canAfford = PlayerData.Diamonds >= cost.amount
                                            if canAfford then PlayerData.Diamonds = PlayerData.Diamonds - cost.amount end
                                        end

                                        if canAfford then
                                            PlayerData.UnlockedSouvenirSlots = PlayerData.UnlockedSouvenirSlots + 1
                                            print("Slot " .. i .. " unlocked!")
                                        else
                                            print("Not enough resources!")
                                        end
                                    end
                                }
                            end
                        else
                            print("Must unlock slots in order!")
                        end
                    end
                else
                    -- Check content
                    local item = PlayerData.SouvenirSlots[i]
                    if item then
                        local cfg = SOUVENIR_CONFIG[item.configId]
                        if cfg then
                            -- 与背包格子一致的图标样式（名字/属性/星级位置统一）
                            DrawSouvenirIconBox(sx, sy, slotSize, cfg, item.star or 1)
                        end
                        -- Unequip on click
                        if mx >= sx and mx <= sx + slotSize and my >= sy and my <= sy + slotSize and isClick then
                            table.insert(PlayerData.SouvenirInventory, item)
                            PlayerData.SouvenirSlots[i] = nil
                        end
                    else
                        -- Empty/Locked icon
                        nvgFontSize(vg, 40)
                        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, nvgRGBA(255, 255, 255, 50))
                        nvgText(vg, sx + slotSize / 2, sy + slotSize / 2, "+")
                    end
                end
            end

            -- Inventory Grid (Right Side)
            local gridX = invX + 20 * BAG_SCALE
            local gridY = invY + 20 * BAG_SCALE
            local gridW = invW - 40 * BAG_SCALE
            local gridH = invH - 100 * BAG_SCALE -- space for buttons

            nvgScissor(vg, gridX, gridY, gridW, gridH)

            local iCols = math.floor(gridW / (slotSize + slotGap))
            if iCols < 1 then iCols = 1 end
            local iRows = math.ceil(#PlayerData.SouvenirInventory / iCols)
            local iTotalH = iRows * (slotSize + slotGap)
            local maxScroll = math.max(0, iTotalH - gridH)

            if not PlayerData.IsSouvenirFuseOpen then
                local wheel = input.mouseMoveWheel
                if wheel ~= 0 then
                    -- 只有当鼠标在右侧库存列表区域内时才响应滚动
                    -- 注意：gridX/Y/W/H 是在后面定义的，这里我们直接用 invX, invY 估算一个大概的交互区域
                    -- invX 是右侧整个区域的起始，invW是宽度
                    -- 为了体验更好，只要鼠标在纪念品Tab的内容区域内，都允许滚动
                    if mx >= invX and mx <= invX + invW and my >= invY and my <= invY + invH then
                        PlayerData.BagScrollY = PlayerData.BagScrollY - wheel * 60
                    end
                end
            end

            if PlayerData.BagScrollY < 0 then PlayerData.BagScrollY = 0 end
            if PlayerData.BagScrollY > maxScroll then PlayerData.BagScrollY = maxScroll end

            for i, item in ipairs(PlayerData.SouvenirInventory) do
                local r = math.floor((i - 1) / iCols)
                local c = (i - 1) % iCols
                local ix = gridX + c * (slotSize + slotGap)
                local iy = gridY + r * (slotSize + slotGap) - PlayerData.BagScrollY

                if iy + slotSize > gridY and iy < gridY + gridH then
                    nvgBeginPath(vg)
                    nvgRoundedRect(vg, ix, iy, slotSize, slotSize, 8)
                    local cfg = SOUVENIR_CONFIG[item.configId]
                    local cc = cfg and cfg.color or { r = 0.5, g = 0.5, b = 0.5 }
                    nvgFillColor(vg, nvgRGBAf(cc.r * 0.8, cc.g * 0.8, cc.b * 0.8, 1.0))
                    nvgFill(vg)

                    -- 使用与装备栏一致的图标绘制（名字 / 属性 / 星级固定在底部）
                    DrawSouvenirIconBox(ix, iy, slotSize, cfg, item.star or 1)

                    -- Equip on click
                    if mx >= ix and mx <= ix + slotSize and my >= iy and my <= iy + slotSize and isClick then
                        -- Find first empty slot
                        local found = false
                        local maxSlots = PlayerData.UnlockedSouvenirSlots or 2
                        for s = 1, maxSlots do
                            if not PlayerData.SouvenirSlots[s] then
                                PlayerData.SouvenirSlots[s] = item
                                found = true
                                -- Remove from inventory
                                table.remove(PlayerData.SouvenirInventory, i)
                                break
                            end
                        end
                        if not found then print("Slots full!") end
                    end
                end
            end
            nvgResetScissor(vg)

            -- Bottom Buttons
            local bbY = invY + invH - 70 * BAG_SCALE
            local bbW = 160 * BAG_SCALE
            local bbH = 50 * BAG_SCALE
            local bbGap = 20 * BAG_SCALE
            local bbCX = invX + invW / 2

            -- FUSE
            local fuseX = bbCX - bbW - bbGap / 2
            nvgBeginPath(vg)
            nvgRoundedRect(vg, fuseX, bbY, bbW, bbH, 8)
            local fuseHover = mx >= fuseX and mx <= fuseX + bbW and my >= bbY and my <= bbY + bbH
            if fuseHover then
                nvgFillColor(vg, nvgRGBA(255, 235, 0, 255))
            else
                nvgFillColor(vg, C_BTN_YELLOW)
            end
            nvgStrokeWidth(vg, 2)
            nvgStrokeColor(vg, C_STROKE)
            nvgStroke(vg)
            nvgFill(vg)
            nvgFillColor(vg, C_STROKE)
            nvgFontSize(vg, 24)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgText(vg, fuseX + bbW / 2, bbY + bbH / 2, "FUSE")

            if fuseHover and isClick then
                OpenSouvenirFuse()
            end

            -- DELETE
            local delX = bbCX + bbGap / 2
            nvgBeginPath(vg)
            nvgRoundedRect(vg, delX, bbY, bbW, bbH, 8)
            nvgFillColor(vg, C_BTN_RED)
            nvgStrokeWidth(vg, 2)
            nvgStrokeColor(vg, C_STROKE)
            nvgStroke(vg)
            nvgFill(vg)
            nvgFillColor(vg, C_TEXT_W)
            nvgText(vg, delX + bbW / 2, bbY + bbH / 2, "DELETE")
        elseif PlayerData.CurrentBagTab == 3 then
            -- ====================================================================
            -- TAB 3: CHEST UI
            -- ====================================================================
            local chestX, chestY, chestW, chestH = contentX, contentY, contentW, contentH
            local headerH = 70

            -- Header
            nvgBeginPath(vg)
            nvgRoundedRect(vg, chestX, chestY, chestW, headerH, 12)
            nvgFillColor(vg, nvgRGBA(200, 100, 50, 255))
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgRect(vg, chestX, chestY + headerH - 12, chestW, 12)
            nvgFillColor(vg, nvgRGBA(200, 100, 50, 255))
            nvgFill(vg)
            nvgBeginPath(vg)
            nvgRect(vg, chestX, chestY, 12, headerH) -- Left square
            nvgFillColor(vg, nvgRGBA(200, 100, 50, 255))
            nvgFill(vg)

            -- Title
            BagFont(48)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, C_TEXT_W)
            nvgText(vg, chestX + 24, chestY + headerH / 2, "CHEST")

            -- Layout: Left List, Right Details/Roll
            local leftX = chestX + 20
            local leftY = chestY + headerH + 20
            local leftW = chestW * 0.4
            local leftH = chestH - headerH - 40

            local rightX = leftX + leftW + 20
            local rightY = leftY
            local rightW = chestW - leftW - 40
            local rightH = leftH

            -- Left List Background
            nvgBeginPath(vg)
            nvgRoundedRect(vg, leftX, leftY, leftW, leftH, 10)
            nvgFillColor(vg, nvgRGBA(5, 20, 40, 255))
            nvgFill(vg)

            -- Draw Chest List
            local itemH = 100
            for i, chest in ipairs(PlayerData.SouvenirChests) do
                local cy = leftY + 10 + (i - 1) * (itemH + 10)
                local cw = leftW - 20
                local cx = leftX + 10

                local isSelected = (PlayerData.SelectedChestIndex == i)

                nvgBeginPath(vg)
                nvgRoundedRect(vg, cx, cy, cw, itemH, 8)
                if isSelected then
                    nvgFillColor(vg, nvgRGBA(80, 120, 180, 255))
                else
                    nvgFillColor(vg, nvgRGBA(40, 60, 90, 255))
                end
                nvgFill(vg)

                local cfg = SOUVENIR_CHEST_CONFIG[chest.id]
                if cfg then
                    nvgFontSize(vg, 28)
                    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                    nvgFillColor(vg, C_TEXT_W)
                    nvgText(vg, cx + 15, cy + 15, cfg.name)

                    nvgFontSize(vg, 22)
                    nvgFillColor(vg, nvgRGBA(200, 200, 200, 255))
                    nvgText(vg, cx + 15, cy + 50, "数量: " .. chest.count)
                end

                if mx >= cx and mx <= cx + cw and my >= cy and my <= cy + itemH and isClick then
                    PlayerData.SelectedChestIndex = i
                end
            end

            -- Right Details Area
            nvgBeginPath(vg)
            nvgRoundedRect(vg, rightX, rightY, rightW, rightH, 10)
            nvgFillColor(vg, nvgRGBA(10, 30, 60, 255))
            nvgFill(vg)

            if ChestRollState.active then
                -- Draw Rolling Animation
                nvgSave(vg)
                nvgScissor(vg, rightX + 20, rightY + 100, rightW - 40, 160)

                -- Center Line
                local centerY = rightY + 100 + 80
                local centerX = rightX + rightW / 2

                -- Calculate Scroll
                local t = ChestRollState.elapsed / ChestRollState.duration
                if t > 1 then t = 1 end
                t = 1 - (1 - t) * (1 - t) * (1 - t) -- Ease Out Cubic

                local viewW = rightW - 40
                local targetCenterX = (ChestRollState.targetIndex - 0.5) * ChestRollState.cellW
                local finalScrollX = targetCenterX - viewW / 2

                local currentScrollX = finalScrollX * t
                local startX = rightX + 20 - currentScrollX

                for i, sId in ipairs(ChestRollState.reel) do
                    local sx = startX + (i - 1) * ChestRollState.cellW
                    local sy = rightY + 100 + 10 -- padding

                    local cfg = SOUVENIR_CONFIG[sId]
                    if cfg then
                        nvgBeginPath(vg)
                        nvgRoundedRect(vg, sx + 5, sy, ChestRollState.cellW - 10, 140, 8)
                        local cc = cfg.color or Color(0.5, 0.5, 0.5)
                        nvgFillColor(vg, nvgRGBAf(cc.r, cc.g, cc.b, 1.0))
                        nvgFill(vg)

                        nvgFontSize(vg, 20)
                        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                        nvgFillColor(vg, C_TEXT_W)
                        nvgText(vg, sx + ChestRollState.cellW / 2, sy + 70, cfg.name)

                        -- Show Star
                        nvgText(vg, sx + ChestRollState.cellW / 2, sy + 30, "★")
                    end
                end

                nvgRestore(vg)

                -- Highlight Box (Fixed in Center)
                nvgBeginPath(vg)
                nvgRoundedRect(vg, centerX - ChestRollState.cellW / 2, rightY + 110, ChestRollState.cellW, 140, 8)
                nvgStrokeWidth(vg, 4)
                nvgStrokeColor(vg, nvgRGBA(255, 215, 0, 255))
                nvgStroke(vg)

                -- Skip/Claim Button
                local btnW, btnH = 200, 60
                local btnX = rightX + (rightW - btnW) / 2
                local btnY = rightY + 300
                nvgBeginPath(vg)
                nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 8)

                local btnLabel = "跳过动画"
                local btnColor = nvgRGBA(100, 100, 100, 255)

                if ChestRollState.isFinished then
                    btnLabel = "领取奖励"
                    btnColor = nvgRGBA(255, 215, 0, 255) -- 金色高亮
                end

                nvgFillColor(vg, btnColor)
                nvgFill(vg)
                nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgFillColor(vg, C_TEXT_W)
                nvgText(vg, btnX + btnW / 2, btnY + btnH / 2, btnLabel)

                if mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH and isClick then
                    if ChestRollState.isFinished then
                        FinishChestRoll()
                    else
                        ChestRollState.skipRequested = true
                    end
                end
            else
                -- Details & Open Button
                if PlayerData.SelectedChestIndex then
                    local chest = PlayerData.SouvenirChests[PlayerData.SelectedChestIndex]
                    local cfg = SOUVENIR_CHEST_CONFIG[chest.id]
                    if cfg then
                        nvgFontSize(vg, 36)
                        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
                        nvgFillColor(vg, C_TEXT_W)
                        nvgText(vg, rightX + rightW / 2, rightY + 50, cfg.name)

                        nvgFontSize(vg, 24)
                        nvgText(vg, rightX + rightW / 2, rightY + 100, cfg.desc)

                        -- Open Button
                        local btnW, btnH = 240, 80
                        local btnX = rightX + (rightW - btnW) / 2
                        local btnY = rightY + rightH - 120

                        nvgBeginPath(vg)
                        nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 10)
                        local hover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH
                        if hover then
                            nvgFillColor(vg, nvgRGBA(255, 200, 0, 255))
                        else
                            nvgFillColor(vg, nvgRGBA(200, 160, 0, 255))
                        end
                        nvgFill(vg)

                        nvgFontSize(vg, 32)
                        nvgFillColor(vg, nvgRGBA(0, 0, 0, 255))
                        nvgText(vg, btnX + btnW / 2, btnY + btnH / 2, "OPEN CHEST")

                        if hover and isClick then
                            StartChestRoll()
                        end
                    end
                else
                    nvgFontSize(vg, 24)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(150, 150, 150, 255))
                    nvgText(vg, rightX + rightW / 2, rightY + rightH / 2, "请选择一个宝箱")
                end
            end
        end

        -- 全局关闭按钮（绘制在最上层，确保可见）
        do
            nvgBeginPath(vg)
            nvgRoundedRect(vg, closeX, closeY, closeSize, closeSize, 8)
            nvgFillColor(vg, C_BTN_RED)
            nvgStrokeWidth(vg, 3)
            nvgStrokeColor(vg, C_STROKE)
            nvgStroke(vg)
            nvgFill(vg)

            BagFont(32)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, C_TEXT_W)
            nvgText(vg, closeX + closeSize / 2, closeY + closeSize / 2 - 2, "X")

            if mx >= closeX and mx <= closeX + closeSize and my >= closeY and my <= closeY + closeSize and isClick then
                PlayerData.IsBagOpen = false
                SetMouseMode(false)
            end
        end

        -- Dialog Rendering (Keep Existing Logic)
        if PlayerData.ActiveDialog then
            nvgBeginPath(vg)
            nvgRect(vg, 0, 0, w, h)
            nvgFillColor(vg, nvgRGBA(0, 0, 0, 150))
            nvgFill(vg)

            local dlgW, dlgH = 500, 250
            local dlgX, dlgY = (w - dlgW) / 2, (h - dlgH) / 2
            nvgBeginPath(vg)
            nvgRoundedRect(vg, dlgX, dlgY, dlgW, dlgH, 12)
            nvgFillColor(vg, C_WIN_BG)
            nvgStrokeWidth(vg, 3)
            nvgStrokeColor(vg, C_BTN_RED)
            nvgStroke(vg)
            nvgFill(vg)

            nvgFontSize(vg, 32)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg, C_BTN_YELLOW)
            nvgText(vg, w / 2, dlgY + 30, PlayerData.ActiveDialog.title)

            nvgFontSize(vg, 24)
            nvgFillColor(vg, C_TEXT_W)
            nvgText(vg, w / 2, dlgY + 80, PlayerData.ActiveDialog.message)

            local btnW_d = 140
            local btnH_d = 50
            local yesX = w / 2 - btnW_d - 20
            local noX = w / 2 + 20
            local btnY_d = dlgY + dlgH - 70

            -- Yes
            nvgBeginPath(vg)
            nvgRoundedRect(vg, yesX, btnY_d, btnW_d, btnH_d, 8)
            nvgFillColor(vg, C_BTN_RED)
            nvgFill(vg)
            nvgFillColor(vg, C_TEXT_W)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgText(vg, yesX + btnW_d / 2, btnY_d + btnH_d / 2, "Yes")
            if mx >= yesX and mx <= yesX + btnW_d and my >= btnY_d and my <= btnY_d + btnH_d and isClick then
                if PlayerData.ActiveDialog.onConfirm then PlayerData.ActiveDialog.onConfirm() end
                PlayerData.ActiveDialog = nil
            end

            -- No
            nvgBeginPath(vg)
            nvgRoundedRect(vg, noX, btnY_d, btnW_d, btnH_d, 8)
            nvgFillColor(vg, nvgRGBA(100, 100, 100, 255))
            nvgFill(vg)
            nvgFillColor(vg, C_TEXT_W)
            nvgText(vg, noX + btnW_d / 2, btnY_d + btnH_d / 2, "No")
            if mx >= noX and mx <= noX + btnW_d and my >= btnY_d and my <= btnY_d + btnH_d and isClick then
                if PlayerData.ActiveDialog.onCancel then PlayerData.ActiveDialog.onCancel() end
                PlayerData.ActiveDialog = nil
            end
        end
    end

    -- 5. 纪念品融合界面（覆盖在其他UI之上）
    if PlayerData.IsSouvenirFuseOpen then
        local mousePos = input.mousePosition
        local mx, my = mousePos.x, mousePos.y
        local isClick = input:GetMouseButtonPress(MOUSEB_LEFT)

        -- 半透明背景
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, w, h)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 180))
        nvgFill(vg)

        -- 主窗口
        local winW, winH = 1000, 560
        local winX, winY = (w - winW) / 2, (h - winH) / 2

        nvgBeginPath(vg)
        nvgRoundedRect(vg, winX, winY, winW, winH, 12)
        nvgFillColor(vg, nvgRGBA(10, 40, 80, 255))
        nvgFill(vg)

        -- 头部区域
        local headerH = 70
        nvgBeginPath(vg)
        nvgRoundedRect(vg, winX, winY, winW, headerH, 12)
        nvgFillColor(vg, nvgRGBA(0, 150, 255, 255))
        nvgFill(vg)
        nvgBeginPath(vg)
        nvgRect(vg, winX, winY + headerH - 12, winW, 12)
        nvgFillColor(vg, nvgRGBA(0, 150, 255, 255))
        nvgFill(vg)

        -- 标题 FUSE
        nvgFontSize(vg, 48)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 120))
        nvgText(vg, winX + 26, winY + headerH / 2 + 4, "FUSE")
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, winX + 22, winY + headerH / 2, "FUSE")

        -- 关闭按钮
        local closeSize = 40
        local closeX = winX + winW - closeSize - 15
        local closeY = winY + (headerH - closeSize) / 2
        nvgBeginPath(vg)
        nvgRoundedRect(vg, closeX, closeY, closeSize, closeSize, 8)
        local closeHover = mx >= closeX and mx <= closeX + closeSize and my >= closeY and my <= closeY + closeSize
        if closeHover then
            nvgFillColor(vg, nvgRGBA(255, 60, 60, 255))
        else
            nvgFillColor(vg, nvgRGBA(220, 50, 50, 255))
        end
        nvgFill(vg)
        nvgFontSize(vg, 30)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, closeX + closeSize / 2, closeY + closeSize / 2 - 1, "X")

        if closeHover and isClick then
            CloseSouvenirFuse()
        end

        -- 左右分栏
        local leftX = winX + 20
        local leftY = winY + headerH + 20
        local leftW = winW * 0.65 - 30
        local leftH = winH - headerH - 40

        local rightX = leftX + leftW + 20
        local rightY = leftY
        local rightW = winW - (rightX - winX) - 20
        local rightH = leftH

        -- 左侧：纪念品网格
        nvgBeginPath(vg)
        nvgRoundedRect(vg, leftX, leftY, leftW, leftH, 10)
        nvgFillColor(vg, nvgRGBA(5, 20, 60, 255))
        nvgFill(vg)

        local gridPadding = 16
        local cardSize = 120
        local cardGap = 14
        local gridX = leftX + gridPadding
        local gridY = leftY + gridPadding
        local gridW = leftW - gridPadding * 2
        local cols = math.floor(gridW / (cardSize + cardGap))
        if cols < 1 then cols = 1 end

        -- 融合界面的滚轮支持
        local rows = math.ceil(#PlayerData.SouvenirInventory / cols)
        local totalGridH = rows * (cardSize + cardGap) + gridPadding * 2
        local viewH = leftH
        local maxFuseScroll = math.max(0, totalGridH - viewH)

        -- 确保滚动变量初始化
        if not PlayerData.SouvenirFuseScrollY then PlayerData.SouvenirFuseScrollY = 0 end

        local fuseWheel = input.mouseMoveWheel
        if fuseWheel ~= 0 and mx >= leftX and mx <= leftX + leftW and my >= leftY and my <= leftY + leftH then
            PlayerData.SouvenirFuseScrollY = PlayerData.SouvenirFuseScrollY - fuseWheel * 60
        end
        if PlayerData.SouvenirFuseScrollY < 0 then PlayerData.SouvenirFuseScrollY = 0 end
        if PlayerData.SouvenirFuseScrollY > maxFuseScroll then PlayerData.SouvenirFuseScrollY = maxFuseScroll end

        nvgScissor(vg, leftX, leftY, leftW, leftH)

        for i, item in ipairs(PlayerData.SouvenirInventory) do
            local row = math.floor((i - 1) / cols)
            local col = (i - 1) % cols
            local cx = gridX + col * (cardSize + cardGap)
            local cy = gridY + row * (cardSize + cardGap) - PlayerData.SouvenirFuseScrollY

            if cy + cardSize > leftY and cy < leftY + leftH then
                local cfg = SOUVENIR_CONFIG[item.configId]
                local cc = (cfg and cfg.color) or Color(0.5, 0.5, 0.5)

                -- 卡片背景
                nvgBeginPath(vg)
                nvgRoundedRect(vg, cx, cy, cardSize, cardSize, 10)
                nvgFillColor(vg, nvgRGBAf(cc.r * 0.7, cc.g * 0.7, cc.b * 0.7, 1.0))
                nvgFill(vg)

                -- 内部色块
                nvgBeginPath(vg)
                nvgRoundedRect(vg, cx + 12, cy + 12, cardSize - 24, cardSize - 24, 8)
                nvgFillColor(vg, nvgRGBAf(cc.r, cc.g, cc.b, 1.0))
                nvgFill(vg)

                -- 星级显示
                local star = item.star or 1
                local starStr = ""
                for s = 1, star do starStr = starStr .. "★" end
                nvgFontSize(vg, 20)
                nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
                nvgFillColor(vg, nvgRGBA(255, 215, 0, 255))
                nvgText(vg, cx + 14, cy + 10, starStr)

                -- 名字
                if cfg then
                    nvgFontSize(vg, 20)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
                    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
                    nvgText(vg, cx + cardSize / 2, cy + cardSize - 6, cfg.name or "")
                end

                local isTarget = (SouvenirFuseState.targetUUID == item.uuid)
                local isMaterial = (SouvenirFuseState.materialUUIDs[item.uuid] == true)

                -- 边框：目标 = 绿色; 材料 = 黄色; 普通 = 黑色
                nvgStrokeWidth(vg, isTarget and 5 or (isMaterial and 4 or 2))
                if isTarget then
                    nvgStrokeColor(vg, nvgRGBA(50, 220, 50, 255))
                elseif isMaterial then
                    nvgStrokeColor(vg, nvgRGBA(255, 220, 0, 255))
                else
                    nvgStrokeColor(vg, nvgRGBA(0, 0, 0, 180))
                end
                nvgStroke(vg)

                -- Target 勾选标记
                if isTarget then
                    local markSize = 26
                    local mx0 = cx + cardSize - markSize - 6
                    local my0 = cy + 6
                    nvgBeginPath(vg)
                    nvgRoundedRect(vg, mx0, my0, markSize, markSize, 6)
                    nvgFillColor(vg, nvgRGBA(40, 200, 80, 255))
                    nvgFill(vg)
                    nvgFontSize(vg, 22)
                    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
                    nvgText(vg, mx0 + markSize / 2, my0 + markSize / 2, "✓")
                end

                -- 交互逻辑
                local hover = mx >= cx and mx <= cx + cardSize and my >= cy and my <= cy + cardSize
                if hover and isClick then
                    if not SouvenirFuseState.targetUUID then
                        -- 第一次点击：设置目标
                        SouvenirFuseState.targetUUID = item.uuid
                        SouvenirFuseState.materialUUIDs = {}
                    else
                        if item.uuid == SouvenirFuseState.targetUUID then
                            -- 再次点击目标：清空选择
                            ResetSouvenirFuseState()
                        else
                            if SouvenirFuseState.materialUUIDs[item.uuid] then
                                SouvenirFuseState.materialUUIDs[item.uuid] = nil
                            else
                                local currentChance = CalcSouvenirFuseChance()
                                if currentChance >= (CONFIG.SouvenirFuseMaxChance or 1.0) then
                                    SouvenirFuseState.lastResult = "成功率已达上限，无需添加更多材料。"
                                else
                                    SouvenirFuseState.materialUUIDs[item.uuid] = true
                                end
                            end
                        end
                    end
                    SouvenirFuseState.lastResult = nil
                end
            end
        end

        nvgResetScissor(vg)

        -- 右侧：成功率与操作区
        nvgBeginPath(vg)
        nvgRoundedRect(vg, rightX, rightY, rightW, rightH, 10)
        nvgFillColor(vg, nvgRGBA(5, 30, 70, 255))
        nvgFill(vg)

        -- 成功率文字
        local chance = CalcSouvenirFuseChance()
        local chancePct = math.floor(chance * 100 + 0.5)

        nvgFontSize(vg, 52)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 215, 0, 255))
        nvgText(vg, rightX + rightW / 2, rightY + 30, string.format("%d%%", chancePct))

        nvgFontSize(vg, 26)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, rightX + rightW / 2, rightY + 100, "Success Chance")

        -- 说明文字
        nvgFontSize(vg, 18)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(220, 220, 220, 255))
        local tipY = rightY + 145
        nvgText(vg, rightX + rightW / 2, tipY,
            "先选择 1 个目标纪念品，再选择若干纪念品作为材料，")
        nvgText(vg, rightX + rightW / 2, tipY + 24,
            string.format("每个材料 +%d%% 成功率，可配置。", math.floor((CONFIG.SouvenirFusePerMaterialChance or 0) * 100 + 0.5)))

        -- 融合按钮
        local btnW, btnH = rightW * 0.7, 70
        local btnX = rightX + (rightW - btnW) / 2
        local btnY = rightY + rightH - btnH - 80

        local canFuse = SouvenirFuseState.targetUUID ~= nil and #PlayerData.SouvenirInventory > 0

        nvgBeginPath(vg)
        nvgRoundedRect(vg, btnX, btnY, btnW, btnH, 10)
        local fuseHover2 = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH

        if not canFuse then
            nvgFillColor(vg, nvgRGBA(100, 100, 100, 255))
        elseif fuseHover2 then
            nvgFillColor(vg, nvgRGBA(80, 230, 80, 255))
        else
            nvgFillColor(vg, nvgRGBA(50, 205, 50, 255))
        end
        nvgFill(vg)

        nvgFontSize(vg, 32)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
        nvgText(vg, btnX + btnW / 2, btnY + btnH / 2 - 2, "FUSE")

        if canFuse and fuseHover2 and isClick then
            PerformSouvenirFuse()
        end

        -- 红色警告文字
        nvgFontSize(vg, 20)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(vg, nvgRGBA(255, 80, 80, 255))
        nvgText(vg, rightX + rightW / 2, btnY + btnH + 10, "被选为材料的纪念品将被永久消耗！")

        -- 结果提示
        if SouvenirFuseState.lastResult then
            nvgFontSize(vg, 20)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, rightX + rightW / 2, rightY + rightH - 30, SouvenirFuseState.lastResult)
        end
    end

    -- 中间提示
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgFillColor(vg, nvgRGBA(255, 255, 0, 255))

    local tip = ""
    if currentState == GameState.Idle then
        tip = "WASD to Move, SPACE to Jump -> Walk to Tower to Climb"
    elseif currentState == GameState.Climbing then
        if PlayerData.FatigueTextTimer > 0 then
            -- 红色疲劳提示
            nvgFontSize(vg, 40)
            nvgFillColor(vg, nvgRGBA(255, 50, 50, 255))
            nvgText(vg, w / 2, h / 2, "你累了，攀爬速度降低！")

            -- 恢复下方提示字体大小
            nvgFontSize(vg, 24)
        end
        tip = string.format("Auto Climbing... Speed: %.1f (Level %d)",
            CONFIG.ClimbSpeed * (CONFIG.FatigueSpeedFactor ^ PlayerData.FatigueLevel),
            PlayerData.FatigueLevel)
    elseif currentState == GameState.OnTop then
        tip = "You Reached the Top! Collect Trophy or Jump Off"
    elseif currentState == GameState.Falling then
        tip = "Wheeeeeee!"
    end

    -- 文字阴影
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 200))
    nvgText(vg, w / 2 + 2, h - 48, tip)

    -- 文字本体
    nvgFillColor(vg, nvgRGBA(255, 255, 0, 255))
    nvgText(vg, w / 2, h - 50, tip)

    nvgEndFrame(vg)
end
