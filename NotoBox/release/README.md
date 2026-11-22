# 安装包

直接下载对应 `.apk` 到手机安装即可（Android 需允许「安装未知来源应用」）。

## 当前版本

| 文件 | 版本 | 大小 | 架构 | 适用 |
| --- | --- | --- | --- | --- |
| `NotoBox-1.0.0-6040-universal.apk` | 1.0.0 (6040) | 69 MB | arm64-v8a / armeabi-v7a / x86_64 | 全部设备，不确定机型时用这个 |

SHA-256（6040 universal）：

```
AABA7AE7D917D06B5355E176253C468D61DAF46B0EB12A95CBFAD9AE233E4EE1
```

校验方法（Windows PowerShell）：

```powershell
Get-FileHash .\NotoBox-1.0.0-6040-universal.apk -Algorithm SHA256
```

## 说明

- 这是 **universal 包**，一个文件兼容 arm64 / armv7 / x86_64，体积较大。
- 想减小体积可在本项目根目录自行构建分架构包：

```bash
flutter build apk --release --split-per-abi
```

产物在 `build/app/outputs/flutter-apk/`，arm64 包通常 20–25 MB。

- 版本号规则：`1.0.0+60xx`，`+` 后为构建号，随每次构建递增。
