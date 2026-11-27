package com.notonote.noto_note

import io.flutter.embedding.android.FlutterActivity

/// 桌面图标跟着系统亮暗走，但**不在代码里切**：
/// 亮/暗两套图放在 `res/mipmap-<dpi>/ic_launcher.png` 与
/// `res/mipmap-night-<dpi>/ic_launcher.png`，同名资源由系统按 uiMode 选。
///
/// 之前用两个 activity-alias + setComponentEnabledSetting 来切，
/// 切换那一刻桌面会把旧入口停用再启用新的，于是图标先消失一下才变
/// （看起来就是「闪退一下」）。改成资源限定符后不需要任何代码，
/// 切换主题时只是换一张图，桌面不重建入口。
class MainActivity : FlutterActivity()
