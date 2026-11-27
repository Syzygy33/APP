# 接入规格 · Integration Spec

> 配套文档：`docs/design-system-analysis.md`（为什么这么做）
> 本文只讲**怎么做**：目录、规则、第一条验证路径。

---

## 1. 当前目录结构

```
NotoNote/
├── pubspec.yaml
├── analysis_options.yaml
├── plugins/
│   └── prism_ui/            # vendored 设计系统（见其 VENDOR.md）
├── lib/
│   ├── main.dart            # PrismApp 入口
│   ├── theme/
│   │   └── app_theme.dart   # ★ 品牌令牌，换肤只改这里
│   ├── l10n/
│   │   └── ui_localizations.dart  # 20 条组件内置文案（中/英）
│   ├── common/
│   │   └── relative_time.dart     # 相对时间与日期格式
│   ├── models/
│   │   ├── note.dart              # 不可变值对象（含 favorite / category）
│   │   └── category.dart          # NoteCategory：四个预置分类
│   ├── services/
│   │   ├── note_repository.dart   # 读写接口 + 内存实现（演示/测试用）
│   │   ├── notes_revision.dart    # ★ 笔记变更信号（跨页签同步）
│   │   ├── prefs_note_repository.dart  # ★ 本地持久化实现
│   │   ├── todo_repository.dart   # 待办接口 + 持久化实现
│   │   └── todo_revision.dart     # 待办变更信号
│   ├── ui/
│   │   ├── app_page_bar.dart      # ★ 页面顶栏（全项目统一用它）
│   │   ├── app_view_scope.dart    # ★ 必须挂在 PrismApp.builder 上，见 4.0
│   │   ├── highlighted_text.dart  # 搜索命中高亮
│   │   ├── bar_clearance.dart     # ★ 顶栏避让（页面和弹层通用）
│   │   ├── home_tab.dart          # HomeTab 枚举 + 跨页签跳转
│   │   ├── icons/app_glyphs.dart  # 业务图标（导航四件套等）
│   │   ├── note_card.dart         # ★ 笔记卡片（笔记页/收藏页/分类页共用）
│   │   ├── list_item.dart         # 六形态设置行（来自 FlClash）
│   │   └── nested_sheet.dart
│   └── pages/
│       ├── home_shell.dart        # ★ 四页签外壳 + 悬浮导航
│       ├── notes_page.dart        # 笔记列表
│       ├── category_page.dart     # 分类页（两列卡片 + 计数）
│       ├── category_notes_page.dart  # 某个分类下的笔记
│       ├── favorites_page.dart    # 收藏页
│       ├── todos_page.dart        # 待办（列表 + 添加弹层）
│       ├── note_detail_page.dart  # 详情（编辑 / 删除入口）
│       ├── note_edit_page.dart    # 新建 / 编辑表单
│       └── settings_demo.dart     # 冒烟验证页，验证完删
├── web/                     # Web 预览外壳（flutter create --platforms=web 生成）
├── docs/
│   ├── design-system-analysis.md
│   ├── dev-env-layout.md          # 工具链落盘位置（不占 C 盘）
│   ├── download-checklist.md      # 需要自己下载的东西 + 校验值
│   └── integration-spec.md
└── .ref/                    # 参考源码克隆，不属于项目，可随时删
```

---

## 2. 分层规则

| 目录 | 职责 | 允许依赖 |
|---|---|---|
| `lib/theme` | 品牌令牌 | `prism_ui` |
| `lib/l10n` | 组件文案 + 业务文案 | `prism_ui` |
| `lib/ui` | 可复用组件（从 FlClash 搬来或自写） | `lib/theme` `lib/l10n` `prism_ui` |
| `lib/widgets` | 业务组件（仅本项目用） | 上面全部 + `lib/models` |
| `lib/pages` | 页面装配 | 全部 |
| `lib/models` / `lib/services` | 数据与外部 IO | **不得** 依赖 `lib/ui` `lib/pages` |

**铁律：依赖只能向下，不能向上。** `lib/ui` 里出现 `import '../pages/...'` 就是设计错了。

---

## 3. 代码规范（都是为了不破坏设计系统的一致性）

### 3.1 只用 `prism_ui`，不做缝合怪

```dart
// ✅
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

// ❌ 禁止：两套 ThemeData 会打架
import 'package:flutter/material.dart';
```

`prism_ui` 自己实现了 `ThemeData` / `Theme` / `ColorScheme` / `Card` / `Switch` / `AppBar` 等同名类型。**一旦 import material，全部歧义。**

### 3.2 颜色

```dart
// ✅ 走语义角色
color: context.colorScheme.onSurfaceVariant

// ✅ 语义扩展
color: context.colorScheme.success      // 也有 warning / destructive / error
color: context.colorScheme.modalScrim

// ❌ 禁止硬编码
color: const Color(0xFF888888)
color: Colors.grey.shade600
```

### 3.3 圆角

```dart
// ✅ 用档位 + 超椭圆
shape: AppShape.lg                       // 20
shape: AppShape.all(AppCorner.md)        // 16
shape: AppShape.top(AppCorner.xl)

// ❌ 禁止：普通圆角和超椭圆混在一起，视觉会"脏"
borderRadius: BorderRadius.circular(16)
```

### 3.4 文字

```dart
// ✅ 字号阶梯
style: AppTextStyle.body.of(context)
style: AppTextStyle.subheadline.of(context, emphasized: true)

// ✅ 列表专用（带语义颜色）
style: context.listTitleStyle
style: context.listSubtitleStyle
style: context.listValueStyle

// ❌ 禁止
style: const TextStyle(fontSize: 15)
```

### 3.5 间距与尺寸

```dart
// ✅ 用常量，保持节奏一致
padding: context.listInsets.page(top: appBarContentGap, bottom: 32)
const SizedBox(height: infoSectionSpacing)

// ❌ 随手写
padding: const EdgeInsets.all(13)
```

### 3.6 动效

```dart
// ✅ 必须过这个函数，否则系统的"减弱动态效果"开关失效
AnimatedContainer(
  duration: context.motionDuration(commonDuration),
  curve: Easing.standard,
)
```

### 3.7 表面层级（比阴影重要）

```dart
// 卡片里的卡片，提升一级，而不是加阴影
SurfaceScope(
  level: context.raisedSurfaceLevel,
  child: ...,
)
```

---

## 4. 常用配方

### 4.1 一个页面

```dart
class FooPage extends StatelessWidget {
  const FooPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PrismScaffold(
      bar: const AppPageBar(title: '标题'),          // 根页面
      // bar: const AppPageBar(title: '标题', showBack: true),  // 推入的页面
      body: ListView(
        padding: context.listInsets.page(top: appBarContentGap, bottom: 32),
        children: [
          generateSection(title: '分组', atTop: true, items: [...]),
        ],
      ),
    );
  }
}
```

`AppPageBar` 已抽到 `lib/ui/app_page_bar.dart`，**不要每个页面再自己写一遍**。

它内部走 `ScaffoldBar`（`PrismScaffold` 要求 `PreferredSizeWidget`，`AppBar` 没实现该接口），
三件事缺一不可：

1. 图标按钮一律用 `BarIconButton`（`lib/ui/app_page_bar.dart`），它内部套了
   `TonalButtonGroup`，画出 FlClash 那种圆形/胶囊底。直接用 `AppBarActionButton`
   会得到"裸图标"，顶栏里一半有底一半没底。
2. `actions` 必须经 `genActions(actions, edge: AppBarActionEdge.container)` 生成——
   它会在末尾补一个 `ActionEdgeGap`，也就是顶栏末端的内缩；传裸列表会让按钮贴边。
3. **必须提供 `AppViewScope`**（见 4.0）。缺了它 `AppBar` 取不到 `ViewScope.isMobileOf`，
   整条顶栏渲染为空且**不会报任何错**。
4. 页面 body 首行用 `BarClearance`（见 4.8）。顶栏是浮在 body 之上的，
   `_ScaffoldFrame` 把 `状态栏 + 72` 放进了 body 的 `MediaQuery` 顶部内边距，
   不消费它，第一个控件就会被顶栏盖住。

### 4.10 需要搜索的页面用 SearchablePageBar，搜索框不再放 body 里

搜索框和顶栏是**同一个东西的两个形态**：平时是「标题 + 放大镜 + ⋮」，
点击后标题与按钮淡出，圆形放大镜向左生长成整条搜索胶囊，右端浮出圆形 `×`。
这是 FlClash 的做法，页面里不该再摆一行常驻的 `SearchField`。

```dart
PrismScaffold(
  bar: SearchablePageBar(
    title: '笔记',
    searching: _searching,                 // 页面持有状态
    onSearchingChanged: _setSearching,
    hintText: '搜索笔记',
    onChanged: (value) => setState(() => _query = value),
    actions: [
      BarIconButton(data: IconButtonData(
        glyph: Glyphs.search,
        tooltip: '搜索',
        onPressed: () => _setSearching(true),
      )),
      // ……其余按钮
    ],
  ),
  body: BarClearance(child: list),
)
```

三条约定：

1. **收起搜索时页面自己清空查询词**。`onChanged` 在收起时不会被回调空串
   （顶栏清自己的输入框，不替页面做业务决定）。
2. **结果为空时不要自己写文案**。`NullStatusSwitcher(isSearching: true)` 会自动换成
   `UiLocalizations.noSearchResults`。
3. **列表要带 `keyboardDismissBehavior: onDrag`**，否则键盘挡住半屏时用户没法收起。

注意：这个顶栏是自己排的 `Row`，**不走 `genActions`**，所以按钮之间的间距要自己给
（`_actionGap = 8`，与 `AppBarActionEdge.container` 的 `barButtonGap` 一致）。
漏了会得到两颗贴在一起的圆。

### 4.12 外观偏好：主题与液态玻璃都走 AppPrefs

两个开关都是全局 `ValueNotifier`，改值即生效：

```dart
AppTheme.mode.value = ThemeMode.dark;      // 深浅色
AppTheme.liquidGlass.value = false;        // 液态玻璃
await AppPrefs.saveThemeMode(mode);        // 持久化，失败只打日志
```

`main.dart` 用 `ListenableBuilder(Listenable.merge([...]))` 同时监听两者。

**为什么必须重建整个 `PrismApp`**：液态玻璃由 `PrismApp` 在顶层注入
`LiquidGlassScope`，改 `ThemeData` 或重建某个子树都不会让已经建好的子树换掉玻璃——
只能整棵树换。这一层重建很便宜（`ThemeData` 有缓存，见 `AppTheme._themes`）。

**代价说清楚**：玻璃是每帧一次片元着色器（`liquid_glass.frag`）。`standard` 档已经省掉
模糊与色散；`ultra` 别默认开。深色纯黑下玻璃几乎看不出来（黑底透出的还是黑），
浅色或内容密集时才明显——这是视觉特性，不是没生效。

**按钮要玻璃，外面必须有一层 `TonalButtonTheme(glass: ...)`。**
`TonalButtonGroup` 内部只认这个：`glassOf` 为真才套 `LiquidGlass`，否则铺
`raisedSurfaceLevel` 实心底色。所以：

| 位置 | 谁负责包 |
|---|---|
| `AppBar` 里的按钮 | `AppPageBar` 已经包好 |
| 自己排的顶栏（`SearchablePageBar`） | 自己包（`AppBar` 那层用不上） |
| 悬浮按钮（`FloatingAddButton`） | 自己包 |

**按钮不能套 `TonalButtonGroup`。** group 会把整行按钮包进一层
`LiquidGlassStyle.regular`，那套样式 `rim: 0.28`，圆边会出现一圈硬白线。

FlClash 的顶栏按钮是 `ElasticPress(child: AppBarActionButton(...))`——不在
group 里，于是走 `TonalButtonTheme` 的 `paned` 分支：每颗按钮自己有一层
玻璃面板（`LiquidGlass.buttonBackground`），边缘是柔和反光。

`regular` 自带的 `rim: 0.28` 就是那道边缘高光（玻璃的边缘反光），**保留**。
试过把它归零，高光确实消失，但按钮也就没有玻璃感了——不采用。

漏了不会报错，只会「开关打开了、按钮还是实心」——这个现象很容易被当成 shader 没生效。

**顶栏的「更多」菜单就是普通 `PopupAnchor` + `PopupMenu`，与设置页主题行逐字一致。**
不要给菜单加参数（surfaceColor / sourceColor 都试过），也不要动按钮（隐藏/模糊都试过）。

在同一页面同时放两个这样的菜单，实测底纹灰度仍然不同：

| 弹出位置 | 底纹灰度 |
|---|---|
| 顶栏 | 25 |
| 列表行 | 43 |

打日志排除了这些差异：`brightness`、`surface`、`surfaceContainer`、
`surfaceContainerHigh`、`glass`、`elevated` **全部相同**。

结论：差异来自菜单玻璃的**背景抓图**（顶栏后面是纯黑，列表行后面是卡片），
以及抓图/折射的取样区域。这与 `prism_ui` 的版本无关——FlClash 用的 `popup.dart`
与我们逐行相同（0 差异），它的截图里也有淡淡的放大镜。

**统一调不透明度**：直接改 `LiquidGlassStyle.menu()` 的深色 tint alpha
（`0.63 → 0.9`，vendored 改动，见 `VENDOR.md`）。这是唯一能同时作用于所有菜单的
参数，所以三者会一起变实，不会彼此不一致。实测详情页菜单底纹 `25 → 32~41`，
正文透出明显减弱，但仍保留玻璃质感。想要更实就继续调大，完全不要透就设 1.0
（那就变成实心浮层，失去玻璃）。

### 4.9 搜索框必须显式给 fill，否则和背景同色

`prism_ui` 的 `SearchField` 默认 `filled: fill != null`——**不传 `fill` 就是透明的**，
在没有卡片底的页面上会和背景融为一体，看不出是个输入框。

统一写法：

```dart
SearchField(
  hintText: '搜索…',
  fill: SurfaceLevel.inset.colorOf(context.colorScheme),
  onChanged: (value) => setState(() => _query = value),
)
```

选 `inset`（凹陷层）而不是 `card`：搜索框是"嵌进页面"的输入，不是浮起的卡片。
清除按钮（×）是组件自带的，不用自己写。

这条对 `SearchablePageBar` 内部同样适用——它已经替传好了 `fill`，
所以页面自己不用再拼 `SearchField`（见 4.10）。

### 4.8 顶栏避让一律用 BarClearance，不要用 SafeArea

`lib/ui/bar_clearance.dart` 取 `max(context.appBarInset, MediaQuery.padding.top)`。
原因：内边距的来源在两种布局下不同。

| 布局 | `MediaQuery.padding.top` | `context.appBarInset` | 取哪个 |
|---|---|---|---|
| 页面（`_ScaffoldFrame`） | 状态栏 + 72 | 只有状态栏（Web 为 0） | MediaQuery |
| 紧凑弹层（`SheetToolBar`） | 0 | `sheetAppBarHeight` = 68 | appBarInset |

只用 `SafeArea(top: true)`：页面里正常，**弹层里第一个控件会被顶栏压住**
（加待办弹层时实际踩到）。所以所有 `PrismScaffold` 的 body 首行统一写：

```dart
body: BarClearance(child: ...)
```

### 4.7 分类为什么叫 NoteCategory

`package:flutter/foundation.dart` 里已经有一个 `Category` 注解（类、库、测试用的元数据），
我们如果再定义一个 `Category` 并同时 import foundation，会直接报
`ambiguous_import`，而且报错位置很隐蔽（在用了 `@immutable` 的文件里）。

所以模型类命名为 `NoteCategory`，文件名仍是 `category.dart`。
以后加同类模型（如 `Tag`）也先查一下 foundation 有没有同名。

### 4.2 设置行

```dart
ListItem(title: Text('纯展示'), trailing: Text('值'))
ListItem.toggle(title: Text('开关'), value: v, onChanged: (v) {})
ListItem.checkbox(title: Text('勾选'), value: v, onChanged: (v) {})
ListItem.options<String>(title: ..., options: [...], value: v, textBuilder: (v) => v, onChanged: ...)
ListItem.input(title: ..., dialogTitle: '修改', value: v, onChanged: ...)
ListItem.open(title: ..., widget: const DetailPage())   // 展开为全屏页
```

圆角、分隔线、首尾收边由 `generateSection` + `ItemPositionProvider` 自动处理，**不要自己包 `ClipRRect`**。

### 4.3 空状态

```dart
NullStatus(
  label: '还没有内容',
  description: '添加第一条记录开始使用',
  illustration: Illustration.search,   // 内置只有这一个
  action: TextButton(onPressed: ..., child: const Text('新建')),
)
```

`illustration` 是必填的。内置只有 `Illustration.search`，要别的插画需自己实现 `Illustration`（只需 `Glyph get glyph` 和 `bool get isError`）——`Glyph` DSL 见 `plugins/prism_ui/lib/icons/glyph.dart`。

**空状态一定要给出口**，别只写一句提示。用 `action:` 放一个按钮：

```dart
NullStatus(
  label: '还没有笔记',
  description: '记下第一条，之后可以搜索和置顶',
  illustration: Illustration.search,
  action: TextButton(onPressed: _create, child: const Text('新建笔记')),
)
```

状态切换用它包一层（首次加载不闪空状态）：

```dart
NullStatusSwitcher(
  isLoading: loading,
  isEmpty: items.isEmpty,
  nullStatus: NullStatus(...),
  child: listView,
)
```

### 4.4 存储

当前实现：`PrefsNoteRepository`，整表 JSON 存进 `SharedPreferences`（key `noto_note.notes.v1`）。

```json
{ "version": 1, "notes": [ { "id": "...", "title": "...", "body": "...", "updatedAt": "ISO8601", "pinned": false } ] }
```

三条设计约束：

1. **数据带版本号**：读到 `version > 1` 时按空处理，不用旧结构去猜新数据。
2. **存档损坏不崩 App**：`jsonDecode` 失败捕获 `FormatException`，返回空列表，下次写入自动覆盖。
3. **每次变更整体重写**：数据量小，比增量更新简单，也不会出现部分写入成功的中间态。

何时该换：正文总量接近 1MB，或需要按字段查询 / 全文索引。换法是新增一个 `NoteRepository`
实现（sqflite / drift），`notes_page.dart` 只改一行 `final NoteRepository _repository = ...`。

**时间语义（容易写错）**：`update()` 按传入值原样保存，**不代刷 `updatedAt`**。

- 改正文 → 调用方传 `copyWith(..., updatedAt: DateTime.now())`
- 置顶 / 取消置顶 → 只改 `pinned`，时间保持不动

否则切换一次置顶，笔记就"变新"了，列表按时间排序时会跳到最前，看起来像数据错乱。
排序规则（置顶优先，其次更新时间倒序）放在仓储的 `load()` 里，页面不管排序。

> 首次启动是空列表，直接看到空状态页——这是刻意的，用来验证 `NullStatus` 与 l10n 都生效。

---

## 5. 第一版页面清单

| # | 页面 | 用到的组件 | 目的 | 状态 |
|---|---|---|---|---|
| 1 | 设置 | `PrismScaffold` + `ListItem` 全形态 | 验证令牌 + 列表体系 | ✅ `settings_demo.dart`（验完删） |
| 2 | 首页列表 | `PrismListView` + `Card`（一卡一条） | 验证滚动与变高卡片 | ✅ `notes_page.dart` |
| 3 | 详情页 | `pushNestedPage` + `AppPageBar(showBack:)` | 验证转场与返回 | ✅ `note_detail_page.dart` |
| 4 | 空状态 / 错误态 | `NullStatusSwitcher` + `NullStatus` | 验证版式 | 🟡 列表页已接入，待真实数据为空时验证 |
| 5 | 搜索 | `SearchField` + 内存过滤 + `isSearching` 空结果 | 验证输入与键盘 | ✅ 已接入，键盘拖拽收起待真机验证 |
| 6 | 表单 | `TextField`（已用）+ `showNestedSheet` + `ListItem.input`（待验） | 验证表单与键盘避让 | 🟡 写路径已通，输入法避让未验证 |

**写入路径已闭环**：新建 / 编辑 / 删除 / 置顶都走通了，数据变更靠"子页关闭后静默重载"生效。

具体做法（写业务时照抄这条，别搞路由回传）：

```dart
// 列表页：子页关闭就重载，不管是编辑、删除还是取消
ListItem.open(
  onChanged: (_) => _reloadSilently(),
  widget: NoteDetailPage(...),
)

// 新建：等待表单返回后重载
await pushNestedPage<Note>(context, NoteEditPage(...));
_reloadSilently();

// 重载不切加载态，避免闪白
Future<void> _load({bool silent = false}) async {
  if (!silent) setState(() => _loading = true);
  ...
}
```

**顺序不要改。** 第 1 页跑通，后面全是拼装；第 1 页跑不通，说明令牌或 SDK 有问题，及早发现。

### 5.2 不可逆操作必须二次确认

删除这类操作一律先弹确认，不要直接执行：

```dart
final confirmed = await showFloatingDialog<bool>(
  context: context,
  child: Builder(
    builder: (dialogContext) => AlertDialog(
      title: '删除笔记',
      destructive: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('删除'),
        ),
      ],
      child: Text('删除后无法恢复。'),
    ),
  ),
);
if (confirmed != true) return;
```

两个细节：

- `destructive: true` 让最后一个按钮变红，这是 `AlertDialog` 的语义，别自己染。
- 按钮里必须用 `Builder` 的 `dialogContext` 调 `pop`。用页面 context 在同级导航下"碰巧能用"，
  但页面开在嵌套表单（`PagedSheetRoute`）里时会弹错路由。

### 5.1 列表选型（容易选错的地方）

| 场景 | 用什么 | 原因 |
|---|---|---|
| **内容流**（笔记、邮件、记录） | `PrismListView` + `Card`，卡片间留 12 间距 | 每条是独立卡片，靠间距分隔，**不用分割线** |
| 设置类分组 | `generateSection(items: [...])` + `ListItem` | 一张大卡内按行排列，行间分割线，首尾行收圆角 |
| 只要一行、不要卡片底 | `ListRow` + 自己包 `PressSurface` | 不含卡片底、分隔线、按压反馈 |

**这是本项目最早搞错、已纠正的一点**：最初用 `ListItem.open` + `ItemPositionProvider` 把笔记排成
"一张大卡 + 分割线"，那是设置页的形态。内容流必须是一卡一条、卡间留白——参照 FlClash 仪表盘卡片。

对应代码：`notes_page.dart` 的 `_NoteCard` 用 `Card(radius: AppCorner.xl, padding: EdgeInsets.all(16))`，
间距靠 `PrismListView` 每项的 `Padding(bottom: 12)`（最后一项为 0）。

`ListItem.open` 的行展开转场（`OpenContainer`）在卡片布局下不再适用——卡片用
`pushNestedPage` 正常推页即可，FlClash 自己的仪表盘也是这么跳的。

---

## 6. 冒烟测试（装好 Flutter 后第一件事）

```bash
cd E:/Project/NotoNote
flutter --version          # 必须 ≥ 3.47
flutter pub get
flutter run -d <device>
```

验收 7 项，缺一不可：

- [ ] **编译通过**（重点：`RoundedSuperellipseBorder` / `clipRSuperellipse` 不存在会直接报错）
- [ ] 每条笔记是**独立卡片**，卡间有 12 间距，四角都是 24 圆角，卡内没有分割线
- [ ] 中文正文不出现日文字形（说明 CJK 回退生效）
- [ ] 主题切"深色"后，页面接近纯黑（`pureBlack` 生效）
- [ ] 新建一条 → 杀掉进程重开 → 笔记还在（持久化生效）
- [ ] 搜索"圆角"只剩匹配项；搜"zzz"显示"没有匹配的结果"（l10n 生效）
- [ ] 点卡片正常推入详情，返回后列表刷新（编辑/删除能反映到列表）

任一项失败 → 先解决，再写业务页面。

---

## 7. 明确不做的事

| 不做 | 原因 |
|---|---|
| 从 FlClash 搬 `views/` `providers/` `pages/` | 全是业务耦合，搬一个带一片 |
| Android 打包 Twemoji | 系统 emoji 够用，省 1.39MB |
| 自己重设圆角/字号/动效 | 包已经定好，重设等于放弃一致性 |
| 用 Riverpod/Provider 包 UI 层 | UI 层只读 `InheritedWidget`，状态管理选型不影响它们 |

> 液态玻璃已改为**运行时可关**（设置 → 外观 → 液态玻璃），默认开。
> 用它替掉原来"先上平面版"的决定：低端机用户自己关一次即可，不必全站牺牲效果。

---

## 8. 待决策

1. **品牌色**：当前 `#007AFF`（FlClash 默认）。定稿后改 `AppTheme.seedColor` 一处即可。
2. **`ColorStyle`**：当前 `soft`。想更鲜明改 `vivid`。
3. **状态管理**：`AppTheme.mode` 现在是全局 `ValueNotifier`，接真实状态管理时替换。
4. **图标**：`prism_ui` 内置 20 个 glyph。需要业务图标时，按 `Glyphs` 的 DSL 自己加（见 `app_glyphs.dart` 129 个示例）。
5. **`shared_preferences` 何时换掉**：正文总量接近 1MB 或需要全文检索时换 sqflite，换的是一个文件。
6. **`.ref/` 去留**：参考源码，约 20MB，验证完可删。
