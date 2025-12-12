-- ============================================================================
-- 3D 赛车游戏 (Racing Game)
-- 使用 RaycastVehicle 物理组件实现真实赛车物理
-- ============================================================================

require "LuaScripts/Utilities/Sample"

-- ============================================================================
-- 1. 全局变量声明
-- ============================================================================
---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil
---@type Node
local vehicleNode_ = nil
---@type RaycastVehicle
local vehicle_ = nil
---@type NVGContextWrapper
local nvg_ = nil

-- 游戏配置
local CONFIG = {
    Title = "3D 赛车游戏",
    
    -- 战斗系统开关
    EnableCombatSystem = false,  -- 是否启用敌人、导弹系统
        
    -- 车辆参数
    VehicleMass = 500.0,        -- 车辆质量 (kg)
    FrontEngineForce = 2000.0,  -- 前轮动力
    RearEngineForce = 2700.0,   -- 后轮动力
    BrakeForce = 1000.0,         -- 刹车力度
    MaxSteeringAngle = 0.2,     -- 最大转向角度（弧度）
    SteeringSpeed = 2.0,        -- 转向速度q2w
    
    -- 悬挂参数
    SuspensionStiffness = 500.0,    -- 悬挂刚度
    SuspensionDamping = 25,       -- 悬挂阻尼
    SuspensionCompression = 25,   -- 压缩阻尼
    SuspensionRestLength = 0.4,   -- 悬挂静止长度（米），控制最大压缩行程
    WheelFriction = 2.0,           -- 轮胎摩擦力
    RollInfluence = 0.01,           -- 侧倾影响（降低防止翻车）
    
    -- 翻车保护参数
    MaxRollAngle = 30.0,           -- 最大侧翻角度（度）
    MaxPitchAngle = 40.0,          -- 最大俯仰角度（度）
    AntiRollForce = 300.0,         -- 防翻车修正力
    AntiRollTorque = 200.0,        -- 防翻车扭矩
    
    -- 相机参数
    CameraDistance = 8.0,       -- 相机距离
    CameraHeight = 3.0,         -- 相机高度
    CameraSmoothness = 5.0,     -- 相机平滑度
    
    -- 漂移参数
    DriftMinSpeed = 30.0,         -- 触发漂移的最低速度 (km/h)
    DriftSteeringBoost = 1.5,    -- 漂移时转向增强倍数
    DriftFrictionMultiplier = 0.5,-- 漂移时摩擦力乘数
    DriftRecoverySpeed = 1.5,     -- 漂移结束后摩擦力恢复速度
    DriftForceCompensation = 0.1, -- 漂移力代偿指数 (开方数值)
    
    -- 滑行转弯参数
    CoastTurnSpeedRetain = 0.2,   -- 滑行转弯时的速度保持率 (0-1, 1=完全保持)
    
    -- 前轮摩擦力（基于速度）- 保持较高以确保转向
    FrontBaseFriction = 2.5,      -- 前轮默认摩擦力（静止时）
    FrontMinFriction = 2.5,       -- 前轮最低摩擦力（高速时）
    
    -- 后轮摩擦力（基于速度）- 较低使后轮更容易打滑
    RearBaseFriction = 2,       -- 后轮默认摩擦力（静止时）
    RearMinFriction = 2,        -- 后轮最低摩擦力（高速时）
    
    FrictionDropSpeed = 100.0,    -- 摩擦力降到最低时的速度 (km/h)
	
}


local CarSetting = {
    [1] = {
        Title = '蓝色跑车',
        -- 外观参数
        BodyColor = Color(0.1, 0.2, 0.5, 1.0),   -- 车身颜色（深蓝色）
        BodyScale = Vector3(1, 0.5, 2.5),       -- 车身缩放
        WheelRadius = 0.35,                       -- 轮子半径
        WheelWidth = 0.3,                         -- 轮子宽度
        WheelHeight = -0.15,                      -- 轮子高度（悬挂连接点Y位置）
        
        -- 车辆参数
        VehicleMass = 800.0,        -- 车辆质量 (kg)
        FrontEngineForce = 2500.0,  -- 前轮动力
        RearEngineForce = 5000.0,   -- 后轮动力
        BrakeForce = 500.0,         -- 刹车力度
        MaxSteeringAngle = 0.25,     -- 最大转向角度（弧度）
        SteeringSpeed = 2.0,        -- 转向速度
        
        -- 悬挂参数
        SuspensionStiffness = 50.0,    -- 悬挂刚度
        SuspensionDamping = 150,       -- 悬挂阻尼
        SuspensionCompression = 100,   -- 压缩阻尼
        SuspensionRestLength = 0.05,   -- 悬挂静止长度（米），控制最大压缩行程
        WheelFriction = 2.0,           -- 轮胎摩擦力
        RollInfluence = 0.01,           -- 侧倾影响（降低防止翻车）
        
        -- 翻车保护参数
        MaxRollAngle = 20.0,           -- 最大侧翻角度（度）
        MaxPitchAngle = 20.0,          -- 最大俯仰角度（度）
        AntiRollForce = 100.0,         -- 防翻车修正力
        AntiRollTorque = 100.0,        -- 防翻车扭矩
        
        -- 相机参数
        CameraDistance = 8.0,       -- 相机距离
        CameraHeight = 3.0,         -- 相机高度
        CameraSmoothness = 5.0,     -- 相机平滑度
        
        -- 漂移参数
        DriftMinSpeed = 30.0,         -- 触发漂移的最低速度 (km/h)
        DriftSteeringBoost = 1.5,    -- 漂移时转向增强倍数
        DriftFrictionMultiplier = 0.5,-- 漂移时摩擦力乘数
        DriftRecoverySpeed = 1.5,     -- 漂移结束后摩擦力恢复速度
        DriftForceCompensation = 0.1, -- 漂移力代偿指数 (开方数值)
        
        -- 滑行转弯参数
        CoastTurnSpeedRetain = 0.6,   -- 滑行转弯时的速度保持率 (0-1, 1=完全保持)
        
        -- 前轮摩擦力（基于速度）- 保持较高以确保转向
        FrontBaseFriction = 1.6,      -- 前轮默认摩擦力（静止时）
        FrontMinFriction = 1.6,       -- 前轮最低摩擦力（高速时）
        
        -- 后轮摩擦力（基于速度）- 较低使后轮更容易打滑
        RearBaseFriction = 1.25,       -- 后轮默认摩擦力（静止时）
        RearMinFriction = 1.25,        -- 后轮最低摩擦力（高速时）
        
        FrictionDropSpeed = 100.0,    -- 摩擦力降到最低时的速度 (km/h)
    },
    [2] = {
        Title = '红色越野',
        -- 外观参数
        BodyColor = Color(0.6, 0.1, 0.1, 1.0),   -- 车身颜色（红色）
        BodyScale = Vector3(1.2, 0.65, 2.5),       -- 车身缩放
        WheelRadius = 0.45,                       -- 轮子半径（更大）
        WheelWidth = 0.4,                        -- 轮子宽度
        WheelHeight = -0.2,                        -- 轮子高度（越野车底盘更高）
        
        -- 车辆参数
        VehicleMass = 800.0,        -- 车辆质量 (kg)
        FrontEngineForce = 4000.0,  -- 前轮动力
        RearEngineForce = 3000.0,   -- 后轮动力
        BrakeForce = 500.0,         -- 刹车力度
        MaxSteeringAngle = 0.25,     -- 最大转向角度（弧度）
        SteeringSpeed = 2.0,        -- 转向速度
        
        -- 悬挂参数
        SuspensionStiffness = 50.0,    -- 悬挂刚度
        SuspensionDamping = 150,       -- 悬挂阻尼
        SuspensionCompression = 100,   -- 压缩阻尼
        SuspensionRestLength = 0.05,   -- 悬挂静止长度（米），控制最大压缩行程
        WheelFriction = 2.0,           -- 轮胎摩擦力
        RollInfluence = 0.01,           -- 侧倾影响（降低防止翻车）
        
        -- 翻车保护参数
        MaxRollAngle = 20.0,           -- 最大侧翻角度（度）
        MaxPitchAngle = 20.0,          -- 最大俯仰角度（度）
        AntiRollForce = 100.0,         -- 防翻车修正力
        AntiRollTorque = 100.0,        -- 防翻车扭矩
        
        -- 相机参数
        CameraDistance = 8.0,       -- 相机距离
        CameraHeight = 3.0,         -- 相机高度
        CameraSmoothness = 5.0,     -- 相机平滑度
        
        -- 漂移参数
        DriftMinSpeed = 30.0,         -- 触发漂移的最低速度 (km/h)
        DriftSteeringBoost = 1.5,    -- 漂移时转向增强倍数
        DriftFrictionMultiplier = 0.5,-- 漂移时摩擦力乘数
        DriftRecoverySpeed = 1.5,     -- 漂移结束后摩擦力恢复速度
        DriftForceCompensation = 0.1, -- 漂移力代偿指数 (开方数值)
        
        -- 滑行转弯参数
        CoastTurnSpeedRetain = 0.6,   -- 滑行转弯时的速度保持率 (0-1, 1=完全保持)
        
        -- 前轮摩擦力（基于速度）- 保持较高以确保转向
        FrontBaseFriction = 1.6,      -- 前轮默认摩擦力（静止时）
        FrontMinFriction = 1.6,       -- 前轮最低摩擦力（高速时）
        
        -- 后轮摩擦力（基于速度）- 较低使后轮更容易打滑
        RearBaseFriction = 1.25,       -- 后轮默认摩擦力（静止时）
        RearMinFriction = 1.25,        -- 后轮最低摩擦力（高速时）
        
        FrictionDropSpeed = 100.0,    -- 摩擦力降到最低时的速度 (km/h)
    },
}
for k,v in pairs(CarSetting[1]) do
    CONFIG[k] = v
end

-- ============================================================================
-- 赛道配置表
-- ============================================================================
local TrackConfig = {
    [1] = {
        Name = "椭圆环道",
        Description = "经典椭圆形赛道，适合练习漂移",
        -- 赛道类型: "loop" = 闭环, "point" = 起终点不同
        TrackType = "loop",
        -- 赛道宽度
        Width = 15,
        -- 起点位置（车辆初始位置）- 在第一个控制点附近
        StartPosition = Vector3(0, 2, 40),
        -- 起点朝向（Y轴旋转角度）- 椭圆顺时针方向，第一段朝右后方约100°
        StartRotation = 100,
        -- 控制点生成方式: "ellipse" = 椭圆, "points" = 直接指定点
        PointsType = "ellipse",
        -- 椭圆参数（当 PointsType = "ellipse" 时使用）
        EllipseRadiusX = 60,
        EllipseRadiusZ = 40,
        EllipsePoints = 12,      -- 控制点数量
        SegmentsPerSpan = 8,     -- 每段细分数
        -- 赛道外观
        TrackOptions = {
            barrierHeight = 0.3,
            barrierWidth = 0.8,
            barrierColor = Color(1.0, 0.3, 0.2),
            trackColor = Color(0.18, 0.18, 0.22),
            closedLoop = true,
        },
        -- 装饰物
        TreeCount = 30,
        InnerTreeCount = 10,
        -- 敌人生成配置
        EnemyConfig = {
            MaxEnemies = 8,           -- 最大敌人数量
            SideOffset = 3,           -- 左右随机偏移范围（米，道路中间）
        },
    },
    [2] = {
        Name = "8字赛道",
        Description = "8字形赛道，考验转向技术",
        TrackType = "loop",
        Width = 14,
        -- 起点在第一个控制点 (0, 0, 50)
        StartPosition = Vector3(0, 0, 0),
        -- 方向：从(0,50)到(30,35)，dirX=30, dirZ=-15, atan2(30,-15)≈117°
        StartRotation = 45,
        PointsType = "points",
        -- 直接指定控制点（当 PointsType = "points" 时使用）
        ControlPoints = {
            Vector3(0, 0, 0),
            Vector3(35, 0, 15),
            Vector3(50, 0, 50),
            Vector3(35, 0, 85),
            Vector3(0, 0, 100),
            Vector3(-35, 0, 115),
            Vector3(-50, 0, 150),
            Vector3(-35, 0, 185),
            Vector3(0, 0, 200),
            Vector3(35, 0, 185),
            Vector3(50, 0, 150),
            Vector3(35, 3, 115),
            Vector3(0, 4, 100),
            Vector3(-35, 4, 85),
            Vector3(-50, 3, 50),
            Vector3(-35, 4, 15),
        },
        SegmentsPerSpan = 10,
        TrackOptions = {
            barrierHeight = 1,
            barrierWidth = 0.6,
            barrierColor = Color(0.2, 0.5, 1.0),
            trackColor = Color(0.15, 0.15, 0.2),
            closedLoop = true,
        },
        TreeCount = 25,
        InnerTreeCount = 0,
        -- 敌人生成配置
        EnemyConfig = {
            MaxEnemies = 10,          -- 最大敌人数量
            SideOffset = 4,           -- 左右随机偏移范围（米）
        },
    },
    [3] = {
        Name = "高架路赛道",
        Description = "S形连续弯道，挑战极限操控",
        TrackType = "loop",
        Width = 12,
        -- 起点在第一个控制点 (-80, 0, 0)
        StartPosition = Vector3(0, 0, 0),
        -- 方向：从(-80,0)到(-60,30)，dirX=20, dirZ=30, atan2(20,30)≈34°
        StartRotation = 90,
        PointsType = "points",
        ControlPoints = {
            Vector3(0, 0, 0),
            Vector3(5, 0, 0),
            Vector3(30, 2, 30),
            Vector3(0, 4, 60),
            Vector3(-30, 6, 30),
            Vector3(0, 8, 0),
            Vector3(30, 10, 30),
            Vector3(0, 12, 60),
            Vector3(-30, 14, 30),
            Vector3(0, 16, 0),
            Vector3(25, 18, 0),
            Vector3(60, 10, 0),
            Vector3(70, 10, -15),
            Vector3(60, 10, -30),
            Vector3(0, 0, -30),
            Vector3(-15, 0, -20),
            Vector3(0, 0, 0),
            --Vector3(-5, 0, 0),
            --Vector3(-1, 0, 0),
        },
        SegmentsPerSpan = 10,
        TrackOptions = {
            barrierHeight = 0.7,
            barrierWidth = 0.5,
            barrierColor = Color(1.0, 0.8, 0.2),
            trackColor = Color(0.2, 0.18, 0.15),
            closedLoop = true,
        },
        TreeCount = 40,
        InnerTreeCount = 15,
        -- 敌人生成配置
        EnemyConfig = {
            MaxEnemies = 12,          -- 最大敌人数量
            SideOffset = 2,           -- 窄道偏移小
        },
    },
    [4] = {
        Name = "平地测试",
        Description = "平地测试",
        TrackType = "loop",
        Width = 12,
        -- 起点在第一个控制点 (-80, 0, 0)
        StartPosition = Vector3(0, 0, 0),
        -- 方向：从(-80,0)到(-60,30)，dirX=20, dirZ=30, atan2(20,30)≈34°
        StartRotation = 90,
        PointsType = "points",
        ControlPoints = {
            Vector3(0, 0, 0),
            Vector3(50, 0, 0),
            Vector3(70, 0, 20),
            Vector3(50, 0, 40),
            Vector3(-50, 0, 40),
            Vector3(-70, 0, 20),
            Vector3(-50, 0, 0),
            Vector3(0, 0, 0),
        },
        SegmentsPerSpan = 10,
        TrackOptions = {
            barrierHeight = 0.1,
            barrierWidth = 0.5,
            barrierColor = Color(1.0, 0.8, 0.2),
            trackColor = Color(0.2, 0.18, 0.15),
            closedLoop = true,
        },
        TreeCount = 40,
        InnerTreeCount = 15,
        -- 敌人生成配置
        EnemyConfig = {
            MaxEnemies = 6,
            SideOffset = 3,
        },
    },
    [5] = {
        Name = "上下坡",
        Description = "上下坡",
        TrackType = "loop",
        Width = 12,
        -- 起点在第一个控制点 (-80, 0, 0)
        StartPosition = Vector3(0, 0, 0),
        -- 方向：从(-80,0)到(-60,30)，dirX=20, dirZ=30, atan2(20,30)≈34°
        StartRotation = 90,
        PointsType = "points",
        ControlPoints = {
            Vector3(0, 0, 0),
            Vector3(50, 10, 0),
            Vector3(100, 0, 0),
            Vector3(100, 0, 20),
            Vector3(0, 0, 20),
            Vector3(0, 0, 0),
        },
        SegmentsPerSpan = 10,
        TrackOptions = {
            barrierHeight = 0.07,
            barrierWidth = 0.5,
            barrierColor = Color(1.0, 0.8, 0.2),
            trackColor = Color(0.2, 0.18, 0.15),
            closedLoop = true,
        },
        TreeCount = 40,
        InnerTreeCount = 15,
        -- 敌人生成配置
        EnemyConfig = {
            MaxEnemies = 8,
            SideOffset = 3,
        },
    },
    [6] = {
        Name = "测试",
        Description = "测试",
        TrackType = "loop",
        Width = 12,
        -- 起点在第一个控制点 (-80, 0, 0)
        StartPosition = Vector3(0, 0, 0),
        -- 方向：从(-80,0)到(-60,30)，dirX=20, dirZ=30, atan2(20,30)≈34°
        StartRotation = 90,
        PointsType = "points",
        ControlPoints = {
            Vector3(0, 0, 0),
            Vector3(5, 0, 0),
            Vector3(6, 0, 0),
            Vector3(10, 0, 0),
            Vector3(100, 0, 0),
            Vector3(100, 0, 20),
            Vector3(0, 0, 20),
            Vector3(-1, 0, 0),
        },
        SegmentsPerSpan = 10,
        TrackOptions = {
            barrierHeight = 0.07,
            barrierWidth = 0.5,
            barrierColor = Color(1.0, 0.8, 0.2),
            trackColor = Color(0.2, 0.18, 0.15),
            closedLoop = true,
        },
        TreeCount = 40,
        InnerTreeCount = 15,
        -- 敌人生成配置
        EnemyConfig = {
            MaxEnemies = 10,
            SideOffset = 4,
        },
    },
--    [7] = {
--        Name = "高架路赛道",
--        Description = "S形连续弯道，挑战极限操控",
--        TrackType = "loop",
--        Width = 12,
--        -- 起点在第一个控制点 (-80, 0, 0)
--        StartPosition = Vector3(0, 0, 0),
--        -- 方向：从(-80,0)到(-60,30)，dirX=20, dirZ=30, atan2(20,30)≈34°
--        StartRotation = 0,
--        PointsType = "points",
--        ControlPoints = {
--            Vector3(0, 0, 0),--Vector3(0, 0, 0),
--            Vector3(0, 0, 5),--Vector3(5, 0, 0),
--            Vector3(30, 2, 30),--Vector3(30, 2, 30),
--            Vector3(60, 4, 0),--Vector3(0, 4, 60),
--            Vector3(30, 6, -30),--Vector3(-30, 6, 30),
--            Vector3(0, 8, 0),--Vector3(0, 8, 0),
--            Vector3(30, 10, 30),--Vector3(30, 10, 30),
--            Vector3(60, 12, 0),--Vector3(0, 12, 60),
--            Vector3(30, 14, -30),--Vector3(-30, 14, 30),
--            Vector3(0, 16, 0),--Vector3(0, 16, 0),
--            Vector3(0, 18, 25),--Vector3(25, 18, 0),
--            Vector3(0, 10, 60),--Vector3(60, 10, 0),
--            Vector3(-15, 10, 70),--Vector3(70, 10, -15),
--            Vector3(-30, 10, 60),--Vector3(60, 10, -30),
--            Vector3(-30, 0, 0),--Vector3(0, 0, -30),
--            Vector3(-20, 0, -15),--Vector3(-15, 0, -20),
--            --Vector3(0, 0, 0),--Vector3(0, 0, 0),
--            --Vector3(-5, 0, 0),
--            --Vector3(-1, 0, 0),
--        },
--        SegmentsPerSpan = 10,
--        TrackOptions = {
--            barrierHeight = 0.7,
--            barrierWidth = 0.5,
--            barrierColor = Color(1.0, 0.8, 0.2),
--            trackColor = Color(0.2, 0.18, 0.15),
--            closedLoop = true,
--        },
--        TreeCount = 40,
--        InnerTreeCount = 15,
--        -- 敌人生成配置
--        EnemyConfig = {
--            MaxEnemies = 12,          -- 最大敌人数量
--            SideOffset = 2,           -- 窄道偏移小
--        },
--    },
}

-- 当前赛道索引
local currentTrackIndex_ = 1

-- 游戏状态
local currentSpeed_ = 0
local currentSteering_ = 0
local lapTime_ = 0
local bestLapTime_ = 999999
local checkpointsPassed_ = 0
local totalCheckpoints_ = 4
local raceStarted_ = false

-- 漂移状态
local isDrifting_ = false         -- 是否在漂移
local driftIntensity_ = 0         -- 漂移强度 (0-1)
local frontBaseFriction_ = 1.2    -- 前轮基于速度计算的基础摩擦力
local rearBaseFriction_ = 1.0     -- 后轮基于速度计算的基础摩擦力
local currentFrontFriction_ = 1.2 -- 当前前轮摩擦力（平滑过渡后）
local currentRearFriction_ = 1.0  -- 当前后轮摩擦力（平滑过渡后）

-- 轮胎烟雾系统（使用球体替代粒子效果）
local SMOKE_DURATION = 1.5        -- 烟雾持续时间（秒）
local SMOKE_INTERVAL = 0.05       -- 生成间隔（秒）
local SMOKE_MIN_SPEED = 10.0      -- 最低触发速度 (km/h)
local smokeTimer_ = 0             -- 生成计时器
local smokeMaterial_ = nil        -- 烟雾球材质
local smokeBalls_ = {}            -- 活跃的烟雾球列表

-- 配置面板状态
local configPanelOpen_ = false    -- 面板是否打开
local activeSlider_ = nil         -- 当前正在拖动的滑块名称
local sliderDragging_ = false     -- 是否正在拖动滑块
local activeToggle_ = nil         -- 当前点击的开关名称
local currentCarSetting_ = 1      -- 当前选中的车辆配置索引

-- 虚拟按钮状态
local driftButtonPressed_ = false -- 漂移按钮是否按下
local fireButtonPressed_ = false  -- 发射按钮是否按下

-- ============================================================================
-- 导弹与敌人系统配置
-- ============================================================================
local MISSILE_CONFIG = {
    FireCooldown = 0.1,        -- 发射冷却时间（秒）
    SearchRange = 50.0,        -- 搜索敌人范围
    Speed = 80.0,              -- 导弹速度 (m/s)
    TurnSpeed = 16,           -- 导弹转向速度
    ExplosionRadius = 2.0,     -- 爆炸半径
    LifeTime = 3.0,            -- 导弹存活时间
    Size = 0.3,                -- 导弹大小
}

local ENEMY_CONFIG = {
    MaxEnemies = 8,            -- 最大敌人数量（默认值）
    ScorePerKill = 100,        -- 击杀得分
    Size = 1.0,                -- 敌人大小
    HitRadius = 1.5,           -- 碰撞半径
    SideOffset = 3,            -- 左右偏移范围（默认值）
}

-- 导弹与敌人状态
local missiles_ = {}           -- 活跃的导弹列表
local enemies_ = {}            -- 活跃的敌人列表
local lastFireTime_ = -999     -- 上次发射时间（初始为负数允许立即发射）
local gameScore_ = 0           -- 当前分数
local totalKills_ = 0          -- 总击杀数
local missileMaterial_ = nil   -- 导弹材质
local enemyMaterial_ = nil     -- 敌人材质
local explosionBalls_ = {}     -- 爆炸效果列表

-- ============================================================================
-- 2. 生命周期函数
-- ============================================================================

function Start()
    SampleStart()
    graphics.windowTitle = CONFIG.Title
    
    InitNanoVG()
    CreateScene()
    CreateVehicle()
    CreateRaceTrack()
    CreateSmokeEffect()  -- 初始化烟雾粒子效果
    CreateMissileAndEnemyMaterials()  -- 初始化导弹和敌人材质
    SetupViewport()
    SubscribeToEvents()
    TestAssets()
    
    -- 设置鼠标模式
    SampleInitMouseMode(MM_FREE)
    
    print("=== 3D 赛车游戏启动 ===")
    print("方向键/WASD 控制，空格刹车，R 重置位置")
    print("检测到敌人时导弹自动发射")
end

function Stop()
    if nvg_ ~= nil then
        nvgDelete(nvg_)
        nvg_ = nil
    end
end


function TestAssets()
    local adjustNode = scene_:CreateChild("test_asset")
    local comp= adjustNode:CreateComponent("AnimatedModel")
    --comp:SetModel(cache:GetResource("Model", "PathToModel/m.mdl"))
    comp:SetModel(cache:GetResource("Model", "m.mdl"))
    local node = comp:GetNode()
    node:SetRotation(Quaternion(0.5,-0.5,-0.5,-0.5))
    node:SetScale(Vector3(0.01,0.01,0.01))
end

-- ============================================================================
-- 3. 初始化函数
-- ============================================================================

function InitNanoVG()
    nvg_ = nvgCreate(1)
    if nvg_ == nil then
        print("❌ ERROR: Failed to create NanoVG context!")
        return
    end
    
    local fontId = nvgCreateFont(nvg_, "sans", "Fonts/MiSans-Regular.ttf")
    if fontId == -1 then
        print("⚠️ WARNING: Failed to load font")
    end
end

function CreateScene()
    scene_ = Scene()
    
    -- 基础组件
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("DebugRenderer")
    
    -- 物理世界
    local physicsWorld = scene_:CreateComponent("PhysicsWorld")
    physicsWorld.gravity = Vector3(0, -9.81, 0)
    
    -- 创建光照
    CreateLighting()
end

function CreateLighting()
    -- 天空盒/环境
    local zoneNode = scene_:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(Vector3(-1000, -1000, -1000), Vector3(1000, 1000, 1000))
    zone.ambientColor = Color(0.2, 0.22, 0.28)  -- 降低环境光
    zone.fogColor = Color(0.25, 0.3, 0.4)       -- 调暗雾气颜色
    zone.fogStart = 80.0
    zone.fogEnd = 400.0
    
    -- 主光源（太阳）- 傍晚效果
    local lightNode = scene_:CreateChild("DirectionalLight")
    lightNode.direction = Vector3(0.6, -0.8, 0.4)  -- 调整光照角度，更接近傍晚
    local light = lightNode:CreateComponent("Light")
    light.lightType = LIGHT_DIRECTIONAL
    light.color = Color(0.9, 0.6, 0.4)  -- 偏暖色调（傍晚阳光）
    light.brightness = 0.6              -- 降低亮度
    light.castShadows = true
    light.shadowBias = BiasParameters(0.00025, 0.5)
    light.shadowCascade = CascadeParameters(10.0, 50.0, 200.0, 0.0, 0.8)
end

function SetupViewport()
    cameraNode_ = scene_:CreateChild("Camera")
    local camera = cameraNode_:CreateComponent("Camera")
    camera.farClip = 500.0
    camera.fov = 60.0
    
    local viewport = Viewport:new(scene_, camera)
    renderer:SetViewport(0, viewport)
end

function SubscribeToEvents()
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PostUpdate", "HandlePostUpdate")
    SubscribeToEvent("PreRenderUI", "HandleRender")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("MouseButtonDown", "HandleMouseDown")
    SubscribeToEvent("MouseButtonUp", "HandleMouseUp")
end

-- ============================================================================
-- 4. 车辆创建
-- ============================================================================

--- 创建车辆
--- 车辆结构：
---   vehicleNode_ (根节点，包含 RigidBody + CollisionShape + RaycastVehicle)
---   ├── Body (车身模型节点)
---   ├── Wheel1 (前左轮)
---   ├── Wheel2 (前右轮)
---   ├── Wheel3 (后左轮)
---   └── Wheel4 (后右轮)
function CreateVehicle()
    -- ========================================
    -- 第一步：创建车辆根节点（初始不设置朝向）
    -- ========================================
    vehicleNode_ = scene_:CreateChild("Vehicle")
    -- 从赛道配置获取起点位置（先只设置位置，朝向稍后设置）
    local trackConfig = GetCurrentTrackConfig()
    local startRotation = 0
    if trackConfig then
        vehicleNode_.position = trackConfig.StartPosition or Vector3(0, 2, 38)
        startRotation = trackConfig.StartRotation or 0
    else
        vehicleNode_.position = Vector3(0, 2, 38)  -- 默认位置
    end
    -- 注意：此时不设置旋转，保持默认朝向（0度），轮子创建完成后再设置
    
    -- ========================================
    -- 第二步：创建车身模型（纯视觉，不参与物理）
    -- ========================================
    local bodyNode = vehicleNode_:CreateChild("Body")
    local bodyModel = bodyNode:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    
    -- 车身 PBR 材质（使用配置的颜色）
    local bodyMat = Material:new()
    bodyMat:SetTechnique(0, cache:GetResource("Technique", 
        "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    local bodyColor = CONFIG.BodyColor or Color(0.1, 0.2, 0.5, 1.0)
    bodyMat:SetShaderParameter("ColorFactor", Variant(bodyColor))
    bodyMat:SetShaderParameter("MetallicFactor", Variant(0.8))   -- 高金属度
    bodyMat:SetShaderParameter("RoughnessFactor", Variant(0.3))  -- 较光滑
    bodyModel:SetMaterial(bodyMat)
    bodyModel.castShadows = true
    
    -- 车身尺寸：宽 1.2m × 高 0.5m × 长 2.5m
    bodyNode.scale = CONFIG.BodyScale or Vector3(0.6, 0.5, 2.5)
    bodyNode.position = Vector3(0, 0.5, 0)  -- 相对于车辆节点，向上偏移 0.5m
    
    -- ========================================
    -- 第三步：创建物理刚体（RigidBody）
    -- ========================================
    local body = vehicleNode_:CreateComponent("RigidBody")
    body.mass = CONFIG.VehicleMass  -- 车辆质量 (kg)
    body.linearDamping = 0.2    -- 线性阻尼（空气阻力）
    body.angularDamping = 0.8   -- 角阻尼（增加以防止过度旋转）
    body.friction = 0.5         -- 摩擦系数
    body.collisionLayer = 1     -- 碰撞层
    body.collisionMask = 0xFFFF -- 碰撞掩码（与所有物体碰撞）
    
    -- ========================================
    -- 第四步：创建碰撞形状（CollisionShape）
    -- ========================================
    local shape = vehicleNode_:CreateComponent("CollisionShape")
    -- SetBox(尺寸, 偏移位置) - 碰撞盒与车身模型对齐
    shape:SetBox(Vector3(1.2, 0.5, 2.5), Vector3(0, 0.5, 0))
    
    -- ========================================
    -- 第五步：创建 RaycastVehicle 组件
    -- ========================================
    -- RaycastVehicle 是 Bullet 物理引擎提供的射线投射车辆
    -- 它通过向下发射射线来模拟悬挂系统，而不是用真实的轮子碰撞体
    vehicle_ = vehicleNode_:CreateComponent("RaycastVehicle")
    vehicle_:Init()  -- 初始化车辆物理
    
    -- ========================================
    -- 第六步：定义轮子参数
    -- ========================================
    local wheelRadius = CONFIG.WheelRadius or 0.35  -- 轮子半径（使用配置）
    local wheelWidth = CONFIG.WheelWidth or 0.3     -- 轮子宽度（使用配置）
    local suspensionRestLength = CONFIG.SuspensionRestLength or 0.4   -- 悬挂静止长度（米），控制最大压缩行程
    
    -- 悬挂方向和轮轴方向（在默认朝向下设置，车辆旋转后会自动跟随）
    local wheelDirection = Vector3(0, -1, 0)  -- 悬挂方向：向下
    local wheelAxle = Vector3(-1, 0, 0)       -- 轮轴方向：指向左侧
    
    -- 四个轮子的位置（相对于车辆根节点）
    -- X: 左右位置（负=左，正=右）
    -- Y: 高度（悬挂连接点高度，使用配置）
    -- Z: 前后位置（正=前，负=后）
    local wheelHeight = CONFIG.WheelHeight or -0.15  -- 轮子高度（使用配置）
    local wheelPositions = {
        Vector3(-0.6, wheelHeight, 1.0),   -- 前左轮
        Vector3(0.6, wheelHeight, 1.0),    -- 前右轮
        Vector3(-0.6, wheelHeight, -1.0),  -- 后左轮
        Vector3(0.6, wheelHeight, -1.0),   -- 后右轮
    }
    
    -- ========================================
    -- 第七步：创建四个轮子
    -- ========================================
    for i, pos in ipairs(wheelPositions) do
        local isFront = (i <= 2)  -- 索引 1,2 是前轮，3,4 是后轮
        
        -- 7.1 创建轮子节点（必须是车辆的子节点）
        local wheelNode = vehicleNode_:CreateChild("Wheel" .. i)
        
        -- ⚠️ 关键：设置轮子的初始位置（局部坐标）
        -- RaycastVehicle 会根据这个位置确定悬挂连接点
        wheelNode.position = pos
        
        -- 7.2 创建轮子模型（圆柱体）
        local wheelModel = wheelNode:CreateComponent("StaticModel")
        wheelModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        
        -- 轮子 PBR 材质（深灰色橡胶质感）
        local wheelMat = Material:new()
        wheelMat:SetTechnique(0, cache:GetResource("Technique", 
            "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
        wheelMat:SetShaderParameter("ColorFactor", Variant(Color(0.15, 0.15, 0.15, 1.0)))  -- 深灰色
        wheelMat:SetShaderParameter("MetallicFactor", Variant(0.0))   -- 非金属
        wheelMat:SetShaderParameter("RoughnessFactor", Variant(0.9))  -- 粗糙（橡胶）
        wheelModel:SetMaterial(wheelMat)
        wheelModel.castShadows = true
        
        -- 7.3 设置轮子尺寸和旋转
        -- Cylinder 模型默认 Y 轴向上，需要绕 Z 轴旋转 90° 让它横躺
        -- scale: (直径, 宽度, 直径)
        wheelNode.scale = Vector3(wheelRadius * 2, wheelWidth, wheelRadius * 2)
        -- 轮子局部旋转：绕 Z 轴旋转 90° 让圆柱体横躺
        wheelNode.rotation = Quaternion(0, 0, 90)
        
        -- 7.4 将轮子添加到 RaycastVehicle 物理系统
        -- AddWheel(轮子节点, 悬挂方向, 轮轴方向, 悬挂长度, 轮子半径, 是否前轮)
        vehicle_:AddWheel(wheelNode, wheelDirection, wheelAxle, 
            suspensionRestLength, wheelRadius, isFront)
        
        -- 7.5 设置轮子物理属性
        local wheelIndex = i - 1  -- Lua 索引从 1 开始，但 API 是 0-based
        
        -- 悬挂刚度：值越大，悬挂越硬（弹簧系数）
        vehicle_:SetWheelSuspensionStiffness(wheelIndex, CONFIG.SuspensionStiffness)
        
        -- 悬挂阻尼（松弛）：悬挂伸展时的阻尼
        vehicle_:SetWheelDampingRelaxation(wheelIndex, CONFIG.SuspensionDamping)
        
        -- 悬挂阻尼（压缩）：悬挂压缩时的阻尼
        vehicle_:SetWheelDampingCompression(wheelIndex, CONFIG.SuspensionCompression)
        
        -- 轮胎摩擦力：值越大，抓地力越强
        vehicle_:SetWheelFrictionSlip(wheelIndex, CONFIG.WheelFriction)
        
        -- 侧倾影响：值越小，车辆越不容易侧翻（0=完全不侧翻）
        vehicle_:SetWheelRollInfluence(wheelIndex, CONFIG.RollInfluence)
    end
    
    -- ========================================
    -- 第八步：重置悬挂系统
    -- ========================================
    -- 初始化完成后调用，让悬挂进入正确的初始状态
    vehicle_:ResetSuspension()
    
    -- ========================================
    -- 第九步：设置车辆朝向
    -- ========================================
    -- 在所有组件创建完成后再设置旋转，轮子作为子节点会跟随旋转
    if startRotation ~= 0 then
        vehicleNode_.rotation = Quaternion(startRotation, Vector3.UP)
    end
end

-- ============================================================================
-- 5. 赛道创建
-- ============================================================================

function CreateRaceTrack()
    -- 主地面
    CreateGround(Vector3(0, -0.5, 0), Vector3(400, 1, 400), Color(0.3, 0.5, 0.3))
    
    -- 从配置表加载当前赛道
    CreateTrackFromConfig(currentTrackIndex_)
end

--- 根据配置表创建赛道
---@param trackIndex number 赛道索引
function CreateTrackFromConfig(trackIndex)
    local config = TrackConfig[trackIndex]
    if not config then
        print("错误: 无效的赛道索引 " .. trackIndex)
        return
    end
    
    print(string.format("正在创建赛道: %s - %s", config.Name, config.Description or ""))
    
    -- 生成控制点
    local controlPoints = {}
    
    if config.PointsType == "ellipse" then
        -- 椭圆形赛道：自动生成控制点
        local radiusX = config.EllipseRadiusX or 60
        local radiusZ = config.EllipseRadiusZ or 40
        local numPoints = config.EllipsePoints or 12
        
        for i = 1, numPoints do
            local angle = ((i - 1) / numPoints) * math.pi * 2
            local x = math.sin(angle) * radiusX
            local z = math.cos(angle) * radiusZ
            table.insert(controlPoints, Vector3(x, 0, z))
        end
    elseif config.PointsType == "points" then
        -- 直接使用配置的控制点
        controlPoints = config.ControlPoints or {}
    end
    
    if #controlPoints < 2 then
        print("错误: 控制点数量不足")
        return
    end
    
    -- 创建赛道
    local segmentsPerSpan = config.SegmentsPerSpan or 8
    -- 将起始点位置传递给赛道创建函数，用于在起始点附近不创建围栏
    local trackOptions = config.TrackOptions or {}
    trackOptions.startPosition = config.StartPosition
    -- 排除半径 = 赛道宽度的一半（护栏在边缘） + 5米余量（确保覆盖入口区域）
    trackOptions.startExcludeRadius = (config.Width / 2) + 5
    CreateSmoothTrackFromPoints(controlPoints, config.Width, segmentsPerSpan, trackOptions)
    
    -- 起点标记（跟随赛道初始角度）
    local startPos = config.StartPosition or Vector3(0, 0, 0)
    local startRotation = config.StartRotation or 0
    CreateStartLine(Vector3(startPos.x, 0.1, startPos.z), startRotation)
    
    -- 装饰物（树木）
    local treeCount = config.TreeCount or 20
    local innerTreeCount = config.InnerTreeCount or 0
    
    for i = 1, treeCount do
        local angle = (i / treeCount) * math.pi * 2
        -- 外圈树木
        local outerRadius = 85 + math.random() * 20
        local x1 = math.sin(angle) * outerRadius
        local z1 = math.cos(angle) * outerRadius * 0.7
        CreateTree(Vector3(x1, 0, z1))
    end
    
    -- 内圈树木
    if innerTreeCount > 0 then
        for i = 1, innerTreeCount do
            local angle = (i / innerTreeCount) * math.pi * 2
            local innerRadius = 15 + math.random() * 15
            local x2 = math.sin(angle) * innerRadius
            local z2 = math.cos(angle) * innerRadius * 0.7
            CreateTree(Vector3(x2, 0, z2))
        end
    end
    
    -- 在赛道上生成初始敌人
    SpawnInitialEnemies()
    
    print(string.format("赛道 [%s] 创建完成", config.Name))
end

--- 切换赛道
---@param trackIndex number 赛道索引
function SwitchTrack(trackIndex)
    if not TrackConfig[trackIndex] then
        print("错误: 无效的赛道索引 " .. trackIndex)
        return
    end
    
    currentTrackIndex_ = trackIndex
    local config = TrackConfig[trackIndex]
    
    -- 清除现有赛道元素
    ClearTrackElements()
    
    -- 清除导弹和敌人
    ClearMissilesAndEnemies()
    
    -- 销毁旧车辆（轮子方向需要根据新赛道朝向重新设置）
    if vehicleNode_ then
        vehicleNode_:Remove()
        vehicleNode_ = nil
        vehicle_ = nil
    end
    
    -- 创建新赛道
    CreateGround(Vector3(0, -0.5, 0), Vector3(400, 1, 400), Color(0.3, 0.5, 0.3))
    CreateTrackFromConfig(trackIndex)
    
    -- 重新创建车辆（会根据新赛道配置设置位置、朝向和轮子方向）
    CreateVehicle()
    
    -- 重置比赛状态
    lapTime_ = 0
    checkpointsPassed_ = 0
    raceStarted_ = false
    currentSpeed_ = 0
    currentSteering_ = 0
    
    -- 重置战斗状态（可选，如果想保留分数就注释掉下面两行）
    -- gameScore_ = 0
    -- totalKills_ = 0
    
    print(string.format("已切换到赛道: %s", config.Name))
end

--- 清除赛道元素（用于切换赛道）
function ClearTrackElements()
    if scene_ == nil then return end
    
    -- 要清除的节点名称列表
    local nodesToRemove = {
        "Ground", "Track", "Barrier", "StartLine", "Tree", 
        "Checkpoint", "Ramp", "TireSmoke"
    }
    
    for _, nodeName in ipairs(nodesToRemove) do
        while true do
            local node = scene_:GetChild(nodeName, true)
            if node then
                node:Remove()
            else
                break
            end
        end
    end
end

--- 获取当前赛道配置
---@return table 当前赛道配置
function GetCurrentTrackConfig()
    return TrackConfig[currentTrackIndex_]
end

--- 获取赛道数量
---@return number 赛道总数
function GetTrackCount()
    return #TrackConfig
end

function CreateGround(position, size, color)
    --do return end
    local node = scene_:CreateChild("Ground")
    node.position = position
    node.scale = size
    
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", 
        "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    mat:SetShaderParameter("ColorFactor", Variant(Color(color.r, color.g, color.b, 1.0)))
    mat:SetShaderParameter("MetallicFactor", Variant(0.0))
    mat:SetShaderParameter("RoughnessFactor", Variant(0.95))
    model:SetMaterial(mat)
    
    local body = node:CreateComponent("RigidBody")
    body.collisionLayer = 2
    body.collisionMask = 0xFFFF
    
    local shape = node:CreateComponent("CollisionShape")
    shape:SetBox(Vector3.ONE)
end

function CreateTrackPiece(position, size, color, yRotation, pitchAngle)
    local node = scene_:CreateChild("Track")
    node.position = position
    node.scale = size
    
    -- 应用旋转（先 yaw 后 pitch）
    if yRotation or pitchAngle then
        local yaw = yRotation or 0
        local pitch = pitchAngle or 0
        -- 先绕 Y 轴旋转（水平方向），再绕局部 X 轴旋转（俯仰）
        local yawQuat = Quaternion(yaw, Vector3.UP)
        local pitchQuat = Quaternion(pitch, Vector3.RIGHT)
        node.rotation = yawQuat * pitchQuat
    end
    
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", 
        "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    mat:SetShaderParameter("ColorFactor", Variant(Color(color.r, color.g, color.b, 1.0)))
    mat:SetShaderParameter("MetallicFactor", Variant(0.0))
    mat:SetShaderParameter("RoughnessFactor", Variant(0.7))
    model:SetMaterial(mat)
    
    local body = node:CreateComponent("RigidBody")
    body.collisionLayer = 2
    body.collisionMask = 0xFFFF
    
    local shape = node:CreateComponent("CollisionShape")
    shape:SetBox(Vector3.ONE)
end

--- 创建斜坡
---@param position Vector3 斜坡中心位置
---@param size Vector3 斜坡尺寸 (宽度, 厚度, 长度)
---@param angle number 倾斜角度（度数，正值为向Z+方向上升）
---@param color Color 颜色
function CreateRamp(position, size, angle, color, rot)
	local list = nil
    local ag_ratio = math.cos(angle*math.pi/180)^0.5
	list = {
		{position + Vector3(math.sin(rot*math.pi/180)*size.x/2*ag_ratio, math.sin(angle*math.pi/180)*size.x/2-1, math.cos(rot*math.pi/180)*size.z/2*math.cos(angle*math.pi/180))*ag_ratio,angle},
		{position + Vector3(math.sin((rot+180)*math.pi/180)*size.x/2*ag_ratio, math.sin(angle*math.pi/180)*size.x/2-1, math.cos((rot+180)*math.pi/180)*size.z/2)*ag_ratio,-angle},
	}
	for _, v in ipairs(list) do
		local pos = v[1]
		local node = scene_:CreateChild("Ramp")
		node.position = pos
		node.scale = size
		-- 绕X轴旋转形成斜坡
		if rot == 0 then
			node.rotation = Quaternion(v[2], Vector3(1, 0, 0))
        elseif rot == 90 then
			node.rotation = Quaternion(v[2], Vector3(0, 0, -1))
		end
		
		local model = node:CreateComponent("StaticModel")
		model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
		
		local mat = Material:new()
		mat:SetTechnique(0, cache:GetResource("Technique", 
			"Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
		mat:SetShaderParameter("ColorFactor", Variant(Color(color.r, color.g, color.b, 1.0)))
		mat:SetShaderParameter("MetallicFactor", Variant(0.1))
		mat:SetShaderParameter("RoughnessFactor", Variant(0.5))
		model:SetMaterial(mat)
		
		local body = node:CreateComponent("RigidBody")
		body.collisionLayer = 2
		body.collisionMask = 0xFFFF
		
		local shape = node:CreateComponent("CollisionShape")
		shape:SetBox(Vector3.ONE)
	end
end

function CreateCheckpoint(position, index)
    local node = scene_:CreateChild("Checkpoint" .. index)
    node.position = position
    node:SetVar(StringHash("CheckpointIndex"), index)
    
    -- 检查点标志（黄色柱子）
    local pillar = node:CreateChild("Pillar")
    pillar.scale = Vector3(0.5, 3, 0.5)
    pillar.position = Vector3(0, 1.5, 0)
    
    local model = pillar:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", 
        "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    mat:SetShaderParameter("ColorFactor", Variant(Color(1.0, 0.8, 0.0, 1.0)))
    mat:SetShaderParameter("MetallicFactor", Variant(0.3))
    mat:SetShaderParameter("RoughnessFactor", Variant(0.5))
    mat:SetShaderParameter("Color_Emissive", Variant(Color(1.0, 0.8, 0.0, 1.0)))
    mat:SetShaderParameter("Emissive_Mul", Variant(0.3))
    model:SetMaterial(mat)
end

function CreateBarrier(position, size, color, yRotation, pitchAngle)
    local node = scene_:CreateChild("Barrier")
    node.position = position
    node.scale = size
    
    -- 应用旋转（先 yaw 后 pitch）
    if yRotation or pitchAngle then
        local yaw = yRotation or 0
        local pitch = pitchAngle or 0
        -- 先绕 Y 轴旋转（水平方向），再绕局部 X 轴旋转（俯仰）
        local yawQuat = Quaternion(yaw, Vector3.UP)
        local pitchQuat = Quaternion(pitch, Vector3.RIGHT)
        node.rotation = yawQuat * pitchQuat
    end
    
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", 
        "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    mat:SetShaderParameter("ColorFactor", Variant(Color(color.r, color.g, color.b, 1.0)))
    mat:SetShaderParameter("MetallicFactor", Variant(0.0))
    mat:SetShaderParameter("RoughnessFactor", Variant(0.8))
    model:SetMaterial(mat)
    
    local body = node:CreateComponent("RigidBody")
    body.collisionLayer = 2
    body.collisionMask = 0xFFFF
    
    local shape = node:CreateComponent("CollisionShape")
    shape:SetBox(Vector3.ONE)
end

function CreateStartLine(position, rotation)
    local node = scene_:CreateChild("StartLine")
    node.position = position
    node.scale = Vector3(15, 0.05, 2)
    
    -- 跟随赛道初始角度旋转
    local yRotation = rotation or 0
    node.rotation = Quaternion(yRotation, Vector3.UP)
    
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    
    -- 黑白格子效果（用白色表示）
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", 
        "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    mat:SetShaderParameter("ColorFactor", Variant(Color(1.0, 1.0, 1.0, 1.0)))
    mat:SetShaderParameter("MetallicFactor", Variant(0.0))
    mat:SetShaderParameter("RoughnessFactor", Variant(0.5))
    model:SetMaterial(mat)
end

function CreateTree(position)
    local node = scene_:CreateChild("Tree")
    node.position = position
    
    -- 树干
    local trunk = node:CreateChild("Trunk")
    trunk.scale = Vector3(0.5, 3, 0.5)
    trunk.position = Vector3(0, 1.5, 0)
    
    local trunkModel = trunk:CreateComponent("StaticModel")
    trunkModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    
    local trunkMat = Material:new()
    trunkMat:SetTechnique(0, cache:GetResource("Technique", 
        "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    trunkMat:SetShaderParameter("ColorFactor", Variant(Color(0.4, 0.25, 0.1, 1.0)))
    trunkMat:SetShaderParameter("MetallicFactor", Variant(0.0))
    trunkMat:SetShaderParameter("RoughnessFactor", Variant(0.9))
    trunkModel:SetMaterial(trunkMat)
    trunkModel.castShadows = true
    
    -- 树冠
    local leaves = node:CreateChild("Leaves")
    leaves.scale = Vector3(3, 4, 3)
    leaves.position = Vector3(0, 5, 0)
    
    local leavesModel = leaves:CreateComponent("StaticModel")
    leavesModel:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
    
    local leavesMat = Material:new()
    leavesMat:SetTechnique(0, cache:GetResource("Technique", 
        "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    leavesMat:SetShaderParameter("ColorFactor", Variant(Color(0.15, 0.4, 0.15, 1.0)))
    leavesMat:SetShaderParameter("MetallicFactor", Variant(0.0))
    leavesMat:SetShaderParameter("RoughnessFactor", Variant(0.8))
    leavesModel:SetMaterial(leavesMat)
    leavesModel.castShadows = true
end

-- ============================================================================
-- 5.5 赛道生成 API
-- ============================================================================

--- 将角度归一化到 [-180, 180] 范围
---@param angle number 输入角度（度）
---@return number 归一化后的角度
local function NormalizeAngle(angle)
    angle = angle % 360
    if angle > 180 then angle = angle - 360 end
    if angle < -180 then angle = angle + 360 end
    return angle
end

--- 计算两个角度之间的最短差值（考虑周期性）
---@param from number 起始角度
---@param to number 目标角度
---@return number 最短角度差（可正可负）
local function ShortestAngleDiff(from, to)
    local diff = NormalizeAngle(to - from)
    return diff
end

--- 平滑过渡角度，避免超过180度的跳变
--- 根据前一个角度调整当前角度，确保差值不超过180度
---@param currentAngle number 当前计算的角度（来自 atan2，范围 [-180, 180]）
---@param prevAngle number|nil 前一段的角度（nil 表示第一段，可能超出 [-180, 180]）
---@return number 调整后的角度（与 prevAngle 连续）
local function SmoothAngleTransition(currentAngle, prevAngle)
    if prevAngle == nil then
        return currentAngle
    end
    
    -- 计算最短角度差
    local shortestDiff = ShortestAngleDiff(prevAngle, currentAngle)
    
    -- 基于前一个角度加上最短差值，保证连续性
    return prevAngle + shortestDiff
end

--- 对点数组进行 Catmull-Rom 平滑处理
---@param points table 原始点数组
---@param subdivisions number 每段细分数量
---@param closedLoop boolean 是否闭合
---@return table 平滑后的点数组
local function SmoothPoints(points, subdivisions, closedLoop)
    if #points < 3 or subdivisions <= 1 then
        return points
    end
    
    local result = {}
    local n = #points
    
    -- 辅助函数：安全获取循环索引的点
    local function getPoint(idx)
        if closedLoop then
            return points[(idx - 1) % n + 1]
        else
            return points[math.max(1, math.min(n, idx))]
        end
    end
    
    -- 确定要处理的段数
    local numSegments = closedLoop and n or (n - 1)
    
    for i = 1, numSegments do
        -- 获取四个控制点 (p0, p1, p2, p3)
        local p0 = getPoint(i - 1)
        local p1 = getPoint(i)
        local p2 = getPoint(i + 1)
        local p3 = getPoint(i + 2)
        
        -- 在 p1 和 p2 之间插入细分点
        for j = 0, subdivisions - 1 do
            local t = j / subdivisions
            table.insert(result, CatmullRomInterpolate(p0, p1, p2, p3, t))
        end
    end
    
    -- 非闭合赛道添加最后一个点
    if not closedLoop then
        table.insert(result, points[n])
    end
    
    return result
end

--- 根据点数组创建赛道
--- 根据传入的路径点和宽度，自动生成赛道路面和两侧栏杆
---@param points table 点数组，每个点是 Vector3，表示赛道中心线的控制点
---@param width number 赛道宽度
---@param options table|nil 可选参数表
---  options.barrierHeight: 栏杆高度（默认 0.5）
---  options.barrierWidth: 栏杆宽度（默认 0.5）
---  options.trackHeight: 赛道厚度（默认 0.1）
---  options.trackColor: 赛道颜色（默认深灰色）
---  options.barrierColor: 栏杆颜色（默认红色）
---  options.createTrackSurface: 是否创建赛道路面（默认 true）
---  options.createBarriers: 是否创建栏杆（默认 true）
---  options.closedLoop: 是否闭合赛道（默认 false，首尾相连）
---  options.smoothness: 平滑度（每段细分数量，默认 5，0 表示不平滑）
---@return table 创建的节点列表
function CreateTrackFromPoints(points, width, options)
    if not points or #points < 2 then
        print("错误: 创建赛道需要至少2个点")
        return {}
    end
    
    -- 默认参数
    options = options or {}
    local barrierHeight = options.barrierHeight or 0.5
    local barrierWidth = options.barrierWidth or 0.5
    local trackHeight = options.trackHeight or 0.1
    local trackColor = options.trackColor or Color(0.2, 0.2, 0.25)
    local barrierColor = options.barrierColor or Color(1, 0.2, 0.2)
    local createTrackSurface = options.createTrackSurface ~= false  -- 默认 true
    local createBarriers = options.createBarriers ~= false  -- 默认 true
    local closedLoop = options.closedLoop or false
    local smoothness = options.smoothness or 5  -- 默认平滑度
    
    local createdNodes = {}
    local numPoints = #points
    
    -- ========================================
    -- 第一步：统计道路中心点和两侧护栏点（原始点）
    -- ========================================
    local centerPoints = {}        -- 道路中心点
    local leftBarrierRaw = {}      -- 左侧护栏原始点
    local rightBarrierRaw = {}     -- 右侧护栏原始点
    
    for i = 1, numPoints do
        local p = points[i]
        
        -- 计算当前点的方向（取前后点的平均方向）
        local prevIdx = closedLoop and ((i - 2) % numPoints + 1) or math.max(1, i - 1)
        local nextIdx = closedLoop and (i % numPoints + 1) or math.min(numPoints, i + 1)
        
        local prev = points[prevIdx]
        local next = points[nextIdx]
        
        -- 计算方向向量
        local dirX = next.x - prev.x
        local dirZ = next.z - prev.z
        local horizontalLength = math.sqrt(dirX * dirX + dirZ * dirZ)
        
        if horizontalLength > 0.001 then
            -- 归一化水平方向
            local normX = dirX / horizontalLength
            local normZ = dirZ / horizontalLength
            
            -- 计算垂直方向（左侧，在水平面上）
            local perpX = -normZ
            local perpZ = normX
            
            -- 计算左右护栏点位置
            local leftX = p.x + perpX * (width / 2)
            local leftZ = p.z + perpZ * (width / 2)
            local rightX = p.x - perpX * (width / 2)
            local rightZ = p.z - perpZ * (width / 2)
            
            -- 存储原始点
            table.insert(centerPoints, p)
            table.insert(leftBarrierRaw, Vector3(leftX, p.y, leftZ))
            table.insert(rightBarrierRaw, Vector3(rightX, p.y, rightZ))
        end
    end
    
    -- ========================================
    -- 第二步：分别对三组点进行平滑处理
    -- ========================================
    local smoothCenterPoints = centerPoints
    local smoothLeftBarrier = leftBarrierRaw
    local smoothRightBarrier = rightBarrierRaw
    
    if smoothness > 1 and #centerPoints >= 3 then
        print(string.format("开始平滑处理: 原始点数 %d, 平滑度 %d", #centerPoints, smoothness))
        
        -- 分别平滑道路中心和两侧护栏
        smoothCenterPoints = SmoothPoints(centerPoints, smoothness, closedLoop)
        smoothLeftBarrier = SmoothPoints(leftBarrierRaw, smoothness, closedLoop)
        smoothRightBarrier = SmoothPoints(rightBarrierRaw, smoothness, closedLoop)
        
        print(string.format("平滑后: 中心点 %d, 左护栏点 %d, 右护栏点 %d", 
            #smoothCenterPoints, #smoothLeftBarrier, #smoothRightBarrier))
    end
    
    -- 如果是闭合赛道，需要额外处理首尾连接
    local totalSegments = closedLoop and #smoothCenterPoints or (#smoothCenterPoints - 1)
    
    -- ========================================
    -- 第三步：根据平滑后的点创建赛道路面（先收集数据再平滑角度）
    -- ========================================
    if createTrackSurface then
        local numCenterPoints = #smoothCenterPoints
        
        -- 3.1 收集所有段的数据（位置、尺寸、原始角度）
        local segmentData = {}
        for i = 1, totalSegments do
            local idx1 = i
            local idx2 = closedLoop and (i % numCenterPoints + 1) or math.min(i + 1, numCenterPoints)
            
            if idx1 <= numCenterPoints and idx2 <= numCenterPoints then
                local p1 = smoothCenterPoints[idx1]
                local p2 = smoothCenterPoints[idx2]
                
                local dirX = p2.x - p1.x
                local dirY = p2.y - p1.y
                local dirZ = p2.z - p1.z
                local horizontalLength = math.sqrt(dirX * dirX + dirZ * dirZ)
                
                -- 计算两侧护栏的距离，取较长的那个作为道路段长度
                local leftLength = 0
                local rightLength = 0
                local leftIdx2 = closedLoop and (i % #smoothLeftBarrier + 1) or math.min(i + 1, #smoothLeftBarrier)
                local rightIdx2 = closedLoop and (i % #smoothRightBarrier + 1) or math.min(i + 1, #smoothRightBarrier)
                
                if idx1 <= #smoothLeftBarrier and leftIdx2 <= #smoothLeftBarrier then
                    local lp1 = smoothLeftBarrier[idx1]
                    local lp2 = smoothLeftBarrier[leftIdx2]
                    local ldx = lp2.x - lp1.x
                    local ldy = lp2.y - lp1.y
                    local ldz = lp2.z - lp1.z
                    leftLength = math.sqrt(ldx * ldx + ldy * ldy + ldz * ldz)
                end
                
                if idx1 <= #smoothRightBarrier and rightIdx2 <= #smoothRightBarrier then
                    local rp1 = smoothRightBarrier[idx1]
                    local rp2 = smoothRightBarrier[rightIdx2]
                    local rdx = rp2.x - rp1.x
                    local rdy = rp2.y - rp1.y
                    local rdz = rp2.z - rp1.z
                    rightLength = math.sqrt(rdx * rdx + rdy * rdy + rdz * rdz)
                end
                
                local totalLength = math.max(leftLength, rightLength)
                
                if horizontalLength > 0.01 then
                    table.insert(segmentData, {
                        midX = (p1.x + p2.x) / 2,
                        midY = (p1.y + p2.y) / 2,
                        midZ = (p1.z + p2.z) / 2,
                        length = totalLength,
                        yRotation = math.atan2(dirX, dirZ) * 180 / math.pi,
                        pitchAngle = -math.atan2(dirY, horizontalLength) * 180 / math.pi,
                    })
                end
            end
        end
        
        -- 3.2 对角度序列进行平滑处理
        if #segmentData >= 2 then
            local numSegs = #segmentData
            
            -- 闭合赛道：用最后一段的角度初始化，保证首尾连续
            local prevYRot = closedLoop and segmentData[numSegs].yRotation or nil
            local prevPitch = closedLoop and segmentData[numSegs].pitchAngle or nil
            
            -- 第一遍：从前往后平滑角度
            for i = 1, numSegs do
                segmentData[i].yRotation = SmoothAngleTransition(segmentData[i].yRotation, prevYRot)
                segmentData[i].pitchAngle = SmoothAngleTransition(segmentData[i].pitchAngle, prevPitch)
                prevYRot = segmentData[i].yRotation
                prevPitch = segmentData[i].pitchAngle
            end
            
            -- 闭合赛道：检查首尾角度差，进行渐变插值平滑
            if closedLoop and numSegs >= 4 then
                local firstYRot = segmentData[1].yRotation
                local lastYRot = segmentData[numSegs].yRotation
                local yRotDiff = ShortestAngleDiff(lastYRot, firstYRot)
                
                local firstPitch = segmentData[1].pitchAngle
                local lastPitch = segmentData[numSegs].pitchAngle
                local pitchDiff = ShortestAngleDiff(lastPitch, firstPitch)
                
                -- 如果首尾角度差超过阈值，对末尾段进行渐变调整
                if math.abs(yRotDiff) > 3 or math.abs(pitchDiff) > 3 then
                    -- 渐变范围：赛道末尾的若干段
                    local blendRange = math.min(math.floor(numSegs / 3), 15)
                    
                    for j = 1, blendRange do
                        local blendFactor = j / blendRange  -- 0->1 渐变
                        local idx = numSegs - blendRange + j
                        
                        if idx >= 1 then
                            -- 计算该段应该达到的目标角度（线性插值到第一段）
                            local targetYRot = lastYRot + yRotDiff * blendFactor
                            local targetPitch = lastPitch + pitchDiff * blendFactor
                            
                            -- 平滑混合当前角度和目标角度
                            segmentData[idx].yRotation = segmentData[idx].yRotation + 
                                (targetYRot - segmentData[idx].yRotation) * blendFactor
                            segmentData[idx].pitchAngle = segmentData[idx].pitchAngle + 
                                (targetPitch - segmentData[idx].pitchAngle) * blendFactor
                        end
                    end
                end
            end
        end
        
        -- 3.3 根据平滑后的角度创建道路段
        for _, seg in ipairs(segmentData) do
            local trackPos = Vector3(seg.midX, seg.midY, seg.midZ)
            local trackSize = Vector3(width, trackHeight, seg.length)
            CreateTrackPiece(trackPos, trackSize, trackColor, seg.yRotation, seg.pitchAngle)
        end
    end
    
    -- ========================================
    -- 第四步：根据平滑后的护栏点创建护栏（使用相同的角度平滑逻辑）
    -- ========================================
    -- 获取起始点排除参数（用于在起始点附近不创建围栏）
    local startPosition = options.startPosition
    local startExcludeRadius = options.startExcludeRadius or 5
    local startExcludeHeight = 2  -- 只排除出生点高度 ±2 米以内的护栏
    local excludedBarrierCount = 0  -- 统计排除的护栏数量
    
    -- 辅助函数：检查位置是否在起始点附近（需要排除围栏）
    -- 条件：XZ 平面距离小于排除半径 且 高度差在 ±2 米以内
    local function isNearStartPosition(posX, posY, posZ)
        if not startPosition then return false end
        local dx = posX - startPosition.x
        local dz = posZ - startPosition.z
        local horizontalDist = math.sqrt(dx * dx + dz * dz)
        -- 高度差：护栏高度与出生点高度的差值
        local heightDiff = math.abs(posY - startPosition.y)
        -- 水平距离在排除范围内 且 高度差在 ±2 米以内
        local isNear = horizontalDist < startExcludeRadius and heightDiff < startExcludeHeight
        if isNear then
            excludedBarrierCount = excludedBarrierCount + 1
        end
        return isNear
    end
    
    if createBarriers then
        -- 辅助函数：收集护栏段数据并平滑角度
        local function collectAndSmoothBarrierData(barrierPoints, yOffset)
            local numPoints = #barrierPoints
            local barrierData = {}
            
            -- 收集所有段的数据
            for i = 1, totalSegments do
                local idx1 = i
                local idx2 = closedLoop and (i % numPoints + 1) or math.min(i + 1, numPoints)
                
                if idx1 <= numPoints and idx2 <= numPoints then
                    local p1 = barrierPoints[idx1]
                    local p2 = barrierPoints[idx2]
                    
                    local dirX = p2.x - p1.x
                    local dirY = p2.y - p1.y
                    local dirZ = p2.z - p1.z
                    local horizontalLength = math.sqrt(dirX * dirX + dirZ * dirZ)
                    local totalLength = math.sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ)
                    
                    if horizontalLength > 0.01 then
                        table.insert(barrierData, {
                            midX = (p1.x + p2.x) / 2,
                            midY = (p1.y + p2.y) / 2 + yOffset,
                            midZ = (p1.z + p2.z) / 2,
                            length = totalLength,
                            yRotation = math.atan2(dirX, dirZ) * 180 / math.pi,
                            pitchAngle = -math.atan2(dirY, horizontalLength) * 180 / math.pi,
                        })
                    end
                end
            end
            
            -- 平滑角度
            if #barrierData >= 2 then
                local numSegs = #barrierData
                local prevYRot = closedLoop and barrierData[numSegs].yRotation or nil
                local prevPitch = closedLoop and barrierData[numSegs].pitchAngle or nil
                
                for i = 1, numSegs do
                    barrierData[i].yRotation = SmoothAngleTransition(barrierData[i].yRotation, prevYRot)
                    barrierData[i].pitchAngle = SmoothAngleTransition(barrierData[i].pitchAngle, prevPitch)
                    prevYRot = barrierData[i].yRotation
                    prevPitch = barrierData[i].pitchAngle
                end
                
                -- 闭合赛道首尾渐变平滑
                if closedLoop and numSegs >= 4 then
                    local firstYRot = barrierData[1].yRotation
                    local lastYRot = barrierData[numSegs].yRotation
                    local yRotDiff = ShortestAngleDiff(lastYRot, firstYRot)
                    
                    local firstPitch = barrierData[1].pitchAngle
                    local lastPitch = barrierData[numSegs].pitchAngle
                    local pitchDiff = ShortestAngleDiff(lastPitch, firstPitch)
                    
                    if math.abs(yRotDiff) > 3 or math.abs(pitchDiff) > 3 then
                        local blendRange = math.min(math.floor(numSegs / 3), 15)
                        for j = 1, blendRange do
                            local blendFactor = j / blendRange
                            local idx = numSegs - blendRange + j
                            if idx >= 1 then
                                local targetYRot = lastYRot + yRotDiff * blendFactor
                                local targetPitch = lastPitch + pitchDiff * blendFactor
                                barrierData[idx].yRotation = barrierData[idx].yRotation + 
                                    (targetYRot - barrierData[idx].yRotation) * blendFactor
                                barrierData[idx].pitchAngle = barrierData[idx].pitchAngle + 
                                    (targetPitch - barrierData[idx].pitchAngle) * blendFactor
                            end
                        end
                    end
                end
            end
            
            return barrierData
        end
        
        -- 创建左侧护栏
        local leftBarrierData = collectAndSmoothBarrierData(smoothLeftBarrier, barrierHeight / 2)
        for _, seg in ipairs(leftBarrierData) do
            -- 检查是否在起始点附近，如果是则跳过创建围栏
            if not isNearStartPosition(seg.midX, seg.midY, seg.midZ) then
                local barrierPos = Vector3(seg.midX, seg.midY, seg.midZ)
                local barrierSize = Vector3(barrierWidth, barrierHeight, seg.length)
                CreateBarrier(barrierPos, barrierSize, barrierColor, seg.yRotation, seg.pitchAngle)
            end
        end
        
        -- 创建右侧护栏
        local rightBarrierData = collectAndSmoothBarrierData(smoothRightBarrier, barrierHeight / 2)
        for _, seg in ipairs(rightBarrierData) do
            -- 检查是否在起始点附近，如果是则跳过创建围栏
            if not isNearStartPosition(seg.midX, seg.midY, seg.midZ) then
                local barrierPos = Vector3(seg.midX, seg.midY, seg.midZ)
                local barrierSize = Vector3(barrierWidth, barrierHeight, seg.length)
                CreateBarrier(barrierPos, barrierSize, barrierColor, seg.yRotation, seg.pitchAngle)
            end
        end
        
        -- 输出排除的护栏数量
        if excludedBarrierCount > 0 then
            print(string.format("在起始点附近排除了 %d 段护栏 (半径: %.1f米)", excludedBarrierCount, startExcludeRadius))
        end
    end
    
    print(string.format("赛道创建完成: %d 个路段, 宽度 %.1f, 原始点 %d -> 平滑后 %d 点", 
        totalSegments, width, #centerPoints, #smoothCenterPoints))
    return createdNodes
end

--- 根据点数组创建平滑曲线赛道
--- 使用 Catmull-Rom 样条插值生成更平滑的曲线
---@param controlPoints table 控制点数组，每个点是 Vector3
---@param width number 赛道宽度
---@param segmentsPerSpan number|nil 每两个控制点之间的细分数量（默认 10）
---@param options table|nil 可选参数（同 CreateTrackFromPoints）
---@return table 创建的节点列表
function CreateSmoothTrackFromPoints(controlPoints, width, segmentsPerSpan, options)
    if not controlPoints or #controlPoints < 2 then
        print("错误: 创建平滑赛道需要至少2个控制点")
        return {}
    end
    
    segmentsPerSpan = segmentsPerSpan or 10
    
    -- 生成插值点
    local smoothPoints = {}
    local numControl = #controlPoints
    
    for i = 1, numControl - 1 do
        -- Catmull-Rom 样条需要4个点
        local p0 = controlPoints[math.max(1, i - 1)]
        local p1 = controlPoints[i]
        local p2 = controlPoints[math.min(numControl, i + 1)]
        local p3 = controlPoints[math.min(numControl, i + 2)]
        
        for j = 0, segmentsPerSpan - 1 do
            local t = j / segmentsPerSpan
            local point = CatmullRomInterpolate(p0, p1, p2, p3, t)
            table.insert(smoothPoints, point)
        end
    end
    
    -- 添加最后一个点
    table.insert(smoothPoints, controlPoints[numControl])
    
    print(string.format("生成平滑曲线: %d 个控制点 -> %d 个插值点", numControl, #smoothPoints))
    
    -- 使用插值点创建赛道
    return CreateTrackFromPoints(smoothPoints, width, options)
end

--- Catmull-Rom 样条插值
---@param p0 Vector3
---@param p1 Vector3
---@param p2 Vector3
---@param p3 Vector3
---@param t number 插值参数 (0-1)
---@return Vector3
function CatmullRomInterpolate(p0, p1, p2, p3, t)
    local t2 = t * t
    local t3 = t2 * t
    
    local x = 0.5 * ((2 * p1.x) +
        (-p0.x + p2.x) * t +
        (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 +
        (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3)
    
    local y = 0.5 * ((2 * p1.y) +
        (-p0.y + p2.y) * t +
        (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 +
        (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)
    
    local z = 0.5 * ((2 * p1.z) +
        (-p0.z + p2.z) * t +
        (2 * p0.z - 5 * p1.z + 4 * p2.z - p3.z) * t2 +
        (-p0.z + 3 * p1.z - 3 * p2.z + p3.z) * t3)
    
    return Vector3(x, y, z)
end

--- 创建烟雾效果（使用球体替代粒子）
function CreateSmokeEffect()
    -- 创建半透明灰色材质用于烟雾球
    smokeMaterial_ = Material:new()
    
    -- 使用 NoTextureUnlitAlpha 技术支持透明度
    local tech = cache:GetResource("Technique", "Techniques/NoTextureUnlitAlpha.xml")
    if tech then
        smokeMaterial_:SetTechnique(0, tech)
    end
    
    -- 设置灰色半透明颜色
    smokeMaterial_:SetShaderParameter("MatDiffColor", Variant(Color(0.7, 0.7, 0.7, 0.5)))
    
    print("烟雾球体效果已创建")
end

--- 在指定位置生成烟雾球体
---@param position Vector3 世界坐标位置
---@param intensity number 强度 (0-1)
function SpawnSmoke(position, intensity)
    if smokeMaterial_ == nil or scene_ == nil then 
        return 
    end
    
    -- 创建烟雾球节点
    local smokeNode = scene_:CreateChild("TireSmoke")
    smokeNode.position = position
    
    -- 添加随机偏移，使烟雾看起来更自然
    local offsetX = (math.random() - 0.5) * 0.3
    local offsetZ = (math.random() - 0.5) * 0.3
    smokeNode.position = Vector3(position.x + offsetX, position.y + 0.1, position.z + offsetZ)
    
    -- 创建球体模型
    local model = smokeNode:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    
    -- 克隆材质以便独立控制透明度
    local mat = smokeMaterial_:Clone()
    model:SetMaterial(mat)
    
    -- 根据强度设置初始大小
    local baseSize = 0.2 + 0.3 * intensity
    smokeNode.scale = Vector3(baseSize, baseSize, baseSize)
    
    -- 添加到烟雾球列表
    table.insert(smokeBalls_, {
        node = smokeNode,
        material = mat,
        timer = SMOKE_DURATION,
        maxTime = SMOKE_DURATION,
        initialScale = baseSize,
        velocityY = 0.5 + math.random() * 0.5,  -- 向上飘动速度
    })
end

--- 更新所有烟雾球（淡出和移除）
---@param dt number 时间步长
function UpdateSmokeBalls(dt)
    local toRemove = {}
    
    for i, ball in ipairs(smokeBalls_) do
        ball.timer = ball.timer - dt
        
        if ball.timer <= 0 then
            -- 标记为需要移除
            table.insert(toRemove, i)
        else
            -- 计算生命周期比例 (1 -> 0)
            local lifeRatio = ball.timer / ball.maxTime
            
            -- 球体逐渐缩小并淡出
            local scale = ball.initialScale * lifeRatio
            ball.node.scale = Vector3(scale, scale, scale)
            
            -- 更新透明度
            local alpha = lifeRatio * 0.5
            ball.material:SetShaderParameter("MatDiffColor", Variant(Color(0.7, 0.7, 0.7, alpha)))
            
            -- 向上飘动
            local pos = ball.node.position
            pos.y = pos.y + ball.velocityY * dt
            ball.node.position = pos
        end
    end
    
    -- 从后向前移除，避免索引错乱
    for i = #toRemove, 1, -1 do
        local idx = toRemove[i]
        smokeBalls_[idx].node:Remove()
        table.remove(smokeBalls_, idx)
    end
end

-- ============================================================================
-- 5.6 导弹与敌人系统
-- ============================================================================

--- 创建导弹和敌人材质
function CreateMissileAndEnemyMaterials()
    -- 导弹材质（红色发光）
    missileMaterial_ = Material:new()
    missileMaterial_:SetTechnique(0, cache:GetResource("Technique", 
        "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    missileMaterial_:SetShaderParameter("ColorFactor", Variant(Color(1.0, 0.3, 0.1, 1.0)))
    missileMaterial_:SetShaderParameter("MetallicFactor", Variant(0.8))
    missileMaterial_:SetShaderParameter("RoughnessFactor", Variant(0.2))
    
    -- 敌人材质（紫色）
    enemyMaterial_ = Material:new()
    enemyMaterial_:SetTechnique(0, cache:GetResource("Technique", 
        "Editor/Techniques/PBR_PackedNormal/DefaultMetallicRoughness.xml"))
    enemyMaterial_:SetShaderParameter("ColorFactor", Variant(Color(0.6, 0.1, 0.8, 1.0)))
    enemyMaterial_:SetShaderParameter("MetallicFactor", Variant(0.5))
    enemyMaterial_:SetShaderParameter("RoughnessFactor", Variant(0.4))
    
    print("导弹和敌人材质已创建")
end

--- 获取赛道上的随机位置
---@return Vector3|nil 随机位置或 nil
function GetRandomTrackPosition()
    local trackConfig = GetCurrentTrackConfig()
    if not trackConfig then return nil end
    
    local controlPoints = nil
    local sideOffset = 3
    
    -- 获取敌人配置中的偏移量
    if trackConfig.EnemyConfig then
        sideOffset = trackConfig.EnemyConfig.SideOffset or 3
    end
    
    -- 获取控制点
    if trackConfig.PointsType == "ellipse" then
        -- 椭圆赛道：生成控制点
        local radiusX = trackConfig.EllipseRadiusX or 60
        local radiusZ = trackConfig.EllipseRadiusZ or 40
        local numPoints = trackConfig.EllipsePoints or 12
        controlPoints = {}
        for i = 1, numPoints do
            local angle = ((i - 1) / numPoints) * math.pi * 2
            local x = math.sin(angle) * radiusX
            local z = math.cos(angle) * radiusZ
            table.insert(controlPoints, Vector3(x, 0, z))
        end
    elseif trackConfig.PointsType == "points" then
        controlPoints = trackConfig.ControlPoints
    end
    
    if not controlPoints or #controlPoints < 2 then
        return nil
    end
    
    -- 随机选择两个相邻控制点之间的位置
    local numPoints = #controlPoints
    local idx1 = math.random(1, numPoints)
    local idx2 = idx1 % numPoints + 1  -- 下一个点（循环）
    
    local p1 = controlPoints[idx1]
    local p2 = controlPoints[idx2]
    
    -- 在两点之间随机插值
    local t = math.random()
    local posX = p1.x + (p2.x - p1.x) * t
    local posY = p1.y + (p2.y - p1.y) * t
    local posZ = p1.z + (p2.z - p1.z) * t
    
    -- 计算方向向量（用于左右偏移）
    local dirX = p2.x - p1.x
    local dirZ = p2.z - p1.z
    local length = math.sqrt(dirX * dirX + dirZ * dirZ)
    
    if length > 0.01 then
        -- 归一化并计算垂直方向
        local perpX = -dirZ / length
        local perpZ = dirX / length
        
        -- 随机左右偏移
        local offset = (math.random() - 0.5) * 2 * sideOffset
        posX = posX + perpX * offset
        posZ = posZ + perpZ * offset
    end
    
    return Vector3(posX, posY + 1.0, posZ)
end

--- 在赛道随机位置生成敌人（距离车辆至少 15 米）
---@return boolean 是否成功生成
function SpawnEnemyAtRandomPosition()
    if scene_ == nil then return false end
    
    local minDistanceFromVehicle = 10  -- 距离车辆的最小距离
    local maxAttempts = 10  -- 最大尝试次数，避免无限循环
    
    for attempt = 1, maxAttempts do
        -- 获取赛道随机位置
        local spawnPos = GetRandomTrackPosition()
        if not spawnPos then return false end
        
        -- 检查与车辆的距离
        local isFarEnough = true
        if vehicleNode_ then
            local vehiclePos = vehicleNode_.position
            local dx = spawnPos.x - vehiclePos.x
            local dy = spawnPos.y - vehiclePos.y
            local dz = spawnPos.z - vehiclePos.z
            local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
            isFarEnough = distance >= minDistanceFromVehicle
        end
        
        -- 如果距离足够，创建敌人
        if isFarEnough then
            return CreateEnemyAtPosition(spawnPos)
        end
    end
    
    -- 尝试多次仍找不到合适位置，放弃本次生成
    return false
end

--- 在指定位置创建敌人
---@param spawnPos Vector3 生成位置
---@return boolean 是否成功创建
function CreateEnemyAtPosition(spawnPos)
    if scene_ == nil or spawnPos == nil then return false end
    
    -- 创建敌人节点
    local enemyNode = scene_:CreateChild("Enemy")
    enemyNode.position = spawnPos
    
    -- 敌人外观（立方体 + 顶部尖刺）
    local bodyNode = enemyNode:CreateChild("EnemyBody")
    local bodyModel = bodyNode:CreateComponent("StaticModel")
    bodyModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    bodyModel:SetMaterial(enemyMaterial_)
    bodyModel.castShadows = true
    bodyNode.scale = Vector3(ENEMY_CONFIG.Size, ENEMY_CONFIG.Size, ENEMY_CONFIG.Size)
    
    -- 顶部尖刺
    local spikeNode = enemyNode:CreateChild("EnemySpike")
    spikeNode.position = Vector3(0, ENEMY_CONFIG.Size * 0.8, 0)
    spikeNode.scale = Vector3(0.4, 0.8, 0.4)
    local spikeModel = spikeNode:CreateComponent("StaticModel")
    spikeModel:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))
    spikeModel:SetMaterial(enemyMaterial_)
    spikeModel.castShadows = true
    
    -- 添加到敌人列表
    table.insert(enemies_, {
        node = enemyNode,
        position = spawnPos,
        health = 1,
        rotationSpeed = 50 + math.random() * 50,  -- 旋转速度
    })
    
    return true
end

--- 在赛道创建时生成初始敌人
function SpawnInitialEnemies()
    -- 检查战斗系统是否启用
    if not CONFIG.EnableCombatSystem then return end
    
    -- 获取当前赛道配置
    local trackConfig = GetCurrentTrackConfig()
    if not trackConfig then return end
    
    -- 获取敌人配置
    local enemyConfig = trackConfig.EnemyConfig or {}
    local maxEnemies = enemyConfig.MaxEnemies or ENEMY_CONFIG.MaxEnemies
    
    -- 生成初始敌人
    for i = 1, maxEnemies do
        SpawnEnemyAtRandomPosition()
    end
    
    print(string.format("已生成 %d 个敌人", #enemies_))
end

--- 发射导弹
---@return boolean 是否成功发射
function FireMissile()
    if vehicleNode_ == nil or scene_ == nil then
        return false
    end
    
    -- 检查冷却时间
    local currentTime = time.elapsedTime
    if currentTime - lastFireTime_ < MISSILE_CONFIG.FireCooldown then
        return false
    end
    
    -- 搜索前方敌人
    local target = FindNearestEnemy()
    
    -- 创建导弹
    local vehiclePos = vehicleNode_.position
    local vehicleForward = vehicleNode_.rotation * Vector3(0, 0, 1)
    
    -- 导弹从车辆前方发射
    local missilePos = Vector3(
        vehiclePos.x + vehicleForward.x * 2,
        vehiclePos.y + 0.5,
        vehiclePos.z + vehicleForward.z * 2
    )
    
    local missileNode = scene_:CreateChild("Missile")
    missileNode.position = missilePos
    
    -- 导弹模型（细长的圆柱体）
    local missileModel = missileNode:CreateComponent("StaticModel")
    missileModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    missileModel:SetMaterial(missileMaterial_)
    missileModel.castShadows = true
    
    local size = MISSILE_CONFIG.Size
    missileNode.scale = Vector3(size, size * 3, size)
    -- 让导弹横躺（指向前方）
    missileNode.rotation = vehicleNode_.rotation * Quaternion(90, Vector3.RIGHT)
    
    -- 初始方向
    local direction = vehicleForward:Normalized()
    
    -- 添加到导弹列表
    table.insert(missiles_, {
        node = missileNode,
        direction = direction,
        target = target,  -- 可能为 nil
        timer = MISSILE_CONFIG.LifeTime,
        speed = MISSILE_CONFIG.Speed,
    })
    
    lastFireTime_ = currentTime
    
    -- 发射音效提示
    -- print("导弹发射！" .. (target and "锁定目标" or "无目标"))
    
    return true
end

--- 搜索最近的敌人（在车辆前方范围内）
---@return table|nil 敌人数据或 nil
function FindNearestEnemy()
    if vehicleNode_ == nil or #enemies_ == 0 then
        return nil
    end
    
    local vehiclePos = vehicleNode_.position
    local vehicleForward = vehicleNode_.rotation * Vector3(0, 0, 1)
    vehicleForward.y = 0
    vehicleForward:Normalize()
    
    local nearestEnemy = nil
    local nearestDist = MISSILE_CONFIG.SearchRange
    
    for _, enemy in ipairs(enemies_) do
        if enemy.node then
            local enemyPos = enemy.node.position
            local toEnemy = enemyPos - vehiclePos
            local dist = toEnemy:Length()
            
            -- 检查距离
            if dist < nearestDist then
                -- 检查是否在前方（点积 > 0）
                toEnemy.y = 0
                toEnemy:Normalize()
                local dot = vehicleForward:DotProduct(toEnemy)
                
                if dot > 0.3 then  -- 前方约 72 度范围内
                    nearestDist = dist
                    nearestEnemy = enemy
                end
            end
        end
    end
    
    return nearestEnemy
end

--- 更新所有导弹
---@param dt number 时间步长
function UpdateMissiles(dt)
    local toRemove = {}
    
    for i, missile in ipairs(missiles_) do
        missile.timer = missile.timer - dt
        
        if missile.timer <= 0 or missile.node == nil then
            table.insert(toRemove, i)
        else
            -- 如果有目标，追踪目标
            if missile.target and missile.target.node then
                local missilePos = missile.node.position
                local targetPos = missile.target.node.position
                local toTarget = targetPos - missilePos
                local dist = toTarget:Length()
                
                -- 检查是否击中
                if dist < ENEMY_CONFIG.HitRadius then
                    -- 击中敌人！
                    OnMissileHit(missile, missile.target)
                    table.insert(toRemove, i)
                else
                    -- 追踪目标
                    toTarget:Normalize()
                    missile.direction = missile.direction + (toTarget - missile.direction) * 
                        math.min(1.0, dt * MISSILE_CONFIG.TurnSpeed)
                    missile.direction:Normalize()
                end
            end
            
            -- 移动导弹
            local pos = missile.node.position
            pos = pos + missile.direction * missile.speed * dt
            missile.node.position = pos
            
            -- 更新导弹朝向
            if missile.direction:Length() > 0.01 then
                local lookTarget = pos + missile.direction
                missile.node:LookAt(lookTarget)
                -- 修正旋转（让圆柱体尖端指向前方）
                missile.node.rotation = missile.node.rotation * Quaternion(90, Vector3.RIGHT)
            end
            
            -- 检查是否超出范围或低于地面
            if pos.y < -5 or pos:Length() > 500 then
                table.insert(toRemove, i)
            end
        end
    end
    
    -- 移除失效导弹
    for i = #toRemove, 1, -1 do
        local idx = toRemove[i]
        if missiles_[idx].node then
            missiles_[idx].node:Remove()
        end
        table.remove(missiles_, idx)
    end
end

--- 导弹击中敌人
---@param missile table 导弹数据
---@param enemy table 敌人数据
function OnMissileHit(missile, enemy)
    -- 检查敌人是否已死亡（被其他导弹击中）
    if enemy.node == nil or enemy.health <= 0 then
        return
    end
    
    -- 标记敌人已死亡
    enemy.health = 0
    
    -- 增加分数
    gameScore_ = gameScore_ + ENEMY_CONFIG.ScorePerKill
    totalKills_ = totalKills_ + 1
    
    -- 创建爆炸效果
    local explosionPos = enemy.node.position
    CreateExplosion(explosionPos)
    
    -- 移除敌人
    if enemy.node then
        enemy.node:Remove()
    end
    
    -- 从敌人列表中移除
    for i, e in ipairs(enemies_) do
        if e == enemy then
            table.remove(enemies_, i)
            break
        end
    end
    
    -- 移除导弹
    if missile.node then
        missile.node:Remove()
    end
    
    -- 在赛道随机位置生成新敌人
    SpawnEnemyAtRandomPosition()
    
    print("击杀敌人！得分: " .. gameScore_)
end

--- 创建爆炸效果
---@param position Vector3 爆炸位置
function CreateExplosion(position)
    -- 创建多个爆炸球体
    for j = 1, 8 do
        local explosionNode = scene_:CreateChild("Explosion")
        
        -- 随机偏移
        local offset = Vector3(
            (math.random() - 0.5) * 2,
            math.random() * 1.5,
            (math.random() - 0.5) * 2
        )
        explosionNode.position = position + offset
        
        local model = explosionNode:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        
        -- 爆炸材质（橙黄色）
        local explosionMat = Material:new()
        local tech = cache:GetResource("Technique", "Techniques/NoTextureUnlitAlpha.xml")
        if tech then
            explosionMat:SetTechnique(0, tech)
        end
        local r = 1.0
        local g = 0.5 + math.random() * 0.5
        local b = 0.1
        explosionMat:SetShaderParameter("MatDiffColor", Variant(Color(r, g, b, 0.8)))
        model:SetMaterial(explosionMat)
        
        local baseSize = 0.5 + math.random() * 0.5
        explosionNode.scale = Vector3(baseSize, baseSize, baseSize)
        
        table.insert(explosionBalls_, {
            node = explosionNode,
            material = explosionMat,
            timer = 0.5 + math.random() * 0.3,
            maxTime = 0.5,
            initialScale = baseSize,
            velocityY = 2 + math.random() * 2,
        })
    end
end

--- 更新爆炸效果
---@param dt number 时间步长
function UpdateExplosions(dt)
    local toRemove = {}
    
    for i, ball in ipairs(explosionBalls_) do
        ball.timer = ball.timer - dt
        
        if ball.timer <= 0 then
            table.insert(toRemove, i)
        else
            local lifeRatio = ball.timer / ball.maxTime
            
            -- 扩大并淡出
            local scale = ball.initialScale * (1 + (1 - lifeRatio) * 2)
            ball.node.scale = Vector3(scale, scale, scale)
            
            local alpha = lifeRatio * 0.8
            ball.material:SetShaderParameter("MatDiffColor", 
                Variant(Color(1.0, 0.6 * lifeRatio, 0.1, alpha)))
            
            -- 向上飘动
            local pos = ball.node.position
            pos.y = pos.y + ball.velocityY * dt
            ball.node.position = pos
        end
    end
    
    for i = #toRemove, 1, -1 do
        local idx = toRemove[i]
        explosionBalls_[idx].node:Remove()
        table.remove(explosionBalls_, idx)
    end
end

--- 更新敌人（旋转动画等）
---@param dt number 时间步长
function UpdateEnemies(dt)
    for _, enemy in ipairs(enemies_) do
        if enemy.node then
            -- 敌人旋转动画
            local rot = enemy.node.rotation
            enemy.node.rotation = rot * Quaternion(enemy.rotationSpeed * dt, Vector3.UP)
            
            -- 上下浮动
            local pos = enemy.node.position
            pos.y = enemy.position.y + math.sin(time.elapsedTime * 2) * 0.3
            enemy.node.position = pos
        end
    end
end

--- 清除所有导弹和敌人
function ClearMissilesAndEnemies()
    -- 清除导弹
    for _, missile in ipairs(missiles_) do
        if missile.node then
            missile.node:Remove()
        end
    end
    missiles_ = {}
    
    -- 清除敌人
    for _, enemy in ipairs(enemies_) do
        if enemy.node then
            enemy.node:Remove()
        end
    end
    enemies_ = {}
    
    -- 清除爆炸效果
    for _, ball in ipairs(explosionBalls_) do
        if ball.node then
            ball.node:Remove()
        end
    end
    explosionBalls_ = {}
end

-- ============================================================================
-- 6. 事件处理
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    
    -- ========================================
    -- 检测鼠标点击（用于配置面板）
    -- ========================================
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        HandleMouseClick()
    end
    
    -- 检测鼠标释放
    if input:GetMouseButtonDown(MOUSEB_LEFT) == false and sliderDragging_ then
        sliderDragging_ = false
        activeSlider_ = nil
    end
    
    if vehicle_ == nil then return end
    
    -- 更新计时
    if raceStarted_ then
        lapTime_ = lapTime_ + dt
    end
    
    -- 获取输入
    local frontEngineForce = 0
    local rearEngineForce = 0
    local brakeForce = 0
    local targetSteering = 0
    
    -- 前进/后退
    if input:GetKeyDown(KEY_UP) or input:GetKeyDown(KEY_W) then
        frontEngineForce = CONFIG.FrontEngineForce  -- 前轮动力 2000
        rearEngineForce = CONFIG.RearEngineForce    -- 后轮动力 1000
        raceStarted_ = true
    end
    if input:GetKeyDown(KEY_DOWN) or input:GetKeyDown(KEY_S) then
        frontEngineForce = -CONFIG.FrontEngineForce * 0.5  -- 倒车力度减半
        rearEngineForce = -CONFIG.RearEngineForce * 0.5
    end
    
    -- 刹车
    if input:GetKeyDown(KEY_SPACE) then
        brakeForce = CONFIG.BrakeForce
    end
    
    -- 转向（正值=左转，负值=右转）
    if input:GetKeyDown(KEY_LEFT) or input:GetKeyDown(KEY_A) then
        targetSteering = -CONFIG.MaxSteeringAngle  -- 左转
    end
    if input:GetKeyDown(KEY_RIGHT) or input:GetKeyDown(KEY_D) then
        targetSteering = CONFIG.MaxSteeringAngle   -- 右转
    end
    
    -- ========================================
    -- 摩擦力系统（基于速度，前后轮分开）
    -- ========================================
    -- 计算速度比例（0 = 静止，1 = 最高速度）
    local speedRatio = math.min(1.0, currentSpeed_ / CONFIG.FrictionDropSpeed)
    
    -- 前轮摩擦力：0.8 ~ 1.2（保持较高以确保转向）
    frontBaseFriction_ = CONFIG.FrontBaseFriction - 
        (CONFIG.FrontBaseFriction - CONFIG.FrontMinFriction) * speedRatio
    
    -- 后轮摩擦力：0.4 ~ 1.0（较低使后轮更容易打滑）
    rearBaseFriction_ = CONFIG.RearBaseFriction - 
        (CONFIG.RearBaseFriction - CONFIG.RearMinFriction) * speedRatio
    
    -- ========================================
    -- 漂移系统
    -- ========================================
    -- 漂移条件：按住 Shift 或 漂移按钮 + 有足够速度 + 正在转向
    local wantDrift = (input:GetKeyDown(KEY_LSHIFT) or driftButtonPressed_) and 
                      currentSpeed_ > CONFIG.DriftMinSpeed and 
                      math.abs(targetSteering) > 0.1
    
    local targetFrontFriction = frontBaseFriction_
    local targetRearFriction = rearBaseFriction_
    
    if wantDrift then
        -- 进入漂移状态
        isDrifting_ = true
        -- 漂移时摩擦力进一步降低
        targetFrontFriction = frontBaseFriction_ * CONFIG.DriftFrictionMultiplier
        targetRearFriction = rearBaseFriction_ * CONFIG.DriftFrictionMultiplier
        
        -- 漂移时增强转向
        targetSteering = targetSteering * CONFIG.DriftSteeringBoost
        
        -- 计算漂移强度（根据后轮侧滑速度）
        local sideSlipL = math.abs(vehicle_:GetWheelSideSlipSpeed(2))
        local sideSlipR = math.abs(vehicle_:GetWheelSideSlipSpeed(3))
        driftIntensity_ = math.min(1.0, (sideSlipL + sideSlipR) / 15.0)
    else
        -- 退出漂移状态
        isDrifting_ = false
        driftIntensity_ = math.max(0, driftIntensity_ - dt * 3.0)  -- 渐出
        
        -- 非漂移状态下，速度越快转向越低，最低60%
        local steeringFactor = 1.0 - speedRatio * 0.5  -- 从100%降到60%
        targetSteering = targetSteering * steeringFactor
    end
    
    -- 平滑过渡摩擦力（避免突然变化导致车辆失控）
	local drift_rate = dt * CONFIG.DriftRecoverySpeed
	--print('drift_rate\t ' .. dt .. ' ,\t' .. drift_rate)
    local smoothFactor = math.min(1.0, drift_rate)
    currentFrontFriction_ = currentFrontFriction_ + 
        (targetFrontFriction - currentFrontFriction_) * smoothFactor
    currentRearFriction_ = currentRearFriction_ + 
        (targetRearFriction - currentRearFriction_) * smoothFactor
    
    -- 应用前轮摩擦力（0, 1）
    vehicle_:SetWheelFrictionSlip(0, currentFrontFriction_)
    vehicle_:SetWheelFrictionSlip(1, currentFrontFriction_)
    
    -- 应用后轮摩擦力（2, 3）
    vehicle_:SetWheelFrictionSlip(2, currentRearFriction_)
    vehicle_:SetWheelFrictionSlip(3, currentRearFriction_)
    
    -- 平滑转向
    currentSteering_ = currentSteering_ + (targetSteering - currentSteering_) * 
        math.min(1.0, dt * CONFIG.SteeringSpeed * 10)
    
    -- 应用到车轮
    -- 前轮（0, 1）用于转向
    vehicle_:SetSteeringValue(0, currentSteering_)
    vehicle_:SetSteeringValue(1, currentSteering_)
    
    -- 获取刚体
    local body = vehicleNode_:GetComponent("RigidBody")
    
    -- ========================================
    -- 向车身中心施加合力
    -- ========================================
    if body then
        -- 检测轮胎是否接地
        local frontWheelsGrounded = vehicle_:WheelIsGrounded(0) or vehicle_:WheelIsGrounded(1)
        local rearWheelsGrounded = vehicle_:WheelIsGrounded(2) or vehicle_:WheelIsGrounded(3)
        local anyWheelGrounded = frontWheelsGrounded or rearWheelsGrounded
        
        -- 车身前进方向（后轮驱动方向）
        local bodyForward = vehicleNode_.rotation * Vector3(0, 0, 1)
        bodyForward.y = 0
        bodyForward:Normalize()
        
        -- 前轮方向（考虑转向角度）
        local steerRotation = Quaternion(currentSteering_ * 180 / math.pi, Vector3.UP)
        local frontWheelDir = vehicleNode_.rotation * steerRotation * Vector3(0, 0, 1)
        frontWheelDir.y = 0
        frontWheelDir:Normalize()
        
        -- 根据轮胎接地情况计算动力
        --local actualFrontForce = frontWheelsGrounded and frontEngineForce or 0
        --local actualRearForce = rearWheelsGrounded and rearEngineForce or 0
        local actualFrontForce = frontEngineForce
        local actualRearForce = rearEngineForce
        
        -- 计算前轮力向量
        local frontForce = frontWheelDir * actualFrontForce
        
        -- 计算后轮力向量
        local rearForce = bodyForward * actualRearForce
        
        -- 合力 = 前轮力 + 后轮力
        local totalForce = frontForce + rearForce

        -- 漂移降低摩擦力后的代偿（只在有轮接地时应用）
        if anyWheelGrounded then
            totalForce = totalForce / (CONFIG.DriftRecoverySpeed^CONFIG.DriftForceCompensation)
        end
        
        -- ========================================
        -- 滑行转弯速度保持
        -- ========================================
        -- 条件：没有动力输入 + 正在转向 + 有一定速度 + 没有刹车 + 有轮子接地
        local isCoasting = (frontEngineForce == 0 and rearEngineForce == 0)
        local isTurning = math.abs(currentSteering_) > 0.05
        local hasSpeed = currentSpeed_ > 5
        local noBrake = brakeForce == 0
        
        if isCoasting and isTurning and hasSpeed and noBrake and anyWheelGrounded then
            -- 计算当前速度方向
            local velocity = body.linearVelocity
            local speed = velocity:Length()
            
            if speed > 0.5 then
                -- 沿速度方向施加一个小的保持力，抵消部分摩擦力损耗
                local velocityDir = velocity:Normalized()
                -- 保持力大小 = 车重 * 保持率 * 转向比例
                local steerRatio = math.abs(currentSteering_) / CONFIG.MaxSteeringAngle
                local retainForce = CONFIG.VehicleMass * CONFIG.CoastTurnSpeedRetain * steerRatio
                local coastForce = velocityDir * retainForce
                totalForce = totalForce + coastForce
            end
        end
        
        -- 施加合力到车身中心
        if totalForce:Length() > 0 then
            body:ApplyForce(totalForce)
        end
        
        -- ========================================
        -- 刹车力（与速度方向相反，只在有轮接地时生效）
        -- ========================================
        if brakeForce > 0 and anyWheelGrounded then
            local velocity = body.linearVelocity
            local speed = velocity:Length()
            if speed > 0.5 then
                local brakeDir = velocity:Normalized() * (-1)
                local actualBrakeForce = brakeDir * brakeForce * 10
                body:ApplyForce(actualBrakeForce)
            end
        end
    end
    
    -- 轮子不再提供动力，只保留刹车
    for i = 0, 3 do
        vehicle_:SetEngineForce(i, 0)
        vehicle_:SetBrake(i, brakeForce)
    end
    if body then
        local velocity = body.linearVelocity
        currentSpeed_ = velocity:Length() * 3.6  -- m/s -> km/h
        
        -- ========================================
        -- 翻车保护系统
        -- ========================================
        local euler = vehicleNode_.rotation:EulerAngles()
        local roll = euler.z   -- 侧翻角度
        local pitch = euler.x  -- 俯仰角度
        
        -- 检测是否接近翻车
        local rollExcess = math.abs(roll) - CONFIG.MaxRollAngle
        local pitchExcess = math.abs(pitch) - CONFIG.MaxPitchAngle
        
        -- 侧翻修正
        if rollExcess > 0 then
            -- 计算修正力（角度越大，力越大）
            local correctionStrength = math.min(1.0, rollExcess / 30.0)
            local rollSign = roll > 0 and -1 or 1
            
            -- 应用修正扭矩（让车回正）
            local torque = Vector3(0, 0, rollSign * CONFIG.AntiRollTorque * correctionStrength)
            body:ApplyTorque(torque)
            
            -- 同时减少角速度
            local angVel = body.angularVelocity
            body.angularVelocity = Vector3(angVel.x * 0.95, angVel.y, angVel.z * 0.9)
        end
        
        -- 俯仰修正
        if pitchExcess > 0 then
            local correctionStrength = math.min(1.0, pitchExcess / 30.0)
            local pitchSign = pitch > 0 and -1 or 1
            
            local torque = Vector3(pitchSign * CONFIG.AntiRollTorque * correctionStrength, 0, 0)
            body:ApplyTorque(torque)
            
            local angVel = body.angularVelocity
            body.angularVelocity = Vector3(angVel.x * 0.9, angVel.y, angVel.z * 0.95)
        end
        
        -- 完全翻车检测（角度超过 90 度）- 自动重置
        if math.abs(roll) > 80 or math.abs(pitch) > 80 then
            -- 车辆完全翻车，3秒后自动重置位置
            -- 这里简单处理：直接修正姿态
            local pos = vehicleNode_.position
            vehicleNode_.position = Vector3(pos.x, pos.y + 1.0, pos.z)
            vehicleNode_.rotation = Quaternion(euler.y, Vector3.UP)  -- 只保留 yaw
            body.linearVelocity = Vector3.ZERO
            body.angularVelocity = Vector3.ZERO
            print("翻车自动修正")
        end
    end
    
    -- 更新轮子变换
    for i = 0, 3 do
        vehicle_:UpdateWheelTransform(i, true)
    end
    
    -- ========================================
    -- 轮胎烟雾生成（当运动方向与车身方向不同步时）
    -- ========================================
    smokeTimer_ = smokeTimer_ + dt
    
    -- 计算运动方向与车身方向的偏差角度
    local slipAngle = 0
    local shouldSmoke = false
    
    if body and currentSpeed_ > 5 then
        -- 获取车身前进方向（局部Z轴在世界坐标系中的方向）
        local bodyForward = vehicleNode_.rotation * Vector3(0, 0, 1)
        bodyForward.y = 0
        bodyForward:Normalize()
        
        -- 获取实际运动方向
        local velocity = body.linearVelocity
        local velocityXZ = Vector3(velocity.x, 0, velocity.z)
        local speed = velocityXZ:Length()
        
        if speed > 1 then
            velocityXZ:Normalize()
            
            -- 计算夹角（点积 -> 角度）
            local dot = bodyForward:DotProduct(velocityXZ)
            dot = math.max(-1, math.min(1, dot))  -- 限制在 [-1, 1] 范围
            slipAngle = math.acos(dot) * 180 / math.pi  -- 转换为度数
            
            -- 当偏差角度大于阈值时生成烟雾（15度以上开始产生轻微烟雾）
            local SLIP_THRESHOLD = 5  -- 开始产生烟雾的角度阈值
            shouldSmoke = slipAngle > SLIP_THRESHOLD and currentSpeed_ > SMOKE_MIN_SPEED
        end
    end
    
    if smokeTimer_ >= SMOKE_INTERVAL and shouldSmoke then
        smokeTimer_ = 0
        
        -- 计算烟雾强度（基于偏差角度，角度越大烟雾越浓）
        -- 15度开始产生烟雾，45度达到最大强度
        local angleIntensity = math.min(1.0, (slipAngle - 15) / 30)
        local speedIntensity = math.min(1.0, currentSpeed_ / 80)
        local intensity = angleIntensity * speedIntensity
        
        -- 只在后轮生成烟雾（后轮打滑更明显）
        for i = 0, 3 do  -- 索引 2, 3 是后轮
            local wheelPos = vehicle_:GetWheelPosition(i)
            -- 将位置放到地面附近
            local groundPos = Vector3(wheelPos.x, wheelPos.y - 0.4, wheelPos.z)
            
            -- 生成烟雾球体
            SpawnSmoke(groundPos, intensity)
        end
    end
    
    -- 更新烟雾球（淡出和移除）
    UpdateSmokeBalls(dt)
    
    -- ========================================
    -- 导弹与敌人系统更新（仅在启用时）
    -- ========================================
    if CONFIG.EnableCombatSystem then
        -- 自动发射导弹：检测到前方敌人时自动发射
        local nearestEnemy = FindNearestEnemy()
        if nearestEnemy then
            -- 有敌人在范围内，自动发射（受冷却限制）
            FireMissile()
        end
        
        -- 手动发射导弹（按 F 键或发射按钮）- 即使没有目标也可以发射
        if input:GetKeyPress(KEY_F) or (fireButtonPressed_ and input:GetMouseButtonPress(MOUSEB_LEFT)) then
            FireMissile()
        end
        
        -- 更新导弹
        UpdateMissiles(dt)
        
        -- 更新敌人
        UpdateEnemies(dt)
        
        -- 更新爆炸效果
        UpdateExplosions(dt)
    end
end

---@param eventType string
---@param eventData PostUpdateEventData
function HandlePostUpdate(eventType, eventData)
    if vehicleNode_ == nil or cameraNode_ == nil then return end
    
    local dt = eventData["TimeStep"]:GetFloat()
    
    -- 计算目标相机位置（在车辆后上方）
    local vehiclePos = vehicleNode_.position
    local vehicleRot = vehicleNode_.rotation
    
    -- 相机在车辆后方（使用世界坐标偏移，不随车辆翻滚）
    -- 只使用车辆的 Yaw（水平旋转），忽略 Pitch 和 Roll
    local vehicleEuler = vehicleRot:EulerAngles()
    local yawOnly = Quaternion(vehicleEuler.y, Vector3.UP)
    
    local cameraOffset = yawOnly * Vector3(0, CONFIG.CameraHeight, -CONFIG.CameraDistance)
    local targetPos = vehiclePos + cameraOffset
    
    -- 平滑移动相机
    local currentPos = cameraNode_.position
    local smoothness = CONFIG.CameraSmoothness * dt
    cameraNode_.position = currentPos + (targetPos - currentPos) * math.min(1.0, smoothness)
    
    -- 相机看向车辆（使用 LookAt 方法）
    local lookAtPos = vehiclePos + Vector3(0, 1, 0)
    cameraNode_:LookAt(lookAtPos)
end

---@param eventType string
---@param eventData KeyDownEventData
function HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    
    -- R 键重置位置
    if key == KEY_R then
        ResetVehicle()
    end
    
    -- O 键打开/关闭配置面板
    if key == KEY_O then
        configPanelOpen_ = not configPanelOpen_
        print("配置面板: " .. (configPanelOpen_ and "打开" or "关闭"))
    end
    
    -- 数字键 1-9 切换赛道
    if key >= KEY_1 and key <= KEY_9 then
        local trackIndex = key - KEY_1 + 1
        if trackIndex <= GetTrackCount() and trackIndex ~= currentTrackIndex_ then
            SwitchTrack(trackIndex)
        end
    end
    
    -- ESC 退出
    if key == KEY_ESCAPE then
        engine:Exit()
    end
end

function ResetVehicle()
    if vehicleNode_ == nil then return end
    
    -- 从赛道配置获取起点位置
    local trackConfig = GetCurrentTrackConfig()
    if trackConfig and trackConfig.StartPosition then
        vehicleNode_.position = trackConfig.StartPosition
        vehicleNode_.rotation = Quaternion(trackConfig.StartRotation or 0, Vector3.UP)
    else
        vehicleNode_.position = Vector3(0, 2, 38)
        vehicleNode_.rotation = Quaternion()
    end
    
    local body = vehicleNode_:GetComponent("RigidBody")
    if body then
        body.linearVelocity = Vector3.ZERO
        body.angularVelocity = Vector3.ZERO
    end
    
    currentSpeed_ = 0
    currentSteering_ = 0
    
    -- 重置比赛状态
    lapTime_ = 0
    checkpointsPassed_ = 0
    raceStarted_ = false
    
    -- 清除导弹和敌人（可选，如果想保留分数就注释掉）
    ClearMissilesAndEnemies()
    
    vehicle_:ResetSuspension()
end

-- ============================================================================
-- 7. UI 渲染
-- ============================================================================

---@param eventType string
---@param eventData table
function HandleRender(eventType, eventData)
    if nvg_ == nil then return end
    
    local width = graphics.width
    local height = graphics.height
    
    nvgBeginFrame(nvg_, width, height, 1.0)
    
    DrawHUD(width, height)
    DrawSpeedometer(width, height)
    DrawMinimap(width, height)
    DrawDebugStatus(width, height)  -- 调试状态面板
    DrawConfigButton(width, height) -- 配置按钮
    DrawCarSelectButtons(width, height) -- 车辆配置选择按钮
    DrawTrackSelectButtons(width, height) -- 赛道选择按钮
    DrawDriftButton(width, height)  -- 漂移按钮（右下角）
    if CONFIG.EnableCombatSystem then
        DrawFireButton(width, height)   -- 发射按钮（漂移按钮左侧）
        DrawScorePanel(width, height)   -- 分数面板（右上角）
    end
    DrawResetButton(width, height)  -- 重置按钮（右上角）
    
    if configPanelOpen_ then
        DrawConfigPanel(width, height)  -- 配置面板
    end
    
    nvgEndFrame(nvg_)
end

function DrawHUD(width, height)
    nvgFontFace(nvg_, "sans")
    
    -- 标题
    nvgFontSize(nvg_, 28)
    nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
    nvgText(nvg_, width / 2, 20, "🏎️ 3D 赛车游戏", nil)
    
    -- 操作提示
    nvgFontSize(nvg_, 16)
    nvgTextAlign(nvg_, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg_, nvgRGBA(200, 200, 200, 200))
    nvgText(nvg_, 20, 20, "方向键/WASD: 控制 | 空格: 刹车 | Shift: 漂移 | 导弹自动发射", nil)
    nvgText(nvg_, 20, 40, "R: 重置 | O: 配置 | 1-6: 切换赛道", nil)
    
    -- 当前赛道名称
    local trackConfig = GetCurrentTrackConfig()
    if trackConfig then
        nvgFontSize(nvg_, 16)
        nvgFillColor(nvg_, nvgRGBA(255, 180, 100, 255))
        nvgText(nvg_, 20, 60, "赛道: " .. trackConfig.Name, nil)
    end
    
    -- 圈数时间
    nvgFontSize(nvg_, 20)
    nvgTextAlign(nvg_, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 100, 255))
    local timeStr = string.format("时间: %.2f 秒", lapTime_)
    nvgText(nvg_, 20, 80, timeStr, nil)
    
    if bestLapTime_ < 999999 then
        nvgFillColor(nvg_, nvgRGBA(100, 255, 100, 255))
        local bestStr = string.format("最佳: %.2f 秒", bestLapTime_)
        nvgText(nvg_, 20, 105, bestStr, nil)
    end
    
    -- 漂移状态显示
    if isDrifting_ or driftIntensity_ > 0.1 then
        -- 漂移指示器背景
        local driftAlpha = math.floor(200 * driftIntensity_)
        nvgBeginPath(nvg_)
        nvgRoundedRect(nvg_, width / 2 - 80, height - 80, 160, 40, 8)
        nvgFillColor(nvg_, nvgRGBA(255, 100, 50, math.floor(driftAlpha * 0.5)))
        nvgFill(nvg_)
        
        -- 漂移文字
        nvgFontSize(nvg_, 24)
        nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg_, nvgRGBA(255, 200, 100, 50 + driftAlpha))
        nvgText(nvg_, width / 2, height - 60, "🔥 DRIFT!", nil)
        
        -- 漂移强度条
        nvgBeginPath(nvg_)
        nvgRoundedRect(nvg_, width / 2 - 60, height - 45, 120 * driftIntensity_, 6, 3)
        nvgFillColor(nvg_, nvgRGBA(255, 150, 50, 200))
        nvgFill(nvg_)
    end
end

function DrawSpeedometer(width, height)
    -- 移动到左下角（在调试面板上方）
    local centerX = 200
    local centerY = height - 200
    local radius = 150
    
    -- 背景圆
    nvgBeginPath(nvg_)
    nvgCircle(nvg_, centerX, centerY, radius)
    nvgFillColor(nvg_, nvgRGBA(20, 20, 30, 200))
    nvgFill(nvg_)
    
    -- 边框
    nvgStrokeColor(nvg_, nvgRGBA(100, 150, 255, 255))
    nvgStrokeWidth(nvg_, 3)
    nvgStroke(nvg_)
    
    -- 速度弧线
    local maxSpeed = 200  -- 最大显示速度 km/h
    local speedRatio = math.min(1.0, currentSpeed_ / maxSpeed)
    local startAngle = math.pi * 0.75
    local endAngle = startAngle + speedRatio * math.pi * 1.5
    
    nvgBeginPath(nvg_)
    nvgArc(nvg_, centerX, centerY, radius - 10, startAngle, endAngle, NVG_CW)
    nvgStrokeColor(nvg_, nvgRGBA(100, 255, 150, 255))
    nvgStrokeWidth(nvg_, 8)
    nvgStroke(nvg_)
    
    -- 速度数字
    nvgFontFace(nvg_, "sans")
    nvgFontSize(nvg_, 32)
    nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
    local speedText = string.format("%d", math.floor(currentSpeed_))
    nvgText(nvg_, centerX, centerY - 10, speedText, nil)
    
    -- km/h 标签
    nvgFontSize(nvg_, 14)
    nvgFillColor(nvg_, nvgRGBA(180, 180, 180, 255))
    nvgText(nvg_, centerX, centerY + 20, "km/h", nil)
    
    -- 车辆坐标显示
    if vehicleNode_ then
        local pos = vehicleNode_.position
        nvgFontSize(nvg_, 12)
        nvgFillColor(nvg_, nvgRGBA(150, 200, 255, 200))
        local posText = string.format("X: %.2f  Z: %.2f", pos.x, pos.z)
        nvgText(nvg_, centerX, centerY + -100, posText, nil)
        local heightText = string.format("Y: %.2f", pos.y)
        nvgText(nvg_, centerX, centerY + 60, heightText, nil)
    end
end

function DrawMinimap(width, height)
    local mapSize = 120
    local mapX = width - mapSize - 20
    local mapY = 20
    local scale = 0.6  -- 地图缩放
    
    -- 背景
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, mapX, mapY, mapSize, mapSize, 5)
    nvgFillColor(nvg_, nvgRGBA(30, 40, 30, 200))
    nvgFill(nvg_)
    nvgStrokeColor(nvg_, nvgRGBA(100, 150, 100, 200))
    nvgStrokeWidth(nvg_, 2)
    nvgStroke(nvg_)
    
    -- 赛道简化显示
    local mapCenterX = mapX + mapSize / 2
    local mapCenterY = mapY + mapSize / 2
    
    nvgStrokeColor(nvg_, nvgRGBA(80, 80, 90, 255))
    nvgStrokeWidth(nvg_, 8)
    
    -- 简化赛道轮廓
    nvgBeginPath(nvg_)
    nvgMoveTo(nvg_, mapCenterX - 20 * scale, mapCenterY + 30 * scale)
    nvgLineTo(nvg_, mapCenterX - 20 * scale, mapCenterY - 30 * scale)
    nvgLineTo(nvg_, mapCenterX + 20 * scale, mapCenterY - 30 * scale)
    nvgLineTo(nvg_, mapCenterX + 20 * scale, mapCenterY + 30 * scale)
    nvgClosePath(nvg_)
    nvgStroke(nvg_)
    
    -- 车辆位置
    if vehicleNode_ then
        local vPos = vehicleNode_.position
        local dotX = mapCenterX + vPos.x * scale
        local dotY = mapCenterY - vPos.z * scale  -- Z轴方向相反
        
        -- 限制在地图范围内
        dotX = math.max(mapX + 5, math.min(mapX + mapSize - 5, dotX))
        dotY = math.max(mapY + 5, math.min(mapY + mapSize - 5, dotY))
        
        nvgBeginPath(nvg_)
        nvgCircle(nvg_, dotX, dotY, 4)
        nvgFillColor(nvg_, nvgRGBA(255, 100, 100, 255))
        nvgFill(nvg_)
    end
end

--- 绘制调试状态面板
function DrawDebugStatus(width, height)
    local panelWidth = 280
    local panelHeight = 160  -- 增加高度以容纳前轮摩擦力
    local panelX = 20
    local panelY = height - panelHeight - 50
    
    -- 面板背景
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, panelX, panelY, panelWidth, panelHeight, 8)
    nvgFillColor(nvg_, nvgRGBA(0, 0, 0, 180))
    nvgFill(nvg_)
    nvgStrokeColor(nvg_, nvgRGBA(100, 100, 100, 200))
    nvgStrokeWidth(nvg_, 1)
    nvgStroke(nvg_)
    
    -- 标题
    nvgFontFace(nvg_, "sans")
    nvgFontSize(nvg_, 16)
    nvgTextAlign(nvg_, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg_, nvgRGBA(150, 150, 150, 255))
    nvgText(nvg_, panelX + 10, panelY + 8, "📊 调试状态", nil)
    
    -- 分隔线
    nvgBeginPath(nvg_)
    nvgMoveTo(nvg_, panelX + 10, panelY + 30)
    nvgLineTo(nvg_, panelX + panelWidth - 10, panelY + 30)
    nvgStrokeColor(nvg_, nvgRGBA(80, 80, 80, 255))
    nvgStrokeWidth(nvg_, 1)
    nvgStroke(nvg_)
    
    -- 状态信息
    nvgFontSize(nvg_, 14)
    local lineHeight = 20
    local startY = panelY + 40
    
    -- 漂移状态（带颜色指示）
    local driftStatus = isDrifting_ and "是 ✓" or "否"
    local driftColor = isDrifting_ and nvgRGBA(100, 255, 100, 255) or nvgRGBA(200, 200, 200, 255)
    nvgFillColor(nvg_, nvgRGBA(200, 200, 200, 255))
    nvgText(nvg_, panelX + 10, startY, "漂移状态:", nil)
    nvgFillColor(nvg_, driftColor)
    nvgText(nvg_, panelX + 100, startY, driftStatus, nil)
    
    -- 漂移强度
    nvgFillColor(nvg_, nvgRGBA(200, 200, 200, 255))
    nvgText(nvg_, panelX + 10, startY + lineHeight, "漂移强度:", nil)
    nvgFillColor(nvg_, nvgRGBA(255, 200, 100, 255))
    nvgText(nvg_, panelX + 100, startY + lineHeight, string.format("%.1f%%", driftIntensity_ * 100), nil)
    
    -- 漂移强度条
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, panelX + 160, startY + lineHeight + 2, 100, 12, 3)
    nvgFillColor(nvg_, nvgRGBA(50, 50, 50, 255))
    nvgFill(nvg_)
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, panelX + 160, startY + lineHeight + 2, 100 * driftIntensity_, 12, 3)
    nvgFillColor(nvg_, nvgRGBA(255, 150, 50, 255))
    nvgFill(nvg_)
    
    -- 前轮摩擦力
    nvgFillColor(nvg_, nvgRGBA(200, 200, 200, 255))
    nvgText(nvg_, panelX + 10, startY + lineHeight * 2, "前轮摩擦:", nil)
    -- 颜色渐变：高摩擦=绿色，低摩擦=黄色
    local frontRatio = (currentFrontFriction_ - CONFIG.FrontMinFriction) / 
        (CONFIG.FrontBaseFriction - CONFIG.FrontMinFriction)
    local frontColor = nvgRGBA(
        math.floor(255 * (1 - frontRatio * 0.6)),
        math.floor(200 + 55 * frontRatio),
        100, 255)
    nvgFillColor(nvg_, frontColor)
    nvgText(nvg_, panelX + 100, startY + lineHeight * 2, string.format("%.2f", currentFrontFriction_), nil)
    
    -- 后轮摩擦力
    nvgFillColor(nvg_, nvgRGBA(200, 200, 200, 255))
    nvgText(nvg_, panelX + 10, startY + lineHeight * 3, "后轮摩擦:", nil)
    -- 颜色渐变：高摩擦=绿色，低摩擦=红色
    local rearRatio = (currentRearFriction_ - CONFIG.RearMinFriction) / 
        (CONFIG.RearBaseFriction - CONFIG.RearMinFriction)
    local rearColor = nvgRGBA(
        math.floor(255 * (1 - rearRatio)),
        math.floor(255 * rearRatio),
        100, 255)
    nvgFillColor(nvg_, rearColor)
    nvgText(nvg_, panelX + 100, startY + lineHeight * 3, string.format("%.2f", currentRearFriction_), nil)
    
    -- 后轮摩擦力条
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, panelX + 160, startY + lineHeight * 3 + 2, 100, 12, 3)
    nvgFillColor(nvg_, nvgRGBA(50, 50, 50, 255))
    nvgFill(nvg_)
    local rearBarRatio = currentRearFriction_ / CONFIG.RearBaseFriction
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, panelX + 160, startY + lineHeight * 3 + 2, 100 * rearBarRatio, 12, 3)
    nvgFillColor(nvg_, isDrifting_ and nvgRGBA(255, 100, 50, 255) or nvgRGBA(100, 200, 150, 255))
    nvgFill(nvg_)
    
    -- 当前速度
    nvgFillColor(nvg_, nvgRGBA(200, 200, 200, 255))
    nvgText(nvg_, panelX + 10, startY + lineHeight * 4, "当前速度:", nil)
    nvgFillColor(nvg_, nvgRGBA(100, 200, 255, 255))
    nvgText(nvg_, panelX + 100, startY + lineHeight * 4, string.format("%.1f km/h", currentSpeed_), nil)
    
    -- 转向角度
    nvgFillColor(nvg_, nvgRGBA(200, 200, 200, 255))
    nvgText(nvg_, panelX + 10, startY + lineHeight * 5, "转向角度:", nil)
    local steerDeg = currentSteering_ * 180 / math.pi
    nvgFillColor(nvg_, nvgRGBA(200, 150, 255, 255))
    nvgText(nvg_, panelX + 100, startY + lineHeight * 5, string.format("%.1f°", steerDeg), nil)
end

-- ============================================================================
-- 7.5 虚拟按钮（漂移、重置）
-- ============================================================================

-- 漂移按钮位置和大小（右下角）
local DRIFT_BUTTON = {
    width = 200,
    height = 150,
    rightMargin = 30,
    bottomMargin = 30,
}

-- 重置按钮位置和大小（右上角，小地图下方）
local RESET_BUTTON = {
    width = 100,
    height = 40,
    rightMargin = 20,
    topMargin = 230,  -- 下移避免与赛道选择按钮重叠
}

--- 绘制漂移按钮（右下角）
function DrawDriftButton(width, height)
    local btn = DRIFT_BUTTON
    local btnX = width - btn.rightMargin - btn.width
    local btnY = height - btn.bottomMargin - btn.height
    
    local mouseX = input.mousePosition.x
    local mouseY = input.mousePosition.y
    
    -- 检测悬停
    local isHover = mouseX >= btnX and mouseX <= btnX + btn.width and
                    mouseY >= btnY and mouseY <= btnY + btn.height
    
    -- 检测是否按下（鼠标左键按住且在按钮区域内）
    local isPressed = isHover and input:GetMouseButtonDown(MOUSEB_LEFT)
    driftButtonPressed_ = isPressed
    
    -- 按钮背景
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, btnX, btnY, btn.width, btn.height, 12)
    
    if isPressed then
        -- 按下状态：橙色
        nvgFillColor(nvg_, nvgRGBA(255, 120, 50, 250))
    elseif isHover then
        -- 悬停状态：浅橙色
        nvgFillColor(nvg_, nvgRGBA(200, 100, 50, 220))
    else
        -- 正常状态：深橙色
        nvgFillColor(nvg_, nvgRGBA(150, 80, 40, 200))
    end
    nvgFill(nvg_)
    
    -- 按钮边框
    nvgStrokeColor(nvg_, nvgRGBA(255, 150, 80, 255))
    nvgStrokeWidth(nvg_, 3)
    nvgStroke(nvg_)
    
    -- 按钮图标和文字
    nvgFontFace(nvg_, "sans")
    nvgFontSize(nvg_, 28)
    nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
    nvgText(nvg_, btnX + btn.width / 2, btnY + btn.height / 2 - 10, "🔥", nil)
    
    nvgFontSize(nvg_, 16)
    nvgText(nvg_, btnX + btn.width / 2, btnY + btn.height / 2 + 20, "漂移", nil)
    
    -- 如果正在漂移，显示特效
    if isDrifting_ or driftIntensity_ > 0.1 then
        nvgBeginPath(nvg_)
        nvgRoundedRect(nvg_, btnX - 3, btnY - 3, btn.width + 6, btn.height + 6, 14)
        nvgStrokeColor(nvg_, nvgRGBA(255, 200, 100, math.floor(150 * driftIntensity_)))
        nvgStrokeWidth(nvg_, 2)
        nvgStroke(nvg_)
    end
end

--- 绘制重置按钮（右上角，小地图下方）
function DrawResetButton(width, height)
    local btn = RESET_BUTTON
    local btnX = width - btn.rightMargin - btn.width
    local btnY = btn.topMargin+100
    
    local mouseX = input.mousePosition.x
    local mouseY = input.mousePosition.y
    
    -- 检测悬停
    local isHover = mouseX >= btnX and mouseX <= btnX + btn.width and
                    mouseY >= btnY and mouseY <= btnY + btn.height
    
    -- 按钮背景
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, btnX, btnY, btn.width, btn.height, 8)
    
    if isHover then
        -- 悬停状态：浅蓝色
        nvgFillColor(nvg_, nvgRGBA(80, 150, 200, 230))
    else
        -- 正常状态：深蓝色
        nvgFillColor(nvg_, nvgRGBA(50, 100, 150, 200))
    end
    nvgFill(nvg_)
    
    -- 按钮边框
    nvgStrokeColor(nvg_, nvgRGBA(100, 180, 255, 255))
    nvgStrokeWidth(nvg_, 2)
    nvgStroke(nvg_)
    
    -- 按钮文字
    nvgFontFace(nvg_, "sans")
    nvgFontSize(nvg_, 16)
    nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
    nvgText(nvg_, btnX + btn.width / 2, btnY + btn.height / 2, "🔄 重置状态", nil)
end

-- 发射按钮位置和大小（漂移按钮左侧）
local FIRE_BUTTON = {
    width = 150,
    height = 150,
    rightMargin = 250,  -- 在漂移按钮左侧
    bottomMargin = 30,
}

--- 绘制发射按钮
function DrawFireButton(width, height)
    local btn = FIRE_BUTTON
    local btnX = width - btn.rightMargin - btn.width
    local btnY = height - btn.bottomMargin - btn.height
    
    local mouseX = input.mousePosition.x
    local mouseY = input.mousePosition.y
    
    -- 检测悬停
    local isHover = mouseX >= btnX and mouseX <= btnX + btn.width and
                    mouseY >= btnY and mouseY <= btnY + btn.height
    
    -- 检测是否按下
    local isPressed = isHover and input:GetMouseButtonDown(MOUSEB_LEFT)
    fireButtonPressed_ = isHover  -- 只要在按钮区域内就标记
    
    -- 计算冷却进度
    local currentTime = time.elapsedTime
    local cooldownRemain = math.max(0, MISSILE_CONFIG.FireCooldown - (currentTime - lastFireTime_))
    local cooldownRatio = cooldownRemain / MISSILE_CONFIG.FireCooldown
    local canFire = cooldownRemain <= 0
    
    -- 按钮背景
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, btnX, btnY, btn.width, btn.height, 12)
    
    if isPressed and canFire then
        -- 按下且可发射：亮红色
        nvgFillColor(nvg_, nvgRGBA(255, 80, 80, 250))
    elseif isHover then
        -- 悬停状态：浅红色
        nvgFillColor(nvg_, nvgRGBA(200, 60, 60, 230))
    else
        -- 正常状态：深红色
        nvgFillColor(nvg_, nvgRGBA(150, 40, 40, 200))
    end
    nvgFill(nvg_)
    
    -- 冷却遮罩
    if cooldownRatio > 0 then
        nvgBeginPath(nvg_)
        nvgRoundedRect(nvg_, btnX, btnY, btn.width, btn.height * cooldownRatio, 12)
        nvgFillColor(nvg_, nvgRGBA(0, 0, 0, 150))
        nvgFill(nvg_)
    end
    
    -- 按钮边框
    if canFire then
        nvgStrokeColor(nvg_, nvgRGBA(255, 100, 100, 255))
    else
        nvgStrokeColor(nvg_, nvgRGBA(150, 80, 80, 255))
    end
    nvgStrokeWidth(nvg_, 3)
    nvgStroke(nvg_)
    
    -- 按钮图标和文字
    nvgFontFace(nvg_, "sans")
    nvgFontSize(nvg_, 32)
    nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, canFire and 255 or 150))
    nvgText(nvg_, btnX + btn.width / 2, btnY + btn.height / 2 - 15, "🚀", nil)
    
    nvgFontSize(nvg_, 14)
    if not canFire then
        nvgText(nvg_, btnX + btn.width / 2, btnY + btn.height / 2 + 20, "冷却中", nil)
    else
        nvgText(nvg_, btnX + btn.width / 2, btnY + btn.height / 2 + 20, "自动发射", nil)
    end
    
    -- 显示搜索到的敌人数量
    local nearestEnemy = FindNearestEnemy()
    nvgFontSize(nvg_, 12)
    if nearestEnemy then
        nvgFillColor(nvg_, nvgRGBA(100, 255, 100, 255))
        nvgText(nvg_, btnX + btn.width / 2, btnY + btn.height / 2 + 38, "目标锁定!", nil)
    else
        nvgFillColor(nvg_, nvgRGBA(200, 200, 200, 150))
        nvgText(nvg_, btnX + btn.width / 2, btnY + btn.height / 2 + 38, "搜索中...", nil)
    end
end

--- 绘制分数面板（右上角，小地图左侧）
function DrawScorePanel(width, height)
    local panelWidth = 160
    local panelHeight = 90
    local panelX = width - panelWidth - 160  -- 小地图左侧
    local panelY = 20
    
    -- 面板背景
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, panelX, panelY, panelWidth, panelHeight, 8)
    nvgFillColor(nvg_, nvgRGBA(20, 20, 40, 220))
    nvgFill(nvg_)
    nvgStrokeColor(nvg_, nvgRGBA(255, 200, 100, 200))
    nvgStrokeWidth(nvg_, 2)
    nvgStroke(nvg_)
    
    -- 标题
    nvgFontFace(nvg_, "sans")
    nvgFontSize(nvg_, 14)
    nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg_, nvgRGBA(255, 200, 100, 255))
    nvgText(nvg_, panelX + panelWidth / 2, panelY + 8, "战斗统计", nil)
    
    -- 分数
    nvgFontSize(nvg_, 24)
    nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 100, 255))
    nvgText(nvg_, panelX + panelWidth / 2, panelY + 40, string.format("%d", gameScore_), nil)
    
    -- 击杀数和敌人数
    nvgFontSize(nvg_, 12)
    nvgFillColor(nvg_, nvgRGBA(200, 200, 200, 200))
    nvgText(nvg_, panelX + panelWidth / 2, panelY + 65, 
        string.format("击杀: %d | 敌人: %d", totalKills_, #enemies_), nil)
    
    -- 导弹数量
    nvgText(nvg_, panelX + panelWidth / 2, panelY + 78, 
        string.format("导弹: %d", #missiles_), nil)
end

-- ============================================================================
-- 8. 配置面板系统
-- ============================================================================

-- 配置按钮位置和大小
local CONFIG_BUTTON = {
    x = 20,
    y = 140,
    width = 100,
    height = 36,
}

-- 配置面板位置和大小
local CONFIG_PANEL = {
    x = 20,
    y = 180,
    width = 340,
    height = 688,  -- 增加高度以容纳系统开关
    sliderWidth = 180,
    sliderHeight = 16,
}

-- 车辆选择按钮位置和大小
local CAR_SELECT_BUTTON = {
    width = 80,
    height = 36,
    spacing = 10,
    rightMargin = 20,
    topY = 140,
}

-- 赛道选择按钮位置和大小
local TRACK_SELECT_BUTTON = {
    width = 90,
    height = 36,
    spacing = 8,
    rightMargin = 20,
    topY = 185,  -- 在车辆选择按钮下方
}

--- 应用车辆配置
---@param index number 配置索引
function ApplyCarSetting(index)
    if not CarSetting[index] then
        print("无效的车辆配置索引: " .. index)
        return
    end
    
    currentCarSetting_ = index
    local setting = CarSetting[index]
    
    -- 复制配置到 CONFIG
    for key, value in pairs(setting) do
        CONFIG[key] = value
    end
    
    -- 保存旧车辆的位置和旋转
    local oldPos = Vector3(0, 2, 0)
    local oldRot = Quaternion()
    local oldVelocity = Vector3(0, 0, 0)
    
    if vehicleNode_ then
        oldPos = vehicleNode_.position
        oldRot = vehicleNode_.rotation
        local body = vehicleNode_:GetComponent("RigidBody")
        if body then
            oldVelocity = body.linearVelocity
        end
        
        -- 销毁旧车辆
        vehicleNode_:Remove()
        vehicleNode_ = nil
        vehicle_ = nil
    end
    
    -- 创建新车辆
    CreateVehicle()
    
    -- 恢复位置和旋转
    if vehicleNode_ then
        vehicleNode_.position = oldPos
        vehicleNode_.rotation = oldRot
        local body = vehicleNode_:GetComponent("RigidBody")
        if body then
            body.linearVelocity = oldVelocity
        end
    end
    
    print("已切换到车辆配置: " .. (setting.Title or ("配置 " .. index)))
end

--- 绘制车辆选择按钮
function DrawCarSelectButtons(screenWidth, height)
    local btn = CAR_SELECT_BUTTON
    local carCount = #CarSetting
    
    -- 计算按钮起始位置（右侧）
    local totalWidth = carCount * btn.width + (carCount - 1) * btn.spacing
    local startX = screenWidth - btn.rightMargin - totalWidth
    local y = btn.topY
    
    local mouseX = input.mousePosition.x
    local mouseY = input.mousePosition.y
    
    -- 标题
    nvgFontFace(nvg_, "sans")
    nvgFontSize(nvg_, 14)
    nvgTextAlign(nvg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg_, nvgRGBA(200, 200, 200, 200))
    nvgText(nvg_, startX - 10, y + btn.height / 2, "车辆配置:", nil)
    
    for i = 1, carCount do
        local x = startX + (i - 1) * (btn.width + btn.spacing)
        
        -- 检测悬停
        local isHover = mouseX >= x and mouseX <= x + btn.width and
                        mouseY >= y and mouseY <= y + btn.height
        local isSelected = (currentCarSetting_ == i)
        
        -- 按钮背景
        nvgBeginPath(nvg_)
        nvgRoundedRect(nvg_, x, y, btn.width, btn.height, 6)
        
        if isSelected then
            nvgFillColor(nvg_, nvgRGBA(80, 180, 80, 230))
        elseif isHover then
            nvgFillColor(nvg_, nvgRGBA(100, 130, 180, 230))
        else
            nvgFillColor(nvg_, nvgRGBA(60, 80, 110, 200))
        end
        nvgFill(nvg_)
        
        -- 按钮边框
        if isSelected then
            nvgStrokeColor(nvg_, nvgRGBA(150, 255, 150, 255))
        else
            nvgStrokeColor(nvg_, nvgRGBA(100, 150, 200, 255))
        end
        nvgStrokeWidth(nvg_, 2)
        nvgStroke(nvg_)
        
        -- 按钮文字（显示 Title）
        nvgFontFace(nvg_, "sans")
        nvgFontSize(nvg_, 14)
        nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
        local title = CarSetting[i].Title or ("配置 " .. i)
        nvgText(nvg_, x + btn.width / 2, y + btn.height / 2, title, nil)
    end
end

--- 绘制赛道选择按钮
function DrawTrackSelectButtons(screenWidth, height)
    local btn = TRACK_SELECT_BUTTON
    local trackCount = GetTrackCount()
    
    -- 计算按钮起始位置（右侧）
    local totalWidth = trackCount * btn.width + (trackCount - 1) * btn.spacing
    local startX = screenWidth - btn.rightMargin - totalWidth
    local y = btn.topY
    
    local mouseX = input.mousePosition.x
    local mouseY = input.mousePosition.y
    
    -- 标题
    nvgFontFace(nvg_, "sans")
    nvgFontSize(nvg_, 14)
    nvgTextAlign(nvg_, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg_, nvgRGBA(200, 200, 200, 200))
    nvgText(nvg_, startX - 10, y + btn.height / 2, "赛道选择:", nil)
    
    for i = 1, trackCount do
        local x = startX + (i - 1) * (btn.width + btn.spacing)
        local config = TrackConfig[i]
        
        -- 检测悬停
        local isHover = mouseX >= x and mouseX <= x + btn.width and
                        mouseY >= y and mouseY <= y + btn.height
        local isSelected = (currentTrackIndex_ == i)
        
        -- 按钮背景
        nvgBeginPath(nvg_)
        nvgRoundedRect(nvg_, x, y, btn.width, btn.height, 6)
        
        if isSelected then
            nvgFillColor(nvg_, nvgRGBA(180, 120, 60, 230))  -- 橙色表示当前赛道
        elseif isHover then
            nvgFillColor(nvg_, nvgRGBA(140, 100, 60, 230))
        else
            nvgFillColor(nvg_, nvgRGBA(80, 60, 40, 200))
        end
        nvgFill(nvg_)
        
        -- 按钮边框
        if isSelected then
            nvgStrokeColor(nvg_, nvgRGBA(255, 200, 100, 255))
        else
            nvgStrokeColor(nvg_, nvgRGBA(180, 140, 80, 255))
        end
        nvgStrokeWidth(nvg_, 2)
        nvgStroke(nvg_)
        
        -- 按钮文字（显示赛道名称）
        nvgFontFace(nvg_, "sans")
        nvgFontSize(nvg_, 13)
        nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
        local title = config.Name or ("赛道 " .. i)
        nvgText(nvg_, x + btn.width / 2, y + btn.height / 2, title, nil)
    end
end

--- 绘制配置按钮
function DrawConfigButton(width, height)
    local btn = CONFIG_BUTTON
    local mouseX = input.mousePosition.x
    local mouseY = input.mousePosition.y
    
    -- 检测悬停
    local isHover = mouseX >= btn.x and mouseX <= btn.x + btn.width and
                    mouseY >= btn.y and mouseY <= btn.y + btn.height
	
	--print("鼠标悬停: " .. tostring(isHover))
    
    -- 按钮背景
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, btn.x, btn.y, btn.width, btn.height, 6)
    
    if configPanelOpen_ then
        nvgFillColor(nvg_, nvgRGBA(80, 150, 80, 230))
    elseif isHover then
        nvgFillColor(nvg_, nvgRGBA(80, 100, 150, 230))
    else
        nvgFillColor(nvg_, nvgRGBA(50, 70, 100, 200))
    end
    nvgFill(nvg_)
    
    -- 按钮边框
    nvgStrokeColor(nvg_, nvgRGBA(100, 150, 200, 255))
    nvgStrokeWidth(nvg_, 2)
    nvgStroke(nvg_)
    
    -- 按钮文字
    nvgFontFace(nvg_, "sans")
    nvgFontSize(nvg_, 16)
    nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
    local btnText = configPanelOpen_ and "关闭配置" or "打开配置"
    nvgText(nvg_, btn.x + btn.width / 2, btn.y + btn.height / 2, btnText, nil)
end

--- 绘制滑块控件
---@param name string 滑块名称（用于标识）
---@param label string 显示标签
---@param x number X坐标
---@param y number Y坐标
---@param value number 当前值
---@param minVal number 最小值
---@param maxVal number 最大值
---@param format string 数值格式
---@return number 新值
function DrawSlider(name, label, x, y, value, minVal, maxVal, format)
    local panel = CONFIG_PANEL
    local sliderX = x + 100
    local sliderY = y
    local sliderW = panel.sliderWidth
    local sliderH = panel.sliderHeight
    
    -- 标签
    nvgFontFace(nvg_, "sans")
    nvgFontSize(nvg_, 14)
    nvgTextAlign(nvg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg_, nvgRGBA(200, 200, 200, 255))
    nvgText(nvg_, x, y + sliderH / 2, label, nil)
    
    -- 滑块背景
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, sliderX, sliderY, sliderW, sliderH, 4)
    nvgFillColor(nvg_, nvgRGBA(40, 40, 50, 255))
    nvgFill(nvg_)
    
    -- 计算滑块位置
    local ratio = (value - minVal) / (maxVal - minVal)
    ratio = math.max(0, math.min(1, ratio))
    local fillWidth = sliderW * ratio
    
    -- 填充条
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, sliderX, sliderY, fillWidth, sliderH, 4)
    nvgFillColor(nvg_, nvgRGBA(80, 150, 220, 255))
    nvgFill(nvg_)
    
    -- 滑块边框
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, sliderX, sliderY, sliderW, sliderH, 4)
    nvgStrokeColor(nvg_, nvgRGBA(100, 120, 150, 255))
    nvgStrokeWidth(nvg_, 1)
    nvgStroke(nvg_)
    
    -- 数值显示
    nvgTextAlign(nvg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 200, 255))
    nvgText(nvg_, sliderX + sliderW + 10, y + sliderH / 2, string.format(format, value), nil)
    
    -- 检测鼠标交互（拖动中）
    local mouseX = input.mousePosition.x
    
    if sliderDragging_ and activeSlider_ == name then
        -- 正在拖动此滑块
        local newRatio = (mouseX - sliderX) / sliderW
        newRatio = math.max(0, math.min(1, newRatio))
        return minVal + newRatio * (maxVal - minVal)
    end
    
    return value
end

--- 绘制开关控件
---@param name string 开关名称（用于标识）
---@param label string 显示标签
---@param x number X坐标
---@param y number Y坐标
---@param value boolean 当前值
---@return boolean 新值
function DrawToggle(name, label, x, y, value)
    local panel = CONFIG_PANEL
    local toggleX = x + 100
    local toggleY = y
    local toggleW = 50
    local toggleH = 20
    
    -- 标签
    nvgFontFace(nvg_, "sans")
    nvgFontSize(nvg_, 14)
    nvgTextAlign(nvg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg_, nvgRGBA(200, 200, 200, 255))
    nvgText(nvg_, x, y + toggleH / 2, label, nil)
    
    -- 开关背景
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, toggleX, toggleY, toggleW, toggleH, toggleH / 2)
    if value then
        nvgFillColor(nvg_, nvgRGBA(80, 180, 80, 255))  -- 开：绿色
    else
        nvgFillColor(nvg_, nvgRGBA(80, 80, 90, 255))   -- 关：灰色
    end
    nvgFill(nvg_)
    
    -- 开关滑块
    local knobX = value and (toggleX + toggleW - toggleH + 2) or (toggleX + 2)
    nvgBeginPath(nvg_)
    nvgCircle(nvg_, knobX + (toggleH - 4) / 2, toggleY + toggleH / 2, (toggleH - 4) / 2)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
    nvgFill(nvg_)
    
    -- 状态文字
    nvgTextAlign(nvg_, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg_, value and nvgRGBA(100, 255, 100, 255) or nvgRGBA(200, 200, 200, 200))
    nvgText(nvg_, toggleX + toggleW + 10, y + toggleH / 2, value and "开启" or "关闭", nil)
    
    -- 检测点击
    local mouseX = input.mousePosition.x
    local mouseY = input.mousePosition.y
    
    if activeToggle_ == name then
        -- 切换状态
        activeToggle_ = nil
        return not value
    end
    
    return value
end

--- 绘制配置面板
function DrawConfigPanel(width, height)
    local panel = CONFIG_PANEL
    
    -- 面板背景
    nvgBeginPath(nvg_)
    nvgRoundedRect(nvg_, panel.x, panel.y, panel.width, panel.height, 10)
    nvgFillColor(nvg_, nvgRGBA(20, 25, 35, 240))
    nvgFill(nvg_)
    nvgStrokeColor(nvg_, nvgRGBA(80, 100, 140, 255))
    nvgStrokeWidth(nvg_, 2)
    nvgStroke(nvg_)
    
    -- 标题
    nvgFontFace(nvg_, "sans")
    nvgFontSize(nvg_, 18)
    nvgTextAlign(nvg_, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg_, nvgRGBA(255, 255, 255, 255))
    nvgText(nvg_, panel.x + 15, panel.y + 12, "车辆参数配置", nil)
    
    -- 分隔线
    nvgBeginPath(nvg_)
    nvgMoveTo(nvg_, panel.x + 10, panel.y + 40)
    nvgLineTo(nvg_, panel.x + panel.width - 10, panel.y + 40)
    nvgStrokeColor(nvg_, nvgRGBA(60, 70, 90, 255))
    nvgStrokeWidth(nvg_, 1)
    nvgStroke(nvg_)
    
    local startY = panel.y + 55
    local lineHeight = 28
    local labelX = panel.x + 15
    
    -- ====== 系统开关 ======
    nvgFontSize(nvg_, 14)
    nvgFillColor(nvg_, nvgRGBA(150, 200, 255, 255))
    nvgText(nvg_, labelX, startY - 5, "【系统开关】", nil)
    startY = startY + 18
    
    -- 战斗系统开关
    CONFIG.EnableCombatSystem = DrawToggle("combat_system", "战斗系统", labelX, startY, CONFIG.EnableCombatSystem)
    startY = startY + lineHeight + 10
    
    -- ====== 动力参数 ======
    nvgFillColor(nvg_, nvgRGBA(150, 200, 255, 255))
    nvgText(nvg_, labelX, startY - 5, "【动力参数】", nil)
    startY = startY + 18
    
    -- 车辆重量
    local newMass = DrawSlider("vehicle_mass", "车辆重量", labelX, startY,
        CONFIG.VehicleMass, 100, 2000, "%.0f")
    if newMass ~= CONFIG.VehicleMass then
        CONFIG.VehicleMass = newMass
        ApplyVehicleMass()
    end
    startY = startY + lineHeight
    
    -- 前轮动力
    CONFIG.FrontEngineForce = DrawSlider("front_power", "前轮动力", labelX, startY, 
        CONFIG.FrontEngineForce, 0, 6000, "%.0f")
    startY = startY + lineHeight
    
    -- 后轮动力
    CONFIG.RearEngineForce = DrawSlider("rear_power", "后轮动力", labelX, startY,
        CONFIG.RearEngineForce, 0, 6000, "%.0f")
    startY = startY + lineHeight
    
    -- 最大转向角度
    CONFIG.MaxSteeringAngle = DrawSlider("max_steering", "转向角度", labelX, startY,
        CONFIG.MaxSteeringAngle, 0.1, 1.2, "%.2f")
    startY = startY + lineHeight + 10
    
    -- ====== 摩擦力参数 ======
    nvgFillColor(nvg_, nvgRGBA(150, 200, 255, 255))
    nvgText(nvg_, labelX, startY - 5, "【摩擦力参数】", nil)
    startY = startY + 18
    
    -- 前轮摩擦力上限
    CONFIG.FrontBaseFriction = DrawSlider("front_friction_max", "前轮上限", labelX, startY,
        CONFIG.FrontBaseFriction, 0.1, 3.0, "%.2f")
    startY = startY + lineHeight
    
    -- 前轮摩擦力下限
    CONFIG.FrontMinFriction = DrawSlider("front_friction_min", "前轮下限", labelX, startY,
        CONFIG.FrontMinFriction, 0.1, 3.0, "%.2f")
    startY = startY + lineHeight
    
    -- 后轮摩擦力上限
    CONFIG.RearBaseFriction = DrawSlider("rear_friction_max", "后轮上限", labelX, startY,
        CONFIG.RearBaseFriction, 0.1, 3.0, "%.2f")
    startY = startY + lineHeight
    
    -- 后轮摩擦力下限
    CONFIG.RearMinFriction = DrawSlider("rear_friction_min", "后轮下限", labelX, startY,
        CONFIG.RearMinFriction, 0.1, 3.0, "%.2f")
    startY = startY + lineHeight + 10
    
    -- ====== 悬挂参数 ======
    nvgFillColor(nvg_, nvgRGBA(150, 200, 255, 255))
    nvgText(nvg_, labelX, startY - 5, "【悬挂参数】", nil)
    startY = startY + 18
    
    -- 悬挂刚度
    local newStiffness = DrawSlider("suspension_stiffness", "悬挂刚度", labelX, startY,
        CONFIG.SuspensionStiffness, 10, 1000, "%.0f")
    if newStiffness ~= CONFIG.SuspensionStiffness then
        CONFIG.SuspensionStiffness = newStiffness
        ApplySuspensionSettings()
    end
    startY = startY + lineHeight
    
    -- 悬挂阻尼
    local newDamping = DrawSlider("suspension_damping", "悬挂阻尼", labelX, startY,
        CONFIG.SuspensionDamping, 0, 200, "%.1f")
    if newDamping ~= CONFIG.SuspensionDamping then
        CONFIG.SuspensionDamping = newDamping
        ApplySuspensionSettings()
    end
    startY = startY + lineHeight
    
    -- 压缩阻尼
    local newCompression = DrawSlider("suspension_compression", "压缩阻尼", labelX, startY,
        CONFIG.SuspensionCompression, 0, 200, "%.1f")
    if newCompression ~= CONFIG.SuspensionCompression then
        CONFIG.SuspensionCompression = newCompression
        ApplySuspensionSettings()
    end
    startY = startY + lineHeight
    
    -- 侧倾影响
    local newRoll = DrawSlider("roll_influence", "侧倾影响", labelX, startY,
        CONFIG.RollInfluence, 0,0.2, "%.2f")
    if newRoll ~= CONFIG.RollInfluence then
        CONFIG.RollInfluence = newRoll
        ApplySuspensionSettings()
    end
    startY = startY + lineHeight + 10
    
    -- ====== 漂移参数 ======
    nvgFillColor(nvg_, nvgRGBA(150, 200, 255, 255))
    nvgText(nvg_, labelX, startY - 5, "【漂移参数】", nil)
    startY = startY + 18
    
    -- 漂移最低速度
    CONFIG.DriftMinSpeed = DrawSlider("drift_min_speed", "最低速度", labelX, startY,
        CONFIG.DriftMinSpeed, 5, 60, "%.0f")
    startY = startY + lineHeight
    
    -- 漂移转向增强
    CONFIG.DriftSteeringBoost = DrawSlider("drift_steering", "转向增强", labelX, startY,
        CONFIG.DriftSteeringBoost, 1.0, 2.0, "%.2f")
    startY = startY + lineHeight
    
    -- 漂移摩擦力乘数
    CONFIG.DriftFrictionMultiplier = DrawSlider("drift_friction", "摩擦乘数", labelX, startY,
        CONFIG.DriftFrictionMultiplier, 0.1, 1.0, "%.2f")
    startY = startY + lineHeight
    
    -- 漂移恢复速度
    CONFIG.DriftRecoverySpeed = DrawSlider("drift_recovery", "恢复速度", labelX, startY,
        CONFIG.DriftRecoverySpeed, 0.5, 5.0, "%.1f")
    startY = startY + lineHeight
    
    -- 漂移力代偿指数
    CONFIG.DriftForceCompensation = DrawSlider("drift_compensation", "力代偿", labelX, startY,
        CONFIG.DriftForceCompensation, 0, 2.0, "%.2f")
    startY = startY + lineHeight
    
    -- 滑行转弯速度保持
    CONFIG.CoastTurnSpeedRetain = DrawSlider("coast_turn_retain", "滑行保持", labelX, startY,
        CONFIG.CoastTurnSpeedRetain, 0, 2.0, "%.2f")
    
    -- 提示文字
    nvgFontSize(nvg_, 12)
    nvgFillColor(nvg_, nvgRGBA(150, 150, 150, 200))
    nvgTextAlign(nvg_, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgText(nvg_, panel.x + panel.width / 2, panel.y + panel.height - 8, 
        "拖动滑块调整参数，实时生效", nil)
end

--- 应用悬挂设置到车辆
function ApplySuspensionSettings()
    if vehicle_ == nil then return end
    
    for i = 0, 3 do
        vehicle_:SetWheelSuspensionStiffness(i, CONFIG.SuspensionStiffness)
        vehicle_:SetWheelDampingRelaxation(i, CONFIG.SuspensionDamping)
        vehicle_:SetWheelDampingCompression(i, CONFIG.SuspensionCompression)
        vehicle_:SetWheelRollInfluence(i, CONFIG.RollInfluence)
        -- 注意：SuspensionRestLength 需要重建车辆才能生效（在 AddWheel 时设置）
    end
end

--- 应用车辆重量设置
function ApplyVehicleMass()
    if vehicleNode_ == nil then return end
    
    local body = vehicleNode_:GetComponent("RigidBody")
    if body then
        body.mass = CONFIG.VehicleMass
    end
end

--- 检测点击是否在滑块上
---@param mouseX number
---@param mouseY number
---@return string|nil 滑块名称或nil
function GetSliderAtPosition(mouseX, mouseY)
    if not configPanelOpen_ then return nil end
    
    local panel = CONFIG_PANEL
    -- 从标签开始检测，而不只是滑块条
    local sliderX = panel.x + 15
    local sliderW = 100 + panel.sliderWidth  -- 标签宽度 + 滑块宽度
    -- 使用整行高度作为检测区域，而不只是滑块条高度
    local sliderH = 28  -- lineHeight，匹配实际布局
    
    -- 计算各滑块的Y坐标（需要与 DrawConfigPanel 中的布局一致）
    -- 开关区域占用：标题(18) + 开关(28) + 间距(10) = 56
    local toggleOffset = 56
    local baseY = panel.y + 55 + 18 + toggleOffset
    local lineHeight = 28
    
    local sliders = {
        {name = "vehicle_mass", y = baseY},
        {name = "front_power", y = baseY + lineHeight},
        {name = "rear_power", y = baseY + lineHeight * 2},
        {name = "max_steering", y = baseY + lineHeight * 3},
        {name = "front_friction_max", y = baseY + lineHeight * 4 + 28},
        {name = "front_friction_min", y = baseY + lineHeight * 5 + 28},
        {name = "rear_friction_max", y = baseY + lineHeight * 6 + 28},
        {name = "rear_friction_min", y = baseY + lineHeight * 7 + 28},
        {name = "suspension_stiffness", y = baseY + lineHeight * 8 + 56},
        {name = "suspension_damping", y = baseY + lineHeight * 9 + 56},
        {name = "suspension_compression", y = baseY + lineHeight * 10 + 56},
        {name = "roll_influence", y = baseY + lineHeight * 11 + 56},
        {name = "drift_min_speed", y = baseY + lineHeight * 12 + 84},
        {name = "drift_steering", y = baseY + lineHeight * 13 + 84},
        {name = "drift_friction", y = baseY + lineHeight * 14 + 84},
        {name = "drift_recovery", y = baseY + lineHeight * 15 + 84},
        {name = "drift_compensation", y = baseY + lineHeight * 16 + 84},
        {name = "coast_turn_retain", y = baseY + lineHeight * 17 + 84},
    }
    
    for _, slider in ipairs(sliders) do
        if mouseX >= sliderX and mouseX <= sliderX + sliderW and
           mouseY >= slider.y and mouseY <= slider.y + sliderH then
            return slider.name
        end
    end
    
    return nil
end

--- 检测点击是否在开关上
---@param mouseX number
---@param mouseY number
---@return string|nil 开关名称或nil
function GetToggleAtPosition(mouseX, mouseY)
    if not configPanelOpen_ then return nil end
    
    local panel = CONFIG_PANEL
    -- 从标签开始检测
    local toggleX = panel.x + 15
    local toggleW = 100 + 50  -- 标签宽度 + 开关宽度
    -- 使用整行高度作为检测区域
    local toggleH = 28  -- lineHeight，匹配实际布局
    
    -- 计算开关的 Y 坐标（需要与 DrawConfigPanel 中的布局一致）
    local baseY = panel.y + 55 + 18  -- 跳过标题
    local lineHeight = 28
    
    local toggles = {
        {name = "combat_system", y = baseY},
    }
    
    for _, toggle in ipairs(toggles) do
        if mouseX >= toggleX and mouseX <= toggleX + toggleW and
           mouseY >= toggle.y and mouseY <= toggle.y + toggleH then
            return toggle.name
        end
    end
    
    return nil
end

--- 处理鼠标点击（在 Update 中调用）
function HandleMouseClick()
    local mouseX = input.mousePosition.x
    local mouseY = input.mousePosition.y
    local screenWidth = graphics.width
    local screenHeight = graphics.height
    
    -- 检测发射按钮点击（仅在启用战斗系统时）
    if CONFIG.EnableCombatSystem then
        local fireBtn = FIRE_BUTTON
        local fireX = screenWidth - fireBtn.rightMargin - fireBtn.width
        local fireY = screenHeight - fireBtn.bottomMargin - fireBtn.height
        if mouseX >= fireX and mouseX <= fireX + fireBtn.width and
           mouseY >= fireY and mouseY <= fireY + fireBtn.height then
            FireMissile()
            return
        end
    end
    
    -- 检测重置按钮点击（右上角）
    local resetBtn = RESET_BUTTON
    local resetX = screenWidth - resetBtn.rightMargin - resetBtn.width
    local resetY = resetBtn.topMargin
    if mouseX >= resetX and mouseX <= resetX + resetBtn.width and
       mouseY >= resetY and mouseY <= resetY + resetBtn.height then
        ResetVehicle()
        print("车辆位置已重置")
        return
    end
    
    -- 检测配置按钮点击
    local btn = CONFIG_BUTTON
    if mouseX >= btn.x and mouseX <= btn.x + btn.width and
       mouseY >= btn.y and mouseY <= btn.y + btn.height then
        configPanelOpen_ = not configPanelOpen_
        print("配置面板: " .. (configPanelOpen_ and "打开" or "关闭"))
        return
    end
    
    -- 检测车辆配置选择按钮点击
    local carBtn = CAR_SELECT_BUTTON
    local carCount = #CarSetting
    local totalWidth = carCount * carBtn.width + (carCount - 1) * carBtn.spacing
    local startX = screenWidth - carBtn.rightMargin - totalWidth
    local y = carBtn.topY
    
    for i = 1, carCount do
        local x = startX + (i - 1) * (carBtn.width + carBtn.spacing)
        if mouseX >= x and mouseX <= x + carBtn.width and
           mouseY >= y and mouseY <= y + carBtn.height then
            if currentCarSetting_ ~= i then
                ApplyCarSetting(i)
            end
            return
        end
    end
    
    -- 检测赛道选择按钮点击
    local trackBtn = TRACK_SELECT_BUTTON
    local trackCount = GetTrackCount()
    local trackTotalWidth = trackCount * trackBtn.width + (trackCount - 1) * trackBtn.spacing
    local trackStartX = screenWidth - trackBtn.rightMargin - trackTotalWidth
    local trackY = trackBtn.topY
    
    for i = 1, trackCount do
        local x = trackStartX + (i - 1) * (trackBtn.width + trackBtn.spacing)
        if mouseX >= x and mouseX <= x + trackBtn.width and
           mouseY >= trackY and mouseY <= trackY + trackBtn.height then
            if currentTrackIndex_ ~= i then
                SwitchTrack(i)
            end
            return
        end
    end
    
    -- 检测开关和滑块点击
    if configPanelOpen_ then
        -- 检测开关点击
        local toggleName = GetToggleAtPosition(mouseX, mouseY)
        if toggleName then
            activeToggle_ = toggleName
            return
        end
        
        -- 检测滑块点击
        local sliderName = GetSliderAtPosition(mouseX, mouseY)
        if sliderName then
            activeSlider_ = sliderName
            sliderDragging_ = true
        end
    end
end

--- 鼠标按下事件（保留备用）
---@param eventType string
---@param eventData MouseButtonDownEventData
function HandleMouseDown(eventType, eventData)
    -- 使用 Update 中的检测代替
end

--- 鼠标释放事件（保留备用）
---@param eventType string
---@param eventData MouseButtonUpEventData
function HandleMouseUp(eventType, eventData)
    -- 使用 Update 中的检测代替
end

