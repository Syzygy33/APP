# Android 环境变量备份

删除时间：2026-11-23 12:59:33

这两个变量原本指向一个不存在的目录，会干扰 Flutter 查找 Android SDK，已删除。

恢复方法（如将来需要）：

```
[Environment]::SetEnvironmentVariable('ANDROID_HOME','E:\Software\Noto扫描\android-sdk','User')
[Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT','E:\Software\Noto扫描\android-sdk','User')
```

原始值：

| 变量 | 作用域 | 值 |
|---|---|---|
| ANDROID_HOME | User | E:\Software\Noto扫描\android-sdk |
| ANDROID_SDK_ROOT | User | E:\Software\Noto扫描\android-sdk |
