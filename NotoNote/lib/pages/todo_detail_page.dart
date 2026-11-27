import 'dart:async';

import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import '../ui/bar_clearance.dart';
import '../common/relative_time.dart';
import '../models/category.dart';
import '../models/todo.dart';
import '../services/note_repository.dart';
import '../services/todo_repository.dart';
import '../ui/app_page_bar.dart';
import '../ui/category_picker.dart';
import '../ui/icons/app_glyphs.dart';
import '../ui/page_back_guard.dart';
import '../ui/reminder_picker.dart';
import '../ui/todo_done_mark.dart';

/// 待办详情 / 原地编辑。
///
/// 与笔记详情一致：顶栏不显示标题文字，点正文（要做什么 / 备注）即在原地
/// 切成输入框，顶栏右侧出现对勾保存。左侧圆点只切完成状态。
class TodoDetailPage extends StatefulWidget {
  const TodoDetailPage({
    super.key,
    required this.todo,
    required this.repository,
  });

  final Todo todo;
  final TodoRepository repository;

  @override
  State<TodoDetailPage> createState() => _TodoDetailPageState();
}

class _TodoDetailPageState extends State<TodoDetailPage> {
  late Todo _todo = widget.todo;

  var _editing = false;
  late final TextEditingController _text = TextEditingController();
  late final TextEditingController _detail = TextEditingController();
  final _textFocus = FocusNode();
  final _detailFocus = FocusNode();

  /// 两栏各一份撤销栈，顶栏按钮作用于当前聚焦的那栏。
  final _textUndo = UndoHistoryController();
  final _detailUndo = UndoHistoryController();
  var _activeIsDetail = false;

  UndoHistoryController get _activeUndo =>
      _activeIsDetail ? _detailUndo : _textUndo;

  @override
  void initState() {
    super.initState();
    _textFocus.addListener(_syncActive);
    _detailFocus.addListener(_syncActive);
  }

  void _syncActive() {
    final isDetail = _detailFocus.hasFocus;
    if (isDetail != _activeIsDetail &&
        (_detailFocus.hasFocus || _textFocus.hasFocus)) {
      setState(() => _activeIsDetail = isDetail);
    }
  }

  @override
  void dispose() {
    _textUndo.dispose();
    _detailUndo.dispose();
    _text.dispose();
    _detail.dispose();
    _textFocus.dispose();
    _detailFocus.dispose();
    super.dispose();
  }

  /// 点标题 / 备注：把当前内容灌进控制器，切到编辑态并聚焦对应输入框。
  void _beginEdit({required bool detail}) {
    _text.text = _todo.text;
    _detail.text = _todo.detail;
    setState(() => _editing = true);
    final focus = detail ? _detailFocus : _textFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
  }

  Future<void> _save() async {
    final text = normalizeTitle(_text.text);
    final stored = await widget.repository.update(
      _todo.copyWith(
        text: text,
        detail: _detail.text,
        updatedAt: DateTime.now(),
      ),
    );
    if (stored == null || !mounted) {
      return;
    }
    setState(() {
      _todo = stored;
      _editing = false;
    });
  }

  void _toggleDone() => unawaited(_setDone(!_todo.done));

  Future<void> _setDone(bool done) async {
    await widget.repository.setDone(_todo.id, done);
    if (!mounted) {
      return;
    }
    // setDone 只改落库；本地同步一份让圆点立刻反映。
    setState(() => _todo = _todo.copyWith(done: done));
  }

  void _togglePin() => unawaited(_setPinned(!_todo.pinned));

  Future<void> _setPinned(bool pinned) async {
    final stored = await widget.repository.update(
      _todo.copyWith(pinned: pinned),
    );
    if (stored == null || !mounted) {
      return;
    }
    setState(() => _todo = stored);
  }

  void _setCategory(NoteCategory category) =>
      unawaited(_applyCategory(category));

  /// 分类只改 `category`，不动 `updatedAt`。
  Future<void> _applyCategory(NoteCategory category) async {
    final stored = await widget.repository.update(
      _todo.copyWith(category: category.name),
    );
    if (stored == null || !mounted) {
      return;
    }
    setState(() => _todo = stored);
  }

  void _toggleFavorite() => unawaited(_setFavorite(!_todo.favorite));

  Future<void> _setFavorite(bool favorite) async {
    final stored = await widget.repository.update(
      _todo.copyWith(favorite: favorite),
    );
    if (stored == null || !mounted) {
      return;
    }
    setState(() => _todo = stored);
  }

  /// 设 / 改 / 清提醒时间。
  Future<void> _pickReminder() async {
    final result = await showReminderPicker(
      context,
      initial: _todo.remindAt,
      subject: _todo.text,
    );
    if (result == null || !mounted) {
      return;
    }
    final stored = await widget.repository.update(
      _todo.copyWith(remindAt: result.time),
    );
    if (stored == null || !mounted) {
      return;
    }
    setState(() => _todo = stored);
  }

  void _delete() => unawaited(_confirmAndDelete());

  Future<void> _confirmAndDelete() async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: Builder(
        builder: (dialogContext) => AlertDialog(
          title: '删除待办',
          destructive: true,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
          child: Text('「${_todo.text}」将移到「最近删除」，可随时恢复。'),
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await widget.repository.delete(_todo.id);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return PageBackGuard(
      // 编辑态下返回先退出编辑，而不是直接关掉详情。
      blocking: _editing,
      onBack: () => setState(() => _editing = false),
      child: PrismScaffold(
        bar: AppPageBar(
          // 顶栏不显示标题文字。
          title: '',
          showBack: true,
          actions: _editing
              ? [
                  BarUndoRedo(controller: _activeUndo),
                  const SizedBox(width: 4),
                  BarSaveButton(onPressed: _save),
                ]
              : [
                  BarMenuButton(
                    items: () => [
                      PopupMenuItem(
                        label: _todo.favorite ? '取消收藏' : '收藏',
                        glyph: AppGlyphs.star,
                        onPressed: _toggleFavorite,
                      ),
                      PopupMenuItem(
                        label: _todo.pinned ? '取消置顶' : '置顶',
                        glyph: Glyphs.pin,
                        onPressed: _togglePin,
                      ),
                      PopupMenuItem(
                        label: '编辑',
                        onPressed: () => _beginEdit(detail: false),
                      ),
                      PopupMenuItem(
                        label: '删除',
                        danger: true,
                        onPressed: _delete,
                      ),
                    ],
                  ),
                ],
        ),
        body: BarClearance(
          // 非编辑态点页面任意空白处也进编辑（点「要做什么/备注」则在对应框聚焦）。
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _editing ? null : () => _beginEdit(detail: true),
            child: ListView(
              padding: context.listInsets.page(
                top: appBarContentGap,
                bottom: 48,
              ),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 12),
                      child: TodoDoneMark(done: _todo.done, onTap: _toggleDone),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _editing
                            ? null
                            : () => _beginEdit(detail: false),
                        child: _editing
                            ? TextField(
                                controller: _text,
                                focusNode: _textFocus,
                                undoController: _textUndo,
                                // 超宽自动折行，与新建页一致。
                                maxLines: null,
                                textInputAction: TextInputAction.next,
                                style: AppTextStyle.title2
                                    .of(context)
                                    .copyWith(
                                      decoration: _todo.done
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                    ),
                                decoration: const InputDecoration(
                                  hintText: '要做什么',
                                  border: NoInputBorder(),
                                ),
                              )
                            : Text(
                                _todo.text,
                                style: AppTextStyle.title2
                                    .of(context)
                                    .copyWith(
                                      decoration: _todo.done
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                      color: _todo.done
                                          ? colorScheme.onSurfaceVariant
                                          : colorScheme.onSurface,
                                    ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_todo.pinned) ...[
                      GlyphIcon(
                        Glyphs.pin,
                        size: 12,
                        fill: 1,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 5),
                    ],
                    if (_todo.favorite) ...[
                      GlyphIcon(
                        AppGlyphs.star,
                        size: 12,
                        fill: 1,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      '更新于 ${fullDateTime(_todo.updatedAt)}',
                      style: AppTextStyle.footnote
                          .of(context)
                          .copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // 分类：详情里也能改，选完就地落库。
                CategoryPicker(
                  value: NoteCategory.of(_todo.category),
                  onChanged: _setCategory,
                ),
                const SizedBox(height: 14),
                ReminderRow(
                  remindAt: _todo.remindAt,
                  onTap: _pickReminder,
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: _editing ? null : () => _beginEdit(detail: true),
                  child: _editing
                      ? TextField(
                          controller: _detail,
                          focusNode: _detailFocus,
                          undoController: _detailUndo,
                          maxLines: null,
                          minLines: 6,
                          keyboardType: TextInputType.multiline,
                          textAlignVertical: TextAlignVertical.top,
                          style: AppTextStyle.body.of(context),
                          decoration: const InputDecoration(
                            hintText: '备注',
                            border: NoInputBorder(),
                          ),
                        )
                      : Text(
                          _todo.detail,
                          style: AppTextStyle.body.of(context),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
