import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimensions.dart';
import 'liquid_bar/loupe_tab_bar.dart';

/// 底部导航的一个标签
class BottomTab {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const BottomTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// 悬浮底部栏：直接使用液态玻璃库官方 example 的 [LoupeTabBar]。
///
/// 效果与 Apple 官方参考图一致：整条玻璃胶囊 + 蓝色选中胶囊 + 按下时
/// 放大镜（loupe）跟随手指、相邻玻璃段水滴式融合。选中图标用 vibrant
/// tint 逐像素混合背景，颜色随底下内容实时变化。
class BottomBar extends StatelessWidget {
  final int currentIndex;
  final List<BottomTab> tabs;
  final ValueChanged<int> onTabTap;

  const BottomBar({
    super.key,
    required this.currentIndex,
    required this.tabs,
    required this.onTabTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final Color primary = isDark ? AppColors.accentDark : AppColors.accent;

    final List<BottomBarTab> libTabs = [
      for (int i = 0; i < tabs.length; i++)
        BottomBarTab(
          icon: i == currentIndex ? tabs[i].activeIcon : tabs[i].icon,
          label: tabs[i].label,
        ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDims.s16,
        0,
        AppDims.s16,
        bottomInset > 0 ? bottomInset + 8 : AppDims.s16,
      ),
      child: SizedBox(
        height: 62,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(31),
          child: Stack(
            children: [
              // 常驻磨砂玻璃底：模糊 + 半透明遮挡，挡住下方滚动内容，
              // 保留通透质感。LoupeTabBar 玻璃交互浮在其上。
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xC21C1C1E)
                          : const Color(0xC2FFFFFF),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: isDark
                            ? const Color(0x33FFFFFF)
                            : const Color(0x338E8E93),
                        width: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
              CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: isDark ? Brightness.dark : Brightness.light,
                  primaryColor: primary,
                ),
                child: LiquidGlassBlendGroup(
                  blend: 8,
                  child: Semantics(
                    label: 'bottom-tab-bar',
                    child: LoupeTabBar(
                      tabs: libTabs,
                      selectedIndex: currentIndex,
                      onSelected: onTabTap,
                      tint: primary,
                      tintBrightness:
                          isDark ? Brightness.dark : Brightness.light,
                      shadows: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 20,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
