import 'dart:async';

import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

import '../models/category.dart';
import '../models/todo.dart';
import '../services/todo_repository.dart';
import '../ui/app_page_bar.dart';
import '../ui/bar_clearance.dart';
import '../ui/category_picker.dart';
import '../ui/reminder_picker.dart';

/// 添加/编辑待办的弹层。
///
/// 用 `showNestedSheet` 而不是新页面：只填几个字段，不值得占满一屏。
/// 待办页、收藏页、分类内容页共用同一份，保证编辑入口一致。
class TodoEditSheet extends StatefulWidget {
  const TodoEditSheet({super.key, required this.repository, this.todo});

  final TodoRepository repository;

  /// 为空表示新增；传入则是在编辑这一条。
  final Todo? todo;

  @override
  State<TodoEditSheet> createState() => _TodoEditSheetState();
}

class _TodoEditSheetState extends State<TodoEditSheet> {
  late final _text = TextEditingController(text: widget.todo?.text ?? '');
  late final _detail = TextEditingController(text: widget.todo?.detail ?? '');
  late NoteCategory _category = NoteCategory.of(widget.todo?.category);

  /// 提醒时间：改动先留在页面里，跟其它字段一起在保存时提交。
  late DateTime? _remindAt = widget.todo?.remindAt;

  /// 两栏各一份撤销栈，顶栏按钮作用于当前聚焦的那栏。
  final _textUndo = UndoHistoryController();
  final _detailUndo = UndoHistoryController();
  final _textFocus = FocusNode();
  final _detailFocus = FocusNode();
  var _activeIsDetail = false;

  var _saving = false;

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
    _textFocus.dispose();
    _detailFocus.dispose();
    _text.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _pickReminder() async {
    final result = await showReminderPicker(
      context,
      initial: _remindAt,
      subject: _text.text,
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() => _remindAt = result.time);
  }

  Future<void> _save() async {
    final text = _text.text.trim();
    if (text.isEmpty || _saving) {
      return;
    }
    setState(() => _saving = true);
    if (widget.todo case final todo?) {
      await widget.repository.update(
        todo.copyWith(
          text: text,
          detail: _detail.text.trim(),
          category: _category.name,
          remindAt: _remindAt,
          updatedAt: DateTime.now(),
        ),
      );
    } else {
      await widget.repository.create(
        text: text,
        detail: _detail.text,
        category: _category.name,
        remindAt: _remindAt,
      );
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PrismScaffold(
      bar: AppPageBar(
        // 顶栏不显示标题文字。
        title: '',
        showBack: true,
        actions: [
          BarUndoRedo(controller: _activeUndo),
          const SizedBox(width: 4),
          BarSaveButton(onPressed: _saving ? null : () => unawaited(_save())),
        ],
      ),
      body: BarClearance(
        child: ListView(
          padding: context.listInsets.page(top: appBarContentGap, bottom: 32),
          children: [
            TextField(
              controller: _text,
              focusNode: _textFocus,
              undoController: _textUndo,
              autofocus: true,
              // 超出一行宽度时自动折行。
              maxLines: null,
              textInputAction: TextInputAction.next,
              style: AppTextStyle.title3.of(context),
              decoration: const InputDecoration(
                hintText: '要做什么',
                border: NoInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detail,
              focusNode: _detailFocus,
              undoController: _detailUndo,
              maxLines: 3,
              minLines: 1,
              style: AppTextStyle.subheadline.of(context),
              decoration: const InputDecoration(
                hintText: '备注（可选）',
                border: NoInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            CategoryPicker(
              value: _category,
              onChanged: (category) => setState(() => _category = category),
            ),
            const SizedBox(height: 4),
            ReminderRow(remindAt: _remindAt, onTap: _pickReminder),
          ],
        ),
      ),
    );
  }
}
