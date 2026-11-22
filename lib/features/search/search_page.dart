import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    hide GlassContainer;
import 'package:material_ui/material_ui.dart';

import '../notes/note_card.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/glass_ink.dart';
import '../../app/theme/app_dimensions.dart';
import '../../app/theme/app_typography.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';
import '../notes/swipe_actions.dart';

/// 搜索页 —— 实时标题/正文全文检索
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  String _keyword = '';
  final _recent = <String>[];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final kw = value.trim();
    if (kw.isEmpty) return;
    setState(() {
      _keyword = kw;
      if (!_recent.contains(kw)) _recent.insert(0, kw);
      if (_recent.length > 8) _recent.removeLast();
    });
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
    final Color fill = isDark ? AppColors.darkFill : AppColors.lightFill;

    final resultsAsync = ref.watch(searchNotesProvider(_keyword));
    final folders = ref.watch(foldersProvider).value ?? [];
    final folderMap = {for (final f in folders) f.id: f};

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        // 库的 GlassSearchBar：走液态玻璃材质（不设 surfaceStyle，用默认 glass）
        // 颜色全部显式指定，避免库默认色在深色模式下不可读
        title: GlassSearchBar(
          controller: _controller,
          autofocus: true,
          placeholder: '搜索笔记…',
          height: 40,
          textStyle: AppTypography.body.copyWith(color: primary),
          placeholderStyle: AppTypography.body.copyWith(
            color: GlassInk.placeholder(context),
          ),
          searchIconColor: GlassInk.secondary(context),
          clearIconColor: GlassInk.secondary(context),
          onSubmitted: _submit,
          onChanged: (v) {
            if (v.isEmpty) setState(() => _keyword = '');
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: _keyword.isEmpty
            ? _buildIdle(secondary, fill)
            : resultsAsync.when(
                data: (list) {
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: Icons.search_off,
                      title: '没有找到结果',
                      subtitle: '试试其它关键词',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(
                      top: AppDims.s8,
                      bottom: 100,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final n = list[i];
                      return NoteCard(
                        note: n,
                        folder: n.folderId != null
                            ? folderMap[n.folderId]
                            : null,
                        onTap: () => context.push('/note/${n.id}'),
                        onSwipeDelete: () => swipeDeleteNote(context, ref, n),
                        onSwipeFavorite: () => swipeToggleFavorite(ref, n),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => EmptyState(
                  icon: Icons.error_outline,
                  title: '搜索失败',
                  subtitle: e.toString(),
                ),
              ),
      ),
    );
  }

  Widget _buildIdle(Color secondary, Color fill) {
    if (_recent.isEmpty) {
      return EmptyState(
        icon: Icons.search,
        title: '搜索你的笔记',
        subtitle: '输入关键词，按回车搜索标题和正文',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppDims.s16),
      children: [
        SectionHeader(
          text: '最近搜索',
          trailing: TextButton(
            onPressed: () => setState(() => _recent.clear()),
            child: const Text('清除'),
          ),
        ),
        ..._recent.map(
          (kw) => ListTile(
            leading: Icon(Icons.history, size: 18, color: secondary),
            title: Text(kw),
            onTap: () {
              _controller.text = kw;
              _submit(kw);
            },
          ),
        ),
      ],
    );
  }
}
