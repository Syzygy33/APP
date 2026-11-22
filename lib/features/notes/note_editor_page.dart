import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/glass_ink.dart';
import '../../shared/widgets/app_trash_icon.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_typography.dart';
import '../../data/database/app_database.dart';
import '../../data/images/image_store.dart';
import '../../data/models/note_kind.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/ios_bottom_sheet.dart';
import '../../shared/widgets/ios_dialog.dart';
import '../../shared/widgets/pressable.dart';

/// 笔记编辑器 —— 新建与编辑共用，真实落库，自动保存。
class NoteEditorPage extends ConsumerStatefulWidget {
  final String noteId; // 'new' 或数字 id

  /// 新建时的默认类型（从待办页进入时由加号带入）
  final NoteKind kindInitial;

  const NoteEditorPage({
    super.key,
    required this.noteId,
    this.kindInitial = NoteKind.note,
  });

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _titleFocus = FocusNode();
  final _contentFocus = FocusNode();
  Note? _existing;
  int? _folderId;
  NoteKind _kind = NoteKind.note;
  bool _loading = true;
  bool _dirty = false;
  Timer? _saveDebounce;
  bool _saving = false;
  List<Attachment> _attachments = const [];
  static const int _maxImages = 9;

  @override
  void initState() {
    super.initState();
    _load();
    _titleController.addListener(_onChanged);
    _contentController.addListener(_onChanged);
  }

  Future<void> _load() async {
    _kind = widget.kindInitial;
    if (widget.noteId != 'new') {
      final id = int.tryParse(widget.noteId);
      if (id != null) {
        _existing = await ref.read(repositoryProvider).findNote(id);
        _folderId = _existing?.folderId;
        _kind = NoteKind.fromValue(_existing?.kind ?? widget.kindInitial.value);
        _titleController.text = _existing?.title ?? '';
        _contentController.text = _existing?.content ?? '';
      }
    }
    await _loadAttachments();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadAttachments() async {
    final note = _existing;
    if (note == null) {
      if (mounted) setState(() => _attachments = const []);
      return;
    }
    final list = await ref.read(repositoryProvider).attachmentsOf(note.id);
    if (mounted) setState(() => _attachments = list);
  }

  void _onChanged() {
    // _load 阶段回填文本也会触发 listener，此时不应视为用户编辑
    if (_loading) return;
    setState(() => _dirty = true);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), _save);
  }

  /// 点空白处聚焦到当前类型的主输入框
  void _focusPrimary() {
    if (_kind.isTodo) {
      _titleFocus.requestFocus();
    } else {
      _contentFocus.requestFocus();
    }
  }

  /// 切换类型时把内容归并到唯一字段，避免「正文有字但列表不显示」
  void _mergeForKind(NoteKind kind) {
    if (kind.isTodo) {
      final String t = _titleController.text.trim();
      final String c = _contentController.text.trim();
      if (c.isEmpty) return;
      _titleController.text = t.isEmpty ? c : '$t\n$c';
      _contentController.clear();
    }
  }

  bool get _blank =>
      _titleController.text.trim().isEmpty &&
      _contentController.text.trim().isEmpty;

  Future<void> _save() async {
    if (_saving) return;
    // 新建但一个字都没写：不留空笔记
    if (_existing == null && _blank) {
      if (mounted) setState(() => _dirty = false);
      return;
    }
    // 已有内容且什么都没改：不写库，避免打开即刷新 updatedAt
    if (_existing != null &&
        _existing!.title == _titleController.text &&
        _existing!.content == _contentController.text &&
        _existing!.folderId == _folderId &&
        NoteKind.fromValue(_existing!.kind) == _kind) {
      if (mounted) setState(() => _dirty = false);
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(repositoryProvider);
    if (_existing != null) {
      await repo.updateNote(
        id: _existing!.id,
        title: _titleController.text,
        content: _contentController.text,
        folderId: _folderId,
      );
      if (NoteKind.fromValue(_existing!.kind) != _kind) {
        await repo.setKind(_existing!.id, _kind);
        _existing = await repo.findNote(_existing!.id);
      }
    } else {
      final newId = await repo.createNote(
        title: _titleController.text,
        content: _contentController.text,
        folderId: _folderId,
        kind: _kind,
      );
      // 新建后立即转为编辑态，避免重复创建
      _existing = await repo.findNote(newId);
    }
    if (mounted) setState(() => _dirty = false);
    _saving = false;
  }

  Future<void> _addImages({required bool camera}) async {
    final int remaining = _maxImages - _attachments.length;
    if (remaining <= 0) {
      _toast('最多添加 $_maxImages 张图片');
      return;
    }
    final picker = ImagePicker();
    try {
      if (camera) {
        final XFile? shot = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 2400,
          imageQuality: 92,
        );
        if (shot == null) return;
        await _saveBytes(await shot.readAsBytes());
      } else {
        final List<XFile> picked = await picker.pickMultiImage(
          imageQuality: 92,
        );
        if (picked.isEmpty) return;
        for (final XFile file in picked.take(remaining)) {
          await _saveBytes(await file.readAsBytes());
        }
      }
    } on Object catch (e) {
      _toast('添加图片失败：$e');
    }
  }

  Future<void> _saveBytes(Uint8List bytes) async {
    // 图片本身就算内容：允许「一个字没写就加图」，此时直接建一条空记录
    Note? note = _existing;
    if (note == null) {
      final repo = ref.read(repositoryProvider);
      final id = await repo.createNote(
        title: _titleController.text,
        content: _contentController.text,
        folderId: _folderId,
        kind: _kind,
      );
      note = await repo.findNote(id);
      _existing = note;
    }
    if (note == null) {
      _toast('添加图片失败：无法创建内容');
      return;
    }
    final String fileName = await ImageStore.save(bytes);
    await ref.read(repositoryProvider).addAttachment(note.id, fileName);
    await _loadAttachments();
    // 图片属于内容，刷新更新时间
    _saveDebounce?.cancel();
    await _save();
  }

  Future<void> _removeImage(Attachment item) async {
    await ref.read(repositoryProvider).removeAttachment(item.id);
    await _loadAttachments();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
      );
  }

  void _previewImage(Attachment item) {
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Container(
          color: Colors.black.withValues(alpha: 0.9),
          child: Center(
            child: InteractiveViewer(
              child: Image.file(ImageStore.fileOf(item.fileName)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _imageTools(Color secondary, Color accent, Color fill) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDims.s8),
      child: Row(
        children: [
          _ToolChip(
            icon: LucideIcons.imagePlus,
            label: '相册',
            fill: fill,
            color: accent,
            onTap: () => _addImages(camera: false),
          ),
          const SizedBox(width: AppDims.s8),
          _ToolChip(
            icon: LucideIcons.camera,
            label: '拍照',
            fill: fill,
            color: accent,
            onTap: () => _addImages(camera: true),
          ),
          const Spacer(),
          if (_attachments.isNotEmpty)
            Text(
              '${_attachments.length}/$_maxImages',
              style: AppTypography.caption1.copyWith(color: secondary),
            ),
        ],
      ),
    );
  }

  Widget _imageStrip() {
    if (_attachments.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppDims.s8),
        itemBuilder: (context, i) {
          final a = _attachments[i];
          return GestureDetector(
            onTap: () => _previewImage(a),
            onLongPress: () => _removeImage(a),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDims.radiusS + 2),
                  child: Image.file(
                    ImageStore.fileOf(a.fileName),
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 76,
                      height: 76,
                      color: AppColors.lightFill,
                      child: const Icon(Icons.broken_image_outlined, size: 20),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: PressableScale(
                    onTap: () => _removeImage(a),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xB3000000),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _delete() async {
    if (_existing == null) {
      if (mounted) context.pop();
      return;
    }
    final confirmed = await showIOSConfirm(
      context: context,
      title: '删除这条笔记？',
      message: '笔记会移入回收站，可随时恢复。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (confirmed == true) {
      _saveDebounce?.cancel();
      await ref.read(repositoryProvider).softDelete(_existing!.id);
      if (mounted) context.pop();
    }
  }

  void _showFolderPicker() {
    final foldersAsync = ref.read(foldersProvider);
    final folders = foldersAsync.value ?? [];
    showIOSBottomSheet<void>(
      context: context,
      title: '选择分类',
      builder: (ctx) => ListView(
        children: [
          _folderTile(ctx, null, '无分类'),
          ...folders.map((f) => _folderTile(ctx, f.id, f.name, f.colorIndex)),
        ],
      ),
    );
  }

  Widget _folderTile(
    BuildContext ctx,
    int? id,
    String name, [
    int? colorIndex,
  ]) {
    final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
    final bool selected = _folderId == id;
    final Color color = colorIndex != null
        ? AppColors.categoryColor(colorIndex)
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);
    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(name),
      trailing: selected
          ? Icon(
              Icons.check,
              color: isDark ? AppColors.accentDark : AppColors.accent,
            )
          : null,
      onTap: () {
        setState(() {
          _folderId = id;
          _dirty = true;
        });
        _save();
        Navigator.of(ctx).pop();
      },
    );
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final Color primary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color secondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final Color accent = isDark ? AppColors.accentDark : AppColors.accent;
    final Color fill = isDark ? AppColors.darkFill : AppColors.lightFill;

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final folders = ref.watch(foldersProvider).value ?? [];
    final currentFolder = folders.where((f) => f.id == _folderId).firstOrNull;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          _saving ? '保存中…' : (_dirty ? '编辑中…' : '已保存'),
          style: AppTypography.subheadline.copyWith(color: secondary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () async {
            await _save();
            if (context.mounted) context.pop();
          },
        ),
        actions: [
          if (_existing != null)
            IconButton(
              icon: AppTrashIcon(color: GlassInk.primary(context)),
              tooltip: '删除',
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          // 点正文空白区域也能直接开始输入（原先空白区不属于任何输入框）
          behavior: HitTestBehavior.opaque,
          onTap: _focusPrimary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDims.s20,
                  AppDims.s8,
                  AppDims.s20,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_kind.isTodo) ...[
                      TextField(
                        controller: _titleController,
                        focusNode: _titleFocus,
                        style: AppTypography.title1.copyWith(color: primary),
                        decoration: InputDecoration(
                          hintText: '标题',
                          hintStyle: AppTypography.title1.copyWith(
                            color: secondary.withValues(alpha: 0.5),
                          ),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        maxLines: null,
                      ),
                      const SizedBox(height: AppDims.s8),
                    ],
                    Row(
                      children: [
                        Icon(Icons.folder_outlined, size: 15, color: secondary),
                        const SizedBox(width: AppDims.s6),
                        PressableScale(
                          onTap: _showFolderPicker,
                          child: Text(
                            currentFolder?.name ?? '无分类',
                            style: AppTypography.footnote.copyWith(
                              color: accent,
                            ),
                          ),
                        ),
                        const Spacer(),
                        _TypeToggle(
                          kind: _kind,
                          onChanged: (v) {
                            setState(() => _kind = v);
                            _mergeForKind(v);
                            _save();
                          },
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppDims.s16),
                      child: Divider(),
                    ),
                    _imageTools(secondary, accent, fill),
                    _imageStrip(),
                  ],
                ),
              ),
              // 正文占满剩余高度，点任意位置都能聚焦并唤起键盘
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDims.s20,
                    0,
                    AppDims.s20,
                    AppDims.s20,
                  ),
                  child: TextField(
                    // 待办没有标题/正文之分，唯一输入区直接写事项
                    controller: _kind.isTodo
                        ? _titleController
                        : _contentController,
                    focusNode: _kind.isTodo ? _titleFocus : _contentFocus,
                    style: AppTypography.body.copyWith(
                      color: primary,
                      height: 1.7,
                    ),
                    decoration: InputDecoration(
                      hintText: switch (_kind) {
                        NoteKind.note => '开始记录你的想法…',
                        NoteKind.todo => '要做什么？',
                      },
                      hintStyle: AppTypography.body.copyWith(
                        color: secondary.withValues(alpha: 0.6),
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
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

/// 「笔记 / 待办」类型切换胶囊
class _TypeToggle extends StatelessWidget {
  final NoteKind kind;
  final ValueChanged<NoteKind> onChanged;

  const _TypeToggle({required this.kind, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color track = isDark ? AppColors.darkFill : AppColors.lightFill;
    final Color activeText = isDark
        ? AppColors.darkTextPrimary
        : Colors.black87;

    Widget seg(NoteKind value) {
      final bool selected = kind == value;
      return PressableScale(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: AppDims.animFast,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDims.s10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            // 深色下轨道本身就是 2C2C2E，选中态必须再亮一档才看得见
            color: selected
                ? (isDark ? const Color(0xFF48484A) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDims.radiusPill),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            value.label,
            style: AppTypography.caption2.copyWith(
              fontSize: 12,
              color: selected
                  ? activeText
                  : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(AppDims.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (final k in NoteKind.values) seg(k)],
      ),
    );
  }
}

/// 编辑器图片工具按钮：小胶囊，图标 + 文案
class _ToolChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color fill;
  final Color color;
  final VoidCallback onTap;

  const _ToolChip({
    required this.icon,
    required this.label,
    required this.fill,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(AppDims.radiusPill),
      child: PressableScale(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDims.s12,
            vertical: 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: AppDims.s6),
              Text(
                label,
                style: AppTypography.caption1.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
