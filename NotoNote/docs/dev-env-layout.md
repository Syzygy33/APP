# 开发环境磁盘布局（避免占用 C 盘）

设定时间：2026-11-23

## 为什么需要这份文档

Windows 把用户目录放在 C 盘，所以 Flutter / Dart / Gradle / Android SDK / 模拟器
**默认全部往 C 盘写**，装完一套（含 IDE、Gradle 缓存、模拟器镜像）可到 10–30 GB。
这些目录全部可以通过环境变量重定向，
但**必须在安装之前设好**——装完再搬，轻则缓存重建，重则路径写死在配置文件里。

本项目约定：所有工具链落在 `E:\Project\DEV`，C 盘只留系统和小体积配置。

## 目录结构

```
E:\Project\NotoNote\        应用代码（唯一需要提交仓库的部分）
E:\Project\DEV\             工具链，不进版本库
├── flutter\                Flutter SDK 解压位置
├── pub-cache\              Dart/Flutter 包缓存
├── gradle\                 Gradle 用户目录（含 wrapper 分发包、依赖缓存）
├── android-sdk\            Android SDK（实际只占约 130 MB：platform-tools + build-tools + 一个 platform）
├── android-user\           Android 用户目录（原 %USERPROFILE%\.android）
│   └── avd\                模拟器实例（每个 2–10 GB）
├── android-studio-config\  AS 配置（idea.config.path）
├── android-studio-system\  AS 索引缓存（idea.system.path）
├── android-studio-plugins\ AS 插件（idea.plugins.path）
└── android-studio-log\     AS 日志（idea.log.path）
```

## 已设置的环境变量（作用域：用户级）

| 变量 | 值 | 控制什么 | 不管的话会去哪 |
|---|---|---|---|
| `PUB_CACHE` | `E:\Project\DEV\pub-cache` | Dart 包缓存 | `%LOCALAPPDATA%\Pub\Cache` |
| `GRADLE_USER_HOME` | `E:\Project\DEV\gradle` | Gradle 缓存 + wrapper 分发 | `%USERPROFILE%\.gradle` |
| `ANDROID_HOME` | `E:\Project\DEV\android-sdk` | SDK 位置（旧变量名） | `%LOCALAPPDATA%\Android\Sdk` |
| `ANDROID_SDK_ROOT` | `E:\Project\DEV\android-sdk` | SDK 位置（新变量名，两者都设最保险） | 同上 |
| `ANDROID_USER_HOME` | `E:\Project\DEV\android-user` | 替代 `%USERPROFILE%\.android` | `%USERPROFILE%\.android` |
| `ANDROID_AVD_HOME` | `E:\Project\DEV\android-user\avd` | 模拟器实例目录 | `%USERPROFILE%\.android\avd` |

> 后两个变量不冲突：`ANDROID_USER_HOME` 换掉整个 `.android` 目录，
> `ANDROID_AVD_HOME` 再单独指定 AVD 子目录。两个都设，新旧工具链都能认。

## 装完之后必须做的三件事

### 1. 把 Flutter 加进 PATH

解压 SDK 到 `E:\Project\DEV\flutter` 之后，Path 里加一条：

```
E:\Project\DEV\flutter\bin
```

**现在不能加**——目录还是空的，加了就是僵尸条目（和刚清理掉的那四条一样）。

### 2. Android Studio 的配置目录

Android Studio 的安装路径在安装时就能选，装到 `E:\Project\DEV\android-studio`。
但它的配置和索引默认仍去 `%APPDATA%` / `%LOCALAPPDATA%`，需要改
`android-studio\bin\idea.properties`，末尾加四行：

```properties
idea.config.path=E:/Project/DEV/android-studio-config
idea.system.path=E:/Project/DEV/android-studio-system
idea.plugins.path=E:/Project/DEV/android-studio-plugins
idea.log.path=E:/Project/DEV/android-studio-log
```

改完重启 Studio 生效。这四个目录已经建好了，直接指过去即可。

### 3. 补原生壳子

```bash
cd E:/Project/NotoNote
flutter create --platforms=android .
flutter pub get
```

`flutter create` 只补 `android/` 目录，不覆盖 `lib/`。

## 验证：怎么确认没写到 C 盘

装完之后跑这段，看所有目录是不是都在 E 盘：

```powershell
'PUB_CACHE','GRADLE_USER_HOME','ANDROID_HOME','ANDROID_SDK_ROOT','ANDROID_USER_HOME','ANDROID_AVD_HOME' |
  ForEach-Object {
    $v = [Environment]::GetEnvironmentVariable($_,'User')
    $s = if (Test-Path $v) {
      (Get-ChildItem -LiteralPath $v -Recurse -Force -File -ErrorAction SilentlyContinue |
        Measure-Object Length -Sum).Sum
    } else { 0 }
    [pscustomobject]@{ 变量=$_; 路径=$v; GB=[math]::Round($s/1GB,2) }
  } | Format-Table -AutoSize
```

再看一眼 C 盘有没有偷偷长东西：

```powershell
foreach ($p in "$env:LOCALAPPDATA\Pub\Cache","$env:USERPROFILE\.gradle","$env:LOCALAPPDATA\Android\Sdk","$env:USERPROFILE\.android") {
  if (Test-Path $p) {
    $s = (Get-ChildItem -LiteralPath $p -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    Write-Output ("{0}  {1} MB" -f $p, [math]::Round($s/1MB,0))
  } else { Write-Output "$p  (不存在，正确)" }
}
```

四个都显示"不存在"或体积很小，说明重定向生效。

## 需要注意的几处例外

| 项目 | 能否重定向 | 说明 |
|---|---|---|
| Chrome / 微信等第三方软件 | 独立设置 | 与本项目无关，不在此文档范围 |
| `%TEMP%` | 可（TEMP/TMP 变量） | 大体积构建临时文件会落在 C。若 C 盘持续紧张再改 |
| `.workbuddy` | 不建议 | 260 MB，改路径可能导致 WorkBuddy 找不到插件 |
| Dart 分析服务缓存 `.dartServer` | **无法用变量重定向** | 固定在 `%LOCALAPPDATA%\.dartServer`，约 150 MB，会随使用增长。这是唯一躲不掉的一项，但量级很小 |

最后一条是硬限制：`dart analysis server` 的缓存路径写死在 Dart 工具里，
没有公开的环境变量可改。150 MB 左右，可以接受。

## 回滚

删除这六个用户变量即可回到默认行为：

```powershell
'PUB_CACHE','GRADLE_USER_HOME','ANDROID_HOME','ANDROID_SDK_ROOT','ANDROID_USER_HOME','ANDROID_AVD_HOME' |
  ForEach-Object { [Environment]::SetEnvironmentVariable($_, $null, 'User') }
```

## 相关备份

- `docs/env-backup-android.md` — 清理前的 `ANDROID_HOME` / `ANDROID_SDK_ROOT` 原值（指向已消失的 `E:\Software\Noto扫描\`）
- `docs/env-backup-path.txt` — 清理前的 PATH 原文（34 段）
