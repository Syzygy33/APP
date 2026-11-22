# NotoBox

一款以 **iOS 26 Liquid Glass** 为视觉语言的 Android 笔记应用，使用 Flutter 构建。功能全部真实可用——笔记 / 待办两类内容的增删改查、图片插入与拍照、滑动操作、分类管理、搜索、收藏、回收站、主题持久化均落到本地 SQLite 数据库，并支持 WebDAV 双向同步与本地备份恢复，没有静态假页面，也没有空函数占位。

---

## 一、技术栈

| 项 | 选型 | 版本 |
| --- | --- | --- |
| 框架 | Flutter（stable） | 3.50.1 |
| 语言 | Dart | 3.14.0 |
| 组件底座 | Material 3（仅用能力，不用默认视觉） | material_ui 1.11.1 |
| 状态管理 | Riverpod | 3.5.0 |
| 路由 | GoRouter（StatefulShellRoute） | 18.1.4 |
| 本地数据库 | drift（SQLite ORM）+ drift_flutter | 2.35.4 / 0.3.1 |
| 偏好持久化 | shared_preferences | 2.5.6 |
| 图标 | lucide_icons_flutter（统一线性图标） | 4.0.3 |
| 格式化 | intl | 0.20.3 |

> Flutter 3.50 起 Material 组件库以独立包 `package:material_ui/material_ui.dart` 提供，项目已全面切换，避免弃用告警。

---

## 二、项目结构（模块化分层）

```
lib/
├── main.dart                        # 入口：ProviderScope 装配、主题模式、系统 UI 样式
├── app/
│   ├── router.dart                  # GoRouter：4 个 tab + push 子页，iOS 右侧滑入转场
│   └── theme/                       # 设计系统（唯一真源）
│       ├── app_colors.dart          # 语义色、玻璃材质色、分类色板、明暗两套
│       ├── app_typography.dart      # iOS 字阶（largeTitle/title/body/footnote…）
│       ├── app_dimensions.dart      # 间距、圆角、模糊半径、导航栏尺寸
│       └── app_theme.dart           # ThemeData 组装（明/暗双主题）
├── data/                            # 数据层
│   ├── database/
│   │   ├── tables.dart              # Folders / Notes 表定义
│   │   ├── app_database.dart        # DriftDatabase + NoteDao + FolderDao
│   │   └── app_database.g.dart      # build_runner 生成代码
│   └── repositories/
│       └── note_repository.dart     # 仓储：业务规则封装，页面不直接碰 DAO
├── providers/
│   └── app_providers.dart           # 数据库/仓储/数据流/主题模式/统计
├── features/                        # 业务模块
│   ├── shell/
│   │   └── app_shell.dart           # 悬浮底栏外壳（四标签 + 悬浮加号）+ 自动同步调度
│   ├── notes/
│   │   ├── notes_page.dart          # 列表页：笔记/待办共用，标题+副标题、全部 N、筛选
│   │   ├── todo_card.dart           # 待办卡片（可勾选、完成项置底）
│   │   ├── note_actions.dart        # 长按动作面板（收藏/置顶/转换类型/删除）
│   │   ├── swipe_actions.dart       # 左滑删除（带撤销）/ 右滑收藏
│   │   ├── note_card.dart           # 笔记卡片（置顶/收藏标记、摘要、时间、分类）
│   │   ├── note_editor_page.dart    # 编辑器：新建/编辑、分类选择、自动保存、删除
│   │   ├── favorites_page.dart      # 收藏列表
│   │   └── trash_page.dart          # 回收站：恢复 / 彻底删除
│   ├── folders/
│   │   ├── folders_page.dart        # 分类管理：新建/重命名/删除（含笔记迁移确认）
│   │   └── folder_notes_page.dart   # 某分类下的笔记
│   ├── search/search_page.dart      # 搜索：命中标题与正文、历史关键词
│   └── settings/settings_page.dart  # 主题切换（持久化）、统计、回收站入口、关于
└── shared/widgets/                  # 复用组件
    ├── glass_card.dart              # 半透明圆角玻璃卡片 / 玻璃容器
    ├── bottom_bar.dart              # 悬浮胶囊底栏（笔记/待办/收藏 三标签）
    ├── swipe_background.dart        # 滑动底层的删除红 / 收藏橙
    ├── circle_button.dart           # 顶部圆形图标按钮
    ├── ios_action_sheet.dart        # iOS 动作面板（自适应高度 + 独立取消）
    ├── ios_dialog.dart              # iOS 风格确认/提示弹窗（缩放淡入）
    ├── ios_bottom_sheet.dart        # iOS 风格底部面板（圆角、拖拽关闭）
    └── common_widgets.dart          # 空状态、分组标题、搜索框等
```

**分层约束**：页面（features）→ 状态（providers）→ 仓储（repositories）→ 数据库（database）。页面不写 SQL，DAO 不含 UI，颜色/字号/圆角只从 `app/theme` 取值。

---

## 三、视觉与性能

- **毛玻璃**：全部使用原生 `BackdropFilter` + `ImageFilter.blur`，模糊只作用于**组件自身矩形**（卡片 / 导航栏 / 弹窗遮罩），不存在全屏高强度模糊。
- **模糊半径分级**：卡片与导航栏 18，弹窗遮罩 24（短时出现），轻玻璃 8（`AppDims.blurGlass/blurOverlay/blurLight`）。
- **悬浮底栏**：单条胶囊承载「笔记 / 待办 / 分类 / 收藏」四个标签；新增按钮 52dp，浮在胶囊正上方居中，`extendBody: true` 让内容从胶囊下方滚过，玻璃才有实际内容可折射，列表底部预留 176px 防遮挡。
- **加号显隐**：只在笔记 / 待办显示（分类页、收藏页收起）；切到收藏时原地缩小并淡出（scale 1→0，200ms easeInCubic），回到前三页时原地放大弹回（easeOutBack），不做位移。
- **页面转场**：所有二级页统一「原地放大进入」（0.92→1 + 淡入，240ms），退出反向缩回，不使用侧滑；返回后保持进入前的页面与状态。
- **iOS 语言**：大标题 + 分组卡片布局、语义化字阶、统一线性图标（lucide）、右侧滑入转场、弹窗缩放淡入、底部面板圆角上滑。
- **明暗双主题**：颜色全部走语义 token，跟随系统 / 强制浅色 / 强制深色三态，选择持久化到 SharedPreferences。
- **多尺寸适配**：平板/折叠屏限制最大宽度 720 保持手机观感；导航栏与列表遵循安全区内边距。

---

## 四、功能清单（均为真实交互）

| 功能 | 实现位置 | 说明 |
| --- | --- | --- |
| 新建 / 编辑笔记 | note_editor_page | 标题 + 正文，切页自动保存，空标题落库为"无标题" |
| 笔记列表 | notes_page | 置顶优先 + 更新时间倒序，实时响应数据库变化 |
| 置顶 / 收藏 | note_card → repository | 立即落库并刷新列表 |
| 待办清单 | notes_page(todo) + todo_card | 圆圈勾选真实写库，完成项自动沉底并加删除线，顶部显示「已完成 N」 |
| 图片插入 | note_editor_page + ImageStore | 相册多选与拍照，最多 9 张，压缩到长边 1600，列表缩略块显示首图 |
| 滑动操作 | note_card / todo_card | 左滑删除（入回收站，带撤销，3 秒自动消失）、右滑收藏；收藏页右滑为取消收藏 |
| 长按/筛选菜单 | context_menu | 从触发位置就近弹出、不占全宽；长按含置顶/转换类型（去收藏、去删除），筛选含分类+排序 |
| 从远端恢复 | sync_page | 用远端备份覆盖本地，覆盖前自动留本地快照 |
| 类型互转 | note_actions / 编辑器 | 笔记、待办两者可随时转换，转换后自动归位到对应列表 |
| 筛选与排序 | notes_page | 底部面板选择分类 + 最近更新/创建时间/标题，实时生效 |
| 分类管理 | folders_page（底栏「分类」标签） | 新建 / 重命名 / 删除；删除前确认并可迁移笔记 |
| 搜索 | search_page | `LIKE` 命中标题与正文，空关键词回退到历史记录 |
| 收藏页 | favorites_page | 独立 tab，取消收藏即从列表消失 |
| 回收站 | trash_page | 软删除 → 恢复 / 彻底删除（二次确认） |
| 设置入口 | notes_page / favorites_page | 右上角三点直接进入设置（放大转场），分类管理、回收站并入设置页「数据」分组 |
| WebDAV 同步 | sync_page + data/sync | 双向合并（同 id 取 updatedAt 较新）、测试连接、立即同步 |
| 自动同步 | app_shell | 启动后、数据变更静默 20s、回到前台各触发一次，30s 内重复触发合并 |
| 本地备份 | sync_page + backup_service | 导出到所选位置、导入（合并/覆盖）、每天自动快照保留最近 7 份 |
| 主题切换 | settings_page | 三段选择器，写入 SharedPreferences 重启保持 |
| 统计 | settings_page | 笔记总数 / 收藏数 / 分类数 / 回收站数量 |
| 关于 | settings_page | 版本信息 |

数据库采用软删除模型（`deleted` 标记），常规查询默认排除已删除项。

---

## 五、构建与运行

### 环境（本机实测）

| 组件 | 路径 |
| --- | --- |
| Flutter 3.50.1 | `D:\Software\Flutter\flutter` |
| Android SDK | `D:\Software\SDK`（platform 36/37、build-tools 36） |
| JDK 17+ | `D:\Program Files\Android\Android Studio\jbr` |

### 命令

```bash
# 1. 生成数据库代码（修改表结构后执行）
dart run build_runner build --delete-conflicting-outputs

# 2. 静态分析
flutter analyze

# 3. 单元 / 组件 / 整机测试
flutter test

# 4. 构建 APK
flutter build apk --release                    # 通用包
flutter build apk --release --split-per-abi    # 按 ABI 分包，体积更小
```

Windows 下若 Gradle 需走代理，`android/gradle.properties` 已内置：

```properties
systemProp.http.proxyHost=127.0.0.1
systemProp.http.proxyPort=7890
kotlin.incremental=false   # 规避 Windows 文件锁导致的 Kotlin 缓存异常
```

---

## 六、测试结果

`flutter analyze`：**No issues found**

`flutter test`：**31 项全部通过**

| 文件 | 用例 |
| --- | --- |
| `test/database_test.dart` | 新建默认状态、软删除隔离、恢复、收藏/置顶切换、关键词搜索、三类内容互不干扰与转换、待办勾选与未完成计数、文件夹 CRUD 与归类（8 项，内存 SQLite 真实读写） |
| `test/widget_test.dart` | 玻璃卡片渲染、点击回调、明暗主题构建（3 项） |
| `test/app_flow_test.dart` | 三标签齐全、切到待办、加号显隐规则、三点菜单进入设置、待办不串到笔记页（5 项） |
| `test/backup_test.dart` | 快照往返、软删除入包、合并取较新、覆盖导入（含恢复前快照）、非法文件拒绝、轮转 7 份、zip 图片往返、旧 JSON 兼容、附件表缺失自愈（10 项） |
| `test/first_image_test.dart` | 首图映射随附件插入实时更新（1 项） |
| `test/first_image_test.dart` | 首图映射随附件插入实时更新（1 项） |
| `test/preview_ui_test.dart` | 离屏渲染首页/待办/收藏为 PNG，输出到 `preview/`，用于视觉核对（1 项） |

整机测试真实装配 `Riverpod + GoRouter + drift(内存库)` 并注入 SharedPreferences，等价于启动链路冒烟。

**测试过程中修复的两个真实缺陷**：

1. `AppShell` 的 `bottomNavigationBar` 使用无约束 `Stack`，占满全屏高度导致正文 `Scaffold` 高度为 0——页面内容完全不可见。已改为 `extendBody + GlassNavBar` 直接作为底栏。
2. 设置页 / 回收站的 `ListTile` 被带背景色的 `Container` 包裹，点击水波纹与背景被遮挡（debug 下触发框架断言）。已改用 `Material` 承载背景。

---

## 七、应用图标

- 源图：用户提供的 1254×1254 方形图标（白底 + 信封 + 橙色星号）。
- 处理脚本：`tool/make_icons.py`
  1. 按图块实测边界（x 75..1178 / y 61..1181，圆角 ≈250px）生成蒙版，把框外黑底与投影统一刷白，框内图案完整保留；
  2. 输出各密度传统图标 `ic_launcher.png`（48 / 72 / 96 / 144 / 192）；
  3. 输出自适应图标前景 `ic_launcher_foreground.png`（108dp 画布，图案占 80% 居中，四周透明，供系统遮罩裁切）。
- 自适应图标：`mipmap-anydpi-v26/ic_launcher.xml`，背景色 `#FFFFFF`（`values/ic_launcher_background.xml`）。
- 应用内展示：设置页「关于」使用 `assets/branding/app_icon_144.png`。
- 重新生成：`python tool/make_icons.py`（需要 Pillow）。

---

## 八、构建产物

| 产物 | 路径 | 体积 |
| --- | --- | --- |
| 通用 release APK | `dist/NotoBox-1.0.0-universal.apk` | 58 MB |
| arm64-v8a（真机首选） | `dist/NotoBox-1.0.0-arm64-v8a.apk` | 21 MB |
| armeabi-v7a（旧机型） | `dist/NotoBox-1.0.0-armeabi-v7a.apk` | 19 MB |
| debug APK | `build/app/outputs/flutter-apk/app-debug.apk` | 167 MB |

三个 release 包均内含 `lib/&lt;abi&gt;/libsqlite3.so`、`libflutter.so`、`libapp.so`，已用 `apksigner` 校验签名有效（Android Debug 证书）。

- 桌面显示名称：**NotoBox**（`android:label`）
- 包名：`com.notobox.noto_box`
- versionName `1.0.0` / versionCode `1`
- minSdk 24 / targetSdk 36
- release 当前使用 debug 签名（Flutter 模板默认），可直接安装；上架前需替换为正式签名。
