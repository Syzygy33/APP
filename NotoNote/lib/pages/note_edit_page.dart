import 'dart:async';

import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

import '../ui/bar_clearance.dart';
import '../models/attachment.dart';
import '../models/category.dart';
import '../models/note.dart';
import '../services/attachment_service.dart';
import '../services/note_repository.dart';
import '../ui/app_page_bar.dart';
import '../ui/attachment_tray.dart';
import '../ui/category_picker.dart';

/// 新建 / 编辑笔记。
///
/// 保存成功后 `pop(savedNote)`，调用方据此更新界面或刷新列表；
/// 取消则返回 null。
class NoteEditPage extends StatefulWidget {
  const NoteEditPage({super.key, required this.repository, this.note});

  final NoteRepository repository;

  /// 为空表示新建。
  final Note? note;

  @override
  State<NoteEditPage> createState() => _NoteEditPageState();
}

class _NoteEditPageState extends State<NoteEditPage> {
  late final TextEditingController _title = TextEditingController(
    text: widget.note?.title ?? '',
  );
  late final TextEditingController _body = TextEditingController(
    text: widget.note?.body ?? '',
  );

  late NoteCategory _category = NoteCategory.of(widget.note?.category);

  /// 标题与正文各有独立的撤销栈（Flutter 的 UndoHistory 是每个输入框一份），
  /// 顶栏按钮作用于「当前聚焦」的那个，避免两边互相污染历史。
  final _titleUndo = UndoHistoryController();
  final _bodyUndo = UndoHistoryController();
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();
  var _activeIsBody = false;

  var _saving = false;

  /// 附件先留在内存里：新建时还没有笔记 id，等顶栏「保存」时跟着一起写入。
  late List<NoteAttachment> _attachments = [...?widget.note?.attachments];

  /// 正在解码文件时把底栏按灰。
  var _busy = false;

  /// 底栏上方的一句临时提示。
  String? _notice;
  Timer? _noticeTimer;

  bool get _isNew => widget.note == null;

  UndoHistoryController get _activeUndo =>
      _activeIsBody ? _bodyUndo : _titleUndo;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(_syncActive);
    _bodyFocus.addListener(_syncActive);
  }

  /// 焦点换了就切撤销目标，并重建顶栏按钮的启停状态。
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
    _titleFocus.dispose();
    _bodyFocus.dispose();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

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
        setState(() => _attachments = [..._attachments, ...result.attachments]);
      }
      if (result.skipped > 0 && mounted) {
        _showNotice('有 ${result.skipped} 个文件超过 2 MB，已跳过');
      }
    } catch (_) {
      if (mounted) {
        _showNotice('没法读取这个文件');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _removeAttachment(NoteAttachment attachment) {
    setState(() {
      _attachments = [
        for (final item in _attachments)
          if (item.id != attachment.id) item,
      ];
    });
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);

    final title = normalizeTitle(_title.text);
    final body = _body.text;
    final note = widget.note;

    final Note? stored;
    if (note == null) {
      stored = await widget.repository.create(
        title: title,
        body: body,
        category: _category.name,
        attachments: _attachments,
      );
    } else {
      stored = await widget.repository.update(
        // 正文改动才算"更新"，时间由这里给，仓库不代劳
        note.copyWith(
          title: title,
          body: body,
          category: _category.name,
          attachments: _attachments,
          updatedAt: DateTime.now(),
        ),
      );
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop<Note>(stored);
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
      // 同上：不为浮动顶栏留出高度，标题输入框会被压在标题栏下面。
      body: BarClearance(
        // 用 Stack 而不是 Column+Expanded：这个页面是弹层（compact），
        // 高度是「按内容撑开」的，Expanded 在无界高度里拿不到空间。
        // Stack 让工具条始终贴住正文区底部，键盘弹起时 body 收短，它自然上移。
        child: Stack(
          children: [
            ListView(
              padding: context.listInsets.page(
                top: appBarContentGap,
                // 给底部工具条 + 提示留位置
                bottom: 112,
              ),
              children: [
                TextField(
                  controller: _title,
                  focusNode: _titleFocus,
                  undoController: _titleUndo,
                  autofocus: _isNew,
                  // 不再限单行：标题超过一行宽度时自动折行，不横向滚动。
                  maxLines: null,
                  textInputAction: TextInputAction.next,
                  style: AppTextStyle.title2.of(context),
                  decoration: const InputDecoration(
                    hintText: '标题',
                    border: NoInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                CategoryPicker(
                  value: _category,
                  onChanged: (category) =>
                      setState(() => _category = category),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _body,
                  focusNode: _bodyFocus,
                  undoController: _bodyUndo,
                  maxLines: null,
                  minLines: 12,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  style: AppTextStyle.body.of(context),
                  decoration: const InputDecoration(
                    hintText: '开始输入…',
                    border: NoInputBorder(),
                  ),
                ),
                if (_attachments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AttachmentSection(
                    attachments: _attachments,
                    onRemove: _removeAttachment,
                    onPreview: (attachment) =>
                        unawaited(showAttachmentPreview(context, attachment)),
                  ),
                ],
              ],
            ),
            if (_notice != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 60,
                child: AttachmentNoticeBar(text: _notice!),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AttachmentTray(
                onAttachFile: _pickFiles,
                onPickPhotos: _pickPhotos,
                onTakePhoto: _takePhoto,
                enabled: !_busy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
