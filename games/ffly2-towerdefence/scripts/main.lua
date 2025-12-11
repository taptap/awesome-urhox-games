--[[
2D塔防游戏

=== 核心系统 ===
1. 关卡配置
   - 路线点：敌人行进路径的拐点坐标列表
   - 波次配置：每波敌人类型、数量、生成间隔
   - 防御塔放置点：预设的可放置防御塔位置
   - 关卡难度递增

2. 敌人配置
   - 形状：使用简单几何图形（圆形=普通、三角形=快速、正方形=坦克）
   - 颜色：绿色=弱、黄色=中等、红色=强、紫色=boss
   - 属性：生命值、防御力、移动速度、击杀奖励金币

3. 防御塔配置
   - 类型：箭塔（单体快速）、炮塔（范围伤害）、减速塔（减速效果）、激光塔（持续伤害）
   - 形状：使用几何图形区分塔类型
   - 属性：攻击力、攻击速度、攻击范围、建造费用

4. 防御塔升级
   - 每种塔有3级，升级提升属性
   - 升级费用 = 建造费用 * 等级
   - 外观随等级变化（大小、颜色深度）

5. 防御塔拆除/出售
   - 出售返还 60% 累计投入金币
   - 拆除后位置可重新建造

=== 经济系统 ===
- 初始金币：100
- 击杀奖励：根据敌人类型
- 波次奖励：完成每波额外奖励

=== 生命系统 ===
- 初始生命：20
- 敌人到达终点扣除生命（根据敌人类型）
- 生命归零游戏失败

=== UI系统 ===
1. 游戏开始页面
   - 关卡选择（3个关卡）
   - 游戏说明

2. 游戏进行页面
   - 顶部HUD：金币、生命、波次信息
   - 底部：防御塔选择栏
   - 点击放置点：显示建造/升级/出售菜单

3. 游戏结束页面
   - 胜利/失败状态
   - 统计信息：击杀数、金币收入
   - 重新开始/返回菜单
]]

-- ============================================================================
-- UrhoX 2D 塔防游戏 (Tower Defence Game)
-- 使用 NanoVG 实现的完整塔防游戏
-- ============================================================================

require "LuaScripts/Utilities/Sample"

-- ============================================================================
-- 1. 全局变量声明
-- ============================================================================
---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil
---@type NVGContextWrapper|nil
local nvg_ = nil

-- 游戏配置
local CONFIG = {
    Title = "2D 塔防游戏",
    Width = 1920,
    Height = 1080,
    PixelPerUnit = 100.0,
    
    -- 游戏参数
    InitialGold = 300,
    InitialLives = 20,
    SellRefundRate = 0.6,
    WaveBonus = 50,
    
    -- 格子大小（用于放置塔）
    GridSize = 48,
}

-- ============================================================================
-- 技能树配置
-- ============================================================================
-- 技能树分为4条线路：
-- 1. tower   - 防御塔强化线：提升防御塔属性
-- 2. life    - 生命线：提升生命值上限
-- 3. gold    - 初始金币线：提升游戏开始时的金币
-- 4. income  - 金币收益线：提升金币获取效率

local SkillTree = {
    -- ========================================
    -- 防御塔强化线
    -- ========================================
    tower = {
        name = "防御塔强化",
        icon = "tower",
        skills = {
            -- 基础伤害提升
            tower_damage_1 = {
                name = "锋利箭头",
                description = "所有防御塔伤害 +10%",
                maxLevel = 3,
                prerequisite = nil,  -- 无前置，可直接学习
                costs = {100, 200, 400},  -- 每级花费的技能点
                effects = {
                    {type = "tower_damage", value = 0.10},  -- 等级1: +10%
                    {type = "tower_damage", value = 0.20},  -- 等级2: +20%
                    {type = "tower_damage", value = 0.30},  -- 等级3: +30%
                },
            },
            -- 攻击速度提升
            tower_speed_1 = {
                name = "快速装填",
                description = "所有防御塔攻击速度 +10%",
                maxLevel = 3,
                prerequisite = "tower_damage_1",  -- 需要先学习锋利箭头
                costs = {150, 300, 600},
                effects = {
                    {type = "tower_attackspeed", value = 0.10},
                    {type = "tower_attackspeed", value = 0.20},
                    {type = "tower_attackspeed", value = 0.30},
                },
            },
            -- 攻击范围提升
            tower_range_1 = {
                name = "精准瞄准",
                description = "所有防御塔攻击范围 +15%",
                maxLevel = 2,
                prerequisite = "tower_speed_1",
                costs = {200, 500},
                effects = {
                    {type = "tower_range", value = 0.15},
                    {type = "tower_range", value = 0.30},
                },
            },
            -- 箭塔专精
            tower_arrow_master = {
                name = "箭塔大师",
                description = "箭塔伤害 +25%，攻击速度 +15%",
                maxLevel = 1,
                prerequisite = "tower_range_1",
                costs = {800},
                effects = {
                    {type = "arrow_damage", value = 0.25, type2 = "arrow_attackspeed", value2 = 0.15},
                },
            },
            -- 炮塔专精
            tower_cannon_master = {
                name = "炮塔大师",
                description = "炮塔伤害 +20%，溅射范围 +30%",
                maxLevel = 1,
                prerequisite = "tower_range_1",
                costs = {800},
                effects = {
                    {type = "cannon_damage", value = 0.20, type2 = "cannon_splash", value2 = 0.30},
                },
            },
            -- 减速塔专精
            tower_slow_master = {
                name = "减速大师",
                description = "减速塔效果 +20%，持续时间 +1秒",
                maxLevel = 1,
                prerequisite = "tower_range_1",
                costs = {800},
                effects = {
                    {type = "slow_effect", value = 0.20, type2 = "slow_duration", value2 = 1.0},
                },
            },
            -- 激光塔专精
            tower_laser_master = {
                name = "激光大师",
                description = "激光塔伤害 +30%，范围 +20%",
                maxLevel = 1,
                prerequisite = "tower_range_1",
                costs = {800},
                effects = {
                    {type = "laser_damage", value = 0.30, type2 = "laser_range", value2 = 0.20},
                },
            },
        },
    },
    
    -- ========================================
    -- 生命线
    -- ========================================
    life = {
        name = "生命强化",
        icon = "heart",
        skills = {
            -- 基础生命提升
            life_base_1 = {
                name = "坚固城墙",
                description = "初始生命值 +5",
                maxLevel = 4,
                prerequisite = nil,
                costs = {80, 160, 320, 640},
                effects = {
                    {type = "max_lives", value = 5},
                    {type = "max_lives", value = 10},
                    {type = "max_lives", value = 15},
                    {type = "max_lives", value = 20},
                },
            },
            -- 生命恢复
            life_regen = {
                name = "城墙修复",
                description = "每波结束后恢复生命值",
                maxLevel = 3,
                prerequisite = "life_base_1",
                costs = {200, 400, 800},
                effects = {
                    {type = "life_regen_wave", value = 1},  -- 每波恢复1点
                    {type = "life_regen_wave", value = 2},  -- 每波恢复2点
                    {type = "life_regen_wave", value = 3},  -- 每波恢复3点
                },
            },
            -- 减少伤害
            life_armor = {
                name = "铁甲护城",
                description = "敌人造成的伤害减少",
                maxLevel = 2,
                prerequisite = "life_regen",
                costs = {500, 1000},
                effects = {
                    {type = "damage_reduction", value = 1},  -- 每个敌人少扣1点生命
                    {type = "damage_reduction", value = 2},  -- 每个敌人少扣2点生命
                },
            },
            -- 最后防线
            life_last_stand = {
                name = "最后防线",
                description = "生命值降到5以下时，防御塔伤害 +50%",
                maxLevel = 1,
                prerequisite = "life_armor",
                costs = {1200},
                effects = {
                    {type = "last_stand_damage", value = 0.50, threshold = 5},
                },
            },
        },
    },
    
    -- ========================================
    -- 初始金币线
    -- ========================================
    gold = {
        name = "初始财富",
        icon = "coin",
        skills = {
            -- 基础金币提升
            gold_start_1 = {
                name = "家族遗产",
                description = "初始金币 +50",
                maxLevel = 5,
                prerequisite = nil,
                costs = {50, 100, 200, 400, 800},
                effects = {
                    {type = "start_gold", value = 50},
                    {type = "start_gold", value = 100},
                    {type = "start_gold", value = 150},
                    {type = "start_gold", value = 200},
                    {type = "start_gold", value = 250},
                },
            },
            -- 贷款系统
            gold_loan = {
                name = "皇家贷款",
                description = "游戏开始时获得额外金币（波次奖励减少10%）",
                maxLevel = 2,
                prerequisite = "gold_start_1",
                costs = {300, 600},
                effects = {
                    {type = "start_gold", value = 100, type2 = "wave_bonus", value2 = -0.10},
                    {type = "start_gold", value = 200, type2 = "wave_bonus", value2 = -0.20},
                },
            },
            -- 建造折扣
            gold_discount = {
                name = "批发采购",
                description = "防御塔建造费用减少",
                maxLevel = 3,
                prerequisite = "gold_start_1",
                costs = {200, 400, 800},
                effects = {
                    {type = "tower_cost", value = -0.05},  -- -5%
                    {type = "tower_cost", value = -0.10},  -- -10%
                    {type = "tower_cost", value = -0.15},  -- -15%
                },
            },
            -- 出售增益
            gold_sell = {
                name = "精明商人",
                description = "出售防御塔返还比例提升",
                maxLevel = 2,
                prerequisite = "gold_discount",
                costs = {400, 800},
                effects = {
                    {type = "sell_refund", value = 0.10},  -- 60% -> 70%
                    {type = "sell_refund", value = 0.20},  -- 60% -> 80%
                },
            },
        },
    },
    
    -- ========================================
    -- 金币收益线
    -- ========================================
    income = {
        name = "金币收益",
        icon = "gold_bar",
        skills = {
            -- 击杀奖励提升
            income_kill_1 = {
                name = "赏金猎人",
                description = "击杀敌人获得的金币 +10%",
                maxLevel = 4,
                prerequisite = nil,
                costs = {100, 200, 400, 800},
                effects = {
                    {type = "kill_gold", value = 0.10},
                    {type = "kill_gold", value = 0.20},
                    {type = "kill_gold", value = 0.30},
                    {type = "kill_gold", value = 0.40},
                },
            },
            -- 波次奖励提升
            income_wave_1 = {
                name = "战术胜利",
                description = "完成波次奖励 +20",
                maxLevel = 3,
                prerequisite = "income_kill_1",
                costs = {150, 300, 600},
                effects = {
                    {type = "wave_bonus_flat", value = 20},
                    {type = "wave_bonus_flat", value = 40},
                    {type = "wave_bonus_flat", value = 60},
                },
            },
            -- 连杀奖励
            income_combo = {
                name = "连杀奖励",
                description = "快速连续击杀敌人获得额外金币",
                maxLevel = 2,
                prerequisite = "income_wave_1",
                costs = {400, 800},
                effects = {
                    {type = "combo_bonus", value = 1, threshold = 3},   -- 3连杀+1金币
                    {type = "combo_bonus", value = 2, threshold = 3},   -- 3连杀+2金币
                },
            },
            -- 利息系统
            income_interest = {
                name = "金库利息",
                description = "每波开始时根据持有金币获得利息",
                maxLevel = 3,
                prerequisite = "income_wave_1",
                costs = {500, 1000, 2000},
                effects = {
                    {type = "interest", value = 0.02},  -- 2%利息
                    {type = "interest", value = 0.04},  -- 4%利息
                    {type = "interest", value = 0.06},  -- 6%利息
                },
            },
            -- 完美波次
            income_perfect = {
                name = "完美防守",
                description = "一波中不损失生命，额外获得金币",
                maxLevel = 2,
                prerequisite = "income_combo",
                costs = {600, 1200},
                effects = {
                    {type = "perfect_wave_bonus", value = 30},
                    {type = "perfect_wave_bonus", value = 60},
                },
            },
        },
    },
}

-- 玩家技能点数据（存档用）
local PlayerSkills = {
    skillPoints = 1000,         -- 可用技能点（初始给一些用于测试）
    totalPointsEarned = 1000,   -- 累计获得的技能点
    unlockedSkills = {},       -- 已解锁的技能 {skillId = currentLevel}
}

-- 技能树布局配置
local SkillTreeLayout = {
    lineOrder = {"tower", "life", "gold", "income"},
    lineColors = {
        tower = {62, 213, 170},   -- 青色
        life = {255, 100, 120},   -- 红色
        gold = {255, 200, 80},    -- 金色
        income = {100, 180, 255}, -- 蓝色
    },
    lineIcons = {
        tower = "🏰",
        life = "❤️",
        gold = "💰",
        income = "📈",
    },
}

-- 获取技能当前等级
local function GetSkillLevel(skillId)
    return PlayerSkills.unlockedSkills[skillId] or 0
end

-- 检查技能是否可以升级
local function CanUpgradeSkill(lineId, skillId)
    local line = SkillTree[lineId]
    if not line then return false, "技能线不存在" end
    
    local skill = line.skills[skillId]
    if not skill then return false, "技能不存在" end
    
    local currentLevel = GetSkillLevel(skillId)
    
    -- 检查是否已满级
    if currentLevel >= skill.maxLevel then
        return false, "技能已满级"
    end
    
    -- 检查前置技能
    if skill.prerequisite then
        local prereqLevel = GetSkillLevel(skill.prerequisite)
        if prereqLevel <= 0 then
            return false, "需要先学习前置技能"
        end
    end
    
    -- 检查技能点
    local cost = skill.costs[currentLevel + 1]
    if PlayerSkills.skillPoints < cost then
        return false, "技能点不足"
    end
    
    return true, nil
end

-- 升级技能
local function UpgradeSkill(lineId, skillId)
    local canUpgrade, errorMsg = CanUpgradeSkill(lineId, skillId)
    if not canUpgrade then
        return false, errorMsg
    end
    
    local skill = SkillTree[lineId].skills[skillId]
    local currentLevel = GetSkillLevel(skillId)
    local cost = skill.costs[currentLevel + 1]
    
    PlayerSkills.skillPoints = PlayerSkills.skillPoints - cost
    PlayerSkills.unlockedSkills[skillId] = currentLevel + 1
    
    return true, nil
end

-- 获取技能效果（用于游戏中应用）
local function GetSkillEffect(effectType)
    local totalValue = 0
    
    for lineId, line in pairs(SkillTree) do
        for skillId, skill in pairs(line.skills) do
            local level = GetSkillLevel(skillId)
            if level > 0 then
                local effect = skill.effects[level]
                if effect and effect.type == effectType then
                    totalValue = totalValue + effect.value
                end
                if effect and effect.type2 == effectType then
                    totalValue = totalValue + effect.value2
                end
            end
        end
    end
    
    return totalValue
end

-- 游戏状态
local GameState = {
    MENU = "menu",
    PLAYING = "playing",
    PAUSED = "paused",
    VICTORY = "victory",
    DEFEAT = "defeat",
}

-- 重置所有技能（返还所有已花费的技能点）
local function ResetAllSkills()
    local refundedPoints = 0
    for lineId, line in pairs(SkillTree) do
        for skillId, skill in pairs(line.skills) do
            local level = GetSkillLevel(skillId)
            if level > 0 then
                -- 计算已花费的技能点
                for i = 1, level do
                    refundedPoints = refundedPoints + skill.costs[i]
                end
            end
        end
    end
    PlayerSkills.unlockedSkills = {}
    PlayerSkills.skillPoints = PlayerSkills.skillPoints + refundedPoints
    return refundedPoints
end

local currentState_ = GameState.MENU
local selectedLevel_ = 1

-- 玩家数据
local playerGold_ = CONFIG.InitialGold
local playerLives_ = CONFIG.InitialLives
local currentWave_ = 0
local totalKills_ = 0
local totalGoldEarned_ = 0

-- 游戏时间
local gameTime_ = 0
local waveTimer_ = 0
local waveDelay_ = 3.0  -- 波次间隔

-- ============================================================================
-- 2. 敌人配置
-- ============================================================================
local EnemyTypes = {
    -- 普通敌人（圆形）
    normal = {
        shape = "circle",
        color = {100, 200, 100},  -- 绿色
        health = 100,
        defense = 0,
        speed = 90,
        reward = 10,
        damage = 1,
        size = 22,
    },
    -- 快速敌人（三角形）
    fast = {
        shape = "triangle",
        color = {255, 200, 50},  -- 黄色
        health = 60,
        defense = 0,
        speed = 180,
        reward = 15,
        damage = 1,
        size = 20,
    },
    -- 坦克敌人（正方形）
    tank = {
        shape = "square",
        color = {200, 100, 100},  -- 红色
        health = 300,
        defense = 5,
        speed = 52,
        reward = 25,
        damage = 3,
        size = 25,
    },
    -- Boss敌人（六边形）
    boss = {
        shape = "hexagon",
        color = {180, 100, 220},  -- 紫色
        health = 1000,
        defense = 10,
        speed = 38,
        reward = 100,
        damage = 10,
        size = 40,
    },
    -- 战车敌人（大圆形内含8个小圆形，死亡后分裂）
    chariot = {
        shape = "chariot",
        color = {255, 150, 100},  -- 橙色
        health = 500,
        defense = 8,
        speed = 45,
        reward = 50,
        damage = 5,
        size = 30,
        spawnOnDeath = "normal",  -- 死亡后生成的敌人类型
        spawnCount = 8,           -- 生成数量
    },
}

-- ============================================================================
-- 3. 防御塔配置
-- ============================================================================
local TowerTypes = {
    -- 箭塔（三角形）- 单体快速攻击
    arrow = {
        name = "箭塔",
        shape = "triangle",
        color = {100, 150, 255},  -- 蓝色
        damage = 25,
        attackSpeed = 2.0,  -- 每秒攻击次数
        range = 240,
        cost = 50,
        projectileSpeed = 1200,
        projectileType = "arrow",
        description = "快速攻击单体敌人",
    },
    -- 炮塔（圆形）- 范围伤害
    cannon = {
        name = "炮塔",
        shape = "circle",
        color = {255, 150, 50},  -- 橙色
        damage = 35,
        attackSpeed = 0.8,
        range = 220,
        cost = 80,
        projectileSpeed = 800,
        projectileType = "cannonball",
        splashRadius = 75,
        description = "范围伤害，攻击速度较慢",
    },
    -- 减速塔（菱形）- 范围减速效果
    slow = {
        name = "减速塔",
        shape = "diamond",
        color = {150, 220, 255},  -- 浅蓝色
        damage = 10,
        attackSpeed = 0.5,  -- 脉冲频率
        range = 200,  -- 范围稍大
        cost = 60,
        projectileType = "aura",  -- 光环型攻击
        slowEffect = 0.3,  -- 减速50%
        slowDuration = 0.7,
        description = "范围减速所有敌人",
    },
    -- 激光塔（正方形）- 持续伤害
    laser = {
        name = "激光塔",
        shape = "square",
        color = {255, 100, 100},  -- 红色
        damage = 40,  -- 每秒伤害
        attackSpeed = 0,  -- 持续攻击
        range = 260,
        cost = 100,
        projectileType = "laser",
        description = "持续照射造成伤害",
    },
}

-- 升级系数
local UpgradeMultipliers = {
    [1] = { damage = 1.0, range = 1.0, attackSpeed = 1.0, cost = 1.0 },
    [2] = { damage = 1.5, range = 1.1, attackSpeed = 1.2, cost = 1.5 },
    [3] = { damage = 2.2, range = 1.2, attackSpeed = 1.4, cost = 2.0 },
}

-- ============================================================================
-- 4. 关卡配置
-- ============================================================================
local Levels = {
    -- 关卡1：简单
    [1] = {
        name = "草原小径",
        description = "适合新手的简单关卡",
        -- 敌人路径点 (1920x1080)
        path = {
            {x = 500, y = 350},
            {x = 1000, y = 350},
            {x = 1000, y = 750},
            {x = 500, y = 750},
        },
        -- 防御塔放置点 (1920x1080) - 距离路线至少100像素
        towerSpots = {
            -- 上方区域 (y < 200)
            {x = 700, y = 250},
			{x = 800, y = 450},
			{x = 900, y = 250},
			
			{x = 1100, y = 550},

            {x = 700, y = 850},
			{x = 800, y = 650},
			{x = 900, y = 850},
        },
        -- 波次配置
        waves = {
            { enemies = { {type = "normal", count = 5, interval = 1.0} } },
            { enemies = { {type = "normal", count = 8, interval = 0.8} } },
            { enemies = { {type = "normal", count = 5, interval = 1.0}, {type = "fast", count = 3, interval = 0.6} } },
            { enemies = { {type = "fast", count = 8, interval = 0.5} } },
            { enemies = { {type = "normal", count = 5, interval = 0.8}, {type = "tank", count = 2, interval = 2.0} } },
            { enemies = { {type = "chariot", count = 1, interval = 0}, {type = "normal", count = 5, interval = 0.8} } },
            { enemies = { {type = "tank", count = 5, interval = 1.5} } },
            { enemies = { {type = "normal", count = 10, interval = 0.5}, {type = "fast", count = 5, interval = 0.4} } },
            { enemies = { {type = "chariot", count = 2, interval = 3.0} } },
            { enemies = { {type = "boss", count = 1, interval = 0} } },
        },
        backgroundColor = {35, 35, 55},  -- 深蓝紫色
    },
    -- 关卡2：中等
    [2] = {
        name = "沙漠迷宫",
        description = "复杂的路径，更多敌人",
        path = {
            {x = 500, y = 500},
            {x = 1300, y = 500},
            {x = 1300, y = 800},
            {x = 800, y = 800},
            {x = 800, y = 300},
        },
        towerSpots = {
            {x = 800-100, y = 500-100},
			{x = 800+100, y = 500+100},
			{x = 1300+100, y = 800+100},
			{x = 800-100, y = 800-100},
        },
        waves = {
            { enemies = { {type = "normal", count = 8, interval = 0.8} } },
            { enemies = { {type = "fast", count = 10, interval = 0.5} } },
            { enemies = { {type = "normal", count = 8, interval = 0.6}, {type = "fast", count = 5, interval = 0.4} } },
            { enemies = { {type = "tank", count = 5, interval = 1.2} } },
            { enemies = { {type = "chariot", count = 2, interval = 2.5} } },
            { enemies = { {type = "fast", count = 15, interval = 0.3} } },
            { enemies = { {type = "normal", count = 10, interval = 0.5}, {type = "tank", count = 5, interval = 1.0} } },
            { enemies = { {type = "chariot", count = 3, interval = 2.0}, {type = "fast", count = 8, interval = 0.4} } },
            { enemies = { {type = "tank", count = 8, interval = 0.8}, {type = "fast", count = 10, interval = 0.3} } },
            { enemies = { {type = "boss", count = 1, interval = 0}, {type = "chariot", count = 2, interval = 3.0} } },
            { enemies = { {type = "boss", count = 2, interval = 5.0} } },
        },
        backgroundColor = {40, 35, 50},  -- 深紫色
    },
    -- 关卡3：困难
    [3] = {
        name = "冰封要塞",
        description = "最终挑战，敌人众多",
        path = {
            {x = 960, y = -56},
            {x = 960, y = 225},
            {x = 300, y = 225},
            {x = 300, y = 525},
            {x = 750, y = 525},
            {x = 750, y = 825},
            {x = 300, y = 825},
            {x = 300, y = 1080},
            {x = 1620, y = 1080},
            {x = 1620, y = 825},
            {x = 1170, y = 825},
            {x = 1170, y = 525},
            {x = 1620, y = 525},
            {x = 1620, y = 225},
            {x = 1995, y = 225},
        },
        -- 放置点距离路线至少100像素
        towerSpots = {
            -- 顶部区域 (y < 125, 远离x=960)
            {x = 150, y = 80}, {x = 500, y = 80}, {x = 700, y = 80},
            {x = 1150, y = 80}, {x = 1350, y = 80}, {x = 1800, y = 80},
            -- 上中区域 (325 < y < 425, 远离x=300,750,960,1170,1620)
            {x = 500, y = 375}, {x = 950, y = 375},
            {x = 1350, y = 375}, {x = 1800, y = 375},
            -- 中间区域 (625 < y < 725, 远离x=300,750,1170,1620)
            {x = 500, y = 675}, {x = 950, y = 675},
            {x = 1350, y = 675}, {x = 1800, y = 675},
            -- 下中区域 (925 < y < 980, 远离x=300,1620和y=825,1080)
            {x = 500, y = 950}, {x = 700, y = 950},
            {x = 950, y = 950}, {x = 1150, y = 950},
            {x = 1350, y = 950},
        },
        waves = {
            { enemies = { {type = "fast", count = 15, interval = 0.4} } },
            { enemies = { {type = "normal", count = 15, interval = 0.5}, {type = "fast", count = 10, interval = 0.3} } },
            { enemies = { {type = "tank", count = 8, interval = 1.0} } },
            { enemies = { {type = "chariot", count = 3, interval = 2.0} } },
            { enemies = { {type = "fast", count = 20, interval = 0.25}, {type = "normal", count = 10, interval = 0.4} } },
            { enemies = { {type = "tank", count = 10, interval = 0.8}, {type = "fast", count = 15, interval = 0.3} } },
            { enemies = { {type = "chariot", count = 4, interval = 1.5}, {type = "tank", count = 5, interval = 1.0} } },
            { enemies = { {type = "boss", count = 1, interval = 0}, {type = "chariot", count = 3, interval = 2.0} } },
            { enemies = { {type = "tank", count = 15, interval = 0.6}, {type = "fast", count = 20, interval = 0.2} } },
            { enemies = { {type = "boss", count = 2, interval = 3.0}, {type = "chariot", count = 5, interval = 1.5} } },
            { enemies = { {type = "boss", count = 3, interval = 2.0}, {type = "fast", count = 30, interval = 0.15} } },
            { enemies = { {type = "boss", count = 5, interval = 1.5} } },
        },
        backgroundColor = {30, 40, 55},  -- 深蓝色
    },
    -- 关卡4：测试关卡（战车测试）
    [4] = {
        name = "战车测试",
        description = "测试战车分裂机制",
        -- 一条从左到右的直线路径
        path = {
            {x = -75, y = 540},
            {x = 1995, y = 540},
        },
        -- 路径上下两侧的放置点 - 距离路线(y=540)至少100像素
        towerSpots = {
            -- 上方一排 (y = 420, 距离路线120像素)
            {x = 200, y = 420}, {x = 400, y = 420}, {x = 600, y = 420}, {x = 800, y = 420},
            {x = 1000, y = 420}, {x = 1200, y = 420}, {x = 1400, y = 420}, {x = 1600, y = 420},
            -- 下方一排 (y = 660, 距离路线120像素)
            {x = 200, y = 660}, {x = 400, y = 660}, {x = 600, y = 660}, {x = 800, y = 660},
            {x = 1000, y = 660}, {x = 1200, y = 660}, {x = 1400, y = 660}, {x = 1600, y = 660},
        },
        -- 只有战车的波次
        waves = {
            { enemies = { {type = "chariot", count = 1, interval = 0} } },
            { enemies = { {type = "chariot", count = 2, interval = 3.0} } },
            { enemies = { {type = "chariot", count = 3, interval = 2.5} } },
            { enemies = { {type = "chariot", count = 4, interval = 2.0} } },
            { enemies = { {type = "chariot", count = 5, interval = 1.5} } },
        },
        backgroundColor = {35, 38, 52},  -- 深灰蓝色
    },
}

-- ============================================================================
-- 5. 运行时数据
-- ============================================================================
local enemies_ = {}          -- 活跃的敌人列表
local towers_ = {}           -- 已建造的防御塔
local projectiles_ = {}      -- 飞行中的子弹
local particles_ = {}        -- 粒子效果

-- 波次生成器状态
local waveActive_ = false
local waveEnemyQueue_ = {}   -- 待生成的敌人队列
local spawnTimer_ = 0

-- UI状态
local selectedTowerSpot_ = nil  -- 当前选中的放置点
local selectedTowerType_ = nil  -- 当前选中要建造的塔类型
local hoveredTower_ = nil       -- 鼠标悬停的塔
local showTowerMenu_ = false    -- 显示塔菜单
local menuTower_ = nil          -- 菜单对应的塔或放置点
local showLevelSelectPanel_ = false  -- 显示关卡选择面板

-- 屏幕震动效果
local screenShake_ = {
    timer = 0,           -- 震动剩余时间
    intensity = 0,       -- 震动强度
    offsetX = 0,         -- 当前X偏移
    offsetY = 0,         -- 当前Y偏移
}

-- ============================================================================
-- 6. 生命周期函数
-- ============================================================================

function Start()
    -- 设置固定窗口大小（不随窗口缩放）
    local gfx = GetGraphics()
    gfx:SetMode(CONFIG.Width, CONFIG.Height)
    
    SampleStart()
    graphics.windowTitle = CONFIG.Title
    
    -- 隐藏右下角的 Logo（否则会阻挡按钮点击）
    SetLogoVisible(false)
    
    InitNanoVG()
    CreateScene()
    SetupViewport()
    SubscribeToEvents()
    
    -- 设置鼠标模式为绝对模式（显示鼠标光标）
    input.mouseVisible = true
    input.mouseMode = MM_ABSOLUTE
    
    print("=== 2D塔防游戏启动 ===")
    print("点击选择关卡开始游戏")
end

function Stop()
    if nvg_ ~= nil then
        nvgDelete(nvg_)
        nvg_ = nil
    end
end

-- ============================================================================
-- 7. 初始化函数
-- ============================================================================

function InitNanoVG()
    nvg_ = nvgCreate(1)
    if nvg_ == nil then
        print("❌ ERROR: Failed to create NanoVG context!")
        return
    end
    
    local fontId = nvgCreateFont(nvg_, "sans", "Fonts/MiSans-Regular.ttf")
    if fontId == -1 then
        print("⚠️ WARNING: Failed to load default font")
    end
end

function CreateScene()
    scene_ = Scene()
    scene_:CreateComponent("Octree")
end

function SetupViewport()
    cameraNode_ = scene_:CreateChild("Camera")
    local camera = cameraNode_:CreateComponent("Camera")
    camera.orthographic = true
    camera.orthoSize = CONFIG.Height / CONFIG.PixelPerUnit
    cameraNode_.position = Vector3(0, 0, -10)
    
    local viewport = Viewport:new(scene_, camera)
    renderer:SetViewport(0, viewport)
end

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PreRenderUI", "HandleRender")
    SubscribeToEvent("MouseButtonDown", "HandleMouseDown")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
end

-- ============================================================================
-- 8. 游戏逻辑
-- ============================================================================

function ResetGame()
    enemies_ = {}
    towers_ = {}
    projectiles_ = {}
    particles_ = {}
    
    -- 应用技能树加成：初始金币
    local startGoldBonus = GetSkillEffect("start_gold")
    playerGold_ = CONFIG.InitialGold + startGoldBonus
    
    -- 应用技能树加成：初始生命
    local maxLivesBonus = GetSkillEffect("max_lives")
    playerLives_ = CONFIG.InitialLives + maxLivesBonus
    
    currentWave_ = 0
    totalKills_ = 0
    totalGoldEarned_ = 0
    
    gameTime_ = 0
    waveTimer_ = 0
    waveActive_ = false
    waveEnemyQueue_ = {}
    spawnTimer_ = 0
    
    selectedTowerSpot_ = nil
    selectedTowerType_ = nil
    hoveredTower_ = nil
    showTowerMenu_ = false
    menuTower_ = nil
    
    -- 清空所有关卡的放置点上的塔绑定
    ClearAllTowerSpots()
end

-- 清空所有放置点上的塔绑定
function ClearAllTowerSpots()
    for _, level in ipairs(Levels) do
        if level.towerSpots then
            for _, spot in ipairs(level.towerSpots) do
                spot.tower = nil
            end
        end
    end
end

function StartLevel(levelIndex)
    selectedLevel_ = levelIndex
    ResetGame()
    currentState_ = GameState.PLAYING
    print("开始关卡: " .. Levels[levelIndex].name)
end

function StartNextWave()
    local level = Levels[selectedLevel_]
    if currentWave_ >= #level.waves then
        -- 所有波次完成，胜利
        currentState_ = GameState.VICTORY
        return
    end
    
    currentWave_ = currentWave_ + 1
    waveActive_ = true
    waveEnemyQueue_ = {}
    
    local waveConfig = level.waves[currentWave_]
    for _, enemyGroup in ipairs(waveConfig.enemies) do
        for i = 1, enemyGroup.count do
            table.insert(waveEnemyQueue_, {
                type = enemyGroup.type,
                delay = (i - 1) * enemyGroup.interval
            })
        end
    end
    
    spawnTimer_ = 0
    print("波次 " .. currentWave_ .. " 开始！敌人数量: " .. #waveEnemyQueue_)
end

function SpawnEnemy(enemyType)
    local level = Levels[selectedLevel_]
    local config = EnemyTypes[enemyType]
    
    -- 计算随机侧方偏移（垂直于路径方向）
    local laneOffset = (math.random() - 0.5) * 50  -- -25 到 +25 的随机偏移
    
    -- 计算初始位置和朝向（基于第一段路径）
    local startX = level.path[1].x
    local startY = level.path[1].y
    local initialRotation = 0
    if #level.path >= 2 then
        local dx = level.path[2].x - level.path[1].x
        local dy = level.path[2].y - level.path[1].y
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0 then
            startX = startX + (-dy / len) * laneOffset
            startY = startY + (dx / len) * laneOffset
            initialRotation = math.atan2(dy, dx)  -- 初始朝向
        end
    end
    
    local enemy = {
        type = enemyType,
        x = startX,
        y = startY,
        health = config.health,
        maxHealth = config.health,
        defense = config.defense,
        speed = config.speed,
        reward = config.reward,
        damage = config.damage,
        size = config.size,
        pathIndex = 1,
        pathProgress = 0,
        slowTimer = 0,
        slowMultiplier = 1.0,
        -- 车道偏移（让敌人不走同一条线）
        laneOffset = laneOffset,
        -- 旋转（朝向前进方向）
        rotation = initialRotation,
        targetRotation = initialRotation,
        -- 受击弹簧偏移效果
        hitRecoilTimer = 0,
        hitRecoilDirX = 0,
        hitRecoilDirY = 0,
        hitRecoilIntensity = 0,
        hitRecoilOffsetX = 0,
        hitRecoilOffsetY = 0,
    }
    
    table.insert(enemies_, enemy)
end

-- 战车分裂：在指定位置生成多个小敌人
function SpawnSplitEnemies(parentEnemy, childType, count)
    local config = EnemyTypes[childType]
    if not config then return end
    
    -- 分裂特效
    CreateSplitParticles(parentEnemy.x, parentEnemy.y)
    
    for i = 1, count do
        -- 每个敌人有一个散开方向（均匀分布在圆周上）
        local scatterAngle = (i - 1) * (2 * math.pi / count) + (math.random() - 0.5) * 0.3
        
        -- 每个分裂敌人有独立的车道偏移
        local laneOffset = (math.random() - 0.5) * 40
        
        local child = {
            type = childType,
            -- 从父敌人中心位置生成
            x = parentEnemy.x,
            y = parentEnemy.y,
            health = config.health,
            maxHealth = config.health,
            defense = config.defense,
            speed = config.speed,
            reward = config.reward,
            damage = config.damage,
            size = config.size,
            pathIndex = parentEnemy.pathIndex,
            pathProgress = parentEnemy.pathProgress or 0,
            slowTimer = 0,
            slowMultiplier = 1.0,
            -- 车道偏移
            laneOffset = laneOffset,
            -- 旋转（初始朝向散开方向）
            rotation = scatterAngle,
            targetRotation = scatterAngle,
            -- 受击弹簧偏移效果
            hitRecoilTimer = 0,
            hitRecoilDirX = 0,
            hitRecoilDirY = 0,
            hitRecoilIntensity = 0,
            hitRecoilOffsetX = 0,
            hitRecoilOffsetY = 0,
            -- 散开阶段
            scatterPhase = true,
            scatterAngle = scatterAngle,
            scatterDistance = 20 + math.random() * 20,  -- 散开距离
            scatterProgress = 0,
        }
        
        table.insert(enemies_, child)
    end
end

function UpdateEnemies(dt)
    local level = Levels[selectedLevel_]
    local path = level.path
    
    for i = #enemies_, 1, -1 do
        local enemy = enemies_[i]
        local config = EnemyTypes[enemy.type]
        
        -- 更新减速效果
        if enemy.slowTimer > 0 then
            enemy.slowTimer = enemy.slowTimer - dt
            if enemy.slowTimer <= 0 then
                enemy.slowMultiplier = 1.0
            end
        end
        
        -- 更新受击弹簧偏移效果
        if enemy.hitRecoilTimer and enemy.hitRecoilTimer > 0 then
            enemy.hitRecoilTimer = enemy.hitRecoilTimer - dt
            local recoilDuration = 0.35
            local t = 1.0 - (enemy.hitRecoilTimer / recoilDuration)  -- t: 0 -> 1
            
            -- 弹簧公式：快速偏移然后弹回
            local damping = 4.0
            local frequency = 12.0
            local springValue = math.exp(-damping * t) * math.cos(frequency * t)
            
            local intensity = enemy.hitRecoilIntensity or 6
            enemy.hitRecoilOffsetX = (enemy.hitRecoilDirX or 0) * intensity * springValue
            enemy.hitRecoilOffsetY = (enemy.hitRecoilDirY or 0) * intensity * springValue
        else
            enemy.hitRecoilOffsetX = 0
            enemy.hitRecoilOffsetY = 0
        end
        
        -- 散开阶段处理（战车分裂后的敌人先向外散开）
        if enemy.scatterPhase then
            local scatterSpeed = 200  -- 散开速度
            local moveDistance = scatterSpeed * dt
            enemy.scatterProgress = (enemy.scatterProgress or 0) + moveDistance
            
            -- 向散开方向移动
            enemy.x = enemy.x + math.cos(enemy.scatterAngle) * moveDistance
            enemy.y = enemy.y + math.sin(enemy.scatterAngle) * moveDistance
            
            -- 散开完成后转入正常移动
            if enemy.scatterProgress >= enemy.scatterDistance then
                enemy.scatterPhase = false
                -- 重新计算旋转角度朝向路径方向
                if enemy.pathIndex < #path then
                    local targetPoint = path[enemy.pathIndex + 1]
                    local dx = targetPoint.x - enemy.x
                    local dy = targetPoint.y - enemy.y
                    enemy.targetRotation = math.atan2(dy, dx)
                end
            end
        else
        -- 正常路径移动（下面的代码块缩进不变）
        
        -- 移动到下一个路径点
        local targetIndex = enemy.pathIndex + 1
        if targetIndex <= #path then
            local currentPoint = path[enemy.pathIndex]
            local targetPoint = path[targetIndex]
            local laneOffset = enemy.laneOffset or 0
            
            -- 计算当前路径段的法线方向
            local pathDx = targetPoint.x - currentPoint.x
            local pathDy = targetPoint.y - currentPoint.y
            local pathLength = math.sqrt(pathDx * pathDx + pathDy * pathDy)
            
            local normalX = 0
            local normalY = 0
            if pathLength > 0 then
                normalX = -pathDy / pathLength
                normalY = pathDx / pathLength
            end
            
            -- 计算带偏移的当前段起点和终点
            local startX = currentPoint.x + normalX * laneOffset
            local startY = currentPoint.y + normalY * laneOffset
            local endX = targetPoint.x + normalX * laneOffset
            local endY = targetPoint.y + normalY * laneOffset
            
            -- 如果有下一段路径，计算下一段的偏移终点用于平滑过渡
            if targetIndex < #path then
                local nextPoint = path[targetIndex + 1]
                local nextDx = nextPoint.x - targetPoint.x
                local nextDy = nextPoint.y - targetPoint.y
                local nextLen = math.sqrt(nextDx * nextDx + nextDy * nextDy)
                if nextLen > 0 then
                    local nextNormalX = -nextDy / nextLen
                    local nextNormalY = nextDx / nextLen
                    -- 在转角处使用两个法线的平均值，使转弯更平滑
                    local avgNormalX = (normalX + nextNormalX) / 2
                    local avgNormalY = (normalY + nextNormalY) / 2
                    local avgLen = math.sqrt(avgNormalX * avgNormalX + avgNormalY * avgNormalY)
                    if avgLen > 0 then
                        avgNormalX = avgNormalX / avgLen
                        avgNormalY = avgNormalY / avgLen
                    end
                    -- 转角点使用平均法线
                    endX = targetPoint.x + avgNormalX * laneOffset
                    endY = targetPoint.y + avgNormalY * laneOffset
                end
            end
            
            -- 计算敌人到目标点的距离和方向
            local dx = endX - enemy.x
            local dy = endY - enemy.y
            local dist = math.sqrt(dx * dx + dy * dy)
            
            -- 更新目标旋转角度（朝向移动方向）
            if dist > 0.1 then
                enemy.targetRotation = math.atan2(dy, dx)
            end
            
            -- 平滑旋转插值
            local rotationSpeed = 15.0  -- 旋转速度（弧度/秒）
            local currentRot = enemy.rotation or 0
            local targetRot = enemy.targetRotation or 0
            
            -- 计算最短旋转方向
            local rotDiff = targetRot - currentRot
            -- 将角度差标准化到 -π 到 π 之间
            while rotDiff > math.pi do rotDiff = rotDiff - 2 * math.pi end
            while rotDiff < -math.pi do rotDiff = rotDiff + 2 * math.pi end
            
            -- 应用旋转插值
            local maxRotation = rotationSpeed * dt
            if math.abs(rotDiff) <= maxRotation then
                enemy.rotation = targetRot
            else
                if rotDiff > 0 then
                    enemy.rotation = currentRot + maxRotation
                else
                    enemy.rotation = currentRot - maxRotation
                end
            end
            
            local speed = enemy.speed * enemy.slowMultiplier
            local moveAmount = speed * dt
            
            if dist <= moveAmount then
                -- 到达当前段终点，进入下一段
                enemy.x = endX
                enemy.y = endY
                enemy.pathIndex = targetIndex
            else
                -- 沿着偏移后的路径移动
                enemy.x = enemy.x + (dx / dist) * moveAmount
                enemy.y = enemy.y + (dy / dist) * moveAmount
            end
        else
            -- 到达终点
            -- 应用技能树加成：伤害减免
            local damageReduction = GetSkillEffect("damage_reduction")
            local actualDamage = math.max(1, enemy.damage - damageReduction)  -- 最少扣1点
            playerLives_ = playerLives_ - actualDamage
            
            -- 播放敌人死亡动画（红色粒子表示伤害）
            CreateEnemyReachEndParticles(enemy.x, enemy.y, config.color)
            
            -- 触发屏幕震动，强度与敌人造成的伤害相关
            local shakeIntensity = 8 + actualDamage * 3
            local shakeDuration = 0.25 + actualDamage * 0.05
            TriggerScreenShake(shakeIntensity, shakeDuration)
            
            table.remove(enemies_, i)
            
            if playerLives_ <= 0 then
                -- 游戏失败时更强的震动
                TriggerScreenShake(25, 0.6)
                currentState_ = GameState.DEFEAT
            end
        end
        end -- 结束 scatterPhase else 分支
        
        -- 检查死亡
        if enemy.health <= 0 then
            -- 应用技能树加成：击杀奖励
            local killGoldBonus = GetSkillEffect("kill_gold")
            local reward = math.floor(enemy.reward * (1 + killGoldBonus))
            playerGold_ = playerGold_ + reward
            totalGoldEarned_ = totalGoldEarned_ + reward
            totalKills_ = totalKills_ + 1
            
            -- 死亡粒子效果
            CreateDeathParticles(enemy.x, enemy.y, config.color)
            
            -- 战车分裂逻辑：死亡后生成多个小敌人
            if config.spawnOnDeath and config.spawnCount then
                SpawnSplitEnemies(enemy, config.spawnOnDeath, config.spawnCount)
            end
            
            table.remove(enemies_, i)
        end
    end
end

function UpdateTowers(dt)
    for _, tower in ipairs(towers_) do
        local config = TowerTypes[tower.type]
        local mult = UpgradeMultipliers[tower.level]
        
        -- 初始化攻击动画状态
        if tower.recoilTimer == nil then
            tower.recoilTimer = 0
            tower.recoilX = 0
            tower.recoilY = 0
            tower.scaleAnim = 1.0
            tower.rotation = 0        -- 塔的当前旋转角度
            tower.targetRotation = 0  -- 目标旋转角度
        end
        
        -- 更新攻击动画（弹簧效果）
        if tower.recoilTimer > 0 then
            tower.recoilTimer = tower.recoilTimer - dt
            local recoilDuration = 0.35  -- 延长动画时间
            local t = 1.0 - (tower.recoilTimer / recoilDuration)  -- t: 0 -> 1
            
            if tower.type == "slow" then
                -- 减速塔弹簧缩放动画
                local damping = 4.0
                local frequency = 12.0
                local springValue = math.exp(-damping * t) * math.cos(frequency * t)
                tower.scaleAnim = 1.0 - springValue * 0.25  -- 缩放幅度0.25
            else
                -- 普通塔弹簧后坐力动画
                local recoilAmount = 10  -- 后坐力最大距离
                local damping = 3.5      -- 阻尼系数（越大衰减越快）
                local frequency = 10.0   -- 振荡频率
                
                -- 阻尼弹簧公式：快速后退然后弹回
                local springValue = math.exp(-damping * t) * math.cos(frequency * t)
                
                tower.recoilX = tower.recoilDirX * recoilAmount * springValue
                tower.recoilY = tower.recoilDirY * recoilAmount * springValue
            end
        else
            tower.recoilX = 0
            tower.recoilY = 0
            tower.scaleAnim = 1.0
        end
        
        -- 找目标
        local target = FindTarget(tower)
        tower.target = target
        
        if config.projectileType == "laser" then
            -- 激光塔持续攻击（应用技能树加成，不触发受击移动效果）
            if target then
                local damage = CalculateTowerDamage(tower.type, config.damage * mult.damage)
                DealDamage(target, damage, config, dt, nil, nil)
                
                -- 激光命中时产生红色火花粒子
                tower.laserParticleTimer = (tower.laserParticleTimer or 0) + dt
                if tower.laserParticleTimer >= 0.05 then  -- 每0.05秒生成一次粒子
                    tower.laserParticleTimer = 0
                    CreateLaserHitParticles(target.x, target.y)
                end
                
                -- 攻击时持续自转
                tower.isAttacking = true
                local spinSpeed = 4.0  -- 自转速度（弧度/秒）
                tower.rotation = tower.rotation + spinSpeed * dt
                -- 保持角度在合理范围内
                if tower.rotation > math.pi * 2 then
                    tower.rotation = tower.rotation - math.pi * 2
                end
            else
                -- 没有目标时，逐渐减速并回正到0
                tower.isAttacking = false
                local returnSpeed = 3.0  -- 回正速度
                
                -- 计算到0的最短路径
                local angleDiff = 0 - tower.rotation
                while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
                while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end
                
                -- 如果角度很小就直接归零
                if math.abs(angleDiff) < 0.05 then
                    tower.rotation = 0
                else
                    tower.rotation = tower.rotation + angleDiff * returnSpeed * dt
                end
            end
        elseif tower.type == "slow" then
            -- 减速塔：范围持续减速（应用技能树加成）
            tower.attackTimer = tower.attackTimer + dt
            local attackSpeed = CalculateTowerAttackSpeed(tower.type, config.attackSpeed * mult.attackSpeed)
            local pulseInterval = 1.0 / attackSpeed
            
            if tower.attackTimer >= pulseInterval then
                tower.attackTimer = 0
                -- 对范围内所有敌人施加减速
                local range = CalculateTowerRange(tower.type, config.range * mult.range)
                local hasTarget = false
                
                -- 计算增强后的减速效果
                local slowEffect = CalculateSlowEffect(config.slowEffect)
                local slowDuration = CalculateSlowDuration(config.slowDuration)
                
                for _, enemy in ipairs(enemies_) do
                    local dx = enemy.x - tower.x
                    local dy = enemy.y - tower.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    
                    if dist <= range then
                        hasTarget = true
                        -- 施加减速效果（应用技能树加成）
                        enemy.slowTimer = slowDuration
                        enemy.slowMultiplier = slowEffect
                        -- 造成少量伤害
                        local damage = CalculateTowerDamage(tower.type, config.damage * mult.damage)
                        DealDamage(enemy, damage, config, 0, tower.x, tower.y)
                    end
                end
                
                -- 有目标时播放脉冲特效和缩放动画
                if hasTarget then
                    tower.pulseTimer = 0.3  -- 脉冲动画持续时间
                    tower.recoilTimer = 0.15  -- 缩放动画
                    CreateSlowPulseParticles(tower.x, tower.y, range)
                end
            end
            
            -- 更新脉冲动画
            if tower.pulseTimer and tower.pulseTimer > 0 then
                tower.pulseTimer = tower.pulseTimer - dt
            end
        else
            -- 普通塔攻击（应用技能树加成）
            tower.attackTimer = tower.attackTimer + dt
            local attackSpeed = CalculateTowerAttackSpeed(tower.type, config.attackSpeed * mult.attackSpeed)
            local attackInterval = 1.0 / attackSpeed
            
            if target and tower.attackTimer >= attackInterval then
                tower.attackTimer = 0
                
                -- 计算后坐力方向（目标的反方向）
                local dx = target.x - tower.x
                local dy = target.y - tower.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist > 0 then
                    tower.recoilDirX = -dx / dist
                    tower.recoilDirY = -dy / dist
                else
                    tower.recoilDirX = 0
                    tower.recoilDirY = 0
                end
                tower.recoilTimer = 0.35  -- 弹簧后坐力动画持续时间
                
                FireProjectile(tower, target, config, mult)
            end
        end
    end
end

function FindTarget(tower)
    local config = TowerTypes[tower.type]
    local mult = UpgradeMultipliers[tower.level]
    -- 应用技能树加成：攻击范围
    local range = CalculateTowerRange(tower.type, config.range * mult.range)
    local level = Levels[selectedLevel_]
    local path = level.path
    
    local bestEnemy = nil
    local bestProgress = -1  -- 路径进度（越大越接近终点）
    
    for _, enemy in ipairs(enemies_) do
        local dx = enemy.x - tower.x
        local dy = enemy.y - tower.y
        local dist = math.sqrt(dx * dx + dy * dy)
        
        -- 只考虑在攻击范围内的敌人
        if dist <= range then
            -- 计算敌人的路径进度
            -- pathIndex 表示已经经过的路径点数量
            -- 再加上当前路段的行进比例（0-1）
            local progress = enemy.pathIndex
            
            -- 计算在当前路段上的进度
            if enemy.pathIndex < #path then
                local nextPoint = path[enemy.pathIndex + 1]
                local segmentDx = nextPoint.x - path[enemy.pathIndex].x
                local segmentDy = nextPoint.y - path[enemy.pathIndex].y
                local segmentLength = math.sqrt(segmentDx * segmentDx + segmentDy * segmentDy)
                
                if segmentLength > 0 then
                    local enemyDx = enemy.x - path[enemy.pathIndex].x
                    local enemyDy = enemy.y - path[enemy.pathIndex].y
                    local enemyDist = math.sqrt(enemyDx * enemyDx + enemyDy * enemyDy)
                    progress = progress + (enemyDist / segmentLength)
                end
            end
            
            -- 选择进度最大的敌人（最接近终点）
            if progress > bestProgress then
                bestProgress = progress
                bestEnemy = enemy
            end
        end
    end
    
    return bestEnemy
end

-- 计算塔的最终伤害（应用技能树加成）
function CalculateTowerDamage(towerType, baseDamage)
    -- 通用伤害加成
    local damageBonus = GetSkillEffect("tower_damage")
    
    -- 塔类型专精加成
    local typeBonus = GetSkillEffect(towerType .. "_damage")
    
    -- 低血量时的伤害加成（最后防线）
    local lastStandBonus = 0
    local maxLives = CONFIG.InitialLives + GetSkillEffect("max_lives")
    if playerLives_ <= 5 then
        lastStandBonus = GetSkillEffect("last_stand_damage")
    end
    
    return baseDamage * (1 + damageBonus + typeBonus + lastStandBonus)
end

-- 计算塔的攻击速度加成
function CalculateTowerAttackSpeed(towerType, baseSpeed)
    local speedBonus = GetSkillEffect("tower_attackspeed")
    local typeBonus = GetSkillEffect(towerType .. "_attackspeed")
    return baseSpeed * (1 + speedBonus + typeBonus)
end

-- 计算塔的攻击范围加成
function CalculateTowerRange(towerType, baseRange)
    local rangeBonus = GetSkillEffect("tower_range")
    local typeBonus = GetSkillEffect(towerType .. "_range")
    return baseRange * (1 + rangeBonus + typeBonus)
end

-- 计算减速塔效果加成
function CalculateSlowEffect(baseEffect)
    local slowBonus = GetSkillEffect("slow_effect")
    return math.min(0.9, baseEffect + slowBonus)  -- 最多减速90%
end

-- 计算减速持续时间加成
function CalculateSlowDuration(baseDuration)
    local durationBonus = GetSkillEffect("slow_duration")
    return baseDuration + durationBonus
end

-- 计算炮塔溅射范围加成
function CalculateSplashRadius(baseRadius)
    local splashBonus = GetSkillEffect("cannon_splash")
    return baseRadius * (1 + splashBonus)
end

function FireProjectile(tower, target, config, mult)
    -- 应用技能树加成
    local finalDamage = CalculateTowerDamage(tower.type, config.damage * mult.damage)
    local finalSplashRadius = config.splashRadius and CalculateSplashRadius(config.splashRadius) or nil
    
    local projectile = {
        x = tower.x,
        y = tower.y,
        targetEnemy = target,
        speed = config.projectileSpeed,
        damage = finalDamage,
        type = config.projectileType,
        splashRadius = finalSplashRadius,
        slowEffect = config.slowEffect,
        slowDuration = config.slowDuration,
    }
    
    table.insert(projectiles_, projectile)
end

function UpdateProjectiles(dt)
    for i = #projectiles_, 1, -1 do
        local proj = projectiles_[i]
        
        -- 检查目标是否还存在
        local targetExists = false
        for _, enemy in ipairs(enemies_) do
            if enemy == proj.targetEnemy then
                targetExists = true
                break
            end
        end
        
        if not targetExists then
            table.remove(projectiles_, i)
        else
            -- 移动向目标
            local target = proj.targetEnemy
            local dx = target.x - proj.x
            local dy = target.y - proj.y
            local dist = math.sqrt(dx * dx + dy * dy)
            
            local moveAmount = proj.speed * dt
            
            if dist <= moveAmount or dist <= target.size then
                -- 击中
                if proj.splashRadius then
                    -- 范围伤害
                    for _, enemy in ipairs(enemies_) do
                        local edx = enemy.x - target.x
                        local edy = enemy.y - target.y
                        local edist = math.sqrt(edx * edx + edy * edy)
                        if edist <= proj.splashRadius then
                            DealDamage(enemy, proj.damage * (1 - edist / proj.splashRadius * 0.5), nil, nil, proj.x, proj.y)
                        end
                    end
                    -- 爆炸粒子
                    CreateExplosionParticles(target.x, target.y)
                else
                    DealDamage(target, proj.damage, {slowEffect = proj.slowEffect, slowDuration = proj.slowDuration}, nil, proj.x, proj.y)
                    
                    -- 箭塔命中特效
                    if proj.type == "arrow" then
                        CreateArrowHitParticles(target.x, target.y, proj.x, proj.y)
                    end
                end
                
                table.remove(projectiles_, i)
            else
                proj.x = proj.x + (dx / dist) * moveAmount
                proj.y = proj.y + (dy / dist) * moveAmount
            end
        end
    end
end

function DealDamage(enemy, damage, config, dt, sourceX, sourceY)
    local actualDamage = math.max(0, damage - enemy.defense)
    if dt then
		actualDamage = actualDamage * dt
	end
    enemy.health = enemy.health - actualDamage
    
    -- 受击弹簧偏移效果（向攻击来源的反方向偏移）
    if actualDamage > 0 and sourceX and sourceY then
        local dx = enemy.x - sourceX
        local dy = enemy.y - sourceY
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 0 then
            enemy.hitRecoilDirX = dx / dist
            enemy.hitRecoilDirY = dy / dist
        else
            enemy.hitRecoilDirX = 0
            enemy.hitRecoilDirY = 1
        end
        enemy.hitRecoilTimer = 0.35  -- 受击动画持续时间
        enemy.hitRecoilIntensity = math.min(24, actualDamage / 8 + 8)  -- 偏移强度与伤害相关
    end
    
    -- 减速效果
    if config and config.slowEffect then
        enemy.slowTimer = config.slowDuration
        enemy.slowMultiplier = config.slowEffect
    end
end

function UpdateParticles(dt)
    for i = #particles_, 1, -1 do
        local p = particles_[i]
        p.life = p.life - dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 200 * dt  -- 重力
        
        if p.life <= 0 then
            table.remove(particles_, i)
        end
    end
end

function CreateDeathParticles(x, y, color)
    -- 主要爆炸粒子
    for i = 1, 12 do
        local angle = (i / 12) * math.pi * 2
        local speed = 100 + math.random() * 80
        table.insert(particles_, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 60,
            life = 0.6,
            maxLife = 0.6,
            color = color,
            size = 6 + math.random() * 4,
            type = "circle",
        })
    end
    -- 火花粒子
    for i = 1, 6 do
        local angle = math.random() * math.pi * 2
        local speed = 150 + math.random() * 100
        table.insert(particles_, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 80,
            life = 0.3,
            maxLife = 0.3,
            color = {255, 255, 200},
            size = 3 + math.random() * 2,
            type = "spark",
        })
    end
end

-- 箭塔命中敌人时的受击特效
function CreateArrowHitParticles(targetX, targetY, projX, projY)
    -- 计算箭矢飞行方向
    local dx = targetX - projX
    local dy = targetY - projY
    local dist = math.sqrt(dx * dx + dy * dy)
    local dirX = dist > 0 and dx / dist or 0
    local dirY = dist > 0 and dy / dist or 1
    
    -- 冲击粒子（沿箭矢方向散开）
    for i = 1, 8 do
        local spreadAngle = (math.random() - 0.5) * math.pi * 0.8  -- 散开角度
        local baseAngle = math.atan2(dirY, dirX)
        local angle = baseAngle + spreadAngle
        local speed = 80 + math.random() * 60
        table.insert(particles_, {
            x = targetX,
            y = targetY,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 0.25 + math.random() * 0.15,
            maxLife = 0.4,
            color = {200, 200, 255},  -- 淡蓝白色
            size = 3 + math.random() * 2,
            type = "spark",
        })
    end
    
    -- 白色闪光粒子（中心爆发）
    for i = 1, 4 do
        local angle = math.random() * math.pi * 2
        local speed = 30 + math.random() * 40
        table.insert(particles_, {
            x = targetX,
            y = targetY,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 20,
            life = 0.15 + math.random() * 0.1,
            maxLife = 0.25,
            color = {255, 255, 255},  -- 纯白
            size = 4 + math.random() * 3,
            type = "circle",
        })
    end
    
    -- 小碎片粒子
    for i = 1, 5 do
        local angle = math.random() * math.pi * 2
        local speed = 50 + math.random() * 80
        table.insert(particles_, {
            x = targetX + (math.random() - 0.5) * 10,
            y = targetY + (math.random() - 0.5) * 10,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 40,
            life = 0.3 + math.random() * 0.2,
            maxLife = 0.5,
            color = {180, 180, 220},  -- 淡紫蓝
            size = 2 + math.random() * 2,
            type = "circle",
        })
    end
end

-- 激光塔命中敌人时的红色火花粒子
function CreateLaserHitParticles(x, y)
    -- 飘散的红色火花（向上飘散）
    for i = 1, 3 do
        local angle = -math.pi / 2 + (math.random() - 0.5) * math.pi * 0.8  -- 主要向上
        local speed = 40 + math.random() * 60
        table.insert(particles_, {
            x = x + (math.random() - 0.5) * 20,
            y = y + (math.random() - 0.5) * 20,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 30,  -- 向上偏移
            life = 0.4 + math.random() * 0.3,
            maxLife = 0.7,
            color = {255, 80 + math.random(80), 50},  -- 红色到橙色
            size = 3 + math.random() * 3,
            type = "spark",
        })
    end
    
    -- 偶尔产生较大的火花
    if math.random() < 0.3 then
        local angle = -math.pi / 2 + (math.random() - 0.5) * math.pi * 0.5
        local speed = 60 + math.random() * 40
        table.insert(particles_, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 50,
            life = 0.5 + math.random() * 0.3,
            maxLife = 0.8,
            color = {255, 200, 100},  -- 亮黄色
            size = 5 + math.random() * 3,
            type = "spark",
        })
    end
end

-- 敌人到达终点时的特殊死亡效果（红色警告粒子）
function CreateEnemyReachEndParticles(x, y, enemyColor)
    -- 红色警告爆炸
    for i = 1, 16 do
        local angle = (i / 16) * math.pi * 2
        local speed = 120 + math.random() * 100
        table.insert(particles_, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 50,
            life = 0.5,
            maxLife = 0.5,
            color = {255, 50, 50},  -- 红色
            size = 8 + math.random() * 6,
            type = "circle",
        })
    end
    -- 敌人颜色粒子
    for i = 1, 10 do
        local angle = math.random() * math.pi * 2
        local speed = 80 + math.random() * 60
        table.insert(particles_, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 40,
            life = 0.4,
            maxLife = 0.4,
            color = enemyColor,
            size = 5 + math.random() * 4,
            type = "circle",
        })
    end
    -- 向上飘散的伤害指示粒子
    for i = 1, 6 do
        table.insert(particles_, {
            x = x + (math.random() - 0.5) * 30,
            y = y,
            vx = (math.random() - 0.5) * 40,
            vy = -150 - math.random() * 80,
            life = 0.7,
            maxLife = 0.7,
            color = {255, 100, 100},
            size = 4 + math.random() * 3,
            type = "spark",
        })
    end
    -- 冲击波
    table.insert(particles_, {
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        life = 0.3,
        maxLife = 0.3,
        color = {255, 80, 80},
        size = 60,
        type = "shockwave",
    })
end

function CreateExplosionParticles(x, y, radius)
    radius = radius or 60
    -- 爆炸核心
    for i = 1, 16 do
        local angle = (i / 16) * math.pi * 2
        local speed = 80 + math.random() * 60
        table.insert(particles_, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 0.5,
            maxLife = 0.5,
            color = {255, 200, 100},
            size = 8 + math.random() * 6,
            type = "circle",
        })
    end
    -- 外圈冲击波
    table.insert(particles_, {
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        life = 0.3,
        maxLife = 0.3,
        color = {255, 150, 50},
        size = radius,
        type = "shockwave",
    })
    -- 烟雾
    for i = 1, 8 do
        local offsetX = (math.random() - 0.5) * 40
        local offsetY = (math.random() - 0.5) * 40
        table.insert(particles_, {
            x = x + offsetX,
            y = y + offsetY,
            vx = (math.random() - 0.5) * 30,
            vy = -30 - math.random() * 20,
            life = 0.8,
            maxLife = 0.8,
            color = {100, 100, 100},
            size = 15 + math.random() * 10,
            type = "smoke",
        })
    end
end

-- 塔攻击闪光效果
function CreateMuzzleFlash(x, y, color)
    table.insert(particles_, {
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        life = 0.1,
        maxLife = 0.1,
        color = color or {255, 255, 200},
        size = 25,
        type = "flash",
    })
end

-- 子弹轨迹效果
function CreateTrailParticle(x, y, color)
    table.insert(particles_, {
        x = x,
        y = y,
        vx = (math.random() - 0.5) * 20,
        vy = (math.random() - 0.5) * 20,
        life = 0.2,
        maxLife = 0.2,
        color = color,
        size = 4,
        type = "trail",
    })
end

-- 战车分裂特效
function CreateSplitParticles(x, y)
    -- 中心爆炸
    for i = 1, 20 do
        local angle = (i / 20) * math.pi * 2
        local speed = 120 + math.random() * 80
        table.insert(particles_, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 0.6,
            maxLife = 0.6,
            color = {255, 150, 100},
            size = 8 + math.random() * 5,
            type = "circle",
        })
    end
    -- 冲击波
    table.insert(particles_, {
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        life = 0.4,
        maxLife = 0.4,
        color = {255, 200, 150},
        size = 80,
        type = "shockwave",
    })
end

-- 建造塔特效
function CreateBuildParticles(x, y, color)
    for i = 1, 12 do
        local angle = (i / 12) * math.pi * 2
        table.insert(particles_, {
            x = x + math.cos(angle) * 40,
            y = y + math.sin(angle) * 40,
            vx = -math.cos(angle) * 80,
            vy = -math.sin(angle) * 80,
            life = 0.4,
            maxLife = 0.4,
            color = color,
            size = 6,
            type = "circle",
        })
    end
    -- 光柱效果
    table.insert(particles_, {
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        life = 0.5,
        maxLife = 0.5,
        color = {255, 255, 255},
        size = 30,
        type = "beam",
    })
end

-- 受击闪烁效果
function CreateHitParticles(x, y, color)
    for i = 1, 4 do
        local angle = math.random() * math.pi * 2
        local speed = 50 + math.random() * 30
        table.insert(particles_, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 0.2,
            maxLife = 0.2,
            color = color or {255, 255, 255},
            size = 4,
            type = "spark",
        })
    end
end

-- 战车分裂特效
function CreateSplitParticles(x, y)
    -- 中心爆炸光环
    table.insert(particles_, {
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        life = 0.4,
        maxLife = 0.4,
        color = {255, 200, 100},
        size = 60,
        type = "split_ring",
    })
    -- 向外散射的火花
    for i = 1, 16 do
        local angle = (i / 16) * math.pi * 2
        local speed = 150 + math.random() * 100
        table.insert(particles_, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 0.5,
            maxLife = 0.5,
            color = {255, 220, 150},
            size = 6 + math.random() * 4,
            type = "spark",
        })
    end
end

-- 金币获取飘字
function CreateGoldPopup(x, y, amount)
    table.insert(particles_, {
        x = x,
        y = y,
        vx = 0,
        vy = -60,
        life = 1.0,
        maxLife = 1.0,
        color = {255, 220, 50},
        size = 24,
        type = "text",
        text = "+" .. amount,
    })
end

-- 减速效果粒子
function CreateSlowParticles(x, y)
    for i = 1, 3 do
        local angle = math.random() * math.pi * 2
        local dist = math.random() * 15
        table.insert(particles_, {
            x = x + math.cos(angle) * dist,
            y = y + math.sin(angle) * dist,
            vx = 0,
            vy = -40,
            life = 0.5,
            maxLife = 0.5,
            color = {150, 220, 255},
            size = 6,
            type = "snowflake",
        })
    end
end

-- 减速塔脉冲特效
function CreateSlowPulseParticles(x, y, range)
    -- 扩散冲击波
    table.insert(particles_, {
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        life = 0.3,
        maxLife = 0.3,
        color = {150, 220, 255},
        size = range,
        type = "slow_pulse",
    })
    -- 雪花粒子
    for i = 1, 12 do
        local angle = (i / 12) * math.pi * 2
        local dist = range * 0.8
        table.insert(particles_, {
            x = x + math.cos(angle) * dist,
            y = y + math.sin(angle) * dist,
            vx = math.cos(angle) * 20,
            vy = math.sin(angle) * 20 - 30,
            life = 0.6,
            maxLife = 0.6,
            color = {180, 230, 255},
            size = 8,
            type = "snowflake",
        })
    end
end

function BuildTower(spot, towerType)
    local config = TowerTypes[towerType]
    -- 应用技能树加成：建造费用折扣
    local costDiscount = GetSkillEffect("tower_cost")
    local actualCost = math.floor(config.cost * (1 + costDiscount))  -- costDiscount是负数
    
    if playerGold_ >= actualCost then
        playerGold_ = playerGold_ - actualCost
        
        local tower = {
            type = towerType,
            x = spot.x,
            y = spot.y,
            level = 1,
            attackTimer = 0,
            totalCost = actualCost,
            target = nil,
            pulseTimer = 0,  -- 减速塔脉冲动画
        }
        
        spot.tower = tower
        table.insert(towers_, tower)
        
        -- 建造特效
        CreateBuildParticles(spot.x, spot.y, config.color)
        
        showTowerMenu_ = false
        print("建造 " .. config.name .. " 花费 " .. actualCost)
        return true
    else
        print("金币不足！")
        return false
    end
end

function UpgradeTower(tower)
    if tower.level >= 3 then
        print("已达最高等级！")
        return false
    end
    
    local config = TowerTypes[tower.type]
    local nextMult = UpgradeMultipliers[tower.level + 1]
    local upgradeCost = math.floor(config.cost * nextMult.cost)
    
    if playerGold_ >= upgradeCost then
        playerGold_ = playerGold_ - upgradeCost
        tower.level = tower.level + 1
        tower.totalCost = tower.totalCost + upgradeCost
        
        showTowerMenu_ = false
        print("升级 " .. config.name .. " 到 " .. tower.level .. " 级")
        return true
    else
        print("金币不足！")
        return false
    end
end

function SellTower(tower, spot)
    -- 应用技能树加成：出售返还比例
    local sellBonus = GetSkillEffect("sell_refund")
    local refundRate = CONFIG.SellRefundRate + sellBonus
    local refund = math.floor(tower.totalCost * refundRate)
    playerGold_ = playerGold_ + refund
    
    -- 从towers_列表移除
    for i, t in ipairs(towers_) do
        if t == tower then
            table.remove(towers_, i)
            break
        end
    end
    
    spot.tower = nil
    showTowerMenu_ = false
    print("出售塔，返还 " .. refund .. " 金币")
end

-- ============================================================================
-- 9. 事件处理
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    
    if currentState_ == GameState.PLAYING then
        gameTime_ = gameTime_ + dt
        
        -- 更新波次生成
        if waveActive_ then
            spawnTimer_ = spawnTimer_ + dt
            
            -- 生成敌人
            for i = #waveEnemyQueue_, 1, -1 do
                if waveEnemyQueue_[i].delay <= spawnTimer_ then
                    SpawnEnemy(waveEnemyQueue_[i].type)
                    table.remove(waveEnemyQueue_, i)
                end
            end
            
            -- 波次结束检查
            if #waveEnemyQueue_ == 0 and #enemies_ == 0 then
                waveActive_ = false
                waveTimer_ = 0
                
                -- 波次奖励（应用技能树加成）
                local waveBonusFlat = GetSkillEffect("wave_bonus_flat")
                local waveBonusPercent = GetSkillEffect("wave_bonus")  -- 可能是负数（贷款debuff）
                local waveReward = math.floor((CONFIG.WaveBonus + waveBonusFlat) * (1 + waveBonusPercent))
                playerGold_ = playerGold_ + waveReward
                totalGoldEarned_ = totalGoldEarned_ + waveReward
                
                -- 技能树加成：每波恢复生命
                local lifeRegen = GetSkillEffect("life_regen_wave")
                if lifeRegen > 0 then
                    local maxLives = CONFIG.InitialLives + GetSkillEffect("max_lives")
                    playerLives_ = math.min(playerLives_ + lifeRegen, maxLives)
                end
                
                print("波次 " .. currentWave_ .. " 完成！奖励 " .. waveReward .. " 金币")
            end
        else
            -- 等待下一波
            waveTimer_ = waveTimer_ + dt
            if waveTimer_ >= waveDelay_ then
                StartNextWave()
            end
        end
        
        UpdateEnemies(dt)
        UpdateTowers(dt)
        UpdateProjectiles(dt)
        UpdateParticles(dt)
        UpdateScreenShake(dt)
    end
end

-- 更新屏幕震动效果
function UpdateScreenShake(dt)
    if screenShake_.timer > 0 then
        screenShake_.timer = screenShake_.timer - dt
        -- 计算随机震动偏移，强度随时间衰减
        local ratio = screenShake_.timer / 0.5  -- 假设最大持续时间0.5秒
        local intensity = screenShake_.intensity * ratio
        screenShake_.offsetX = (math.random() - 0.5) * 2 * intensity
        screenShake_.offsetY = (math.random() - 0.5) * 2 * intensity
    else
        screenShake_.offsetX = 0
        screenShake_.offsetY = 0
    end
end

-- 触发屏幕震动
function TriggerScreenShake(intensity, duration)
    intensity = intensity or 10
    duration = duration or 0.3
    -- 如果新的震动更强，则覆盖
    if intensity >= screenShake_.intensity or screenShake_.timer <= 0 then
        screenShake_.intensity = intensity
        screenShake_.timer = duration
    end
end

---@param eventType string
---@param eventData MouseButtonDownEventData
function HandleMouseDown(eventType, eventData)
    local button = eventData["Button"]:GetInt()
    local mx = input.mousePosition.x
    local my = input.mousePosition.y
    
    if button == MOUSEB_LEFT then
        if currentState_ == GameState.MENU then
            HandleMenuClick(mx, my)
        elseif currentState_ == GameState.PLAYING then
            HandleGameClick(mx, my)
        elseif currentState_ == GameState.VICTORY or currentState_ == GameState.DEFEAT then
            HandleEndClick(mx, my)
        end
    elseif button == MOUSEB_RIGHT then
        -- 右键取消
        showTowerMenu_ = false
        selectedTowerSpot_ = nil
    end
end

function HandleMenuClick(mx, my)
    local width = graphics.width
    local height = graphics.height
    
    -- 如果关卡选择面板打开，优先处理面板点击
    if showLevelSelectPanel_ then
        HandleLevelSelectPanelClick(mx, my)
        return
    end
    
    -- 底部按钮区域（与 DrawMenu 一致：height - 200）
    local bottomBarY = height - 200
    
    -- 先检查是否在底部区域
    if my >= bottomBarY then
        -- 检查"重置技能"按钮点击
        local resetBtnWidth = 120
        local resetBtnHeight = 40
        local resetBtnX = 30
        local resetBtnY = bottomBarY + 50
        
        if mx >= resetBtnX and mx <= resetBtnX + resetBtnWidth and
           my >= resetBtnY and my <= resetBtnY + resetBtnHeight then
            ResetAllSkills()
            return
        end
        
        -- 检查"进入战斗"按钮点击
        local battleBtnWidth = 280
        local battleBtnX = (width - battleBtnWidth) / 2
        local battleBtnY = bottomBarY + 40
        local battleBtnHeight = 60
        
        if mx >= battleBtnX and mx <= battleBtnX + battleBtnWidth and
           my >= battleBtnY and my <= battleBtnY + battleBtnHeight then
            showLevelSelectPanel_ = true
            return
        end
        
        return  -- 底部区域但不在按钮上，不处理
    end
    
    -- 检查技能节点点击（在底部按钮区域之上）
    HandleMenuSkillClick(mx, my)
end

-- 处理主菜单中技能节点的点击
function HandleMenuSkillClick(mx, my)
    local width = graphics.width
    local height = graphics.height
    
    local lineCount = #SkillTreeLayout.lineOrder
    local lineWidth = (width - 100) / lineCount
    local startY = 120
    local skillNodeHeight = 65
    local skillGap = 12
    
    for lineIdx, lineId in ipairs(SkillTreeLayout.lineOrder) do
        local line = SkillTree[lineId]
        local lineX = 50 + (lineIdx - 1) * lineWidth + lineWidth / 2
        local nodeWidth = lineWidth - 30
        local nodeX = lineX - nodeWidth / 2
        
        local orderedSkills = GetOrderedSkills(lineId)
        
        for skillIdx, skillId in ipairs(orderedSkills) do
            local nodeY = startY + 35 + (skillIdx - 1) * (skillNodeHeight + skillGap)
            
            if mx >= nodeX and mx <= nodeX + nodeWidth and
               my >= nodeY and my <= nodeY + skillNodeHeight then
                local success, errMsg = UpgradeSkill(lineId, skillId)
                if success then
                    print("成功升级技能: " .. line.skills[skillId].name)
                else
                    print("无法升级: " .. (errMsg or "未知原因"))
                end
                return
            end
        end
    end
end

-- 处理关卡选择面板点击
function HandleLevelSelectPanelClick(mx, my)
    local width = graphics.width
    local height = graphics.height
    
    -- 面板尺寸
    local panelWidth = 500
    local panelHeight = 500
    local panelX = (width - panelWidth) / 2
    local panelY = (height - panelHeight) / 2
    
    -- 检查关闭按钮
    local closeBtnSize = 40
    local closeBtnX = panelX + panelWidth - closeBtnSize - 10
    local closeBtnY = panelY + 10
    
    if mx >= closeBtnX and mx <= closeBtnX + closeBtnSize and
       my >= closeBtnY and my <= closeBtnY + closeBtnSize then
        showLevelSelectPanel_ = false
        return
    end
    
    -- 检查关卡按钮
    local buttonWidth = 420
    local buttonHeight = 75
    local buttonStartY = panelY + 90
    local buttonGap = 15
    
    for i = 1, 4 do
        local bx = panelX + (panelWidth - buttonWidth) / 2
        local by = buttonStartY + (i - 1) * (buttonHeight + buttonGap)
        
        if mx >= bx and mx <= bx + buttonWidth and my >= by and my <= by + buttonHeight then
            showLevelSelectPanel_ = false
            StartLevel(i)
            return
        end
    end
    
    -- 点击面板外部关闭面板
    if mx < panelX or mx > panelX + panelWidth or my < panelY or my > panelY + panelHeight then
        showLevelSelectPanel_ = false
        return
    end
end

function HandleGameClick(mx, my)
    local level = Levels[selectedLevel_]
    local width = graphics.width
    local height = graphics.height
    
    -- 检查是否点击了"退出"按钮（右上角）
    local exitBtnWidth = 100
    local exitBtnHeight = 40
    local exitBtnX = width - exitBtnWidth - 20
    local exitBtnY = 10
    
    if mx >= exitBtnX and mx <= exitBtnX + exitBtnWidth and my >= exitBtnY and my <= exitBtnY + exitBtnHeight then
        -- 返回主菜单
        currentState_ = GameState.MENU
        showTowerMenu_ = false
        selectedTowerSpot_ = nil
        return
    end
    
    -- 检查是否点击了"下一波"按钮
    local buttonWidth = 180
    local buttonHeight = 60
    local bx = width - buttonWidth - 30
    local by = height - buttonHeight - 30
    
    if mx >= bx and mx <= bx + buttonWidth and my >= by and my <= by + buttonHeight then
        TriggerNextWave()
        return
    end
    
    -- 检查是否点击了塔菜单
    if showTowerMenu_ and menuTower_ then
        local menuHandled = HandleTowerMenuClick(mx, my)
        if menuHandled then
            return
        end
    end
    
    -- 检查是否点击了放置点
    for _, spot in ipairs(level.towerSpots) do
        local dist = math.sqrt((mx - spot.x)^2 + (my - spot.y)^2)
        if dist <= CONFIG.GridSize / 2 then
            selectedTowerSpot_ = spot
            showTowerMenu_ = true
            menuTower_ = spot
            return
        end
    end
    
    -- 点击空白处关闭菜单
    showTowerMenu_ = false
    selectedTowerSpot_ = nil
end

-- 触发下一波
function TriggerNextWave()
    local level = Levels[selectedLevel_]
    if not waveActive_ and currentWave_ < #level.waves then
        waveTimer_ = waveDelay_  -- 立即触发下一波
    end
end

function HandleTowerMenuClick(mx, my)
    local spot = menuTower_
    if not spot then return false end
    
    local menuX = spot.x + 60
    local menuY = spot.y - 100
    local buttonWidth = 160
    local buttonHeight = 48
    
    if spot.tower then
        -- 已有塔：升级/出售
        -- 升级按钮
        if mx >= menuX and mx <= menuX + buttonWidth and my >= menuY and my <= menuY + buttonHeight then
            UpgradeTower(spot.tower)
            return true
        end
        -- 出售按钮
        menuY = menuY + 58
        if mx >= menuX and mx <= menuX + buttonWidth and my >= menuY and my <= menuY + buttonHeight then
            SellTower(spot.tower, spot)
            return true
        end
    else
        -- 空地：选择塔类型
        local towerTypes = {"arrow", "cannon", "slow", "laser"}
        for i, ttype in ipairs(towerTypes) do
            local by = menuY + (i - 1) * 58
            if mx >= menuX and mx <= menuX + buttonWidth and my >= by and my <= by + buttonHeight then
                BuildTower(spot, ttype)
                return true
            end
        end
    end
    
    return false
end

function HandleEndClick(mx, my)
    local width = graphics.width
    local height = graphics.height
    
    -- 重新开始按钮
    local buttonWidth = 220
    local buttonHeight = 60
    local bx = (width - buttonWidth) / 2
    local by = height / 2 + 120
    
    if mx >= bx and mx <= bx + buttonWidth and my >= by and my <= by + buttonHeight then
        StartLevel(selectedLevel_)
        return
    end
    
    -- 返回菜单按钮
    by = by + 80
    if mx >= bx and mx <= bx + buttonWidth and my >= by and my <= by + buttonHeight then
        currentState_ = GameState.MENU
        return
    end
end

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    
    if key == KEY_ESCAPE then
        if currentState_ == GameState.MENU and showLevelSelectPanel_ then
            -- 关闭关卡选择面板
            showLevelSelectPanel_ = false
        elseif currentState_ == GameState.PLAYING then
            currentState_ = GameState.MENU
        else
            engine:Exit()
        end
    elseif key == KEY_SPACE then
        if currentState_ == GameState.PLAYING then
            TriggerNextWave()
        end
    end
end

-- ============================================================================
-- 10. 渲染函数
-- ============================================================================

function HandleRender(eventType, eventData)
    if nvg_ == nil then return end
    
    local width = graphics.width
    local height = graphics.height
    
    nvgBeginFrame(nvg_, width, height, 1.0)
    
    if currentState_ == GameState.MENU then
        DrawMenu(width, height)
    elseif currentState_ == GameState.PLAYING then
        DrawGame(width, height)
    elseif currentState_ == GameState.VICTORY then
        DrawEndScreen(width, height, true)
    elseif currentState_ == GameState.DEFEAT then
        DrawEndScreen(width, height, false)
    end
    
    nvgEndFrame(nvg_)
end

function DrawMenu(width, height)
    -- 背景（深紫色渐变，与技能树风格一致）
    local bg = nvgLinearGradient(nvg_, 0, 0, 0, height,
        nvgRGBA(35, 25, 55, 255),
        nvgRGBA(20, 15, 35, 255))
    nvgBeginPath(nvg_)
    nvgRect(nvg_, 0, 0, width, height)
    nvgFillPaint(nvg_, bg)
    nvgFill(nvg_)
    
    -- 标题
    nvgFontFace(nvg_, "sans")
    nvgFontSize(nvg_, 56)
    nvgFillColor(nvg_, nvgRGBA(200, 150, 255, 255))
    nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(nvg_, width / 2, 45, "⭐ 塔防游戏 - 技能树", nil)
    
    -- 技能点显示
    nvgFontSize(nvg_, 24)
    nvgFillColor(nvg_, nvgRGBA(255, 220, 100, 255))
    nvgText(nvg_, width / 2, 85, "可用技能点: " .. PlayerSkills.skillPoints, nil)
    
    -- 计算布局（底部留出空间给按钮）
    local lineCount = #SkillTreeLayout.lineOrder
    local lineWidth = (width - 100) / lineCount
    local startY = 120
    local skillNodeHeight = 65
    local skillGap = 12
    
    -- 绘制每条技能线
    for lineIdx, lineId in ipairs(SkillTreeLayout.lineOrder) do
        local line = SkillTree[lineId]
        local lineX = 50 + (lineIdx - 1) * lineWidth + lineWidth / 2
        local lineColor = SkillTreeLayout.lineColors[lineId]
        local lineIcon = SkillTreeLayout.lineIcons[lineId]
        
        -- 线路标题
        nvgFontSize(nvg_, 22)
        nvgFillColor(nvg_, nvgRGBA(lineColor[1], lineColor[2], lineColor[3], 255))
        nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(nvg_, lineX, startY, lineIcon .. " " .. line.name, nil)
        
        -- 按照依赖顺序排列技能
        local orderedSkills = GetOrderedSkills(lineId)
        
        -- 绘制每个技能节点
        for skillIdx, skillId in ipairs(orderedSkills) do
            local skill = line.skills[skillId]
            local nodeY = startY + 35 + (skillIdx - 1) * (skillNodeHeight + skillGap)
            local nodeWidth = lineWidth - 30
            local nodeX = lineX - nodeWidth / 2
            
            local currentLevel = GetSkillLevel(skillId)
            local canUpgrade, _ = CanUpgradeSkill(lineId, skillId)
            
            -- 节点背景
            local alpha = 200
            if currentLevel > 0 then
                -- 已学习：高亮
                nvgBeginPath(nvg_)
                nvgRoundedRect(nvg_, nodeX, nodeY, nodeWidth, skillNodeHeight, 8)
                nvgFillColor(nvg_, nvgRGBA(lineColor[1], lineColor[2], lineColor[3], alpha))
                nvgFill(nvg_)
            elseif canUpgrade then
                -- 可学习：半透明
                nvgBeginPath(nvg_)
                nvgRoundedRect(nvg_, nodeX, nodeY, nodeWidth, skillNodeHeight, 8)
                nvgFillColor(nvg_, nvgRGBA(lineColor[1] / 2, lineColor[2] / 2, lineColor[3] / 2, alpha))
                nvgFill(nvg_)
                -- 发光边框表示可点击
                nvgStrokeColor(nvg_, nvgRGBA(255, 255, 100, 180))
                nvgStrokeWidth(nvg_, 2)
                nvgStroke(nvg_)
            else
                -- 锁定：暗色
                nvgBeginPath(nvg_)
                nvgRoundedRect(nvg_, nodeX, nodeY, nodeWidth, skillNodeHeight, 8)
                nvgFillColor(nvg_, nvgRGBA(60, 60, 70, alpha))
                nvgFill(nvg_)
            end
            
            -- 边框
            nvgBeginPath(nvg_)
            nvgRoundedRect(nvg_, nodeX, nodeY, nodeWidth, skillNodeHeight, 8)
            nvgStrokeColor(nvg_, nvgRGBA(lineColor[1], lineColor[2], lineColor[3], 150))
            nvgStrokeWidth(nvg_, 1)
            nvgStroke(nvg_)
            
            -- 技能名称
            nvgFontSize(nvg_, 18)
            nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
            nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgText(nvg_, lineX, nodeY + 15, skill.name, nil)
            
            -- 等级显示
            nvgFontSize(nvg_, 14)
            if currentLevel >= skill.maxLevel then
                nvgFillColor(nvg_, nvgRGBA(100, 255, 100, 255))
                nvgText(nvg_, lineX, nodeY + 32, "已满级 (" .. currentLevel .. "/" .. skill.maxLevel .. ")", nil)
            else
                nvgFillColor(nvg_, nvgRGBA(200, 200, 200, 255))
                local costText = ""
                if currentLevel < skill.maxLevel then
                    costText = " 花费: " .. skill.costs[currentLevel + 1]
                end
                nvgText(nvg_, lineX, nodeY + 32, currentLevel .. "/" .. skill.maxLevel .. costText, nil)
            end
            
            -- 描述
            nvgFontSize(nvg_, 13)
            nvgFillColor(nvg_, nvgRGBA(200, 200, 200, 220))
            nvgText(nvg_, lineX, nodeY + 50, skill.description, nil)
        end
    end
    
    -- 底部按钮区域背景（移动到更上方以测试）
    local bottomBarY = height - 200
    nvgBeginPath(nvg_)
    nvgRect(nvg_, 0, bottomBarY, width, 200)
    nvgFillColor(nvg_, nvgRGBA(25, 20, 40, 200))
    nvgFill(nvg_)
    
    -- 分隔线
    nvgBeginPath(nvg_)
    nvgMoveTo(nvg_, 0, bottomBarY)
    nvgLineTo(nvg_, width, bottomBarY)
    nvgStrokeColor(nvg_, nvgRGBA(100, 80, 150, 150))
    nvgStrokeWidth(nvg_, 2)
    nvgStroke(nvg_)
    
    -- 进入战斗按钮（居中，大按钮，移动到更上方）
    local battleBtnWidth = 280
    local battleBtnHeight = 60
    local battleBtnX = (width - battleBtnWidth) / 2
    local battleBtnY = bottomBarY + 40
    
    -- 按钮背景（青色风格）
    local btnBg = nvgLinearGradient(nvg_, battleBtnX, battleBtnY, battleBtnX, battleBtnY + battleBtnHeight,
        nvgRGBA(62, 213, 170, 230),
        nvgRGBA(45, 160, 130, 230))
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, battleBtnX, battleBtnY, battleBtnWidth, battleBtnHeight, 12)
    nvgFillPaint(nvg_, btnBg)
    nvgFill(nvg_)
    
    -- 按钮边框
    nvgStrokeColor(nvg_, nvgRGBA(80, 240, 200, 200))
    nvgStrokeWidth(nvg_, 3)
    nvgStroke(nvg_)
    
    -- 按钮文字
    nvgFontSize(nvg_, 32)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
    nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(nvg_, battleBtnX + battleBtnWidth / 2, battleBtnY + battleBtnHeight / 2, "⚔️ 进入战斗", nil)
    
    -- 重置技能按钮（左侧，与进入战斗按钮同一行）
    local resetBtnWidth = 120
    local resetBtnHeight = 40
    local resetBtnX = 30
    local resetBtnY = bottomBarY + 50
    
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, resetBtnX, resetBtnY, resetBtnWidth, resetBtnHeight, 8)
    nvgFillColor(nvg_, nvgRGBA(150, 70, 70, 200))
    nvgFill(nvg_)
    nvgStrokeColor(nvg_, nvgRGBA(200, 100, 100, 180))
    nvgStrokeWidth(nvg_, 2)
    nvgStroke(nvg_)
    
    nvgFontSize(nvg_, 18)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
    nvgText(nvg_, resetBtnX + resetBtnWidth / 2, resetBtnY + resetBtnHeight / 2, "🔄 重置技能", nil)
    
    -- 绘制关卡选择面板（如果打开）
    if showLevelSelectPanel_ then
        DrawLevelSelectPanel(width, height)
    end
end

-- 绘制关卡选择面板
function DrawLevelSelectPanel(width, height)
    -- 半透明遮罩
    nvgBeginPath(nvg_)
    nvgRect(nvg_, 0, 0, width, height)
    nvgFillColor(nvg_, nvgRGBA(0, 0, 0, 180))
    nvgFill(nvg_)
    
    -- 面板尺寸
    local panelWidth = 500
    local panelHeight = 500
    local panelX = (width - panelWidth) / 2
    local panelY = (height - panelHeight) / 2
    
    -- 面板背景
    local panelBg = nvgLinearGradient(nvg_, panelX, panelY, panelX, panelY + panelHeight,
        nvgRGBA(50, 40, 70, 250),
        nvgRGBA(35, 28, 50, 250))
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, panelX, panelY, panelWidth, panelHeight, 16)
    nvgFillPaint(nvg_, panelBg)
    nvgFill(nvg_)
    
    -- 面板边框
    nvgStrokeColor(nvg_, nvgRGBA(100, 80, 150, 200))
    nvgStrokeWidth(nvg_, 3)
    nvgStroke(nvg_)
    
    -- 标题
    nvgFontFace(nvg_, "sans")
    nvgFontSize(nvg_, 36)
    nvgFillColor(nvg_, nvgRGBA(62, 213, 170, 255))
    nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(nvg_, panelX + panelWidth / 2, panelY + 45, "⚔️ 选择关卡", nil)
    
    -- 关卡按钮
    local buttonWidth = 420
    local buttonHeight = 75
    local buttonStartY = panelY + 90
    local buttonGap = 15
    
    for i = 1, 4 do
        local bx = panelX + (panelWidth - buttonWidth) / 2
        local by = buttonStartY + (i - 1) * (buttonHeight + buttonGap)
        local level = Levels[i]
        
        -- 按钮背景渐变
        local btnBg = nvgLinearGradient(nvg_, bx, by, bx, by + buttonHeight,
            nvgRGBA(62, 213, 170, 180),
            nvgRGBA(45, 160, 130, 180))
        nvgBeginPath(nvg_)
        nvgRoundedRect(nvg_, bx, by, buttonWidth, buttonHeight, 12)
        nvgFillPaint(nvg_, btnBg)
        nvgFill(nvg_)
        
        -- 按钮边框
        nvgStrokeColor(nvg_, nvgRGBA(80, 240, 200, 150))
        nvgStrokeWidth(nvg_, 2)
        nvgStroke(nvg_)
        
        -- 关卡名称
        nvgFontSize(nvg_, 26)
        nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
        nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgText(nvg_, bx + buttonWidth / 2, by + buttonHeight / 2 - 10, level.name, nil)
        
        -- 关卡描述
        nvgFontSize(nvg_, 16)
        nvgFillColor(nvg_, nvgRGBA(220, 220, 220, 200))
        nvgText(nvg_, bx + buttonWidth / 2, by + buttonHeight / 2 + 14, level.description, nil)
    end
    
    -- 关闭按钮（X）
    local closeBtnSize = 40
    local closeBtnX = panelX + panelWidth - closeBtnSize - 10
    local closeBtnY = panelY + 10
    
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, closeBtnX, closeBtnY, closeBtnSize, closeBtnSize, 8)
    nvgFillColor(nvg_, nvgRGBA(150, 70, 70, 200))
    nvgFill(nvg_)
    
    nvgFontSize(nvg_, 28)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
    nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(nvg_, closeBtnX + closeBtnSize / 2, closeBtnY + closeBtnSize / 2, "✕", nil)
    
    -- 底部提示
    nvgFontSize(nvg_, 16)
    nvgFillColor(nvg_, nvgRGBA(150, 150, 150, 200))
    nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgText(nvg_, panelX + panelWidth / 2, panelY + panelHeight - 15, "点击选择关卡开始游戏 | ESC关闭面板", nil)
end

-- ============================================================================
-- 技能树辅助函数
-- ============================================================================

-- 获取排序后的技能列表（按依赖顺序）
function GetOrderedSkills(lineId)
    local line = SkillTree[lineId]
    local ordered = {}
    local added = {}
    
    -- 先添加没有前置的技能
    for skillId, skill in pairs(line.skills) do
        if not skill.prerequisite then
            table.insert(ordered, skillId)
            added[skillId] = true
        end
    end
    
    -- 然后按依赖顺序添加其他技能
    local maxIterations = 20
    local iteration = 0
    while iteration < maxIterations do
        iteration = iteration + 1
        local addedAny = false
        for skillId, skill in pairs(line.skills) do
            if not added[skillId] and skill.prerequisite and added[skill.prerequisite] then
                table.insert(ordered, skillId)
                added[skillId] = true
                addedAny = true
            end
        end
        if not addedAny then break end
    end
    
    return ordered
end

function DrawGame(width, height)
    local level = Levels[selectedLevel_]
    
    -- 绘制游戏场景背景（背景不震动）
    local bgColor = level.backgroundColor
    nvgBeginPath(nvg_)
    nvgRect(nvg_, 0, 0, width, height)
    nvgFillColor(nvg_, nvgRGBA(bgColor[1], bgColor[2], bgColor[3], 255))
    nvgFill(nvg_)
    
    -- 应用屏幕震动偏移
    nvgSave(nvg_)
    if screenShake_.timer > 0 then
        nvgTranslate(nvg_, screenShake_.offsetX, screenShake_.offsetY)
    end
    
    -- 绘制路径
    DrawPath(level.path)
    
    -- 绘制放置点
    DrawTowerSpots(level.towerSpots)
    
    -- 绘制塔
    DrawTowers()
    
    -- 绘制敌人
    DrawEnemies()
    
    -- 绘制激光（在敌人之上）
    DrawLasers()
    
    -- 绘制子弹
    DrawProjectiles()
    
    -- 绘制粒子
    DrawParticles()
    
    -- 绘制塔菜单
    if showTowerMenu_ and menuTower_ then
        DrawTowerMenu(menuTower_)
    end
    
    -- 恢复变换（HUD不震动）
    nvgRestore(nvg_)
    
    -- 绘制HUD
    DrawHUD(width, height)
    
    -- 如果正在震动，绘制红色闪烁边框效果
    if screenShake_.timer > 0 then
        local alpha = math.floor(80 * (screenShake_.timer / 0.3))
        nvgBeginPath(nvg_)
        nvgRect(nvg_, 0, 0, width, height)
        nvgStrokeColor(nvg_, nvgRGBA(255, 50, 50, alpha))
        nvgStrokeWidth(nvg_, 8)
        nvgStroke(nvg_)
    end
end

-- 检查点是否在道路区域内（包括护栏）
function IsPointInPathArea(px, py, path, checkWidth, excludeSegment)
    local halfWidth = checkWidth / 2
    for i = 1, #path - 1 do
        if i ~= excludeSegment then
            local x1, y1 = path[i].x, path[i].y
            local x2, y2 = path[i + 1].x, path[i + 1].y
            
            local dx = x2 - x1
            local dy = y2 - y1
            local len = math.sqrt(dx * dx + dy * dy)
            if len > 0 then
                local t = math.max(0, math.min(1, ((px - x1) * dx + (py - y1) * dy) / (len * len)))
                local closestX = x1 + t * dx
                local closestY = y1 + t * dy
                local distSq = (px - closestX)^2 + (py - closestY)^2
                if distSq < halfWidth * halfWidth then
                    return true
                end
            end
        end
    end
    return false
end

-- 检查点是否在道路线段内部
function IsPointNearSegment(px, py, x1, y1, x2, y2, width)
    local dx = x2 - x1
    local dy = y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len == 0 then return false end
    
    local t = math.max(0, math.min(1, ((px - x1) * dx + (py - y1) * dy) / (len * len)))
    local closestX = x1 + t * dx
    local closestY = y1 + t * dy
    local distSq = (px - closestX)^2 + (py - closestY)^2
    return distSq < (width / 2)^2
end

-- 切割矩形：如果矩形被道路分割，返回切割后的矩形列表
function SplitRectByPath(rect, path, pathWidth)
    local result = {}
    local p1, p2, p3, p4 = rect.p1, rect.p2, rect.p3, rect.p4
    
    -- 计算矩形的中心线上多个采样点
    local samplePoints = {}
    for t = 0, 1, 0.1 do
        local mx = p1.x * (1-t) + p2.x * t
        local my = p1.y * (1-t) + p2.y * t
        local mx2 = p4.x * (1-t) + p3.x * t
        local my2 = p4.y * (1-t) + p3.y * t
        table.insert(samplePoints, {
            t = t,
            inner = {x = mx, y = my},
            outer = {x = mx2, y = my2},
            center = {x = (mx + mx2) / 2, y = (my + my2) / 2}
        })
    end
    
    -- 检查每个采样点是否被道路遮挡
    local segments = {}
    local currentSegment = nil
    
    for _, sample in ipairs(samplePoints) do
        local isBlocked = false
        for j = 1, #path - 1 do
            if j ~= rect.segmentIndex then
                if IsPointNearSegment(sample.center.x, sample.center.y, 
                    path[j].x, path[j].y, path[j+1].x, path[j+1].y, pathWidth + 20) then
                    isBlocked = true
                    break
                end
            end
        end
        
        if not isBlocked then
            if not currentSegment then
                currentSegment = {startT = sample.t, endT = sample.t}
            else
                currentSegment.endT = sample.t
            end
        else
            if currentSegment then
                table.insert(segments, currentSegment)
                currentSegment = nil
            end
        end
    end
    
    if currentSegment then
        table.insert(segments, currentSegment)
    end
    
    -- 根据分段创建子矩形
    for _, seg in ipairs(segments) do
        local t1, t2 = seg.startT, seg.endT
        local subRect = {
            segmentIndex = rect.segmentIndex,
            p1 = { x = p1.x * (1-t1) + p2.x * t1, y = p1.y * (1-t1) + p2.y * t1 },
            p2 = { x = p1.x * (1-t2) + p2.x * t2, y = p1.y * (1-t2) + p2.y * t2 },
            p3 = { x = p4.x * (1-t2) + p3.x * t2, y = p4.y * (1-t2) + p3.y * t2 },
            p4 = { x = p4.x * (1-t1) + p3.x * t1, y = p4.y * (1-t1) + p3.y * t1 },
        }
        subRect.centerX = (subRect.p1.x + subRect.p2.x + subRect.p3.x + subRect.p4.x) / 4
        subRect.centerY = (subRect.p1.y + subRect.p2.y + subRect.p3.y + subRect.p4.y) / 4
        table.insert(result, subRect)
    end
    
    return result
end

function DrawPath(path)
    if #path < 2 then return end
    
    local pathWidth = 100       -- 道路内部宽度
    local railWidth = 100       -- 护栏宽度（上下左右都是这个宽度）
    local shadowOffset = 5     -- 阴影偏移
    local halfPath = pathWidth / 2
    
    -- 收集所有8方向的矩形
    local allRects = {}
    
    -- 先收集所有道路的边界框
    local roadBounds = {}
    for i = 1, #path - 1 do
        local x1, y1 = path[i].x, path[i].y
        local x2, y2 = path[i + 1].x, path[i + 1].y
        table.insert(roadBounds, {
            x_min = math.min(x1, x2) - halfPath,
            x_max = math.max(x1, x2) + halfPath,
            y_min = math.min(y1, y2) - halfPath,
            y_max = math.max(y1, y2) + halfPath,
            segmentIndex = i,
        })
    end
    
    -- 切割矩形的函数：如果矩形被道路切割，返回切割后的矩形列表
    local function splitRectByRoads(rect, excludeSegment)
        local results = {rect}
        
        for _, road in ipairs(roadBounds) do
            if road.segmentIndex ~= excludeSegment then
                local newResults = {}
                
                for _, r in ipairs(results) do
                    -- 检查矩形r是否与道路road相交
                    local intersectX = not (r.x_max <= road.x_min or r.x_min >= road.x_max)
                    local intersectY = not (r.y_max <= road.y_min or r.y_min >= road.y_max)
                    
                    if intersectX and intersectY then
                        -- 有相交，需要切割
                        -- 计算切割后的矩形（水平切割或垂直切割）
                        
                        -- 水平切割（上下分割）
                        if road.x_min <= r.x_min and road.x_max >= r.x_max then
                            -- 道路完全覆盖矩形的X范围，进行Y方向切割
                            -- 上方部分
                            if r.y_min < road.y_min then
                                table.insert(newResults, {
                                    x_min = r.x_min, x_max = r.x_max,
                                    y_min = r.y_min, y_max = math.min(r.y_max, road.y_min),
                                    segmentIndex = r.segmentIndex,
                                })
                            end
                            -- 下方部分
                            if r.y_max > road.y_max then
                                table.insert(newResults, {
                                    x_min = r.x_min, x_max = r.x_max,
                                    y_min = math.max(r.y_min, road.y_max), y_max = r.y_max,
                                    segmentIndex = r.segmentIndex,
                                })
                            end
                        -- 垂直切割（左右分割）
                        elseif road.y_min <= r.y_min and road.y_max >= r.y_max then
                            -- 道路完全覆盖矩形的Y范围，进行X方向切割
                            -- 左边部分
                            if r.x_min < road.x_min then
                                table.insert(newResults, {
                                    x_min = r.x_min, x_max = math.min(r.x_max, road.x_min),
                                    y_min = r.y_min, y_max = r.y_max,
                                    segmentIndex = r.segmentIndex,
                                })
                            end
                            -- 右边部分
                            if r.x_max > road.x_max then
                                table.insert(newResults, {
                                    x_min = math.max(r.x_min, road.x_max), x_max = r.x_max,
                                    y_min = r.y_min, y_max = r.y_max,
                                    segmentIndex = r.segmentIndex,
                                })
                            end
                        else
                            -- 部分相交但不完全覆盖，保留原矩形（或可以更复杂处理）
                            -- 简化处理：如果中心点在道路内，则删除整个矩形
                            local centerX = (r.x_min + r.x_max) / 2
                            local centerY = (r.y_min + r.y_max) / 2
                            if not (centerX >= road.x_min and centerX <= road.x_max and
                                    centerY >= road.y_min and centerY <= road.y_max) then
                                table.insert(newResults, r)
                            end
                        end
                    else
                        -- 无相交，保留原矩形
                        table.insert(newResults, r)
                    end
                end
                
                results = newResults
            end
        end
        
        return results
    end
    
    for i = 1, #path - 1 do
        -- 获取当前路径段的起点和终点坐标
        local x1, y1 = path[i].x, path[i].y      -- 起点
        local x2, y2 = path[i + 1].x, path[i + 1].y  -- 终点
        local road_x_min = math.min(x1, x2) - halfPath
        local road_x_max = math.max(x1, x2) + halfPath
        local road_y_min = math.min(y1, y2) - halfPath
        local road_y_max = math.max(y1, y2) + halfPath
        
        -- 定义4个方向的护栏矩形
        local railRects = {
            -- 上侧矩形
            { x_min = road_x_min - railWidth, x_max = road_x_max + railWidth,
              y_min = road_y_max, y_max = road_y_max + railWidth, segmentIndex = i },
            -- 下侧矩形
            { x_min = road_x_min - railWidth, x_max = road_x_max + railWidth,
              y_min = road_y_min - railWidth, y_max = road_y_min, segmentIndex = i },
            -- 左侧矩形
            { x_min = road_x_min - railWidth, x_max = road_x_min,
              y_min = road_y_min - railWidth, y_max = road_y_max + railWidth, segmentIndex = i },
            -- 右侧矩形
            { x_min = road_x_max, x_max = road_x_max + railWidth,
              y_min = road_y_min - railWidth, y_max = road_y_max + railWidth, segmentIndex = i },
        }
        
        -- 对每个护栏矩形进行切割处理
        for _, rail in ipairs(railRects) do
            local splitResults = splitRectByRoads(rail, i)
            for _, splitRect in ipairs(splitResults) do
                -- 只添加有效矩形（宽度和高度都大于0）
                if splitRect.x_max > splitRect.x_min and splitRect.y_max > splitRect.y_min then
                    table.insert(allRects, splitRect)
                end
            end
        end
    end
    
    -- 计算每个矩形的中心点和y_min（用于排序）
    for _, rect in ipairs(allRects) do
        rect.centerX = (rect.x_min + rect.x_max) / 2
        rect.centerY = (rect.y_min + rect.y_max) / 2
        -- 计算矩形的y_min（四个顶点中最小的y值）
        rect.sort_value = rect.y_max
    end
    
    -- 对 allRects 按 y_min 排序（y_min 越大越靠前，这样先绘制y小的，后绘制y大的）
    table.sort(allRects, function(a, b)
        return a.sort_value < b.sort_value
    end)
	
    -- ========== 绘制所有护栏矩形 ==========
    local liftOffset = 10  -- 护栏向上偏移量
    local cornerRadius = 10  -- 圆角半径
    
    for _, rect in ipairs(allRects) do
        local width = rect.x_max - rect.x_min
        local height = rect.y_max - rect.y_min
        
        -- 1. 先绘制下方深青色部分（10像素高度的立体效果）
        nvgBeginPath(nvg_)
        nvgRoundedRect(nvg_, rect.x_min, rect.y_min + liftOffset, width, height, cornerRadius)
        nvgFillColor(nvg_, nvgRGBA(35, 140, 110, 255))
        nvgFill(nvg_)
    end
    
    for _, rect in ipairs(allRects) do
        local width = rect.x_max - rect.x_min
        local height = rect.y_max - rect.y_min

		-- 2. 绘制青色护栏
        nvgBeginPath(nvg_)
        nvgRoundedRect(nvg_, rect.x_min, rect.y_min, width, height, cornerRadius)
        nvgFillColor(nvg_, nvgRGBA(62, 213, 170, 255))
        nvgFill(nvg_)
    end
    
    ---- 3. 绘制深色道路内部
    --for i = 1, #path - 1 do
    --    local x1, y1 = path[i].x, path[i].y
    --    local x2, y2 = path[i + 1].x, path[i + 1].y
    --    
    --    -- 路径只有水平或垂直两种情况
    --    local isHorizontal = (y1 == y2)
    --    
    --    nvgBeginPath(nvg_)
    --    if isHorizontal then
    --        -- 水平路径：上下偏移halfPath
    --        nvgMoveTo(nvg_, x1, y1 - halfPath)
    --        nvgLineTo(nvg_, x2, y2 - halfPath)
    --        nvgLineTo(nvg_, x2, y2 + halfPath)
    --        nvgLineTo(nvg_, x1, y1 + halfPath)
    --    else
    --        -- 垂直路径：左右偏移halfPath
    --        nvgMoveTo(nvg_, x1 - halfPath, y1)
    --        nvgLineTo(nvg_, x2 - halfPath, y2)
    --        nvgLineTo(nvg_, x2 + halfPath, y2)
    --        nvgLineTo(nvg_, x1 + halfPath, y1)
    --    end
    --    nvgClosePath(nvg_)
    --    nvgFillColor(nvg_, nvgRGBA(35, 40, 55, 255))
    --    nvgFill(nvg_)
    --end
    
    -- 终点标记（橙色火焰图标）
    local endPoint = path[#path]
    DrawEndpointMarker(endPoint.x, endPoint.y)
end

-- 绘制终点标记（橙色火焰）
function DrawEndpointMarker(x, y)
    -- 火焰外发光
    local glowGrad = nvgRadialGradient(nvg_, x, y - 10, 0, 30,
        nvgRGBA(255, 180, 50, 80),
        nvgRGBA(255, 100, 0, 0))
    nvgBeginPath(nvg_)
    nvgCircle(nvg_, x, y - 10, 30)
    nvgFillPaint(nvg_, glowGrad)
    nvgFill(nvg_)
    
    -- 火焰主体
    nvgBeginPath(nvg_)
    nvgMoveTo(nvg_, x, y - 35)  -- 顶点
    nvgBezierTo(nvg_, x + 8, y - 25, x + 15, y - 15, x + 12, y - 5)
    nvgBezierTo(nvg_, x + 10, y + 5, x + 5, y + 10, x, y + 8)
    nvgBezierTo(nvg_, x - 5, y + 10, x - 10, y + 5, x - 12, y - 5)
    nvgBezierTo(nvg_, x - 15, y - 15, x - 8, y - 25, x, y - 35)
    nvgClosePath(nvg_)
    
    -- 火焰渐变（橙色到黄色）
    local flameGrad = nvgLinearGradient(nvg_, x, y + 10, x, y - 35,
        nvgRGBA(255, 100, 0, 255),
        nvgRGBA(255, 220, 50, 255))
    nvgFillPaint(nvg_, flameGrad)
    nvgFill(nvg_)
    
    -- 火焰内核（亮黄色）
    nvgBeginPath(nvg_)
    nvgMoveTo(nvg_, x, y - 20)
    nvgBezierTo(nvg_, x + 4, y - 12, x + 6, y - 5, x + 4, y)
    nvgBezierTo(nvg_, x + 2, y + 3, x, y + 5, x, y + 5)
    nvgBezierTo(nvg_, x, y + 5, x - 2, y + 3, x - 4, y)
    nvgBezierTo(nvg_, x - 6, y - 5, x - 4, y - 12, x, y - 20)
    nvgClosePath(nvg_)
    nvgFillColor(nvg_, nvgRGBA(255, 250, 180, 255))
    nvgFill(nvg_)
end

function DrawTowerSpots(spots)
    for _, spot in ipairs(spots) do
        if not spot.tower then
            local radius = CONFIG.GridSize / 2 - 5  -- 圆形半径
            DrawCylinderHole(nvg_, spot.x, spot.y, radius)
        end
    end
end


-- 绘制凹陷的圆柱形洞
-- cx, cy: 圆心位置
-- radius: 圆的半径
function DrawCylinderHole(ctx, cx, cy, radius)
    -- 颜色定义 - 参考原图
    local darkColor = nvgRGBA(12, 130, 129, 255)      -- 深色阴影（凹陷侧壁）
    local brightColor = nvgRGBA(45, 190, 180, 255)  -- 亮色青绿（圆柱底部）

    -- 先画整个圆形底色（深色阴影）
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, radius)
    nvgFillColor(ctx, darkColor)
    nvgFill(ctx)

    -- 画下半部分的亮色（圆柱底部）
    -- 关键：用椭圆弧作为上边界，形成月牙形的阴影
    local edgeOffsetY = radius * 0.2  -- 弧线两端往下偏移（正值往下，调这个让整体下移）
    local arcRadiusY = radius * 0.7   -- 椭圆弧的垂直半径（弯曲程度）

    -- 计算弧线两端在圆上的位置
    local edgeAngle = math.asin(edgeOffsetY / radius)  -- 根据Y偏移计算角度
    local edgeX = radius * math.cos(edgeAngle)         -- 对应的X坐标

    nvgBeginPath(ctx)
    -- 从左边开始（往下偏移后的位置）
    nvgMoveTo(ctx, cx - edgeX, cy + edgeOffsetY)
    -- 画外圆的下半弧（从左到右，角度调整）
    nvgArc(ctx, cx, cy, radius, math.pi - edgeAngle, edgeAngle, 1)
    -- 画椭圆弧作为顶部边界（从右到左）
    nvgBezierTo(ctx,
        cx + edgeX * 0.55, cy + edgeOffsetY - arcRadiusY,
        cx - edgeX * 0.55, cy + edgeOffsetY - arcRadiusY,
        cx - edgeX, cy + edgeOffsetY
    )
    nvgClosePath(ctx)
    nvgFillColor(ctx, brightColor)
    nvgFill(ctx)
end


function DrawTowers()
    for _, tower in ipairs(towers_) do
        local config = TowerTypes[tower.type]
        local mult = UpgradeMultipliers[tower.level]
        local size = 16 + tower.level * 4
        local color = config.color
        local range = config.range * mult.range
        
        -- 减速塔始终显示范围（淡色）
        if tower.type == "slow" then
            -- 范围底色
            local rangeGrad = nvgRadialGradient(nvg_, tower.x, tower.y, 0, range,
                nvgRGBA(150, 220, 255, 20),
                nvgRGBA(150, 220, 255, 5))
            nvgBeginPath(nvg_)
            nvgCircle(nvg_, tower.x, tower.y, range)
            nvgFillPaint(nvg_, rangeGrad)
            nvgFill(nvg_)
            
            -- 范围边框
            nvgBeginPath(nvg_)
            nvgCircle(nvg_, tower.x, tower.y, range)
            nvgStrokeColor(nvg_, nvgRGBA(150, 220, 255, 40))
            nvgStrokeWidth(nvg_, 2)
            nvgStroke(nvg_)
            
            -- 脉冲动画
            if tower.pulseTimer and tower.pulseTimer > 0 then
                local pulseRatio = tower.pulseTimer / 0.3
                nvgBeginPath(nvg_)
                nvgCircle(nvg_, tower.x, tower.y, range * (1 - pulseRatio * 0.2))
                nvgStrokeColor(nvg_, nvgRGBA(150, 220, 255, 150 * pulseRatio))
                nvgStrokeWidth(nvg_, 4 * pulseRatio)
                nvgStroke(nvg_)
            end
        end
        
        -- 攻击范围（选中时显示）
        if selectedTowerSpot_ and selectedTowerSpot_.tower == tower then
            nvgBeginPath(nvg_)
            nvgCircle(nvg_, tower.x, tower.y, range)
            nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 30))
            nvgFill(nvg_)
            nvgStrokeColor(nvg_, nvgRGBA(255, 255, 255, 80))
            nvgStrokeWidth(nvg_, 2)
            nvgStroke(nvg_)
        end
        
        -- 获取攻击动画偏移和缩放
        local recoilX = tower.recoilX or 0
        local recoilY = tower.recoilY or 0
        local scaleAnim = tower.scaleAnim or 1.0
        
        -- 应用动画后的绘制位置
        local drawX = tower.x + recoilX
        local drawY = tower.y + recoilY
        local drawSize = size * scaleAnim
        
        -- 塔阴影（在塔下方偏移绘制，不受后坐力影响）
        local shadowOffsetY = size * 0.9
        local shadowSize = size + 12
        nvgBeginPath(nvg_)
        nvgEllipse(nvg_, tower.x, tower.y + shadowOffsetY, shadowSize, shadowSize * 0.5)
        nvgFillColor(nvg_, nvgRGBA(0, 0, 0, 80))
        nvgFill(nvg_)
        
        -- 塔底座（应用动画偏移和缩放，不旋转）
        nvgBeginPath(nvg_)
        nvgCircle(nvg_, drawX, drawY, (size + 8) * scaleAnim)
        nvgFillColor(nvg_, nvgRGBA(60, 60, 60, 200))
        nvgFill(nvg_)
        
        -- 激光塔需要旋转绘制（激光本身在 DrawLasers 中绘制，在敌人之后）
        if config.projectileType == "laser" then
            nvgSave(nvg_)
            nvgTranslate(nvg_, drawX, drawY)
            nvgRotate(nvg_, tower.rotation or 0)
            -- 塔形状（在原点绘制，已经平移过了）
            DrawShape(config.shape, 0, 0, drawSize, color, tower.level)
            nvgRestore(nvg_)
        else
            -- 其他塔形状（应用动画偏移和缩放）
            DrawShape(config.shape, drawX, drawY, drawSize, color, tower.level)
        end
        
        -- 等级指示（不受动画影响，固定在原位）
        if tower.level > 1 then
            nvgFontFace(nvg_, "sans")
            nvgFontSize(nvg_, 18)
            nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
            nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgText(nvg_, tower.x, tower.y + size + 18, "Lv" .. tower.level, nil)
        end
    end
end

-- 绘制激光（单独绘制，确保在敌人之上）
function DrawLasers()
    for _, tower in ipairs(towers_) do
        local config = TowerTypes[tower.type]
        
        if config.projectileType == "laser" and tower.target then
            local recoilX = tower.recoilX or 0
            local recoilY = tower.recoilY or 0
            local drawX = tower.x + recoilX
            local drawY = tower.y + recoilY
            
            -- 激光光晕（先绘制，在下层）
            nvgBeginPath(nvg_)
            nvgMoveTo(nvg_, drawX, drawY)
            nvgLineTo(nvg_, tower.target.x, tower.target.y)
            nvgStrokeColor(nvg_, nvgRGBA(255, 150, 150, 100))
            nvgStrokeWidth(nvg_, 12)
            nvgStroke(nvg_)
            
            -- 激光主体
            nvgBeginPath(nvg_)
            nvgMoveTo(nvg_, drawX, drawY)
            nvgLineTo(nvg_, tower.target.x, tower.target.y)
            nvgStrokeColor(nvg_, nvgRGBA(255, 50, 50, 200))
            nvgStrokeWidth(nvg_, 5)
            nvgStroke(nvg_)
        end
    end
end

function DrawShape(shape, x, y, size, color, level)
    -- 颜色随等级加深
    local r = math.min(255, color[1] + (level - 1) * 20)
    local g = math.min(255, color[2] + (level - 1) * 20)
    local b = math.min(255, color[3] + (level - 1) * 20)
    
    nvgBeginPath(nvg_)
    
    if shape == "circle" then
        nvgCircle(nvg_, x, y, size)
    elseif shape == "triangle" then
        nvgMoveTo(nvg_, x, y - size)
        nvgLineTo(nvg_, x + size * 0.866, y + size * 0.5)
        nvgLineTo(nvg_, x - size * 0.866, y + size * 0.5)
        nvgClosePath(nvg_)
    elseif shape == "square" then
        nvgRect(nvg_, x - size * 0.7, y - size * 0.7, size * 1.4, size * 1.4)
    elseif shape == "diamond" then
        nvgMoveTo(nvg_, x, y - size)
        nvgLineTo(nvg_, x + size, y)
        nvgLineTo(nvg_, x, y + size)
        nvgLineTo(nvg_, x - size, y)
        nvgClosePath(nvg_)
    elseif shape == "hexagon" then
        for i = 0, 5 do
            local angle = (i / 6) * math.pi * 2 - math.pi / 2
            local px = x + math.cos(angle) * size
            local py = y + math.sin(angle) * size
            if i == 0 then
                nvgMoveTo(nvg_, px, py)
            else
                nvgLineTo(nvg_, px, py)
            end
        end
        nvgClosePath(nvg_)
    end
    
    nvgFillColor(nvg_, nvgRGBA(r, g, b, 255))
    nvgFill(nvg_)
    
    nvgStrokeColor(nvg_, nvgRGBA(255, 255, 255, 150))
    nvgStrokeWidth(nvg_, 2)
    nvgStroke(nvg_)
end

-- 在原点绘制形状（用于已旋转的敌人）
function DrawShapeRotated(shape, size, color, level, healthRatio)
    healthRatio = healthRatio or 1.0
    
    -- 颜色
    local r = math.min(255, color[1])
    local g = math.min(255, color[2])
    local b = math.min(255, color[3])
    
    -- 内部填充大小随血量缩小
    local innerSize = size * healthRatio
    
    -- 先绘制深色背景（表示损失的生命）
    nvgBeginPath(nvg_)
    if shape == "circle" then
        nvgCircle(nvg_, 0, 0, size)
    elseif shape == "triangle" then
        nvgMoveTo(nvg_, size, 0)
        nvgLineTo(nvg_, -size * 0.5, size * 0.866)
        nvgLineTo(nvg_, -size * 0.5, -size * 0.866)
        nvgClosePath(nvg_)
    elseif shape == "square" then
        nvgRect(nvg_, -size * 0.7, -size * 0.7, size * 1.4, size * 1.4)
    elseif shape == "diamond" then
        nvgMoveTo(nvg_, size, 0)
        nvgLineTo(nvg_, 0, size)
        nvgLineTo(nvg_, -size, 0)
        nvgLineTo(nvg_, 0, -size)
        nvgClosePath(nvg_)
    elseif shape == "hexagon" then
        for i = 0, 5 do
            local angle = (i / 6) * math.pi * 2
            local px = math.cos(angle) * size
            local py = math.sin(angle) * size
            if i == 0 then
                nvgMoveTo(nvg_, px, py)
            else
                nvgLineTo(nvg_, px, py)
            end
        end
        nvgClosePath(nvg_)
    end
    nvgFillColor(nvg_, nvgRGBA(30, 30, 30, 255))
    nvgFill(nvg_)
    
    -- 绘制内部颜色填充（大小随血量缩小）
    if innerSize > 0.5 then
        nvgBeginPath(nvg_)
        if shape == "circle" then
            nvgCircle(nvg_, 0, 0, innerSize)
        elseif shape == "triangle" then
            nvgMoveTo(nvg_, innerSize, 0)
            nvgLineTo(nvg_, -innerSize * 0.5, innerSize * 0.866)
            nvgLineTo(nvg_, -innerSize * 0.5, -innerSize * 0.866)
            nvgClosePath(nvg_)
        elseif shape == "square" then
            nvgRect(nvg_, -innerSize * 0.7, -innerSize * 0.7, innerSize * 1.4, innerSize * 1.4)
        elseif shape == "diamond" then
            nvgMoveTo(nvg_, innerSize, 0)
            nvgLineTo(nvg_, 0, innerSize)
            nvgLineTo(nvg_, -innerSize, 0)
            nvgLineTo(nvg_, 0, -innerSize)
            nvgClosePath(nvg_)
        elseif shape == "hexagon" then
            for i = 0, 5 do
                local angle = (i / 6) * math.pi * 2
                local px = math.cos(angle) * innerSize
                local py = math.sin(angle) * innerSize
                if i == 0 then
                    nvgMoveTo(nvg_, px, py)
                else
                    nvgLineTo(nvg_, px, py)
                end
            end
            nvgClosePath(nvg_)
        end
        nvgFillColor(nvg_, nvgRGBA(r, g, b, 255))
        nvgFill(nvg_)
    end
    
    -- 最后绘制纯白色描边（外圈）
    nvgBeginPath(nvg_)
    if shape == "circle" then
        nvgCircle(nvg_, 0, 0, size)
    elseif shape == "triangle" then
        nvgMoveTo(nvg_, size, 0)
        nvgLineTo(nvg_, -size * 0.5, size * 0.866)
        nvgLineTo(nvg_, -size * 0.5, -size * 0.866)
        nvgClosePath(nvg_)
    elseif shape == "square" then
        nvgRect(nvg_, -size * 0.7, -size * 0.7, size * 1.4, size * 1.4)
    elseif shape == "diamond" then
        nvgMoveTo(nvg_, size, 0)
        nvgLineTo(nvg_, 0, size)
        nvgLineTo(nvg_, -size, 0)
        nvgLineTo(nvg_, 0, -size)
        nvgClosePath(nvg_)
    elseif shape == "hexagon" then
        for i = 0, 5 do
            local angle = (i / 6) * math.pi * 2
            local px = math.cos(angle) * size
            local py = math.sin(angle) * size
            if i == 0 then
                nvgMoveTo(nvg_, px, py)
            else
                nvgLineTo(nvg_, px, py)
            end
        end
        nvgClosePath(nvg_)
    end
    nvgStrokeColor(nvg_, nvgRGBA(255, 255, 255, 255))
    nvgStrokeWidth(nvg_, 3)
    nvgStroke(nvg_)
end

-- 在原点绘制战车（用于已旋转的敌人）
function DrawChariotRotated(size, color, healthRatio)
    healthRatio = healthRatio or 1.0
    
    -- 内部填充大小随血量缩小
    local innerSize = size * healthRatio
    
    -- 外圈深色背景
    nvgBeginPath(nvg_)
    nvgCircle(nvg_, 0, 0, size)
    nvgFillColor(nvg_, nvgRGBA(30, 30, 30, 255))
    nvgFill(nvg_)
    
    -- 内圈颜色填充（大小随血量缩小）
    if innerSize > 0.5 then
        nvgBeginPath(nvg_)
        nvgCircle(nvg_, 0, 0, innerSize)
        nvgFillColor(nvg_, nvgRGBA(color[1], color[2], color[3], 255))
        nvgFill(nvg_)
    end
    
    -- 外圈纯白色描边
    nvgBeginPath(nvg_)
    nvgCircle(nvg_, 0, 0, size)
    nvgStrokeColor(nvg_, nvgRGBA(255, 255, 255, 255))
    nvgStrokeWidth(nvg_, 4)
    nvgStroke(nvg_)
    
    -- 中心圆点
    nvgBeginPath(nvg_)
    nvgCircle(nvg_, 0, 0, size * 0.12)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 200))
    nvgFill(nvg_)
    
    -- 前进方向指示（小箭头）
    nvgBeginPath(nvg_)
    nvgMoveTo(nvg_, size * 0.5, 0)
    nvgLineTo(nvg_, size * 0.25, -size * 0.2)
    nvgLineTo(nvg_, size * 0.25, size * 0.2)
    nvgClosePath(nvg_)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
    nvgFill(nvg_)
end

function DrawEnemies()
    for _, enemy in ipairs(enemies_) do
        local config = EnemyTypes[enemy.type]
        local color = config.color
        local size = config.size
        local healthRatio = enemy.health / enemy.maxHealth
        
        -- 应用受击弹簧偏移
        local drawX = enemy.x + (enemy.hitRecoilOffsetX or 0)
        local drawY = enemy.y + (enemy.hitRecoilOffsetY or 0)
        local rotation = enemy.rotation or 0
        
        -- 受击闪烁效果（受击时变亮）
        local drawColor = color
        if enemy.hitRecoilTimer and enemy.hitRecoilTimer > 0 then
            local flashRatio = enemy.hitRecoilTimer / 0.35
            drawColor = {
                math.min(255, color[1] + 80 * flashRatio),
                math.min(255, color[2] + 80 * flashRatio),
                math.min(255, color[3] + 80 * flashRatio),
            }
        end
        
        -- 减速效果（不旋转）
        if enemy.slowTimer > 0 then
            nvgBeginPath(nvg_)
            nvgCircle(nvg_, drawX, drawY, size + 8)
            nvgFillColor(nvg_, nvgRGBA(150, 200, 255, 60))
            nvgFill(nvg_)
            nvgStrokeColor(nvg_, nvgRGBA(150, 200, 255, 120))
            nvgStrokeWidth(nvg_, 2)
            nvgStroke(nvg_)
        end
        
        -- 保存状态，应用旋转
        nvgSave(nvg_)
        nvgTranslate(nvg_, drawX, drawY)
        nvgRotate(nvg_, rotation)
        
        -- 敌人形状（在原点绘制，传入血量比例）
        if config.shape == "chariot" then
            -- 战车特殊绘制
            DrawChariotRotated(size, drawColor, healthRatio)
        else
            DrawShapeRotated(config.shape, size, drawColor, 1, healthRatio)
        end
        
        -- 恢复状态
        nvgRestore(nvg_)
    end
end

-- 绘制战车（大圆内含8个小圆）
function DrawChariot(x, y, size, color)
    -- 外圈大圆（底色）
    nvgBeginPath(nvg_)
    nvgCircle(nvg_, x, y, size)
    nvgFillColor(nvg_, nvgRGBA(color[1] - 50, color[2] - 50, color[3] - 50, 255))
    nvgFill(nvg_)
    
    -- 外圈边框
    nvgBeginPath(nvg_)
    nvgCircle(nvg_, x, y, size)
    nvgStrokeColor(nvg_, nvgRGBA(color[1], color[2], color[3], 255))
    nvgStrokeWidth(nvg_, 4)
    nvgStroke(nvg_)
    
    -- 内部8个小圆（代表载着的敌人）
    local innerRadius = size * 0.6
    local smallSize = size * 0.22
    local normalColor = EnemyTypes.normal.color
    
    for i = 1, 8 do
        local angle = (i - 1) * (2 * math.pi / 8) - math.pi / 2
        local cx = x + math.cos(angle) * innerRadius
        local cy = y + math.sin(angle) * innerRadius
        
        -- 小圆填充
        nvgBeginPath(nvg_)
        nvgCircle(nvg_, cx, cy, smallSize)
        nvgFillColor(nvg_, nvgRGBA(normalColor[1], normalColor[2], normalColor[3], 255))
        nvgFill(nvg_)
        
        -- 小圆边框
        nvgBeginPath(nvg_)
        nvgCircle(nvg_, cx, cy, smallSize)
        nvgStrokeColor(nvg_, nvgRGBA(normalColor[1] - 30, normalColor[2] - 30, normalColor[3] - 30, 255))
        nvgStrokeWidth(nvg_, 2)
        nvgStroke(nvg_)
    end
    
    -- 中心标识
    nvgBeginPath(nvg_)
    nvgCircle(nvg_, x, y, smallSize * 0.8)
    nvgFillColor(nvg_, nvgRGBA(color[1], color[2], color[3], 255))
    nvgFill(nvg_)
end

function DrawProjectiles()
    for _, proj in ipairs(projectiles_) do
        local size = 10
        local color = {255, 255, 100}
        
        if proj.type == "arrow" then
            -- 箭塔投射物：锥形带拖尾效果
            color = {200, 200, 255}
            
            -- 计算飞行方向
            local target = proj.targetEnemy
            if target then
                local dx = target.x - proj.x
                local dy = target.y - proj.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist > 0 then
                    local dirX = dx / dist
                    local dirY = dy / dist
                    local angle = math.atan2(dy, dx)
                    
                    -- 锥形参数
                    local tipLength = 18    -- 尖端长度
                    local tailLength = 35   -- 拖尾长度
                    local tailWidth = 12    -- 拖尾宽度
                    
                    -- 计算锥形顶点（尖端）
                    local tipX = proj.x + dirX * tipLength
                    local tipY = proj.y + dirY * tipLength
                    
                    -- 计算拖尾末端中心
                    local tailX = proj.x - dirX * tailLength
                    local tailY = proj.y - dirY * tailLength
                    
                    -- 计算拖尾两侧点（垂直于飞行方向）
                    local perpX = -dirY
                    local perpY = dirX
                    local tail1X = proj.x + perpX * tailWidth * 0.5
                    local tail1Y = proj.y + perpY * tailWidth * 0.5
                    local tail2X = proj.x - perpX * tailWidth * 0.5
                    local tail2Y = proj.y - perpY * tailWidth * 0.5
                    
                    -- 绘制拖尾（渐变三角形）
                    nvgBeginPath(nvg_)
                    nvgMoveTo(nvg_, tail1X, tail1Y)
                    nvgLineTo(nvg_, tail2X, tail2Y)
                    nvgLineTo(nvg_, tailX, tailY)
                    nvgClosePath(nvg_)
                    nvgFillColor(nvg_, nvgRGBA(color[1], color[2], color[3], 60))
                    nvgFill(nvg_)
                    
                    -- 绘制中间拖尾（更亮）
                    local midTailX = proj.x - dirX * tailLength * 0.6
                    local midTailY = proj.y - dirY * tailLength * 0.6
                    nvgBeginPath(nvg_)
                    nvgMoveTo(nvg_, tail1X, tail1Y)
                    nvgLineTo(nvg_, tail2X, tail2Y)
                    nvgLineTo(nvg_, midTailX, midTailY)
                    nvgClosePath(nvg_)
                    nvgFillColor(nvg_, nvgRGBA(color[1], color[2], color[3], 120))
                    nvgFill(nvg_)
                    
                    -- 绘制箭头主体（锥形）
                    nvgBeginPath(nvg_)
                    nvgMoveTo(nvg_, tipX, tipY)
                    nvgLineTo(nvg_, tail1X, tail1Y)
                    nvgLineTo(nvg_, tail2X, tail2Y)
                    nvgClosePath(nvg_)
                    nvgFillColor(nvg_, nvgRGBA(color[1], color[2], color[3], 255))
                    nvgFill(nvg_)
                    
                    -- 高亮尖端
                    nvgBeginPath(nvg_)
                    nvgCircle(nvg_, tipX, tipY, 4)
                    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
                    nvgFill(nvg_)
                end
            end
        elseif proj.type == "cannonball" then
            color = {100, 100, 100}
            size = 12
            
            nvgBeginPath(nvg_)
            nvgCircle(nvg_, proj.x, proj.y, size)
            nvgFillColor(nvg_, nvgRGBA(color[1], color[2], color[3], 255))
            nvgFill(nvg_)
            
            -- 光晕
            nvgBeginPath(nvg_)
            nvgCircle(nvg_, proj.x, proj.y, size + 5)
            nvgFillColor(nvg_, nvgRGBA(color[1], color[2], color[3], 80))
            nvgFill(nvg_)
        elseif proj.type == "ice" then
            color = {150, 220, 255}
            size = 10
            
            nvgBeginPath(nvg_)
            nvgCircle(nvg_, proj.x, proj.y, size)
            nvgFillColor(nvg_, nvgRGBA(color[1], color[2], color[3], 255))
            nvgFill(nvg_)
            
            -- 光晕
            nvgBeginPath(nvg_)
            nvgCircle(nvg_, proj.x, proj.y, size + 5)
            nvgFillColor(nvg_, nvgRGBA(color[1], color[2], color[3], 80))
            nvgFill(nvg_)
        else
            -- 默认投射物
            nvgBeginPath(nvg_)
            nvgCircle(nvg_, proj.x, proj.y, size)
            nvgFillColor(nvg_, nvgRGBA(color[1], color[2], color[3], 255))
            nvgFill(nvg_)
            
            -- 光晕
            nvgBeginPath(nvg_)
            nvgCircle(nvg_, proj.x, proj.y, size + 5)
            nvgFillColor(nvg_, nvgRGBA(color[1], color[2], color[3], 80))
            nvgFill(nvg_)
        end
    end
end

function DrawParticles()
    for _, p in ipairs(particles_) do
        local alpha = (p.life / p.maxLife) * 255
        local lifeRatio = p.life / p.maxLife
        local ptype = p.type or "circle"
        
        if ptype == "circle" then
            -- 普通圆形粒子
            nvgBeginPath(nvg_)
            nvgCircle(nvg_, p.x, p.y, p.size * lifeRatio)
            nvgFillColor(nvg_, nvgRGBA(p.color[1], p.color[2], p.color[3], alpha))
            nvgFill(nvg_)
            
        elseif ptype == "spark" then
            -- 火花粒子（带光晕）
            nvgBeginPath(nvg_)
            nvgCircle(nvg_, p.x, p.y, p.size * lifeRatio)
            nvgFillColor(nvg_, nvgRGBA(p.color[1], p.color[2], p.color[3], alpha))
            nvgFill(nvg_)
            -- 光晕
            nvgBeginPath(nvg_)
            nvgCircle(nvg_, p.x, p.y, p.size * lifeRatio * 2)
            nvgFillColor(nvg_, nvgRGBA(p.color[1], p.color[2], p.color[3], alpha * 0.3))
            nvgFill(nvg_)
            
        elseif ptype == "shockwave" then
            -- 冲击波（扩展的圆环）
            local expandSize = p.size * (1 - lifeRatio) * 2
            nvgBeginPath(nvg_)
            nvgCircle(nvg_, p.x, p.y, expandSize)
            nvgStrokeColor(nvg_, nvgRGBA(p.color[1], p.color[2], p.color[3], alpha * 0.8))
            nvgStrokeWidth(nvg_, 4 * lifeRatio)
            nvgStroke(nvg_)
            
        elseif ptype == "smoke" then
            -- 烟雾（渐变变大）
            local smokeSize = p.size * (1 + (1 - lifeRatio) * 0.5)
            nvgBeginPath(nvg_)
            nvgCircle(nvg_, p.x, p.y, smokeSize)
            nvgFillColor(nvg_, nvgRGBA(p.color[1], p.color[2], p.color[3], alpha * 0.5))
            nvgFill(nvg_)
            
        elseif ptype == "flash" then
            -- 闪光（快速消失的亮光）
            local flashGrad = nvgRadialGradient(nvg_, p.x, p.y, 0, p.size * lifeRatio,
                nvgRGBA(p.color[1], p.color[2], p.color[3], alpha),
                nvgRGBA(p.color[1], p.color[2], p.color[3], 0))
            nvgBeginPath(nvg_)
            nvgCircle(nvg_, p.x, p.y, p.size * lifeRatio)
            nvgFillPaint(nvg_, flashGrad)
            nvgFill(nvg_)
            
        elseif ptype == "trail" then
            -- 轨迹粒子
            nvgBeginPath(nvg_)
            nvgCircle(nvg_, p.x, p.y, p.size * lifeRatio)
            nvgFillColor(nvg_, nvgRGBA(p.color[1], p.color[2], p.color[3], alpha * 0.7))
            nvgFill(nvg_)
            
        elseif ptype == "beam" then
            -- 光柱效果
            nvgBeginPath(nvg_)
            nvgRect(nvg_, p.x - 5, p.y - 100 * lifeRatio, 10, 100 * lifeRatio)
            nvgFillColor(nvg_, nvgRGBA(p.color[1], p.color[2], p.color[3], alpha * 0.6))
            nvgFill(nvg_)
            
        elseif ptype == "text" then
            -- 飘字效果
            nvgFontFace(nvg_, "sans")
            nvgFontSize(nvg_, p.size)
            nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg_, nvgRGBA(p.color[1], p.color[2], p.color[3], alpha))
            nvgText(nvg_, p.x, p.y, p.text or "", nil)
            
        elseif ptype == "snowflake" then
            -- 雪花/冰冻粒子
            nvgBeginPath(nvg_)
            local size = p.size * lifeRatio
            -- 画十字
            nvgMoveTo(nvg_, p.x - size, p.y)
            nvgLineTo(nvg_, p.x + size, p.y)
            nvgMoveTo(nvg_, p.x, p.y - size)
            nvgLineTo(nvg_, p.x, p.y + size)
            -- 画斜线
            nvgMoveTo(nvg_, p.x - size * 0.7, p.y - size * 0.7)
            nvgLineTo(nvg_, p.x + size * 0.7, p.y + size * 0.7)
            nvgMoveTo(nvg_, p.x + size * 0.7, p.y - size * 0.7)
            nvgLineTo(nvg_, p.x - size * 0.7, p.y + size * 0.7)
            nvgStrokeColor(nvg_, nvgRGBA(p.color[1], p.color[2], p.color[3], alpha))
            nvgStrokeWidth(nvg_, 2)
            nvgStroke(nvg_)
            
        elseif ptype == "split_ring" then
            -- 战车分裂光环效果
            local expandRatio = 1 - lifeRatio  -- 从0到1扩展
            local currentSize = p.size * expandRatio
            
            -- 外扩光环
            nvgBeginPath(nvg_)
            nvgCircle(nvg_, p.x, p.y, currentSize)
            nvgStrokeColor(nvg_, nvgRGBA(p.color[1], p.color[2], p.color[3], alpha * 0.9))
            nvgStrokeWidth(nvg_, 6 * lifeRatio)
            nvgStroke(nvg_)
            
            -- 中心闪光
            if lifeRatio > 0.5 then
                local flashAlpha = (lifeRatio - 0.5) * 2 * alpha
                local flashGrad = nvgRadialGradient(nvg_, p.x, p.y, 0, p.size * 0.3,
                    nvgRGBA(255, 255, 200, flashAlpha),
                    nvgRGBA(255, 200, 100, 0))
                nvgBeginPath(nvg_)
                nvgCircle(nvg_, p.x, p.y, p.size * 0.3)
                nvgFillPaint(nvg_, flashGrad)
                nvgFill(nvg_)
            end
            
        elseif ptype == "slow_pulse" then
            -- 减速塔脉冲效果（扩散的冰冻圈）
            local expandRatio = 1 - lifeRatio  -- 从0到1扩展
            local currentSize = p.size * expandRatio
            
            -- 外圈
            nvgBeginPath(nvg_)
            nvgCircle(nvg_, p.x, p.y, currentSize)
            nvgStrokeColor(nvg_, nvgRGBA(p.color[1], p.color[2], p.color[3], alpha * 0.8))
            nvgStrokeWidth(nvg_, 4 * lifeRatio)
            nvgStroke(nvg_)
            
            -- 内部填充（渐变）
            local fillGrad = nvgRadialGradient(nvg_, p.x, p.y, 0, currentSize,
                nvgRGBA(p.color[1], p.color[2], p.color[3], alpha * 0.3),
                nvgRGBA(p.color[1], p.color[2], p.color[3], 0))
            nvgBeginPath(nvg_)
            nvgCircle(nvg_, p.x, p.y, currentSize)
            nvgFillPaint(nvg_, fillGrad)
            nvgFill(nvg_)
        end
    end
end

function DrawTowerMenu(spot)
    local menuX = spot.x + 60
    local menuY = spot.y - 100
    local buttonWidth = 160
    local buttonHeight = 48
    
    if spot.tower then
        -- 已有塔：显示升级/出售
        local tower = spot.tower
        local config = TowerTypes[tower.type]
        
        -- 菜单背景
        nvgBeginPath(nvg_)
        nvgRoundedRect(nvg_, menuX - 10, menuY - 10, buttonWidth + 20, 120, 10)
        nvgFillColor(nvg_, nvgRGBA(30, 30, 30, 230))
        nvgFill(nvg_)
        
        -- 升级按钮
        local canUpgrade = tower.level < 3
        local nextMult = UpgradeMultipliers[tower.level + 1]
        local upgradeCost = 0
        if canUpgrade and nextMult then
            upgradeCost = math.floor(config.cost * nextMult.cost)
        end
        
        nvgBeginPath(nvg_)
        nvgRoundedRect(nvg_, menuX, menuY, buttonWidth, buttonHeight, 8)
        if canUpgrade and playerGold_ >= upgradeCost then
            nvgFillColor(nvg_, nvgRGBA(80, 150, 80, 255))
        else
            nvgFillColor(nvg_, nvgRGBA(80, 80, 80, 255))
        end
        nvgFill(nvg_)
        
        nvgFontFace(nvg_, "sans")
        nvgFontSize(nvg_, 22)
        nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
        nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        if canUpgrade then
            nvgText(nvg_, menuX + buttonWidth / 2, menuY + buttonHeight / 2, "升级 $" .. upgradeCost, nil)
        else
            nvgText(nvg_, menuX + buttonWidth / 2, menuY + buttonHeight / 2, "已满级", nil)
        end
        
        -- 出售按钮（应用技能树加成显示）
        menuY = menuY + 58
        local sellBonus = GetSkillEffect("sell_refund")
        local sellValue = math.floor(tower.totalCost * (CONFIG.SellRefundRate + sellBonus))
        
        nvgBeginPath(nvg_)
        nvgRoundedRect(nvg_, menuX, menuY, buttonWidth, buttonHeight, 8)
        nvgFillColor(nvg_, nvgRGBA(150, 80, 80, 255))
        nvgFill(nvg_)
        
        nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
        nvgText(nvg_, menuX + buttonWidth / 2, menuY + buttonHeight / 2, "出售 +$" .. sellValue, nil)
    else
        -- 空地：显示可建造的塔
        local towerTypes = {"arrow", "cannon", "slow", "laser"}
        local menuHeight = #towerTypes * 58 + 16
        
        -- 菜单背景
        nvgBeginPath(nvg_)
        nvgRoundedRect(nvg_, menuX - 10, menuY - 10, buttonWidth + 20, menuHeight, 10)
        nvgFillColor(nvg_, nvgRGBA(30, 30, 30, 230))
        nvgFill(nvg_)
        
        -- 获取建造费用折扣
        local costDiscount = GetSkillEffect("tower_cost")
        
        for i, ttype in ipairs(towerTypes) do
            local config = TowerTypes[ttype]
            local by = menuY + (i - 1) * 58
            -- 应用技能树加成计算实际价格
            local actualCost = math.floor(config.cost * (1 + costDiscount))
            local canBuy = playerGold_ >= actualCost
            
            nvgBeginPath(nvg_)
            nvgRoundedRect(nvg_, menuX, by, buttonWidth, buttonHeight, 8)
            if canBuy then
                nvgFillColor(nvg_, nvgRGBA(config.color[1], config.color[2], config.color[3], 200))
            else
                nvgFillColor(nvg_, nvgRGBA(60, 60, 60, 200))
            end
            nvgFill(nvg_)
            
            nvgFontFace(nvg_, "sans")
            nvgFontSize(nvg_, 22)
            nvgFillColor(nvg_, nvgRGBA(255, 255, 255, canBuy and 255 or 150))
            nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgText(nvg_, menuX + buttonWidth / 2, by + buttonHeight / 2, config.name .. " $" .. actualCost, nil)
        end
    end
end

function DrawHUD(width, height)
    -- 顶部HUD背景
    nvgBeginPath(nvg_)
    nvgRect(nvg_, 0, 0, width, 60)
    nvgFillColor(nvg_, nvgRGBA(20, 20, 20, 200))
    nvgFill(nvg_)
    
    nvgFontFace(nvg_, "sans")
    nvgFontSize(nvg_, 32)
    nvgTextAlign(nvg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    
    -- 金币
    nvgFillColor(nvg_, nvgRGBA(255, 220, 50, 255))
    nvgText(nvg_, 30, 30, "💰 " .. playerGold_, nil)
    
    -- 生命
    nvgFillColor(nvg_, nvgRGBA(255, 100, 100, 255))
    nvgText(nvg_, 240, 30, "❤️ " .. playerLives_, nil)
    
    -- 波次
    nvgFillColor(nvg_, nvgRGBA(100, 200, 255, 255))
    local level = Levels[selectedLevel_]
    nvgText(nvg_, 450, 30, "🌊 波次 " .. currentWave_ .. "/" .. #level.waves, nil)
    
    -- 敌人数量
    nvgFillColor(nvg_, nvgRGBA(200, 150, 255, 255))
    nvgText(nvg_, 750, 30, "👾 敌人 " .. #enemies_, nil)
    
    -- 关卡名
    nvgTextAlign(nvg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg_, nvgRGBA(200, 200, 200, 255))
    nvgText(nvg_, width - 150, 30, level.name, nil)
    
    -- 退出按钮（右上角）
    local exitBtnWidth = 100
    local exitBtnHeight = 40
    local exitBtnX = width - exitBtnWidth - 20
    local exitBtnY = 10
    
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, exitBtnX, exitBtnY, exitBtnWidth, exitBtnHeight, 8)
    nvgFillColor(nvg_, nvgRGBA(150, 50, 50, 200))
    nvgFill(nvg_)
    
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, exitBtnX, exitBtnY, exitBtnWidth, exitBtnHeight, 8)
    nvgStrokeColor(nvg_, nvgRGBA(200, 80, 80, 255))
    nvgStrokeWidth(nvg_, 2)
    nvgStroke(nvg_)
    
    nvgFontSize(nvg_, 24)
    nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
    nvgText(nvg_, exitBtnX + exitBtnWidth / 2, exitBtnY + exitBtnHeight / 2, "退出", nil)
    
    -- 右下角"下一波"按钮
    DrawNextWaveButton(width, height)
end

-- 绘制下一波按钮
function DrawNextWaveButton(width, height)
    local level = Levels[selectedLevel_]
    local buttonWidth = 180
    local buttonHeight = 60
    local bx = width - buttonWidth - 30
    local by = height - buttonHeight - 30
    
    -- 检查是否可以触发下一波
    local canTrigger = not waveActive_ and currentWave_ < #level.waves
    
    -- 按钮背景
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, bx, by, buttonWidth, buttonHeight, 10)
    
    if canTrigger then
        -- 可点击状态 - 亮色
        local btnGrad = nvgLinearGradient(nvg_, bx, by, bx, by + buttonHeight,
            nvgRGBA(80, 180, 80, 240),
            nvgRGBA(50, 140, 50, 240))
        nvgFillPaint(nvg_, btnGrad)
    else
        -- 不可点击状态 - 暗色
        nvgFillColor(nvg_, nvgRGBA(60, 60, 60, 200))
    end
    nvgFill(nvg_)
    
    -- 按钮边框
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, bx, by, buttonWidth, buttonHeight, 10)
    if canTrigger then
        nvgStrokeColor(nvg_, nvgRGBA(150, 255, 150, 200))
    else
        nvgStrokeColor(nvg_, nvgRGBA(100, 100, 100, 150))
    end
    nvgStrokeWidth(nvg_, 3)
    nvgStroke(nvg_)
    
    -- 按钮文字
    nvgFontFace(nvg_, "sans")
    nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    
    if canTrigger then
        local remaining = math.ceil(waveDelay_ - waveTimer_)
        -- 主文字
        nvgFontSize(nvg_, 24)
        nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
        nvgText(nvg_, bx + buttonWidth / 2, by + buttonHeight / 2 - 10, "下一波 (" .. remaining .. "s)", nil)
        -- 提示文字
        nvgFontSize(nvg_, 16)
        nvgFillColor(nvg_, nvgRGBA(200, 255, 200, 200))
        nvgText(nvg_, bx + buttonWidth / 2, by + buttonHeight / 2 + 14, "点击或按空格", nil)
    elseif waveActive_ then
        nvgFontSize(nvg_, 22)
        nvgFillColor(nvg_, nvgRGBA(180, 180, 180, 200))
        nvgText(nvg_, bx + buttonWidth / 2, by + buttonHeight / 2, "战斗中...", nil)
    else
        nvgFontSize(nvg_, 22)
        nvgFillColor(nvg_, nvgRGBA(150, 150, 150, 200))
        nvgText(nvg_, bx + buttonWidth / 2, by + buttonHeight / 2, "已完成", nil)
    end
end

function DrawEndScreen(width, height, isVictory)
    -- 背景
    nvgBeginPath(nvg_)
    nvgRect(nvg_, 0, 0, width, height)
    if isVictory then
        nvgFillColor(nvg_, nvgRGBA(30, 60, 30, 240))
    else
        nvgFillColor(nvg_, nvgRGBA(60, 30, 30, 240))
    end
    nvgFill(nvg_)
    
    -- 标题
    nvgFontFace(nvg_, "sans")
    nvgFontSize(nvg_, 72)
    nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    
    if isVictory then
        nvgFillColor(nvg_, nvgRGBA(100, 255, 100, 255))
        nvgText(nvg_, width / 2, height / 2 - 140, "🎉 胜利！", nil)
    else
        nvgFillColor(nvg_, nvgRGBA(255, 100, 100, 255))
        nvgText(nvg_, width / 2, height / 2 - 140, "💀 失败", nil)
    end
    
    -- 统计信息
    nvgFontSize(nvg_, 28)
    nvgFillColor(nvg_, nvgRGBA(220, 220, 220, 255))
    nvgText(nvg_, width / 2, height / 2 - 50, "击杀数: " .. totalKills_, nil)
    nvgText(nvg_, width / 2, height / 2, "总金币: " .. totalGoldEarned_, nil)
    nvgText(nvg_, width / 2, height / 2 + 50, "完成波次: " .. currentWave_, nil)
    
    -- 按钮
    local buttonWidth = 220
    local buttonHeight = 60
    local bx = (width - buttonWidth) / 2
    local by = height / 2 + 120
    
    -- 重新开始按钮
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, bx, by, buttonWidth, buttonHeight, 10)
    nvgFillColor(nvg_, nvgRGBA(80, 150, 80, 255))
    nvgFill(nvg_)
    
    nvgFontSize(nvg_, 26)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
    nvgText(nvg_, bx + buttonWidth / 2, by + buttonHeight / 2, "重新开始", nil)
    
    -- 返回菜单按钮
    by = by + 80
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, bx, by, buttonWidth, buttonHeight, 10)
    nvgFillColor(nvg_, nvgRGBA(100, 100, 150, 255))
    nvgFill(nvg_)
    
    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
    nvgText(nvg_, bx + buttonWidth / 2, by + buttonHeight / 2, "返回菜单", nil)
end
