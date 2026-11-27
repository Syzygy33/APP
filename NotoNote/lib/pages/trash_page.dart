import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

import '../common/relative_time.dart';
import '../models/note.dart';
import '../models/todo.dart';
import '../services/note_repository.dart';
import '../services/notes_revision.dart';
import '../services/todo_repository.dart';
import '../services/todo_revision.dart';
import '../ui/app_page_bar.dart';
import '../ui/bar_clearance.dart';
import '../ui/confirm.dart';
import '../ui/icons/app_glyphs.dart';
import '../ui/list_stats_header.dart';

/// 「最近删除」回收站。
///
/// 笔记和待办各有自己的软删除仓储，页面把两股数据合并展示：
/// 顶部一组笔记、下面一组待办，都按删除时间从近到远。
/// 行右侧的菜单提供「恢复」和「彻底删除」，顶栏可以一次清空。
class TrashPage extends StatefulWidget {
  const TrashPage({
    super.key,
    required this.noteRepository,
    required this.todoRepository,
  });

  final NoteRepository noteRepository;
  final TodoRepository todoRepository;

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  var _loading = true;
  List<Note> _notes = const [];
  List<Todo> _todos = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    notesRevision.addListener(_onChanged);
    todoRevision.addListener(_onChanged);
  }

  @override
  void dispose() {
    notesRevision.removeListener(_onChanged);
    todoRevision.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => unawaited(_load());

  Future<void> _load() async {
    final notes = await widget.noteRepository.loadTrash();
    final todos = await widget.todoRepository.loadTrash();
    if (!mounted) {
      return;
    }
    setState(() {
      _notes = notes;
      _todos = todos;
      _loading = false;
    });
  }

  Future<void> _restoreNote(Note note) =>
      widget.noteRepository.restore(note.id);

  Future<void> _restoreTodo(Todo todo) =>
      widget.todoRepository.restore(todo.id);

  Future<void> _purgeNote(Note note) => widget.noteRepository.purge(note.id);

  Future<void> _purgeTodo(Todo todo) => widget.todoRepository.purge(todo.id);

  Future<void> _emptyTrash() async {
    final ok = await confirmDestructive(
      context,
      title: '清空回收站',
      message: '回收站里的笔记和待办会被彻底删除，无法恢复。',
      confirmLabel: '清空',
    );
    if (!ok || !mounted) {
      return;
    }
    await widget.noteRepository.purgeAll();
    await widget.todoRepository.purgeAll();
  }

  List<PopupMenuItem> _noteMenu(Note note) => [
    PopupMenuItem(label: '恢复', onPressed: () => unawaited(_restoreNote(note))),
    PopupMenuItem(
      label: '彻底删除',
      danger: true,
      onPressed: () => unawaited(_confirmPurgeNote(note)),
    ),
  ];

  List<PopupMenuItem> _todoMenu(Todo todo) => [
    PopupMenuItem(label: '恢复', onPressed: () => unawaited(_restoreTodo(todo))),
    PopupMenuItem(
      label: '彻底删除',
      danger: true,
      onPressed: () => unawaited(_confirmPurgeTodo(todo)),
    ),
  ];

  /// 彻底删除无法恢复，必须二次确认。
  Future<void> _confirmPurgeNote(Note note) async {
    final ok = await confirmDestructive(
      context,
      title: '彻底删除笔记',
      message: '「${note.title}」将被永久删除，无法恢复。',
      confirmLabel: '彻底删除',
    );
    if (!ok || !mounted) {
      return;
    }
    await _purgeNote(note);
  }

  Future<void> _confirmPurgeTodo(Todo todo) async {
    final ok = await confirmDestructive(
      context,
      title: '彻底删除待办',
      message: '「${todo.text}」将被永久删除，无法恢复。',
      confirmLabel: '彻底删除',
    );
    if (!ok || !mounted) {
      return;
    }
    await _purgeTodo(todo);
  }

  /// 一条笔记：独立一张卡片，长按弹「恢复 / 彻底删除」。
  Widget _noteCard(Note note) {
    final excerpt = note.excerpt;
    final deletedAt = note.deletedAt;
    return ContextMenuRegion(
      menuBuilder: (_) => _noteMenu(note),
      child: Card(
        radius: AppCorner.lg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        // Card 的 PressSurface 默认不把 child 撑满（childFills = false），
        // 内容会缩成自己的宽度再被居中，看起来像「前面空了一块、字跑中间」。
        // 撑满宽度后靠 CrossAxisAlignment.start 左对齐，和列表里的卡片一致。
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              note.title.isEmpty ? '无标题' : note.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.body
                  .of(context)
                  .copyWith(fontWeight: FontWeight.w500),
            ),
            if (excerpt.isNotEmpty || deletedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (excerpt.isNotEmpty) excerpt,
                  if (deletedAt != null) '删除于 ${relativeTime(deletedAt)}',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.subheadline
                    .of(context)
                    .copyWith(color: context.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 一条待办：同样独立一张卡片，长按弹菜单。
  Widget _todoCard(Todo todo) {
    final deletedAt = todo.deletedAt;
    return ContextMenuRegion(
      menuBuilder: (_) => _todoMenu(todo),
      child: Card(
        radius: AppCorner.lg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        // Card 的 PressSurface 默认不把 child 撑满（childFills = false），
        // 内容会缩成自己的宽度再被居中，看起来像「前面空了一块、字跑中间」。
        // 撑满宽度后靠 CrossAxisAlignment.start 左对齐，和列表里的卡片一致。
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              todo.text.isEmpty ? '无内容' : todo.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.body
                  .of(context)
                  .copyWith(fontWeight: FontWeight.w500),
            ),
            if (todo.detail.isNotEmpty || deletedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (todo.detail.isNotEmpty) todo.detail,
                  if (deletedAt != null) '删除于 ${relativeTime(deletedAt)}',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.subheadline
                    .of(context)
                    .copyWith(color: context.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = _notes.isNotEmpty || _todos.isNotEmpty;
    final insets = context.listInsets;
    final gap = insets.margin;
    return PrismScaffold(
      bar: const AppPageBar(title: '最近删除', showBack: true),
      body: Stack(
        children: [
          Positioned.fill(
            child: BarClearance(
              child: NullStatusSwitcher(
                isLoading: _loading,
                isEmpty: !hasContent,
                nullStatus: const NullStatus(
                  label: '没有已删除的内容',
                  description: '删除的笔记和待办会在这里保留，可随时恢复',
                  illustration: Illustration.search,
                ),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    gap,
                    appBarContentGap,
                    gap,
                    // 给底部「全部清空」留出位置
                    32 + context.bottomInset + 44 + 20,
                  ),
                  children: [
                    ListStatsHeader(
                      noteCount: _notes.length,
                      todoCount: _todos.length,
                      padding: const EdgeInsets.only(bottom: 10),
                    ),
                    if (_notes.isNotEmpty) ...[
                      ListHeader(
                        title: '笔记',
                        atTop: true,
                        padding: groupHeaderPadding(context),
                      ),
                      for (var i = 0; i < _notes.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: i == _notes.length - 1 ? 0 : 10,
                          ),
                          child: _noteCard(_notes[i]),
                        ),
                    ],
                    if (_todos.isNotEmpty) ...[
                      ListHeader(
                        title: '待办',
                        atTop: _notes.isEmpty,
                        padding: groupHeaderPadding(context),
                      ),
                      for (var i = 0; i < _todos.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: i == _todos.length - 1 ? 0 : 10,
                          ),
                          child: _todoCard(_todos[i]),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (hasContent)
            // 底部一个垃圾桶图标按钮（液态玻璃），点一次清空。
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: context.bottomInset + 20),
                child: TonalButtonTheme(
                  glass: LiquidGlassScope.of(context),
                  child: BarIconButton(
                    data: IconButtonData(
                      glyph: AppGlyphs.trash,
                      tooltip: '全部清空',
                      onPressed: _emptyTrash,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
