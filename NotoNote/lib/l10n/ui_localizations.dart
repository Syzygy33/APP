import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

/// prism_ui 组件自带文案的实现。
///
/// 组件内部（对话框、文本选择菜单、搜索框、折叠区…）会自己显示这些文字，
/// 若不注册 delegate，组件会触发 assert 并在调试模式下暴露缺失。
///
/// 新增语言：写一个 `_XxLocalizations` 类实现 20 个 getter，然后在
/// [AppUiLocalizationsDelegate.load] 里按语言分支即可。
abstract final class AppUiLocalizations {
  /// 注册到 `PrismApp.localizationsDelegates`。
  static const delegate = AppUiLocalizationsDelegate();

  static const supportedLanguages = {'zh', 'en'};

  static UiLocalizations of(BuildContext context) =>
      UiLocalizations.of(context);
}

class AppUiLocalizationsDelegate
    extends LocalizationsDelegate<UiLocalizations> {
  const AppUiLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppUiLocalizations.supportedLanguages.contains(locale.languageCode);

  @override
  Future<UiLocalizations> load(Locale locale) => SynchronousFuture(
    locale.languageCode == 'zh'
        ? const _ZhUiLocalizations()
        : const _EnUiLocalizations(),
  );

  @override
  bool shouldReload(AppUiLocalizationsDelegate old) => false;
}

class _ZhUiLocalizations implements UiLocalizations {
  const _ZhUiLocalizations();

  @override
  String get back => '返回';

  @override
  String get cancel => '取消';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get close => '关闭';

  @override
  String get copy => '复制';

  @override
  String get cut => '剪切';

  @override
  String get dialog => '对话框';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String get more => '更多';

  @override
  String get noSearchResults => '没有匹配的结果';

  @override
  String get paste => '粘贴';

  @override
  String get reset => '重置';

  @override
  String get search => '搜索';

  @override
  String get select => '选中';

  @override
  String get selectAll => '全选';

  @override
  String get showLess => '收起';

  @override
  String get showMore => '展开';

  @override
  String get showPassword => '显示密码';

  @override
  String get sort => '排序';

  @override
  String get submit => '提交';
}

class _EnUiLocalizations implements UiLocalizations {
  const _EnUiLocalizations();

  @override
  String get back => 'Back';

  @override
  String get cancel => 'Cancel';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get close => 'Close';

  @override
  String get copy => 'Copy';

  @override
  String get cut => 'Cut';

  @override
  String get dialog => 'Dialog';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get more => 'More';

  @override
  String get noSearchResults => 'No matching results';

  @override
  String get paste => 'Paste';

  @override
  String get reset => 'Reset';

  @override
  String get search => 'Search';

  @override
  String get select => 'Select';

  @override
  String get selectAll => 'Select all';

  @override
  String get showLess => 'Collapse';

  @override
  String get showMore => 'Expand';

  @override
  String get showPassword => 'Show password';

  @override
  String get sort => 'Sort';

  @override
  String get submit => 'Submit';
}
