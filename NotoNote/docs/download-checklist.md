# 需要自己下载的软件清单

核对时间：2026-11-23 15:05
目标：在 `E:\Project\DEV` 下搭好 Flutter + Android 工具链，C 盘只留系统。

---

## 版本基准（已核实，不是猜的）

| 软件 | 版本 | 发布日期 | 来源 |
|---|---|---|---|
| Flutter SDK | **3.50.0** stable（Dart 3.14.0） | 2026-11-11 | Flutter 官方发布清单 |
| Android Studio | **Rabbit 2 Patch 1**（2026.2.2） | 2026-10-28 进 Stable | developer.android.google.cn |
| Git for Windows | 最新稳定版 | — | 官网 |

> 项目对 Flutter 的要求是 ≥ 3.47（`RoundedSuperellipseBorder` / `clipRSuperellipse` 需要新版 SDK）。
> 3.50.0 满足，直接用最新稳定版即可。

---

## 一、必装（3 个下载包，合计约 3.4 GB）

> Android SDK 不在这个列表里——它不是"一个下载包"，而是由 SDK Manager 按组件从
> `dl.google.com` 拉取，实际只需约 130 MB。单独放在第三节讲清楚。

### 1. Flutter SDK 3.50.0

| 项 | 值 |
|---|---|
| 文件名 | `flutter_windows_3.50.0-stable.zip` |
| 下载大小 | **1782 MB**（1,868,535,132 字节） |
| 解压后 | 约 4 GB |
| 存放位置 | `E:\Project\DEV\flutter` |
| SHA-256 | `35fb843409c80a1c69b64bbae1756bba437222f909622d83540e266e1759aab8` |

下载地址（两个都实测可达，优先镜像）：

```
# 国内镜像（推荐，快）
https://storage.flutter-io.cn/flutter_infra_release/releases/stable/windows/flutter_windows_3.50.0-stable.zip

# 官方源（备用）
https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.50.0-stable.zip
```

**解压要点**：zip 里自带一层 `flutter/` 顶层目录。所以**直接解压到 `E:\Project\DEV`**，
自然会得到 `E:\Project\DEV\flutter\bin\flutter.bat`。

如果解压完发现路径变成 `E:\Project\DEV\flutter\flutter\bin`，说明多套了一层，把内层内容提上来。

校验（PowerShell，下完先跑）：

```powershell
Get-FileHash "$env:USERPROFILE\Downloads\flutter_windows_3.50.0-stable.zip" -Algorithm SHA256
# 结果应为 35FB843409C80A1C69B64BBAE1756BBA437222F909622D83540E266E1759AAB8
```

> 解压需要约 4 GB 空间，E 盘剩 64 GB，够。

### 2. Android Studio Rabbit 2 Patch 1

| 项 | 值 |
|---|---|
| 文件名 | `android-studio-rabbit2-patch1-windows.exe` |
| 下载大小 | **1.5 GB** |
| 安装位置 | `E:\Project\DEV\android-studio`（安装向导里改，别用默认的 `C:\Program Files`） |
| 磁盘占用 | 约 3.5 GB（含自带 JDK） |
| SHA-256 | `00e98c1c23e1d27a8079951291d1ae310bbc8c7ef1030ab9db1f45a1bb96543b` |

下载页（国内可直连）：

```
https://developer.android.google.cn/studio
```

页面上的「下载 Android Studio Rabbit 2」按钮会给出上面那个 exe。

**这个包解决了什么**：自带 JetBrains Runtime（JDK）、SDK Manager、模拟器管理。
**所以不需要另外装 JDK**——这是最容易多装的一样东西。

### 3. Git for Windows

| 项 | 值 |
|---|---|
| 文件名 | `Git-2.xx.x-64-bit.exe`（取最新） |
| 下载大小 | 约 **65 MB** |
| 安装位置 | 默认即可（约 350 MB，装在 C 盘无妨） |
| 用途 | Flutter 工具链判断版本/通道、`flutter upgrade`、`pub` 的 git 依赖 |

下载地址：

```
# 官网
https://git-scm.com/download/win

# 国内镜像（列目录，自己挑最新版）
https://registry.npmmirror.com/-/binary/git-for-windows/
```

安装全程默认下一步即可，它会自动把 `git` 加进 PATH 并装 Git Bash。

> 现状说明：你机器上目前**没有系统级 Git**。我这边能用的 git 来自 WorkBuddy 内置的 PortableGit，
> 只在它自己的 shell 里有效，Flutter 在 PowerShell / cmd 里调不到。

---

## 二、明确不用装

| 东西 | 为什么不用装 |
|---|---|
| **JDK / Java** | Android Studio 自带 JBR。单独再装一个反而可能版本打架 |
| **adb / platform-tools** | SDK Manager 里勾一下就有。你已有 `C:\Users\Syzygy\platform-tools\adb.exe`（v37.0.1）可留作备用 |
| **Node.js / Python / VS Code** | 与本项目无关 |
| **7-Zip / WinRAR** | Windows 自带 zip 解压够用 |
| **Flutter 的 Dart SDK** | 已经打包在 Flutter SDK 里，不要单独装 Dart |

---

## 三、Android SDK 到底要装什么

### 它不是"一个包"

Android SDK 是一组组件的集合，由 SDK Manager 分别下载。常见误解是"5–8 GB 一大坨"，
**那是把模拟器和系统镜像也算进去了。纯构建只要约 130 MB。**

### 构建必需（体积取自 Google 官方仓库清单，2026-11-23 实测）

| 组件 | 包名 | 版本 | 体积 |
|---|---|---|---|
| 平台工具（adb / fastboot） | `platform-tools` | 37.0.3 | **7.8 MB** |
| 构建工具（aapt2 / d8 / apksigner） | `build-tools;37.0.0` | 37.0.0 | **58.2 MB** |
| 平台（android.jar，编译目标） | `platforms;android-36` | rev2 | **62.8 MB** |
| **合计** | | | **≈ 129 MB** |

API 36 是当前最高正式版平台（Android 16）。Flutter 3.50 默认按它编译。

> AGP 有自动补装机制（`android.builder.sdkDownload` 默认开启）：如果它发现缺少某个
> build-tools 或 platform 版本，会自己下载。所以实际只要勾 Platform-Tools，其余可让 Gradle 自己补。
> 前提是代理配好了，否则自动补装也会失败。

### 可选组件（不装也能编译）

| 组件 | 包名 | 体积 | 什么时候要 |
|---|---|---|---|
| 模拟器本体 | `emulator` | 439.5 MB | 要跑 AVD 才装 |
| 系统镜像 | `system-images;android-36;google_apis;x86_64` | 每个 1.5–2 GB | 每个 AVD 一份 |
| 命令行工具 | `cmdline-tools;latest` | 155.7 MB | AS 自带；纯命令行方案才单独装 |
| NDK | `ndk;27.x` | 约 1 GB | 有 C/C++ 原生代码才要，**本项目不需要** |

### 三种获取方式

**A. Android Studio 的 SDK Manager（推荐）**
图形化，自动处理 license、目录结构、`package.xml`。**但要先配代理**，见下。

**B. 命令行 sdkmanager**

```powershell
sdkmanager --proxy=http --proxy_host=127.0.0.1 --proxy_port=7890 `
  "platform-tools" "build-tools;37.0.0" "platforms;android-36"
```

**C. 直接下 zip 解压（连 sdkmanager 都不用）**

三条链接实测可用（腾讯镜像直连，不需要代理）：

```
https://mirrors.cloud.tencent.com/AndroidSDK/platform-tools_r37.0.3-win.zip
https://mirrors.cloud.tencent.com/AndroidSDK/build-tools_r37_windows.zip
https://mirrors.cloud.tencent.com/AndroidSDK/platform-36_r02.zip
```

解压到：

```
E:\Project\DEV\android-sdk\platform-tools\
E:\Project\DEV\android-sdk\build-tools\37.0.0\
E:\Project\DEV\android-sdk\platforms\android-36\
```

坑：zip 内部自带的目录名不一定等于包名（build-tools 的包常解出 `android-15` 这种名字），
必须重命名成 `37.0.0`，否则 Gradle 找不到。这种方式不会生成 `package.xml`，
`sdkmanager --list_installed` 认不出来，但 Gradle 能正常使用。

### 网络：最容易卡住的地方（实测结果）

| 地址 | 直连 | 走 `127.0.0.1:7890` |
|---|---|---|
| `dl.google.com`（sdkmanager 默认源） | ❌ **不通** | ✅ 200 |
| `storage.flutter-io.cn`（Flutter 包） | ✅ 通 | — |
| `developer.android.google.cn`（AS 下载页） | ✅ 通 | — |
| `mirrors.cloud.tencent.com/AndroidSDK/` | ✅ 通（能下组件包） | — |

**所以 Android Studio 装完第一件事是配代理**：

```
Settings → Appearance & Behavior → System Settings → HTTP Proxy
→ Manual proxy configuration
→ Host: 127.0.0.1    Port: 7890
→ 勾选 "HTTP"
→ Check connection 填 https://dl.google.com，应返回 200
```

不配代理，SDK Manager 会一直转圈到超时，报 `Connection failed` / `Read timed out`。
这个报错看起来像防火墙或权限问题，实际就是源不通。

### 一个能省掉一半下载的判断

**`flutter analyze` 不需要 Android SDK，也不需要 Android Studio。**

它只依赖 Flutter SDK 自带的 Dart 分析器。所以：

| 只想做的事 | 需要装什么 |
|---|---|
| 验证这 1942 行代码能不能编译 | **只装 Flutter**（1782 MB） |
| 真机跑起来看效果 / 打 APK | 再加 Android SDK（130 MB）+ JDK |

需要 JDK 是 AGP 的要求（AGP 8.x 要 JDK ≥ 17），AS 自带的 JBR 是 21，够用；
不走 AS 的话，单独装一个 JDK 21 即可。

---

## 四、安装顺序（照这个来）

### 第 1 步：Git

装完**新开一个** PowerShell：

```powershell
git --version    # 应输出 git version 2.x
```

### 第 2 步：解压 Flutter

解压到 `E:\Project\DEV`，然后核验：

```powershell
Test-Path 'E:\Project\DEV\flutter\bin\flutter.bat'   # 必须是 True
```

此时**不要急着跑 flutter**，PATH 还没配。

### 第 3 步：装 Android Studio

安装向导里唯一要改的是路径 → `E:\Project\DEV\android-studio`。
「Android Virtual Device」组件可以取消勾选（除非你确定要跑模拟器，理由见第六节）。

### 第 4 步：首次启动 AS，先配代理（否则 SDK 一步都下不动）

启动后立刻做这一步，别先打开 SDK Manager：

```
Settings → Appearance & Behavior → System Settings → HTTP Proxy
→ Manual proxy configuration
→ Host: 127.0.0.1    Port: 7890    ☑ HTTP
→ Check connection: https://dl.google.com   （应返回 200）
```

原因：`dl.google.com` 直连不通（实测），而它是 SDK 唯一的官方下载源。
代理是 `127.0.0.1:7890`（你机器上 mihomo 正在跑，已验证走它能拿到 200）。

### 第 5 步：改 SDK 路径 + 装组件

1. 进 **Settings → Languages & Frameworks → Android SDK**
2. 把 **Android SDK Location** 从默认的 `C:\Users\Syzygy\AppData\Local\Android\Sdk`
   改成 **`E:\Project\DEV\android-sdk`**
3. 勾选并 Apply：
   - ✅ **Android SDK Platform-Tools**（含 adb，7.8 MB）
   - ✅ **Android SDK Build-Tools**（选最新，58 MB）
   - ✅ **Android SDK Platform**（API 36，63 MB）
   - ⬜ Android Emulator（按需，439 MB）
   - ⬜ 系统镜像（按需，每个 1.5–2 GB）

三个必选项合计约 130 MB，一两分钟就下完。

> 路径改晚了，SDK 会先往 C 盘下一部分再搬，白折腾。
> 详见第三节「Android SDK 到底要装什么」。

### 第 6 步：配置（我来做，或你照着 `docs/dev-env-layout.md`）

- PATH 加 `E:\Project\DEV\flutter\bin`
- 改 `android-studio\bin\idea.properties` 四行（把 AS 的配置/索引挪到 E 盘）
- `flutter create --platforms=android .`
- `flutter pub get` / `flutter analyze`

---

## 五、验收（装完后按顺序跑）

```powershell
flutter --version
# 期望：Flutter 3.50.0 • channel stable • Dart 3.14.0

flutter doctor -v
# 期望：Flutter / Android toolchain / Android Studio 三项打勾
# 若 Android toolchain 报 licenses 未接受：flutter doctor --android-licenses 一路 y

cd E:\Project\NotoNote
flutter analyze
```

`flutter analyze` 是真正的重点——它会把我写的 1942 行里所有拼错的 API 一次性列出来。

---

## 六、模拟器：建议先别装

你的机器情况（已实测）：

| 项 | 状态 |
|---|---|
| CPU | AMD Ryzen 7 4800H |
| 内存 | 15.4 GB |
| 固件虚拟化 | 已启用 ✅ |
| Hyper-V | 未启用 |
| Windows Hypervisor Platform | **未启用** |
| VirtualMachinePlatform | 已启用（这是给 WSL2 的，对模拟器没帮助） |

结论：**模拟器现在跑不起来**，需要额外一步——在 SDK Manager 的 SDK Tools 里装
「Android Emulator hypervisor driver」（AMD 平台），或者启用 WHPX（需管理员权限 + 重启）。

而且系统镜像本身 2–4 GB。

**更省事的路**：用真机。你已有可用的 adb，手机开 USB 调试插上就能跑，省 4 GB 下载和一次重启。
屏幕效果也比模拟器真实。

模拟器等确实需要了再装，SDK Manager 里随时能加。

---

## 七、如果下载卡住

三个地址今天都实测返回 200，但国内网络会波动。备用手段：

```powershell
# 让 pub get / flutter 更新也走镜像（不影响已设的 PUB_CACHE，两者不冲突）
$env:PUB_HOSTED_URL = 'https://pub.flutter-io.cn'
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
```

Flutter zip 如果官方源慢，用 `storage.flutter-io.cn` 那个镜像链接，实测通。
Android Studio 用 `developer.android.google.cn`（不是 `.com`，`.cn` 国内可直连）。

---

## 八、下载完成后的交接

把这三样下好、或装好 Git 和 AS 之后告诉我，剩下的我全包：

1. 核验文件完整性和解压路径
2. 写 PATH、改 `idea.properties`
3. `flutter create` / `pub get` / `analyze`
4. 按真实报错逐条修掉那 1942 行里未验证的 API

---

## 附：一条更轻的替代路线（了解即可）

不想装 1.5 GB 的 Android Studio 的话，可以只装：

- **Android 命令行工具** `commandlinetools-win-15859902_latest.zip`（155.7 MB）
- 一个 **JDK**（如 Microsoft OpenJDK 21，约 200 MB）

然后用 `sdkmanager` 命令行装 SDK。总体积从 3.5 GB 降到约 1.5 GB。

**但不推荐给你**：没有图形化 SDK Manager，路径、license、环境变量全靠手敲，出问题不好查。
省下的 2 GB 不值得。除非你明确不想要 IDE。
