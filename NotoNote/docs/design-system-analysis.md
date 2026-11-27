# FlClash UI 复用分析 · 设计阶段成果

> 分析对象：`chen08209/FlClash`（commit `afe7136`，2026-11-20）+ 其子模块 `chen08209/prism_ui`（v0.1.3）
> 目的：为自建安卓 App 抽取一套与代理业务无关的 UI 资产
> 结论基于源码逐文件核对，不含推测

---

## 0. 结论先行

| 判断 | 内容 |
|---|---|
| **最大的意外收获** | FlClash 的 UI 并不在 `lib/` 里，而在独立包 `plugins/prism_ui`（独立 git 仓库、独立版本号、独立测试）。整包可直接复用 |
| **可直接搬走** | `prism_ui` 全部 147 个文件 / 约 4.9 万行，零代理依赖、零状态管理依赖、不 import Material |
| **应用层可搬** | `lib/ui/` 中的 `ListItem`、`Scaffold`、`NestedSheet`、`SettingTextCard`、QR 组件、129 个矢量图标 |
| **必须放弃** | `lib/core`、`lib/plugins`、`lib/providers`、`lib/models`、`lib/database`、`lib/l10n`、`lib/manager` 主体（约 12.7 万行） |
| **真实成本** | ① 自己实现 20 条组件内置文案；② 需 Flutter ≥ 3.47（用到 SDK 的 `RoundedSuperellipseBorder`、`clipRSuperellipse`）；③ 应用层外壳全与 Riverpod 绑定，只能当参考实现重写 |

一句话：**你不是"从别人的 App 里抠组件"，而是"拿到了别人已经抽好的设计系统包，只要换掉它的业务外壳"。**

---

## 1. 关键结构发现

### 1.1 UI 早已被抽成独立包

```
FlClash/
├── lib/                    ← 业务 + 应用层 UI（370 文件 / 19.8 万行）
├── core/Clash.Meta/        ← 代理内核（子模块，Rust）
└── plugins/
    ├── prism_ui/           ← ★ 设计系统本体（子模块，独立仓库）
    ├── rust_api/           ← 内核 FFI 桥
    ├── dynamic_color/      ← 安卓取色（平台专属）
    ├── code_forge/         ← 代码编辑器
    └── setup/              ← 构建脚本
```

`pubspec.yaml` 中的声明：

```yaml
prism_ui:
  path: plugins/prism_ui
```

`lib/ui/ui.dart` 的第一行就是：

```dart
export 'package:prism_ui/prism_ui.dart';
```

**含义**：FlClash 自己也不复制这套 UI，它直接依赖包。你同样可以，而且不存在版本冲突——这是一个可以被 `pubspec` 单独引用的单元（也可以直接 vendor 进 `plugins/`）。

### 1.2 prism_ui 的依赖清单（完整）

```yaml
name: prism_ui
version: 0.1.3
environment:
  sdk: '>=3.10.0 <4.0.0'
  flutter: '>=3.47.0'
dependencies:
  flutter: {sdk: flutter}
  collection: ^1.19.1
  freezed_annotation: ^3.1.0
  path_parsing: ^1.1.0
flutter:
  shaders:
    - shaders/liquid_glass.frag    # 23.8 KB
    - shaders/ink_sparkle.frag     # 3.9 KB
```

逐文件扫描结果：

- `import 'package:flutter/material.dart'`：**0 处**
- `import 'package:flutter_riverpod/...'` / `provider`：**0 处**（`scaffold.dart` 里的 `provider` 是它自己的 `SheetProvider`，与状态管理无关）
- 外部包导入仅 4 个：`flutter`（231 次）、`collection`（3 次）、`path_parsing`（1 次）、`freezed_annotation`（1 次）
- Material 的配色算法被**内联**了：`lib/hct/`（2105 行，Material Color Utilities 的 HCT 实现），因此不需要 `material_color_utilities` 依赖

**这是本文最重要的结论：prism_ui 是一个自洽的 UI 运行时，不含任何业务、网络、存储、状态管理代码。**

### 1.3 它重写了 Theme，而不是套 Material 主题

`lib/theme_data.dart` 定义了**自己的** `ThemeData`、`Theme`、`VisualDensity`、`TapTargetSize`、`Easing`、`Colors`，并通过 `InheritedTheme` 下发。`lib/app.dart` 的 `PrismApp` 基于 `WidgetsApp`（不是 `MaterialApp`）。

后果：

- 好处：不会被 Material 的默认样式污染，圆角/动效/层级可完全按 iOS 语义控制
- 代价：**与你现有的 Material 代码不共存**。要么整站迁到 `PrismApp`，要么只取其中的纯展示组件、用 Material 主题包一层（可行但会失去 `SurfaceLevel` 等语义）
- 建议：新 App 从零开始 → 直接用 `PrismApp`，不要混搭

---

## 2. 可独立使用的 UI 组件

### 2.1 分层依据（不是猜的）

对 147 个文件统计"被其他文件 import 的次数"（fan-in），层级自然浮现：

| 文件 | fan-in | 定位 |
|---|---|---|
| `theme_data.dart` | 45 | 主题装配 |
| `context.dart` | 45 | 上下文扩展（`context.colorScheme` 等） |
| `shape.dart` | 37 | 圆角/形状 |
| `surface.dart` | 31 | 层级表面 |
| `typography.dart` | 25 | 字号阶梯 |
| `metrics.dart` | 17 | 间距/尺寸 |
| `color.dart` | 11 | 配色生成 |
| `motion.dart` | 7 | 动效 |
| `l10n.dart` | 12 | 内置文案 |
| `common_button.dart` | 9 | 按钮基座 |
| `liquid_glass.dart` | 8 | 玻璃效果 |
| `press_region.dart` / `press_surface.dart` | 6 / 4 | 按压反馈 |

### 2.2 L0 · 令牌层（先搬这一层，其他都是它的消费者）

| 文件 | 行数 | 提供什么 |
|---|---|---|
| `theme_data.dart` | 266 | `ThemeData`、`Theme`、`ThemeMode`、`Easing`、`kThemeAnimationDuration` |
| `color_scheme.dart` | 729 | 自研 `ColorScheme`（50+ 颜色角色，含 `lerp`、`==`、`hashCode`） |
| `color.dart` | 355 | `seededColorScheme()`、`ColorStyle` 四风格、`ColorExtension`、`ColorSchemeExtension` |
| `shape.dart` | 193 | `AppCorner`、`AppRadius`、`AppShape`、`AppInputBorder` |
| `typography.dart` | 71 | `AppTextStyle` 13 级字号 |
| `metrics.dart` | 116 | `ListInsets`、间距常量、`.ap` / `.mAp` 文本缩放适配 |
| `motion.dart` | 78 | `SpringCurve`、`dropletSpring`、`ArrivingSimulation` |
| `surface.dart` | 304 | `SurfaceLevel`（page/card/block/inset）+ `SurfaceScope` |
| `context.dart` | 75 | `context.colorScheme` / `listTitleStyle` / `motionDuration()` |
| `font.dart` | 79 | 平台字体 + CJK 字形回退 |
| `l10n.dart` | 57 | `UiLocalizations`（20 条文案接口） |

### 2.3 L1 · 基础元件

| 文件 | 行数 | 组件 |
|---|---|---|
| `common_button.dart` | 734 | 所有按钮的基座（按压、禁用、涟漪） |
| `button.dart` | 520 | `TextButton` / `FilledButton` / `IconButton` 风格 |
| `press_region.dart` / `press_surface.dart` | 213 / 496 | 手势与按压表面 |
| `card_surface.dart` | 759 | 卡片表面（含层级自动推进） |
| `card.dart` | — | `Card(onPressed, isSelected, fillsSelection)` |
| `divider.dart` | 33 | 分隔线（含 `createBorderSide`） |
| `text.dart` / `selectable_text.dart` | 236 / 155 | 文本与可选文本 |
| `text_field.dart` | 1588 | 输入框（含明文/密文切换、清除、校验） |
| `input.dart` / `input_border.dart` | 283 / 49 | 输入装饰与边框 |
| `checkbox.dart` / `switch.dart` / `slider.dart` | 145 / 330 / 436 | 开关类控件 |
| `segmented_control.dart` | 141 | 分段控件 |
| `chip.dart` | — | 标签 |
| `chip_title.dart`(FlClash) | 116 | 带头像的标签 |
| `loading.dart` / `skeleton.dart` / `linear_progress.dart` | 514 / 114 / 176 | 加载态 |
| `icons/` | 868 | 矢量图标 DSL：`Glyph`、`GlyphIcon`、20 个内置符号、`AnimatedGlyph` |

### 2.4 L2 · 组合控件

| 文件 | 行数 | 组件 | 复用判断 |
|---|---|---|---|
| `list_row.dart` | 494 | iOS 风格列表行（leading/title/subtitle/trailing） | ★★★ 核心 |
| `list_row_separator.dart` | 394 | 分组分隔线，按位置收边 | ★★★ |
| `list.dart` / `prism_list.dart` | 315 / 240 | 内嵌分组列表（inset grouped） | ★★★ |
| `list_selected.dart` | 200 | 选中态列表 | ★★ |
| `item_position.dart` | 18 | 首/中/尾位置枚举，驱动圆角 | ★★★ 常被忽略但关键 |
| `popup.dart` | 3100 | 弹出菜单 / 气泡 / 锚点 / 数值文本 | ★★★ |
| `dialog.dart` | 913 | 浮动对话框、输入框、`showFloatingDialog` | ★★★ |
| `context_menu.dart` | 237 | 长按菜单 | ★★ |
| `sheet.dart` / `snap_sheet.dart` / `side_sheet.dart` / `paged_sheet.dart` / `form_sheet.dart` | 291 / 1650 / 435 / 277 / 136 | 底部表单、可吸附、侧边、分页 | ★★★ |
| `sheet_header.dart` / `sheet_navigator.dart` | 234 / 65 | 表单头部、表单内导航 | ★★ |
| `search_field.dart` | 152 | 搜索框 | ★★★ |
| `collapsible_section.dart` | 512 | 可折叠分组 | ★★★ |
| `banner.dart` | 669 | 顶部横幅通知 | ★★ |
| `tooltip.dart` | 95 | 悬浮提示 | ★★ |

### 2.5 L3 · 容器与导航

| 文件 | 行数 | 组件 | 复用判断 |
|---|---|---|---|
| `scaffold.dart` | 844 | 页面脚手架（标题、动作折叠、状态栏位） | ★★★ |
| `navigation_dock.dart` | 2139 | iOS 27 悬浮胶囊式导航（含 `NavigationDock.insetOf`） | ★★★ 招牌组件 |
| `navigation_bar.dart` | 136 | 底部标签栏 | ★★★ |
| `tab_view.dart` / `fade_through.dart` | 409 / 348 | 标签页与交叉淡入 | ★★ |
| `sidebar.dart` | 574 | 侧边栏（桌面/平板） | ★★ 手机项目可不用 |
| `navigator.dart` / `navigator_resizable.dart` | — / 519 | 导航栈与可调尺寸壳 | ★★ |
| `view_scope.dart` | 72 | `ViewScope`：窗口尺寸/断点下发 | ★★★ 响应式基础 |
| `measure.dart` | 103 | `MeasureScope`：文本缩放测量 | ★★ |
| `null_status.dart` | 746 | 空状态/错误态版式 | ★★★ |
| `bar_item_presence.dart` | 1091 | 导航栏项目增删动画 | ★ |
| `foot_bar.dart` / `proportion_bar.dart` | 71 / 71 | 底部操作条、占比条 | ★★ |
| `line_chart.dart` | 220 | 迷你折线图 | ★★ |
| `table_layout.dart` / `sortable.dart` | — / 649 | 表格布局、拖拽排序 | ★ |
| `sliver_list/` | 1618 | 自研超级 sliver 列表（变高条目） | ★★ |

### 2.6 L4 · 动效与特效（这是它的差异化所在）

| 文件 | 行数 | 内容 |
|---|---|---|
| `liquid_glass.dart` | 1846 | iOS 26/27 液态玻璃（fragment shader + `LiquidGlassHost` / `LiquidGlassScope`） |
| `liquid_glass_capture.dart` | 1192 | 玻璃采样 |
| `page_transition.dart` | 1108 | 页面推入/弹出转场（弹簧参数取自模拟器实测） |
| `open_container.dart` | 1413 | 列表行展开为全屏页（手风琴式） |
| `goo.dart` | 670 | 果冻融合效果 |
| `drag_back.dart` | 639 | 边缘右滑返回 |
| `theme_cross_fade.dart` | 230 | 明暗主题交叉淡入 |
| `press_sparkle.dart` | 208 | 按压火花（shader） |
| `animated_visibility.dart` / `fade_box.dart` / `keyed_animated_list.dart` | 158 / 231 / 427 | 显隐、淡入淡出、列表增删 |
| `disabled_mask.dart` / `selection_mark.dart` | 48 / 57 | 禁用遮罩、选中标记 |

取舍建议：

- **必留**：`page_transition`、`theme_cross_fade`、`open_container`、`animated_visibility`、`keyed_animated_list`
- **看设备**：`liquid_glass`（1846 行 + 23.8KB shader，低端机上开销可观；`PrismApp` 的 `liquidGlass` 参数可整体关掉）
- **可砍**：`goo`、`press_sparkle`、`bar_item_presence`、`sliver_list`（除非你确实需要变高列表）

---

## 3. FlClash 应用层里那 6 个值得单拿的组件

`lib/ui/`（16 文件 / 5060 行）是应用层 UI，依赖面很小。逐个核过 import：

| 文件 | 行数 | 依赖 | 值不值得拿 |
|---|---|---|---|
| `list_item.dart` | 450 | 仅 `flutter` + `prism_ui` + 同目录 `nested_sheet.dart` | ★★★ **最值得**。一个类 6 个构造器覆盖全部设置行形态 |
| `nested_sheet.dart` | 49 | `flutter` + `prism_ui` | ★★★ 配合上一项，`showNestedExtend()` |
| `scaffold/scaffold.dart`(+2 part) | 1951 | `flutter` + `prism_ui` | ★★★ 自适应 AppBar：动作超 3 个自动折进溢出菜单、搜索态、筛选 chip |
| `setting_text_card.dart` | 37 | `flutter` + `prism_ui` | ★★ 11 行就能自己写 |
| `qr_code.dart` + `qr_matrix.dart` | 74 + 535 | `flutter` + `prism_ui`／纯 Dart | ★★ `qr_matrix` 是纯算法（零依赖），可白拿 |
| `icons/app_glyphs.dart` | — | `flutter` + `prism_ui` | ★★ 129 个矢量图标（dashboard/proxies/profiles…），业务相关的删掉，剩下的能直接用 |
| `null_status_illustration.dart` | 52 | `app_glyphs` | ★★ 空状态插画 |

`ListItem` 的 6 个构造器（这是它最实用的设计）：

```dart
ListItem(...)                 // 纯展示行，可 onTap
ListItem.open(widget: ...)    // 点击展开子页（手机上走 OpenContainer 手风琴，桌面走 NestedSheet）
ListItem.options<T>(...)      // 右侧下拉选项 + 就地弹出菜单
ListItem.input(...)           // 点击弹输入框，带校验/后缀/长度限制
ListItem.checkbox(...)        // 勾选行
ListItem.toggle(...)          // 开关行
```

一个 `ListItem` 就能搭完整个设置页，且圆角/分隔线由 `ItemPositionProvider` 自动按首尾收边——**这是自己从零写最容易漏掉的细节**。

### 不值得拿的

| 文件 | 原因 |
|---|---|
| `delay_color.dart` | 11 行，但语义是"代理延迟"（<600ms 绿、>600 黄）。要的是它的**模式**：把领域数值映射到 `success`/`warning`/`error` |
| `profile_id.dart` | 订阅 ID 配色，纯业务 |
| `emoji.dart` / `fonts.dart` | 只是枚举包装，配合打包字体用 |

---

## 4. 主题 / 颜色 / 字体 / 圆角 / 动画 配置详解

### 4.1 颜色：单一种子色生成整套方案

```
种子色 (seedColor)
   ├── Brightness.light / dark
   ├── ColorStyle: vivid | tinted | soft | monochrome
   └── pureBlack: 深色模式下的纯黑开关
        ↓
   seededColorScheme() → 自研 ColorScheme（50+ 角色）
```

四套风格的实际差异（`lib/color.dart`）：

| ColorStyle | 底层 Variant | 观感 |
|---|---|---|
| `vivid` | `content` | 强调色饱和、鲜明 |
| `tinted` | `content` + 全局轻染色 | 强调色鲜明，中性面也带色相 |
| `soft` | `tonalSpot` | 柔和，是 `ThemeData` 的默认风格 |
| `monochrome` | `monochrome` | 全灰阶，只靠明度 |

关键调色常量（改设计时直接调这些）：

| 常量 | 值 | 作用 |
|---|---|---|
| `_surfaceChroma` | 3.0 | 页面/卡片的色度上限（越低越"白纸"） |
| `_paperChroma` | 1.5 | 浅色下 paper 面的色度 |
| `_primaryContainerChroma` | 48.0 | 主色容器上限 |
| `_statusContainerChroma` | 16.0 | 成功/警告容器上限（防止绿色块过艳） |
| `_darkCardTone` / `_darkBlockTone` / `_darkInsetTone` | 15 / 21 / 27 | 深色下三层卡片的明度 |
| `_darkOnSurfaceTone` | 97 | 深色正文（不用纯白，减疲劳） |
| `_minAccentTone` / `_maxAccentTone` | 35 / 60 | 浅色强调色明度夹取区间 |
| `_minDarkAccentTone` / `_maxDarkAccentTone` | 50 / 75 | 深色强调色夹取 |

Material 没有、它自己加的语义色（`lib/color.dart` 扩展）：

| 属性 | 浅色 | 深色 |
|---|---|---|
| `success` / `onSuccess` | tone 40 / 100 | tone 80 / 20 |
| `successContainer` | tone 90 | tone 30 |
| `warning` / `warningContainer` | 同构于 success | 同构 |
| `destructive`（iOS systemRed） | `#FF383C` | `#FF4245` |
| `modalScrim` / `alertScrim` | alpha 0.2 | alpha 0.48 |
| `chromeSurface` | 侧边栏/工具条专用面 | — |

还有 `ColorScheme.toPureBlack(bool)`：深色模式下把 `surface` 系列按 tone 整体下压到纯黑，OLED 省电。

**落地建议**：`ColorStyle.soft` + 一个品牌色做种子，就能得到 FlClash 的默认观感；想让 App 更有个性就走 `vivid`。

### 4.2 表面层级：4 级，取代阴影

`SurfaceLevel` 是这套设计里比圆角更重要的结构约束：

| 层级 | 浅色取色 | 深色取色 |
|---|---|---|
| `page` | `surfaceContainer` | `surface` |
| `card` | `surfaceBright` | `surfaceContainer` |
| `block` | `surfaceContainer` | `surfaceContainerHigh` |
| `inset` | `surfaceContainerHighest` | `surfaceContainerHighest` |

配套：

- `context.surfaceLevel` / `context.raisedSurfaceLevel`（自动取下一级）
- `SurfaceScope(level: ...)` 显式声明，子组件用 `context.raisedSurfaceLevel` 自适应
- `SurfaceLevel.floatingOf(scheme)`：深色下浮层用 `block`，浅色用 `card`

**规则**：卡片里放卡片必须提升一级，而不是加阴影。这是这套 UI"平但有层次"的原因。

### 4.3 字体

字号阶梯（`AppTextStyle`，iOS Dynamic Type 的 1dp = 1pt 映射 + 2 个自加档）：

| 档位 | 字号/行高 | 字重 | 用途 |
|---|---|---|---|
| `display` | 40 / 44 | w700 | 仪表盘大数字（自加） |
| `largeTitle` | 34 / 41 | w700 | 大标题 |
| `title1` | 28 / 34 | w700 | 一级标题 |
| `pageTitle` | 24 / 30 | w600 | 页面标题（自加） |
| `title2` | 22 / 28 | w700 | 二级标题 |
| `title3` | 20 / 25 | w400 | 三级标题 |
| `headline` | 17 / 22 | w600 | 强调正文 |
| `body` | 17 / 22 | w400 | 正文 |
| `callout` | 16 / 21 | w400 | 副正文 |
| `subheadline` | 15 / 20 | w400 | 列表副标题 |
| `footnote` | 13 / 18 | w400 | 注释 |
| `caption1` | 12 / 16 | w400 | 辅助说明 |
| `caption2` | 11 / 13 | w400 | 最小字 |

统一处理：`letterSpacing: 0`、`height = leading / size`、`leadingDistribution: even`。
每个档位另有"强调"变体：`AppTextStyle.body.of(context, emphasized: true)` → w600。

字体来源（**关键**，`lib/font.dart` + `theme_data.dart`）：

| 平台 | family | 说明 |
|---|---|---|
| Android | `Roboto` | 系统默认 |
| iOS | `CupertinoSystemText` / `CupertinoSystemDisplay`（20pt 分界） | |
| 桌面 | 各自系统字体 | |

**中文回退表**（这段代码很值钱，能避免英文界面下中文被渲染成日文字形）：

| 平台 | 简体 | 繁体 | 日 | 韩 |
|---|---|---|---|---|
| Windows | Microsoft YaHei UI | Microsoft JhengHei UI | Yu Gothic UI | Malgun Gothic |
| macOS | PingFang SC | PingFang TC | Hiragino Sans | Apple SD Gothic Neo |
| Linux | Noto Sans CJK SC | Noto Sans CJK TC | Noto Sans CJK JP | Noto Sans CJK KR |

判断逻辑：先看 locale 的 `scriptCode`（`Hans`/`Hant`），再看 countryCode（`TW`/`HK`/`MO`），兜底简体。

打包字体（`assets/fonts/`）：

| 字体 | 体积 | 用途 |
|---|---|---|
| `Twemoji.Mozilla.ttf` | 1.39 MB | emoji 统一渲染（`PrismApp(emojiFont:)`） |
| `JetBrainsMono-Regular.ttf` | 267 KB | 日志/代码等等宽场景 |

安卓上 emoji 由系统字体处理即可，**Twemoji 可以不要**（省 1.39MB）；等宽字体只在实际有代码/日志页时才需要。

### 4.4 圆角：9 档 + 超椭圆

```dart
AppCorner.none = 0    xs = 4     sm = 8      md = 16
AppCorner.lg   = 20   xl = 24    xxl = 28
AppCorner.listGroup = 26     // 内嵌分组列表的段圆角
AppCorner.alert     = 34     // 对话框，比 sheet 更圆
AppCorner.full      = 1000   // 胶囊
```

`AppCorner.fit(shortestSide)`：按短边的 1/3 作为上限自动降档（小头像不会被圆角吃掉）。

**形状用 `RoundedSuperellipseBorder`（超椭圆），不是 `BorderRadius`。** 这是它看起来"像 iOS 而不像 Material"的根本原因——普通圆角在视觉上会有"直边突然转圆"的接缝，超椭圆的曲率是连续的。

```dart
AppShape.sm          // 8 的超椭圆
AppShape.xl          // 24 的超椭圆
AppShape.all(12)     // 任意值
AppShape.circle      // 正圆
AppShape.input       // AppInputBorder，专供 TextField
```

⚠️ `RoundedSuperellipseBorder` 和 `Canvas.clipRSuperellipse` / `drawRSuperellipse` 来自 Flutter SDK 较新版本。**这是本项目对 Flutter 版本的硬约束**，落地第一步要验证。

### 4.5 动画

时长与曲线令牌：

| 令牌 | 值 | 用途 |
|---|---|---|
| `kThemeAnimationDuration` | 200 ms | 主题切换淡入 |
| `midDuration` | 200 ms | 中等过渡 |
| `commonDuration` | 300 ms | 常用过渡 |
| `fadeTabDuration` | 220 ms + `Curves.easeInOut` | 标签页淡入 |
| `kMinInteractiveDimension` | 48 dp | 最小点击区 |

曲线（`Easing`，Material 3 那套）：

| 名称 | 值 |
|---|---|
| `standard` | `Cubic(0.2, 0, 0, 1)` |
| `standardDecelerate` | `Cubic(0, 0, 0, 1)` |
| `standardAccelerate` | `Cubic(0.3, 0, 1, 1)` |
| `emphasizedDecelerate` | `Cubic(0.05, 0.7, 0.1, 1)` |
| `legacyDecelerate` | `Cubic(0, 0, 0.2, 1)` |

弹簧参数（真实物理参数，不是贝塞尔近似）：

| 场景 | 参数 |
|---|---|
| `dropletSpring`（水滴） | mass 1, stiffness 165, dampingRatio 0.8 |
| 页面推入 `_pushSpring` | `withDurationAndBounce(300ms)`，初速 9（距离/秒），容差 1e-3 |
| 对话框 `_alertSpring` | 弹簧 404 ms |
| 菜单展开 | 弹簧 405 ms / 收起 150 ms |
| 拖拽回弹 | 80 ms（跟手）/ 300 ms（回位） |

组件级时长抽样（看见它的节奏感）：

```
checkbox 150 · collapse 240 · connected_button 240 · loading 240
animated_visibility 300 · fade_through 300 · button 380
animated_glyph 350 · banner 出 170 / 停留 3150 · navigation_bar 500
liquid_glass 亮 120 / 暗 360 · bar_item_presence 292 / 330 / 416
```

**无障碍**：`context.motionDuration(d)` 会在 `MediaQuery.disableAnimations` 时返回 `Duration.zero`。所有动画都走这个函数——这点务必照抄，系统"减弱动态效果"开关必须生效。

---

## 5. 组件依赖关系

```
┌──────────────────────────────────────────────────────────────┐
│ L4 特效/动效   liquid_glass · page_transition · open_container │
│                goo · drag_back · press_sparkle · sortable      │
├──────────────────────────────────────────────────────────────┤
│ L3 容器/导航   PrismApp · Scaffold · NavigationDock/NavBar     │
│                Sidebar · ViewScope · NullStatus · tab_view     │
├──────────────────────────────────────────────────────────────┤
│ L2 组合控件    list(list_row/separator/item_position) · popup  │
│                dialog · sheet 家族 · search_field · chip        │
│                collapsible_section · banner · tooltip          │
├──────────────────────────────────────────────────────────────┤
│ L1 基础元件    button/common_button · press_surface · card_surface │
│                text_field · checkbox/switch/slider · icons     │
├──────────────────────────────────────────────────────────────┤
│ L0 令牌        theme_data · color_scheme/color · shape         │
│                typography · metrics · motion · surface         │
│                context · font · l10n                           │
├──────────────────────────────────────────────────────────────┤
│ 外部依赖       flutter SDK · collection · path_parsing         │
│                freezed_annotation · (2 个 shader)              │
└──────────────────────────────────────────────────────────────┘
```

依赖方向单一（下层不知道上层），所以可以**只取 L0+L1+L2 做一套轻量组件库**，不引入 L3/L4 的导航与玻璃特效。

应用层（FlClash `lib/ui/`）的位置：

```
lib/ui/list_item.dart ──► prism_ui (list_row, popup, open_container, checkbox, switch)
                     └──► lib/ui/nested_sheet.dart ──► prism_ui (sheet, navigator)
lib/ui/scaffold/*    ──► prism_ui (popup, common_button, icons, bar_item_presence)
lib/ui/icons/app_glyphs.dart ──► prism_ui/icons/glyph
```

**注意**：`ListItem` 里有两处会直接影响你的适配成本：

1. `context.isMobileView`（来自 `ViewScope`）决定走手风琴还是 NestedSheet
2. `showNestedExtend()` 依赖 `prism_ui` 的 navigator 约定，必须包在 `PrismApp` 内

---

## 6. 剔除清单

### 6.1 按目录剔除（FlClash `lib/`）

| 目录 | 文件/行数 | 为什么剔除 | 替代 |
|---|---|---|---|
| `lib/core/` | 17 / 3,707 | 代理核心控制（Clash 配置、TUN、DNS） | 无 |
| `lib/plugins/` | 5 / 732 | 平台通道（Android/iOS 原生桥） | 自己写或用 `MethodChannel` |
| `lib/manager/` | 13 / 2,008 | 平台窗口/托盘/自启/更新 | 保留 `theme_manager.dart` 思路自写 |
| `lib/database/` | 13 / 12,221 | Drift 数据库（含生成代码） | 你自己的存储 |
| `lib/providers/` | 50 / 21,260 | Riverpod 状态层，全部业务耦合 | 自选状态管理 |
| `lib/models/` | 30 / 47,608 | Clash 配置模型（含生成代码），最重的一块 | 无 |
| `lib/l10n/` | 8 / 34,311 | 8 种语言的 ARB 生成物 | 自己的 i18n |
| `lib/pages/` | 5 / 3,157 | 主页/编辑器/扫码，业务页 | `home.dart` 可当外壳参考 |
| `lib/views/` | 78 / 36,785 | 全部业务页面（配置/订阅/连接/规则） | 无 |
| `lib/features/` | 40 / 9,793 | 表单/连接/编辑器特性，多数绑 providers | 仅 `form_row.dart` 可参考 |
| `lib/common/` | 77 / 16,252 | 网络/HTTP/WebDAV/YAML/加密等 | 按需自写 |
| `lib/enum/` | 1 / 889 | 业务枚举 | 无 |

**合计剔除约 18.7 万行，占 `lib/` 的 95%。**

### 6.2 按依赖剔除（即使在 `lib/ui/` 内）

| 判据 | 涉及文件 | 处理 |
|---|---|---|
| `import flutter_riverpod` | `widgets/config_item.dart`、`widgets/record_filter.dart`、`widgets/record_table.dart`、`manager/app_manager.dart` | 剔除或重写状态层 |
| `import rust_api`（24 文件） | 内核 FFI，全部业务层 | 剔除 |
| `import dio`（12 文件） | 网络请求 | 剔除 |
| `import drift`（4 文件） | 数据库 | 剔除 |
| 平台专属 | `plugins/dynamic_color`（安卓 Material You 取色）、`common/linux_elevation.dart`、`common/tray.dart`、`common/window.dart` | 剔除；取色可选保留（见下） |
| 扫码/选图/文件选择 | `mobile_scanner`(2)、`image_picker`(1)、`file_picker`(1) | 剔除 |
| 业务图标 | `app_glyphs` 中 proxies/profiles 等条目 | 只留通用（设置、搜索、箭头、关闭等） |

### 6.3 需要"改造而不是直接搬"的部分

| 目标 | 现状 | 改法 |
|---|---|---|
| `AppSidebarContainer`（侧边栏 + 页面切换） | `manager/app_manager.dart`，`ConsumerWidget`，读 `navigationStateProvider` / `sideWidthProvider` / `windowBlurProvider` | 结构可抄，状态换成你自己的（`setState` / `ValueNotifier` / 你选的库），约 100 行 |
| `pages/home.dart`（外壳） | Riverpod + `appSettingProvider` | 同上，抄 `NavigationDock` + `NavigationBar` + `_FadeTabPage` 的组合方式 |
| `ThemeManager` | 依赖 4 个 provider | 用 `AnimatedBuilder` + 一个 `ValueNotifier<Brightness>` 即可，逻辑就 30 行 |
| `dynamic_color`（可选） | Android 12+ 取系统壁纸色作种子 | 想保留"跟随系统主题色"就接这个插件，只取 `Color` 再喂给 `seededColorScheme`，不引入其他依赖 |

---

## 7. 建议的最小技术栈

```yaml
dependencies:
  flutter: {sdk: flutter}
  prism_ui: {path: plugins/prism_ui}   # vendored，可改
  collection: ^1.19.1
  path_parsing: ^1.1.0
  freezed_annotation: ^3.1.0           # prism_ui 自身需要
```

不引入：`flutter_riverpod`、`dio`、`drift`、`rust_api`、`flutter_svg`、`mobile_scanner`。

状态管理自选（`prism_ui` 不关心）；若用 Riverpod 或 Provider 均可，因为 UI 层只读 `InheritedWidget`（`Theme` / `SurfaceScope` / `ViewScope` / `MeasureScope`）。

---

## 8. 接入步骤（设计阶段 checklist）

1. **建立 `plugins/prism_ui`**：以子模块或直接 vendored 源码方式引入（v0.1.3，147 文件 / 4.9 万行）
2. **实现 `UiLocalizations`**：20 个 getter（`back`/`cancel`/`clearSearch`/`close`/`copy`/`cut`/`dialog`/`hidePassword`/`more`/`noSearchResults`/`paste`/`reset`/`search`/`select`/`selectAll`/`showLess`/`showMore`/`showPassword`/`sort`/`submit`），注册 delegate。**漏了会 assert 失败**
3. **定义品牌主题**：`seededColorScheme(seedColor: 你的品牌色, style: ColorStyle.soft)`
4. **替换 App 入口**：`PrismApp(theme:, darkTheme:, themeMode:, home:, localizationsDelegates:)`
5. **搬 `ListItem` + `nested_sheet.dart`**：设置页基建
6. **决定是否启用**：`liquidGlass`（性能）、`sidebar`（手机用不上）、`Twemoji`（省 1.39MB）
7. **验证 Flutter 版本**：`RoundedSuperellipseBorder` / `clipRSuperellipse` 必须存在
8. **自建导航外壳**：参考 `home.dart` + `AppSidebarContainer`，去掉 Riverpod
9. **定 3 个基准页面**做视觉验收：设置页（列表体系）、详情页（转场 + 玻璃）、空状态页

---

## 9. 风险与注意事项

| 风险 | 说明 | 应对 |
|---|---|---|
| Flutter 版本门槛 | ≥3.47，且用到超椭圆 API；FlClash 本体要求 ≥3.50 | 先跑通一个空白 `PrismApp` 再往下做 |
| 不能与 Material 混用 | 它重写了 `Theme`，`MaterialApp` 里的组件拿不到 `prism_ui` 的 `ThemeData` | 全站统一，或只取纯展示组件 |
| `ListItem` 的隐式依赖 | `context.isMobileView`、`showNestedExtend` 都需要 `PrismApp` 的 navigator | 整体接入，别单文件复制 |
| 玻璃效果开销 | 1846 行 + 23.8KB shader，中低端机掉帧 | `liquidGlass: null` 整体关闭，双端配置化 |
| 无障碍 | 所有动画须走 `context.motionDuration()` | 照抄，别用裸 `Duration` |
| 中文字形 | 不配 fallback 时英文界面下中文可能显示日文字形 | 抄 `app_font.dart` 的回退表 |
| 版本漂移 | `prism_ui` 仍在演进（0.1.x） | vendored 固定版本，不跟上游 |

---

## 10. 附：原始数据

| 指标 | 数值 |
|---|---|
| FlClash `lib/` | 370 文件 / 197,704 行 |
| prism_ui `lib/` | 147 文件 / 48,986 行 |
| 其中可搬部分 | ≈ 4.9 万行（prism_ui）+ 3,000 行（lib/ui 精选） |
| 剔除部分 | ≈ 18.7 万行 |
| prism_ui 顶层组件文件 | 111 个 |
| prism_ui 外部依赖 | 4 个 |
| FlClash 自定义图标 | 129 个矢量 glyph |
| 内置文案条目 | 20 条 |
