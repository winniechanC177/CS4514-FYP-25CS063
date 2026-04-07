part of 'database_helper.dart';

extension TranslationDao on DatabaseHelper {
  Future<int> createTranslationSession(String title, String content) async {
    return await dbInsert(DatabaseHelper.tblTranslationSession, {
      'Title': title,
      'Content': content,
      'Date': today(),
    });
  }

  Future<int> createTranslationItem({
    required int sessionId,
    required String lang,
    required String convLang,
    required String text,
    String? convText,
  }) async {
    return await dbInsert(DatabaseHelper.tblTranslationItem, {
      'TranslationSessionID': sessionId,
      'Lang': lang,
      'ConvLang': convLang,
      'Text': text,
      'ConvText': convText,
    });
  }

  Future<List<Map<String, dynamic>>> getAllTranslationSessions() async {
    final db = await database;
    return await db.rawQuery('''
        SELECT TranslationSessionId AS Id, Title, Content, Date
        FROM ${DatabaseHelper.tblTranslationSession}
        ORDER BY TranslationSessionId DESC
      ''');
  }

  Future<List<Map<String, dynamic>>> getTranslationSessionItems(
      int sessionId) async {
    final db = await database;
    return await db.query(
      DatabaseHelper.tblTranslationItem,
      where: 'TranslationSessionID = ?',
      whereArgs: [sessionId],
      orderBy: 'TranslationItemID ASC',
    );
  }


  Future<int> deleteTranslationItem(int itemId) async {
    final db = await database;
    return await db.delete(DatabaseHelper.tblTranslationItem,
        where: 'TranslationItemID = ?', whereArgs: [itemId]);
  }

  Future<int> updateTranslationItem({
    required int itemId,
    required String lang,
    required String convLang,
    required String text,
    String? convText,
  }) async {
    final db = await database;
    return await db.update(
      DatabaseHelper.tblTranslationItem,
      {
        'Lang': lang,
        'ConvLang': convLang,
        'Text': text,
        'ConvText': convText,
      },
      where: 'TranslationItemID = ?',
      whereArgs: [itemId],
    );
  }
}
