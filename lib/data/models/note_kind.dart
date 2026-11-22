/// 内容类型：笔记 / 待办。
/// 数据库以 int 存储（[value]），便于索引与迁移。
///
/// 历史上曾有「便签」类型（value=1），已于 1.0.0+4014 移除；
/// [fromValue] 把旧值 1 统一兜底为笔记，避免旧备份/远端数据成为孤儿。
enum NoteKind {
  note(0, '笔记', '日行一记，灵感有光'),
  todo(2, '待办', '列出要紧事，逐件清空');

  const NoteKind(this.value, this.label, this.subtitle);

  final int value;
  final String label;
  final String subtitle;

  static NoteKind fromValue(int value) => switch (value) {
    2 => NoteKind.todo,
    _ => NoteKind.note,
  };

  bool get isTodo => this == NoteKind.todo;
}
