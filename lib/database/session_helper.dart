part of 'database_helper.dart';

extension SessionHelper on DatabaseHelper {
  Future<int> deleteSession(int sessionId, String type) async {
    final db = await database;
    final (sessionTable, sessionCol) = sessionTableAndCol(type);
    return await db.delete(sessionTable,
        where: '$sessionCol = ?', whereArgs: [sessionId]);
  }

  Future<int> deleteAllSessions(String type) async {
    final db = await database;
    final (table, _) = sessionTableAndCol(type);
    return await db.delete(table);
  }

  Future<int> updateSessionTitle(
      int sessionId, String type, String newTitle) async {
    final db = await database;
    final (table, col) = sessionTableAndCol(type);
    return await db.update(table, {'Title': newTitle},
        where: '$col = ?', whereArgs: [sessionId]);
  }

  Future<int> updateSessionContent(
      int sessionId, String type, String newContent) async {
    final db = await database;
    final (table, col) = sessionTableAndCol(type);
    return await db.update(table, {'Content': newContent},
        where: '$col = ?', whereArgs: [sessionId]);
  }

  Future<int> getSessionLength(int sessionId, String type) async {
    final db = await database;
    final (itemTable, sessionCol) = itemTableAndSessionCol(type);
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $itemTable WHERE $sessionCol = ?',
      [sessionId],
    );
    return (r.first['c'] as int?) ?? 0;
  }

}
