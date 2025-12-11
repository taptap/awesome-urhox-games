# 🎮 Awesome UrhoX Games

<div align="center">

**精选 UrhoX 引擎 Lua 游戏合集**

[![Awesome](https://awesome.re/badge.svg)](https://awesome.re)
[![UrhoX](https://img.shields.io/badge/Engine-UrhoX-blue.svg)](https://github.com/xindong/UrhoX)
[![Lua](https://img.shields.io/badge/Lua-5.4-00007C.svg)](https://www.lua.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

*社区开发者基于 UrhoX 引擎创作的优秀 Lua 游戏作品*

[English](#english) | [中文](#中文)

</div>

---

<a name="中文"></a>

## 📋 游戏目录

| 游戏 | 作者 | 类型 | 描述 |
|------|------|------|------|
| *等待你的作品...* | - | - | - |

---

## 🚀 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/ArcadeHustle/awesome-urhox-games.git
```

### 2. 运行游戏

每个游戏都是独立的项目，进入游戏目录查看对应的 README 了解运行方式。

通用运行方式（需要 UrhoX 引擎环境）：

```bash
TODO
```

---

## 📁 仓库结构

```
awesome-urhox-games/
├── README.md                 # 本文件
├── LICENSE                   # 开源协议
├── CONTRIBUTING.md           # 贡献指南
├── .gitignore
├── .github/
│   ├── ISSUE_TEMPLATE/
│   └── PULL_REQUEST_TEMPLATE.md
│
└── games/                    # 🎮 游戏合集（每个子目录是一个独立项目）
    ├── <author>-<game-name>/ # 游戏目录：作者名-游戏名
    │   ├── README.md         # 游戏说明（必需）
    │   ├── game.json         # 游戏元信息（必需）
    │   ├── preview/          # 预览资源
    │   │   ├── icon.png      # 游戏图标（256x256）
    │   │   └── screenshot*.png
    │   ├── scripts/          # Lua 脚本
    │   │   ├── main.lua      # 入口脚本
    │   │   └── ...
    │   └── assets/           # 游戏资源（可选）
    │
    └── another-game/
        └── ...
```

---

## 🎯 游戏项目规范

### 目录命名

```
games/<author>-<game-name>/
```

- 使用小写字母和连字符
- 格式：`作者名-游戏名`
- 示例：`zhangsan-flappy-bird`、`lisi-maze-runner`

### 必需文件

每个游戏项目**必须**包含以下文件：

#### 1. `game.json` - 游戏元信息

```json
{
  "name": "My Awesome Game",
  "name_zh": "我的超棒游戏",
  "version": "1.0.0",
  "author": {
    "name": "张三",
    "github": "zhangsan",
    "email": "zhangsan@example.com"
  },
  "description": "A brief description of the game",
  "description_zh": "游戏简介",
  "category": "casual",
  "tags": ["2d", "puzzle", "nanovg"],
  "engine": {
    "name": "UrhoX",
    "minVersion": "1.0.0"
  },
  "entry": "scripts/main.lua",
  "orientation": "portrait",
  "license": "MIT",
  "created": "2025-12-01",
  "updated": "2025-12-11"
}
```

**category 可选值**：
- `casual` - 休闲
- `puzzle` - 益智解谜
- `action` - 动作
- `platformer` - 平台跳跃
- `rpg` - 角色扮演
- `strategy` - 策略
- `simulation` - 模拟经营
- `racing` - 竞速
- `arcade` - 街机
- `adventure` - 冒险
- `sports` - 体育
- `card` - 卡牌
- `3d` - 3D 游戏

#### 2. `README.md` - 游戏说明

```markdown
# 🎮 游戏名称

![游戏截图](preview/screenshot1.png)

## 📖 简介

游戏简介...

## 🎮 操作方式

- **鼠标/触屏**：点击跳跃
- **空格键**：跳跃
- **ESC**：退出

## 📦 依赖

- UrhoX 引擎 v1.0.0+

## 🚀 运行

TODO

## 📄 开源协议

MIT License
```

#### 3. `preview/` - 预览资源

- `icon.png` - 游戏图标，256×256 像素，PNG 格式
- `screenshot1.png` - 至少一张游戏截图

### 入口脚本

主入口脚本应放在 `scripts/main.lua`，并遵循 UrhoX 标准生命周期：

```lua
-- scripts/main.lua
require "LuaScripts/Utilities/Sample"

function Start()
    -- 初始化游戏
end

function Update(timeStep)
    -- 游戏主循环
end

function Stop()
    -- 清理资源
end
```

---

## 🤝 如何贡献

我们欢迎所有 UrhoX 开发者提交自己的作品！详见 [CONTRIBUTING.md](CONTRIBUTING.md)。

### 快速提交

1. **Fork 本仓库**
2. **创建游戏目录**: `games/yourname-yourgame/`
3. **开发游戏** - 确保包含所有必需文件
4. **提交 PR** - 填写 PR 模板

### 审核标准

- ✅ 游戏可正常启动和运行
- ✅ 包含所有必需文件
- ✅ 代码质量达标
- ✅ 无恶意代码
- ✅ 素材版权合规

---

## 📜 开源协议

本仓库采用 [MIT License](LICENSE)。

每个游戏项目可有自己的协议，请查看各项目的 `game.json` 中的 `license` 字段。

---

## 🔗 相关链接

- [UrhoX 引擎](https://github.com/xindong/UrhoX)
- [UrhoX AI 开发套件](https://github.com/xindong/UrhoX/tree/main/ai-dev-kit)
- [Lua API 文档](https://github.com/xindong/UrhoX/tree/main/ai-dev-kit/docs/api)
- [项目脚手架](https://github.com/xindong/UrhoX/tree/main/ai-dev-kit/templates)

---

<a name="english"></a>

## English

### About

A curated collection of awesome Lua games built with the UrhoX game engine by community developers.

### Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### License

MIT License - See [LICENSE](LICENSE) for details.

---

<div align="center">

**Made with ❤️ by UrhoX Community**

*欢迎提交你的游戏作品！*

</div>
