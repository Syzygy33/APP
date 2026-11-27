# VENDOR.md —— prism_ui 本地副本说明

## 来源

| 项 | 值 |
|---|---|
| 上游仓库 | `git@github.com:chen08209/prism_ui.git`（branch `main`） |
| 引入版本 | `0.1.3`（`pubspec.yaml: version: 0.1.3`） |
| 引入方式 | 整包复制（vendored），**不是** submodule，**不是** git 依赖 |
| 引入日期 | 2026-11-23 |
| 代码规模 | 147 个 `lib/` 文件 / 约 4.9 万行 |

## 为什么是 vendored

1. 本项目的 20 条 `UiLocalizations` 必须在本包之外实现，但品牌色、图标、可能的性能补丁都在包内——需要能自由修改。
2. 上游是 `0.1.x`、无 tag、仓库地址为 SSH。用 git 依赖意味着上游任何一次 push 都会影响构建。
3. 包内无原生代码、无构建步骤（除 2 个 shader），维护成本低。

## 红线

- **不要 `flutter pub upgrade` 时把它当普通依赖升级**——升级必须整包替换后重跑冒烟测试。
- **不要删 `shaders/`**：`liquid_glass.frag` / `ink_sparkle.frag` 缺失会导致运行时崩溃（即使不使用玻璃效果，`PrismApp` 的 shader 声明仍在 `pubspec.yaml` 里）。
- **改动要记录**，格式见下方表格。上游修 bug 时才能判断能否直接摘。

## 本地改动记录

| 日期 | 文件 | 改动 | 原因 |
|---|---|---|---|
| 2026-11-23 | `lib/liquid_glass.dart` | `pushClipRSuperellipse` 补 `clipBehavior: ui.Clip.antiAlias` | Flutter 3.50 的 Web 端 `dart:ui` 把该参数声明为 `required`，原生端仍有默认值；不显式传值 Web 构建直接编译失败。行为不变。 |
| 2026-11-23 | `lib/liquid_glass.dart` | `LiquidGlassStyle.menu` 深色 tint alpha `0.63 → 0.9` | 深色下菜单太透，背后的正文/按钮能透过菜单读出来；提高不透明度后仍保留玻璃质感，所有菜单同步变化，不会彼此不一致。 |


## 上游同步方式

```bash
# 1. 拉新版本到临时目录
git clone git@github.com:chen08209/prism_ui.git /tmp/prism_ui_new

# 2. 对比差异（重点看 lib/ 与 shaders/）
diff -rq plugins/prism_ui/lib /tmp/prism_ui_new/lib

# 3. 只摘需要的修复，别整包覆盖（会丢掉本地改动）
```

## 已知上游限制

- `lib/app.dart` 的 `PrismApp` 基于 `WidgetsApp`，**不与 `MaterialApp` 共存**。
- 全部组件依赖 `UiLocalizations`，未注册 delegate 时调试模式会 assert。
- `lib/scaffold.dart` 的 `PrismScaffold` 需要 `PreferredSizeWidget bar`，Dart 侧需自己包一层（见 `lib/pages/settings_demo.dart` 的 `_DemoBar`）。
