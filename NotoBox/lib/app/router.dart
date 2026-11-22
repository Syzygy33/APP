import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/note_kind.dart';
import '../features/shell/app_shell.dart';
import '../features/notes/notes_page.dart';
import '../features/notes/note_editor_page.dart';
import '../features/notes/favorites_page.dart';
import '../features/notes/trash_page.dart';
import '../features/folders/folders_page.dart';
import '../features/folders/folder_notes_page.dart';
import '../features/search/search_page.dart';
import '../features/settings/settings_page.dart';
import '../features/settings/sync_page.dart';

/// 全局路由配置。
/// 主壳有「笔记 / 待办 / 分类 / 收藏」四个分支，
/// 分类管理、回收站、设置等二级页面从右上角菜单 push 进入。
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/notes',
    debugLogDiagnostics: false,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notes',
                builder: (_, _) => const NotesPage(kind: NoteKind.note),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/todo',
                builder: (_, _) => const NotesPage(kind: NoteKind.todo),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/folders', builder: (_, _) => const FoldersPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/favorites',
                builder: (_, _) => const FavoritesPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/note/:id',
        pageBuilder: (_, state) {
          final int? kindValue = int.tryParse(
            state.uri.queryParameters['kind'] ?? '',
          );
          return _zoomPage(
            NoteEditorPage(
              noteId: state.pathParameters['id'] ?? 'new',
              kindInitial: NoteKind.fromValue(kindValue ?? 0),
            ),
            ValueKey('note-${state.pathParameters['id']}'),
          );
        },
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (_, _) =>
            _zoomPage(const SearchPage(), const ValueKey('search')),
      ),
      GoRoute(
        path: '/trash',
        pageBuilder: (_, _) =>
            _zoomPage(const TrashPage(), const ValueKey('trash')),
      ),
      GoRoute(
        path: '/folder/:id',
        pageBuilder: (_, state) => _zoomPage(
          FolderNotesPage(
            folderId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          ),
          ValueKey('folder-${state.pathParameters['id']}'),
        ),
      ),
      GoRoute(
        path: '/sync',
        pageBuilder: (_, _) =>
            _zoomPage(const SyncPage(), const ValueKey('sync')),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (_, _) =>
            _zoomPage(const SettingsPage(), const ValueKey('settings')),
      ),
    ],
  );
});

/// 二级页统一转场：原地放大进入、反向缩回退出（不侧滑）。
/// 进入 0.92 → 1 并淡入；pop 时动画反向，自然回到进入前的页面。
CustomTransitionPage<void> _zoomPage(Widget child, LocalKey? key) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
