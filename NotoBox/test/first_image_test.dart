import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noto_box/data/database/app_database.dart';
import 'package:noto_box/data/repositories/note_repository.dart';

void main() {
  test('首图映射会随附件插入而更新', () async {
    final db = AppDatabase.test(NativeDatabase.memory());
    final repo = NoteRepository(db);

    final id = await db.noteDao.insertNote(
      NotesCompanion.insert(
        title: const Value('带图'),
        createdAt: 1,
        updatedAt: 1,
      ),
    );

    final emissions = <Map<int, String>>[];
    final sub = repo.watchFirstImage().listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    await repo.addAttachment(id, 'a.jpg');
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(emissions.isNotEmpty, isTrue);
    expect(emissions.last[id], 'a.jpg');

    await sub.cancel();
    await db.close();
  });
}
