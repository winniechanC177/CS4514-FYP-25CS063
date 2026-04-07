part of 'database_helper.dart';

extension LearningDao on DatabaseHelper {
  Future<int> createLearningSession(String title, String content) async {
    return await dbInsert(DatabaseHelper.tblLearningSession,
        {'Title': title, 'Content': content, 'Date': today()});
  }

  Future<int> createLearningItem({
    required int sessionId,
    required String lang,
    required String convLang,
    required String text,
    String? convText,
    String? example,
    String entryType = 'vocab',
  }) async {
    return await dbInsert(DatabaseHelper.tblLearningItem, {
      'LearningSessionId': sessionId,
      'Lang': lang,
      'ConvLang': convLang,
      'Text': text,
      'ConvText': convText,
      'Example': example,
      'EntryType': entryType,
    });
  }

  Future<List<Map<String, dynamic>>> getAllLearningSessions() async {
    final db = await database;
    return await db.rawQuery('''
        SELECT LearningSessionId AS Id, Title, Content, Date
        FROM ${DatabaseHelper.tblLearningSession}
        ORDER BY LearningSessionId DESC
      ''');
  }

  Future<Map<String, dynamic>?> getLearningSession(int sessionId) async {
    final db = await database;
    final result = await db.query(
      DatabaseHelper.tblLearningSession,
      where: 'LearningSessionId = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Map<String, dynamic>>> getLearningSessionItems(
      int sessionId) async {
    final db = await database;
    return await db.query(
      DatabaseHelper.tblLearningItem,
      where: 'LearningSessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'LearningItemId ASC',
    );
  }


  Future<int> deleteLearningItem(int itemId) async {
    final db = await database;
    return await db.delete(DatabaseHelper.tblLearningItem,
        where: 'LearningItemId = ?', whereArgs: [itemId]);
  }
}
