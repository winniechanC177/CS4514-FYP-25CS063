part of 'database_helper.dart';

extension TestDao on DatabaseHelper {
  Future<int> createTestSession(
    String title,
    String content, {
    int? sourceLearningSessionId,
  }) async {
    return await dbInsert(DatabaseHelper.tblTestSession, {
      'Title': title,
      'Content': content,
      'Date': today(),
      if (sourceLearningSessionId != null)
        'SourceLearningSessionId': sourceLearningSessionId,
    });
  }

  Future<int> createTestItemWithOptions({
    required int sessionId,
    required String question,
    required List<Map<String, dynamic>> options,
  }) async {
    final db = await database;
    return await db.transaction<int>((txn) async {
      final itemId = await txn.insert(DatabaseHelper.tblTestItem, {
        'TestSessionID': sessionId,
        'Question': question,
      });
      for (final opt in options) {
        await txn.insert(DatabaseHelper.tblTestOption, {
          'TestItemID': itemId,
          'Option': opt['option'] as String,
          'IsCorrect': (opt['isCorrect'] == true) ? 1 : 0,
          'Explanation': opt['explanation'] as String?,
        });
      }
      return itemId;
    });
  }


  Future<Map<String, dynamic>?> getTestSessionByLearningSessionId(
      int learningSessionId) async {
    final db = await database;
    final result = await db.query(
      DatabaseHelper.tblTestSession,
      where: 'SourceLearningSessionId = ?',
      whereArgs: [learningSessionId],
      orderBy: 'TestSessionID DESC',
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }


  Future<List<Map<String, dynamic>>> getFullTest(int sessionId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT ti.TestItemID, ti.Question,
             o.TestOptionId, o.Option, o.IsCorrect, o.Explanation
      FROM ${DatabaseHelper.tblTestItem} ti
      LEFT JOIN ${DatabaseHelper.tblTestOption} o ON ti.TestItemID = o.TestItemID
      WHERE ti.TestSessionID = ?
      ORDER BY ti.TestItemID ASC, o.TestOptionId ASC
    ''', [sessionId]);
  }

  Future<List<Map<String, dynamic>>> getLearningSessionsWithTestContent() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        ls.LearningSessionId AS Id,
        ls.Title,
        COALESCE(
          (SELECT ts.Content
           FROM   ${DatabaseHelper.tblTestSession} ts
           WHERE  ts.SourceLearningSessionId = ls.LearningSessionId
           ORDER  BY ts.TestSessionID DESC
           LIMIT  1),
          ls.Content
        ) AS Content,
        ls.Date
      FROM ${DatabaseHelper.tblLearningSession} ls
      ORDER BY ls.LearningSessionId DESC
    ''');
  }

  Future<int> deleteTestItem(int itemId) async {
    final db = await database;
    return await db.delete(DatabaseHelper.tblTestItem,
        where: 'TestItemID = ?', whereArgs: [itemId]);
  }

}
