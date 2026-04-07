part of 'database_helper.dart';

extension ChatbotDao on DatabaseHelper {
  Future<int> createChatbotSession(String title, String content) async {
    return await dbInsert(DatabaseHelper.tblChatbotSession,
        {'Title': title, 'Content': content, 'Date': today()});
  }

  Future<int> createChatbotItem({
    required int sessionId,
    required String text,
    required String answer,
    String? image,
    ChatbotSuggestion? suggestion,
  }) async {
    return await dbInsert(DatabaseHelper.tblChatbotItem, {
      'ChatbotSessionID': sessionId,
      'Text': text,
      'Answer': answer,
      'Image': image,
      'Suggestion': suggestion?.name,
    });
  }

  Future<List<Map<String, dynamic>>> getAllChatbotSessions() async {
    final db = await database;
    return await db.rawQuery('''
        SELECT ChatbotSessionId AS Id, Title, Content, Date
        FROM ${DatabaseHelper.tblChatbotSession}
        ORDER BY ChatbotSessionId DESC
      ''');
  }

  Future<List<Map<String, dynamic>>> getChatbotSessionItems(
      int sessionId) async {
    final db = await database;
    return await db.query(
      DatabaseHelper.tblChatbotItem,
      where: 'ChatbotSessionID = ?',
      whereArgs: [sessionId],
      orderBy: 'ChatbotItemID ASC',
    );
  }


  Future<int> deleteChatbotItem(int itemId) async {
    final db = await database;
    return await db.delete(DatabaseHelper.tblChatbotItem,
        where: 'ChatbotItemID = ?', whereArgs: [itemId]);
  }

  Future<int> updateChatbotItem({
    required int itemId,
    required String text,
    required String answer,
    String? image,
    ChatbotSuggestion? suggestion,
  }) async {
    final db = await database;
    return await db.update(
      DatabaseHelper.tblChatbotItem,
      {
        'Text': text,
        'Answer': answer,
        'Image': image,
        'Suggestion': suggestion?.name,
      },
      where: 'ChatbotItemID = ?',
      whereArgs: [itemId],
    );
  }
}
