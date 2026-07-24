#!/usr/bin/env python3
"""
Claude Code Review Script for UrhoX Games

当 PR 评论中包含 @claude 时，使用 Claude API 进行代码审查。
会自动加载 UrhoX AI Dev Kit 作为上下文知识。
"""

import os
import sys
import glob
import anthropic

def load_ai_dev_kit_knowledge():
    """加载 UrhoX AI Dev Kit 知识文件"""
    knowledge_parts = []
    ai_dev_kit_path = "/tmp/ai-dev-kit"
    
    # 优先加载的关键文档
    priority_files = [
        "CLAUDE.md",
        "docs/AI_QUICK_RULES.md", 
        "docs/AI_DEVELOPER_GUIDE.md",
    ]
    
    for rel_path in priority_files:
        full_path = os.path.join(ai_dev_kit_path, rel_path)
        if os.path.exists(full_path):
            try:
                with open(full_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    knowledge_parts.append(f"## {rel_path}\n\n{content}\n")
            except Exception as e:
                print(f"Warning: Failed to read {full_path}: {e}")
    
    # 加载 patterns 目录的示例代码
    patterns_dir = os.path.join(ai_dev_kit_path, "docs/patterns")
    if os.path.exists(patterns_dir):
        for pattern_file in glob.glob(os.path.join(patterns_dir, "*.md")):
            try:
                with open(pattern_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                    rel_name = os.path.basename(pattern_file)
                    knowledge_parts.append(f"## Pattern: {rel_name}\n\n{content}\n")
            except Exception as e:
                print(f"Warning: Failed to read {pattern_file}: {e}")
    
    return "\n---\n".join(knowledge_parts) if knowledge_parts else ""


def load_pr_diff():
    """加载 PR diff"""
    diff_file = "/tmp/pr_diff.patch"
    if os.path.exists(diff_file):
        with open(diff_file, 'r', encoding='utf-8', errors='ignore') as f:
            return f.read()
    return ""


def load_changed_files_content():
    """加载变更文件的完整内容"""
    files_list = "/tmp/changed_files.txt"
    contents = []
    
    if not os.path.exists(files_list):
        return ""
    
    with open(files_list, 'r') as f:
        files = [line.strip() for line in f if line.strip()]
    
    for filepath in files:
        # 只关注游戏相关的 Lua 文件和配置
        if filepath.startswith("games/") and (
            filepath.endswith(".lua") or 
            filepath.endswith(".json") or
            filepath.endswith(".md")
        ):
            if os.path.exists(filepath):
                try:
                    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                        contents.append(f"### {filepath}\n```\n{content}\n```\n")
                except Exception as e:
                    print(f"Warning: Failed to read {filepath}: {e}")
    
    return "\n".join(contents)


def run_claude_review():
    """执行 Claude 代码审查"""
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        error_msg = "❌ **Error**: `ANTHROPIC_API_KEY` secret is not configured.\n\nPlease add your Anthropic API key in repository Settings → Secrets → Actions."
        with open("/tmp/review_result.md", 'w') as f:
            f.write(error_msg)
        return

    base_url = os.environ.get("ANTHROPIC_BASE_URL", "https://api.anthropic.com")
    model = os.environ.get("ANTHROPIC_MODEL", "claude-sonnet-4-20250514")
    
    pr_number = os.environ.get("PR_NUMBER", "unknown")
    comment_body = os.environ.get("COMMENT_BODY", "")
    
    # 提取 @claude 后面的具体指令
    user_instruction = ""
    if "@claude" in comment_body.lower():
        parts = comment_body.lower().split("@claude", 1)
        if len(parts) > 1:
            user_instruction = parts[1].strip()
    
    # 加载知识和代码
    knowledge = load_ai_dev_kit_knowledge()
    pr_diff = load_pr_diff()
    changed_files = load_changed_files_content()
    
    # 构建系统提示
    system_prompt = f"""你是一个专业的 UrhoX 游戏引擎 Lua 代码审查专家。你的任务是审查提交到 awesome-urhox-games 仓库的游戏代码。

## 你的专业知识

以下是 UrhoX 引擎的开发文档和最佳实践：

{knowledge[:50000] if knowledge else "（知识库加载失败，请基于通用 Lua 最佳实践进行审查）"}

## 审查标准

1. **代码质量**: Lua 代码是否遵循最佳实践
2. **UrhoX API 使用**: 是否正确使用 UrhoX 引擎 API
3. **游戏逻辑**: 游戏逻辑是否合理、是否有明显 bug
4. **性能**: 是否有性能问题（如 Update 中的频繁分配）
5. **安全性**: 是否有安全隐患
6. **项目规范**: 是否符合 awesome-urhox-games 的项目规范（game.json、README.md 等）

## 输出格式

请用中文回复，格式如下：
- 使用 emoji 使审查更易读
- 分类列出问题（严重 🔴、警告 🟡、建议 🟢）
- 对每个问题给出具体的代码位置和修改建议
- 最后给出总体评价和是否建议合并
"""

    # 构建用户消息
    user_message = f"""请审查以下 Pull Request #{pr_number} 的代码变更：

## 用户特别要求
{user_instruction if user_instruction else "（无特别要求，请进行全面审查）"}

## PR Diff
```diff
{pr_diff[:30000] if pr_diff else "（无法获取 diff）"}
```

## 变更文件完整内容
{changed_files[:20000] if changed_files else "（无游戏相关文件变更）"}

请开始代码审查。
"""

    try:
        client = anthropic.Anthropic(api_key=api_key, base_url=base_url)
        
        response = client.messages.create(
            model=model,
            max_tokens=4096,
            system=system_prompt,
            messages=[
                {"role": "user", "content": user_message}
            ]
        )
        
        review_content = response.content[0].text
        
        # 添加头部信息
        result = f"""## 🤖 Claude Code Review

> 由 Claude AI 自动生成的代码审查报告
> PR #{pr_number} | 触发者: @claude 命令

---

{review_content}

---
<sub>🔗 Powered by [Claude](https://anthropic.com) | 知识来源: [UrhoX AI Dev Kit](https://urhox-demo-platform.spark.xd.com/ai-dev-kit/pd/stable/ai-dev-kit.zip)</sub>
"""
        
        with open("/tmp/review_result.md", 'w', encoding='utf-8') as f:
            f.write(result)
            
        print("✅ Code review completed successfully")
        
    except Exception as e:
        error_msg = f"""## ❌ Claude Code Review Failed

抱歉，代码审查过程中出现错误：

```
{str(e)}
```

请检查 `ANTHROPIC_API_KEY` 配置是否正确。
"""
        with open("/tmp/review_result.md", 'w', encoding='utf-8') as f:
            f.write(error_msg)
        print(f"❌ Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    run_claude_review()
