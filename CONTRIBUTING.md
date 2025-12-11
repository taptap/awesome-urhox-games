# 🤝 贡献指南

感谢你对 Awesome UrhoX Games 的关注！我们欢迎所有基于 UrhoX 引擎开发的优秀 Lua 游戏作品。

---

## 📋 提交要求

### 基本要求

- [ ] 游戏使用 UrhoX 引擎和 Lua 开发
- [ ] 游戏可在 UrhoX 标准环境下正常运行
- [ ] 包含所有必需文件（见下方）
- [ ] 代码遵循基本规范
- [ ] 素材版权合规

### 必需文件清单

```
games/yourname-yourgame/
├── README.md           ✅ 必需 - 游戏说明
├── game.json           ✅ 必需 - 游戏元信息
├── scripts/
│   └── Main.lua        ✅ 必需 - 入口脚本
└── preview/
    ├── icon.png        ✅ 必需 - 256x256 图标
    └── screenshot1.png ✅ 必需 - 至少一张截图
```

---

## 🚀 提交流程

### Step 1: Fork 仓库

点击右上角 Fork 按钮，将仓库 fork 到你的账号下。

### Step 2: 克隆到本地

```bash
git clone https://github.com/YOUR_USERNAME/awesome-urhox-games.git
cd awesome-urhox-games
```

### Step 3: 创建游戏目录

```bash
mkdir -p games/yourname-yourgame/{scripts,preview,assets}
```

### Step 4: 开发游戏

在 `games/yourname-yourgame/` 目录下开发你的游戏：

1. 创建 `game.json` 填写游戏信息
2. 编写 `scripts/Main.lua` 主入口脚本
3. 添加游戏资源到 `assets/` 目录
4. 创建 `preview/icon.png` 和截图
5. 编写 `README.md` 游戏说明

### Step 5: 测试

确保游戏可以正常运行：

```bash
# 使用 UrhoX 启动器测试
cd games/yourname-yourgame
urho3d_player scripts/Main.lua
```

### Step 6: 提交代码

```bash
git add games/yourname-yourgame/
git commit -m "feat: 添加游戏 - 游戏名称"
git push origin main
```

### Step 7: 创建 Pull Request

1. 访问你的 Fork 仓库
2. 点击 "Compare & pull request"
3. 填写 PR 描述
4. 提交等待审核

---

## 📝 game.json 规范

```json
{
  "name": "My Game",
  "name_zh": "我的游戏",
  "version": "1.0.0",
  "author": {
    "name": "你的名字",
    "github": "your-github-username",
    "email": "your@email.com"
  },
  "description": "English description",
  "description_zh": "中文描述",
  "category": "casual",
  "tags": ["2d", "puzzle"],
  "engine": {
    "name": "UrhoX",
    "minVersion": "1.0.0"
  },
  "entry": "scripts/Main.lua",
  "orientation": "portrait",
  "license": "MIT",
  "created": "2025-12-01",
  "updated": "2025-12-01"
}
```

### category 可选值

| 值 | 中文 | 说明 |
|---|------|------|
| `casual` | 休闲 | 轻松休闲类 |
| `puzzle` | 益智 | 解谜益智类 |
| `action` | 动作 | 动作类 |
| `platformer` | 平台跳跃 | 马里奥风格 |
| `rpg` | 角色扮演 | RPG |
| `strategy` | 策略 | 策略类 |
| `simulation` | 模拟 | 模拟经营 |
| `racing` | 竞速 | 赛车类 |
| `arcade` | 街机 | 街机风格 |
| `adventure` | 冒险 | 冒险探索 |
| `sports` | 体育 | 体育运动 |
| `card` | 卡牌 | 卡牌类 |
| `3d` | 3D | 3D 游戏 |

### orientation 可选值

| 值 | 说明 |
|---|------|
| `portrait` | 竖屏 |
| `landscape` | 横屏 |
| `any` | 任意方向 |

---

## 📐 代码规范

### Lua 编码风格

```lua
-- ✅ 好的命名
local playerHealth = 100
local function updatePlayerPosition()
end

-- ❌ 避免
local ph = 100
local function f1()
end
```

### 推荐做法

- 使用有意义的变量名
- 添加必要的注释
- 函数保持单一职责
- 避免全局变量污染
- 正确处理资源释放

### 入口脚本结构

```lua
-- scripts/Main.lua
require "LuaScripts/Utilities/Sample"

-- 游戏配置
local CONFIG = {
    Title = "My Game",
    Width = 800,
    Height = 600
}

-- 初始化
function Start()
    -- 设置窗口
    -- 加载资源
    -- 订阅事件
end

-- 主循环
function HandleUpdate(eventType, eventData)
    local timeStep = eventData["TimeStep"]:GetFloat()
    -- 更新游戏逻辑
end

-- 清理
function Stop()
    -- 释放资源
end
```

---

## ⚠️ 素材版权

### 必须确保

- ✅ 所有素材均为原创或有合法授权
- ✅ 第三方素材注明来源和协议
- ✅ 不使用未授权的商业素材

### 推荐素材来源

- [OpenGameArt](https://opengameart.org/) - 免费游戏素材
- [Kenney Assets](https://kenney.nl/assets) - CC0 游戏素材
- [Freesound](https://freesound.org/) - 免费音效

---

## 🔍 审核标准

我们会从以下方面审核提交：

| 维度 | 要求 |
|------|------|
| **可运行性** | 游戏能正常启动和运行 |
| **完整性** | 包含所有必需文件 |
| **代码质量** | 代码结构清晰、无明显 bug |
| **安全性** | 无恶意代码、无网络风险 |
| **版权合规** | 素材版权无争议 |
| **原创性** | 非简单复制已有项目 |

---

## 💬 获取帮助

- **问题反馈**: [GitHub Issues](https://github.com/ArcadeHustle/awesome-urhox-games/issues)
- **讨论交流**: [GitHub Discussions](https://github.com/ArcadeHustle/awesome-urhox-games/discussions)
- **UrhoX 文档**: [AI Dev Kit](https://github.com/xindong/UrhoX/tree/main/ai-dev-kit)

---

## 🙏 感谢

感谢每一位贡献者让这个社区更加丰富多彩！

你的名字将出现在游戏目录和项目 Contributors 中。

---

*Happy Coding! 🎮*
