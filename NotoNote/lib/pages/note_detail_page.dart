import 'dart:async';

import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:prism_ui/icons/icons.dart';
import 'package:prism_ui/prism_ui.dart';

import '../ui/bar_clearance.dart';
import '../common/relative_time.dart';
import '../models/attachment.dart';
import '../models/category.dart';
import '../models/note.dart';
import '../services/attachment_service.dart';
import '../services/note_repository.dart';
import '../ui/app_page_bar.dart';
import '../ui/attachment_tray.dart';
import '../ui/category_picker.dart';
import '../ui/icons/app_glyphs.dart';
import '../ui/page_back_guard.dart';

/// 笔记详情 / 原地编辑。
///
/// 顶栏不显示标题文字（只留返回与菜单）。点标题或正文即在原地切成输入框，
/// 顶栏右侧出现对勾保存。保存后就地刷新，删除则直接退出。
class NoteDetailPage extends StatefulWidget {
  const NoteDetailPage({
    super.key,
    required this.note,
    required this.repository,
  });

  final Note note;
  final NoteRepository repository;

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  late Note _note = widget.note;

  var _editing = false;
  late final TextEditingController _title = TextEditingController();
  late final TextEditingController _body = TextEditingController();
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();

  /// 标题与正文各一份撤销栈，顶栏按钮作用于当前聚焦的那个。
  final _titleUndo = UndoHistoryController();
  final _bodyUndo = UndoHistoryController();
  var _activeIsBody = false;

  /// 正在读文件 / 落库时把底栏按灰，避免连点重复添加。
  var _busy = false;

  /// 底栏上方的一句临时提示（文件太大被跳过等）。
  String? _notice;
  Timer? _noticeTimer;

  UndoHistoryController get _activeUndo =>
      _activeIsBody ? _bodyUndo : _titleUndo;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(_syncActive);
    _bodyFocus.addListener(_syncActive);
  }

  void _syncActive() {
    final isBody = _bodyFocus.hasFocus;
    if (isBody != _activeIsBody &&
        (_bodyFocus.hasFocus || _titleFocus.hasFocus)) {
      setState(() => _activeIsBody = isBody);
    }
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _titleUndo.dispose();
    _bodyUndo.dispose();
    _title.dispose();
    _body.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  /// 点标题 / 正文：把当前内容灌进控制器，切到编辑态并聚焦对应输入框。
  void _beginEdit({required bool body}) {
    _title.text = _note.title;
    _body.text = _note.body;
    setState(() => _editing = true);
    final focus = body ? _bodyFocus : _titleFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
  }

  Future<void> _save() async {
    final title = normalizeTitle(_title.text);
    final body = _body.text;
    final stored = await widget.repository.update(
      _note.copyWith(title: title, body: body, updatedAt: DateTime.now()),
    );
    if (stored == null || !mounted) {
      return;
    }
    setState(() {
      _note = stored;
      _editing = false;
    });
  }

  void _togglePin() => unawaited(_setPinned(!_note.pinned));

  /// 置顶只改 `pinned`，不动 `updatedAt`——否则一切换时间就"变新"了。
  Future<void> _setPinned(bool pinned) async {
    final stored = await widget.repository.update(
      _note.copyWith(pinned: pinned),
    );
    if (stored == null || !mounted) {
      return;
    }
    setState(() => _note = stored);
  }

  void _setCategory(NoteCategory category) =>
      unawaited(_applyCategory(category));

  /// 分类只改 `category`，不动 `updatedAt`——归个类不该算"有新内容"。
  Future<void> _applyCategory(NoteCategory category) async {
    final stored = await widget.repository.update(
      _note.copyWith(category: category.name),
    );
    if (stored == null || !mounted) {
      return;
    }
    setState(() => _note = stored);
  }

  void _toggleFavorite() => unawaited(_setFavorite(!_note.favorite));

  /// 收藏同理：只改 `favorite`，时间不动。
  Future<void> _setFavorite(bool favorite) async {
    final stored = await widget.repository.update(
      _note.copyWith(favorite: favorite),
    );
    if (stored == null || !mounted) {
      return;
    }
    setState(() => _note = stored);
  }

  void _delete() => unawaited(_confirmAndDelete());

  /// 删除不可撤销，必须先确认。
  Future<void> _confirmAndDelete() async {
    final confirmed = await showFloatingDialog<bool>(
      context: context,
      child: Builder(
        builder: (dialogContext) => AlertDialog(
          title: '删除笔记',
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
          child: Text('「${_note.title}」删除后无法恢复。'),
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _deleteNote();
  }

  Future<void> _deleteNote() async {
    await widget.repository.delete(_note.id);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  // ---- 附件 ----------------------------------------------------------

  void _showNotice(String text) {
    _noticeTimer?.cancel();
    setState(() => _notice = text);
    _noticeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _notice = null);
      }
    });
  }

  void _pickFiles() => unawaited(_addAttachments(AttachmentService.pickFiles));

  void _pickPhotos() =>
      unawaited(_addAttachments(AttachmentService.pickPhotos));

  void _takePhoto() => unawaited(_addAttachments(AttachmentService.takePhoto));

  /// 挑完直接落库：附件是独立操作，不必等编辑态顶栏那下「保存」。
  Future<void> _addAttachments(
    Future<AttachmentPickResult> Function() pick,
  ) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await pick();
      if (!mounted) {
        return;
      }
      if (result.attachments.isNotEmpty) {
        await _applyAttachments([
          ..._note.attachments,
          ...result.attachments,
        ]);
      }
      if (result.skipped > 0 && mounted) {
        _showNotice('有 ${result.skipped} 个文件超过 2 MB，已跳过');
      }
    } catch (_) {
      if (mounted) {
        _showNotice('保存失败，可能是存储空间不够');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _removeAttachment(NoteAttachment attachment) => unawaited(
    _applyAttachments([
      for (final item in _note.attachments)
        if (item.id != attachment.id) item,
    ]),
  );

  Future<void> _applyAttachments(List<NoteAttachment> next) async {
    final stored = await widget.repository.update(
      _note.copyWith(attachments: next),
    );
    if (stored == null || !mounted) {
      return;
    }
    setState(() => _note = stored);
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
                        label: _note.favorite ? '取消收藏' : '收藏',
                        glyph: AppGlyphs.star,
                        onPressed: _toggleFavorite,
                      ),
                      PopupMenuItem(
                        label: _note.pinned ? '取消置顶' : '置顶',
                        glyph: Glyphs.pin,
                        onPressed: _togglePin,
                      ),
                      PopupMenuItem(
                        label: '编辑',
                        onPressed: () => _beginEdit(body: false),
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
          child: Column(
            children: [
              Expanded(
                // 非编辑态点页面任意空白处也进编辑（点标题/正文则在对应框聚焦）。
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _editing ? null : () => _beginEdit(body: true),
                  child: ListView(
                    padding: context.listInsets.page(
                      top: appBarContentGap,
                      bottom: 12,
                    ),
                    children: [
                // 标题：常态点一下进编辑，编辑态是输入框
                GestureDetector(
                  onTap: _editing ? null : () => _beginEdit(body: false),
                  child: _editing
                      ? TextField(
                          controller: _title,
                          focusNode: _titleFocus,
                          undoController: _titleUndo,
                          // 超宽自动折行，与新建页一致。
                          maxLines: null,
                          textInputAction: TextInputAction.next,
                          style: AppTextStyle.title1.of(context),
                          decoration: const InputDecoration(
                            hintText: '标题',
                            border: NoInputBorder(),
                          ),
                        )
                      : Text(
                          _note.title,
                          style: AppTextStyle.title1.of(context),
                        ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_note.pinned) ...[
                      GlyphIcon(
                        Glyphs.pin,
                        size: 12,
                        fill: 1,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 5),
                    ],
                    if (_note.favorite) ...[
                      GlyphIcon(
                        AppGlyphs.star,
                        size: 12,
                        fill: 1,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      '更新于 ${fullDateTime(_note.updatedAt)}',
                      style: AppTextStyle.footnote
                          .of(context)
                          .copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // 分类：详情里也能改（不必回新建页），选完就地落库。
                CategoryPicker(
                  value: NoteCategory.of(_note.category),
                  onChanged: _setCategory,
                ),
                const SizedBox(height: 22),
                // 正文：同上
                GestureDetector(
                  onTap: _editing ? null : () => _beginEdit(body: true),
                  child: _editing
                      ? TextField(
                          controller: _body,
                          focusNode: _bodyFocus,
                          undoController: _bodyUndo,
                          maxLines: null,
                          minLines: 12,
                          keyboardType: TextInputType.multiline,
                          textAlignVertical: TextAlignVertical.top,
                          style: AppTextStyle.body.of(context),
                          decoration: const InputDecoration(
                            hintText: '正文',
                            border: NoInputBorder(),
                          ),
                        )
                      : _note.body.isEmpty
                      // 正文为空时给一句占位提示（点一下就进编辑）。
                      ? Text(
                          '点按输入正文',
                          style: AppTextStyle.body
                              .of(context)
                              .copyWith(
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                        )
                      : Text(_note.body, style: AppTextStyle.body.of(context)),
                ),
                    if (_note.attachments.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      AttachmentSection(
                        attachments: _note.attachments,
                        onRemove: _removeAttachment,
                        onPreview: (attachment) => unawaited(
                          showAttachmentPreview(context, attachment),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
              if (_notice != null) AttachmentNoticeBar(text: _notice!),
              AttachmentTray(
                onAttachFile: _pickFiles,
                onPickPhotos: _pickPhotos,
                onTakePhoto: _takePhoto,
                enabled: !_busy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
