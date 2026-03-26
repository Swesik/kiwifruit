# Claude Skills 使用指南

这份文档说明 PR #32 引入的两个 Claude Code skill 的用途和使用方式。
Skill 合并后，Claude Code 可以直接调用这些能力，你只需要用自然语言描述想做什么。

---

## 1. iOS Simulator Skill

**能做什么**：让 Claude 直接操控 iOS 模拟器——点按钮、输入文字、滑动屏幕、检查 UI、跑测试，不需要你手动操作。

### 前置条件

```bash
# 检查环境是否就绪
bash .claude/ios-simulator-skill/scripts/sim_health_check.sh
```

需要：macOS 12+、Xcode Command Line Tools、Python 3

### 常见使用场景

#### 启动 app
```
跟 Claude 说：帮我启动 kiwifruit app
```
Claude 会执行：
```bash
python scripts/app_launcher.py --launch com.kiwifruit.app
```

#### 测试一个功能流程
```
跟 Claude 说：帮我测试一下加入 challenge 的完整流程
```
Claude 会：
1. 分析当前屏幕（`screen_mapper.py`）
2. 找到对应按钮（`navigator.py --find-text "JOIN NOW" --tap`）
3. 验证结果是否正确

#### 检查 UI 问题
```
跟 Claude 说：帮我检查当前屏幕有没有 accessibility 问题
```
Claude 会执行：
```bash
python scripts/accessibility_audit.py --verbose
```
输出缺失 label、空按钮、触控区域太小等问题。

#### 模拟推送通知
```
跟 Claude 说：发一条测试推送通知
```
```bash
python scripts/push_notification.py \
  --bundle-id com.kiwifruit.app \
  --title "New Challenge" \
  --body "A rainy day challenge is waiting for you"
```

#### 设置模拟器位置权限
```
跟 Claude 说：给 app 授予位置权限
```
```bash
python scripts/privacy_manager.py \
  --bundle-id com.kiwifruit.app \
  --grant location
```

#### 截图对比（回归测试）
```
跟 Claude 说：和上次截图对比看看 UI 有没有变化
```
```bash
python scripts/visual_diff.py before.png after.png --threshold 0.02
```

#### Build 并跑测试
```
跟 Claude 说：帮我 build 项目并跑一下测试
```
```bash
python scripts/build_and_test.py \
  --project kiwifruit/kiwifruit.xcodeproj \
  --scheme kiwifruit \
  --test
```

### 脚本速查

| 脚本 | 用途 |
|---|---|
| `sim_health_check.sh` | 检查环境 |
| `app_launcher.py` | 启动/关闭/安装 app |
| `screen_mapper.py` | 列出当前屏幕所有可交互元素 |
| `navigator.py` | 找元素并点击/输入 |
| `gesture.py` | 滑动、长按、缩放 |
| `keyboard.py` | 输入文字、按硬件键 |
| `log_monitor.py` | 实时查看 app 日志 |
| `accessibility_audit.py` | 无障碍合规检查 |
| `visual_diff.py` | 截图对比 |
| `push_notification.py` | 模拟推送通知 |
| `privacy_manager.py` | 管理 app 权限 |
| `status_bar.py` | 设置状态栏（时间、电量） |
| `build_and_test.py` | 构建 + 测试 |

---

## 2. Frontend Design Skill

**能做什么**：生成高质量、有设计感的前端界面代码（HTML/CSS/JS、React 等），避免千篇一律的"AI 风格"。

### 使用场景

这个 skill 主要用于 web 端，对 kiwifruit（SwiftUI iOS app）直接用途有限，但可以用于：
- 生成项目官网或 landing page
- 设计 web 版 dashboard（如果以后有后台管理页面）
- 快速出一个 UI 原型用来讨论设计方向

### 使用方式

```
跟 Claude 说：帮我设计一个 kiwifruit 的 landing page，
风格要和 app 一致，手绘感、kiwi 绿色调
```

Claude 会：
1. 先分析设计方向（目标用户、色调、记忆点）
2. 输出完整可运行的 HTML/CSS/JS 代码
3. 字体、动画、布局都会有明确的设计意图

---

## 总结

| Skill | 主要用途 | 对 kiwifruit 的价值 |
|---|---|---|
| ios-simulator-skill | 自动化测试和模拟器操控 | 高——可以让 Claude 自动测试功能流程 |
| frontend-design | 生成 web UI 代码 | 中——适合官网或后台页面 |

merge PR #32 后，这些能力就可以直接在 Claude Code 对话里使用。
