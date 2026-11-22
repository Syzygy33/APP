import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database/app_database.dart';
import '../data/models/note_kind.dart';
import '../data/repositories/note_repository.dart';

/// 数据库实例（全局单例）
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

/// 仓储层
final repositoryProvider = Provider<NoteRepository>((ref) {
  return NoteRepository(ref.watch(databaseProvider));
});

/// ---- 响应式数据流 ----
final allNotesProvider = StreamProvider<List<Note>>((ref) {
  return ref.watch(repositoryProvider).watchAllActive();
});

/// 按类型取列表：笔记 / 待办
final notesByKindProvider = StreamProvider.family<List<Note>, NoteKind>((
  ref,
  kind,
) {
  return ref.watch(repositoryProvider).watchKind(kind);
});

/// 未完成待办数量（底栏角标与副标题使用）
final todoOpenCountProvider = FutureProvider<int>((ref) async {
  return ref.watch(repositoryProvider).countTodoOpen();
});

final favoriteNotesProvider = StreamProvider<List<Note>>((ref) {
  return ref.watch(repositoryProvider).watchFavorites();
});

final trashNotesProvider = StreamProvider<List<Note>>((ref) {
  return ref.watch(repositoryProvider).watchTrash();
});

/// 某条内容的图片附件
final attachmentsProvider = StreamProvider.family<List<Attachment>, int>((
  ref,
  noteId,
) {
  return ref.watch(repositoryProvider).watchAttachments(noteId);
});

/// 列表缩略图：noteId → 首图文件名
final firstImageMapProvider = StreamProvider<Map<int, String>>((ref) {
  return ref.watch(repositoryProvider).watchFirstImage();
});

final foldersProvider = StreamProvider<List<Folder>>((ref) {
  return ref.watch(repositoryProvider).watchFolders();
});

/// 按文件夹筛选
final folderNotesProvider = StreamProvider.family<List<Note>, int>((
  ref,
  folderId,
) {
  return ref.watch(repositoryProvider).watchByFolder(folderId);
});

/// 搜索（输入为空时返回全部）
final searchNotesProvider = StreamProvider.family<List<Note>, String>((
  ref,
  keyword,
) {
  if (keyword.trim().isEmpty) {
    return ref.watch(repositoryProvider).watchAllActive();
  }
  return ref.watch(repositoryProvider).watchSearch(keyword.trim());
});

/// 文件夹笔记计数
final folderCountProvider = FutureProvider.family<int, int>((ref, folderId) {
  return ref.watch(repositoryProvider).countNotesInFolder(folderId);
});

/// 统计
///
/// 用**流**而不是一次性 Future：drift 的 `.watch()` 会在 notes 表发生
/// 任何写入（新增 / 删除 / 勾选待办 / 收藏 / 移入回收站）时自动重发，
/// 统计数字因此能实时增减，不需要清后台重进。
///
/// 之前是 FutureProvider，只在首次读取时查询一次；页面被 go_router 缓存在
/// 栈里不销毁，于是数字一直停在打开那一刻的值。
final statsProvider = StreamProvider<Map<String, int>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchAllActive().map((List<Note> list) {
    int notes = 0;
    int todo = 0;
    int todoOpen = 0;
    int favorites = 0;
    for (final Note n in list) {
      if (n.favorite) favorites++;
      if (n.kind == NoteKind.todo.value) {
        todo++;
        if (!n.done) todoOpen++;
      } else if (n.kind == NoteKind.note.value) {
        notes++;
      }
    }
    return <String, int>{
      'notes': notes,
      'favorites': favorites,
      'todo': todo,
      'todoOpen': todoOpen,
    };
  });
});

/// ---- 偏好设置 (主题) ----
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('由 main() 中 override');
});

/// 主题模式：0=跟随系统 1=浅色 2=深色
final themeModeProvider = NotifierProvider<ThemeModeNotifier, int>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<int> {
  static const _key = 'theme_mode';

  @override
  int build() {
    final prefs = ref.watch(sharedPrefsProvider);
    return prefs.getInt(_key) ?? 0;
  }

  Future<void> setMode(int mode) async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setInt(_key, mode);
    state = mode;
  }
}
