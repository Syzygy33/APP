# NotoBox 实机预览启动脚本
# 用法（在项目根目录）：
#   powershell -ExecutionPolicy Bypass -File tool\preview.ps1
# 可选：指定设备 ID
#   powershell -ExecutionPolicy Bypass -File tool\preview.ps1 -Device 192.168.31.23:5555

param(
    [string]$Device = ""
)

$ErrorActionPreference = "Stop"

# ---- 本机工具链路径 ----
$env:JAVA_HOME = "D:\Program Files\Android\Android Studio\jbr"
$env:ANDROID_HOME = "D:\Software\SDK"
$env:ANDROID_SDK_ROOT = "D:\Software\SDK"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.googleapis.com"
$env:PATH = "D:\Software\Flutter\flutter\bin;D:\Software\SDK\platform-tools;$env:JAVA_HOME\bin;" + $env:PATH

Write-Host "===== 当前连接的设备 =====" -ForegroundColor Cyan
& "D:\Software\SDK\platform-tools\adb.exe" devices -l

if ($Device -ne "") {
    Write-Host "`n===== 指定设备：$Device =====" -ForegroundColor Cyan
    flutter run -d $Device
} else {
    Write-Host "`n===== 启动 flutter run（自动选择唯一设备）=====" -ForegroundColor Cyan
    flutter run
}

Write-Host @"

----------------------------------------
运行中可用按键：
  r   热重载（保持页面状态，改 UI 最快）
  R   热重启（重置状态）
  q   退出
----------------------------------------
"@ -ForegroundColor DarkGray
