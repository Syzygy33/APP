# NotoNote

本地优先的笔记 / 待办应用，Flutter 编写，Android 与 Web 双端可运行。
界面基于 vendored 的 [`prism_ui`](plugins/prism_ui)（改造自 FlClash 的液态玻璃设计系统）。

## 功能

- **笔记**：纯文本内容、分类、收藏、按更新 / 创建时间排序与筛选
- **待办**：完成状态、提醒时间、分类与筛选
- **附件**：从文件管理器选文件、相册多选照片、直接拍照；图片压缩后内嵌进笔记（单文件上限 2 MB）
- **提醒**：到点通过系统本地通知提醒，设备重启后自动重排；支持随时清除
- **外观**：Liquid Glass 风格，菜单为实时背景捕获 + 模糊，亮 / 暗色自适应
- **存储**：数据默认只留在本机（`shared_preferences`），另提供 WebDAV 备份与本地备份导出 / 恢复

## 技术栈

- Flutter（SDK >= 3.47）
- `prism_ui`：本地 vendored 设计系统，含 `RoundedSuperellipseBorder`、液态玻璃弹层
- `shared_preferences` 2.4.x（整表 JSON 存 KV）
- `flutter_local_notifications` 23 + `timezone`（本地定时通知）
- `image_picker` / `file_picker`（附件与备份文件）

## 运行

```bash
flutter pub get
flutter run -d chrome     # Web
flutter run -d android    # Android 真机 / 模拟器
```

## 构建

```bash
# Web
flutter build web

# Android APK（arm64）
flutter build apk --release --target-platform android-arm64
```

Android 构建要求：

- JDK 17
- Android SDK Platform **37.0**（`platforms;android-37.0`）与 Build-Tools 37.0.0
- `compileSdk = 37`（`flutter_local_notifications` 23 与 `androidx.core` 1.19 的要求），
  `targetSdk` 仍为 36

## 目录

```
lib/
  models/       笔记、待办、分类、附件数据模型
  pages/        列表页、详情页、编辑弹层、设置页
  services/     仓库（持久化）、附件选择、提醒通知
  ui/           列表头、附件工具条、时间选择器、图标
plugins/prism_ui/   本地设计系统（vendored，带少量 VENDOR 补丁）
android/        Android 工程（通知权限与 Receiver 已配置）
web/            Web 入口
docs/           设计与开发记录
prototype/      早期原型
```

## 说明

- `plugins/prism_ui` 为 vendored 源码，与上游 FlClash 的差异均以
  `[VENDOR-PATCH]` / `[VENDOR-FIX]` / `[VENDOR-ADD]` 注释标出。
- 应用默认只在本地读写数据；WebDAV 同步仅在用户主动配置后启用。
