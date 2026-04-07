import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../types/chatbot_suggestion.dart';

part 'translation_dao.dart';
part 'chatbot_dao.dart';
part 'learning_dao.dart';
part 'test_dao.dart';
part 'session_helper.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  static const String tblTranslationSession = 'TranslationSession';
  static const String tblTranslationItem = 'TranslationItem';

  static const String tblChatbotSession = 'ChatbotSession';
  static const String tblChatbotItem = 'ChatbotItem';

  static const String tblLearningSession = 'LearningSession';
  static const String tblLearningItem = 'LearningItem';

  static const String tblTestSession = 'TestSession';
  static const String tblTestItem = 'TestItem';
  static const String tblTestOption = 'TestOption';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('language_learning_app.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    Directory documentsDir = await getApplicationDocumentsDirectory();
    String dbPath = join(documentsDir.path, fileName);
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tblTranslationSession (
        TranslationSessionID INTEGER PRIMARY KEY AUTOINCREMENT,
        Title   TEXT NOT NULL,
        Content TEXT NOT NULL,
        Date    TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $tblTranslationItem (
        TranslationItemID    INTEGER PRIMARY KEY AUTOINCREMENT,
        TranslationSessionID INTEGER NOT NULL,
        Lang     TEXT NOT NULL,
        ConvLang TEXT NOT NULL,
        Text     TEXT NOT NULL,
        ConvText TEXT,
        FOREIGN KEY (TranslationSessionID)
          REFERENCES $tblTranslationSession(TranslationSessionID) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $tblChatbotSession (
        ChatbotSessionID INTEGER PRIMARY KEY AUTOINCREMENT,
        Title   TEXT NOT NULL,
        Content TEXT NOT NULL,
        Date    TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $tblChatbotItem (
        ChatbotItemID    INTEGER PRIMARY KEY AUTOINCREMENT,
        ChatbotSessionID INTEGER NOT NULL,
        Text       TEXT NOT NULL,
        Answer     TEXT NOT NULL,
        Image      TEXT,
        Suggestion TEXT,
        FOREIGN KEY (ChatbotSessionID)
          REFERENCES $tblChatbotSession(ChatbotSessionID) ON DELETE CASCADE
      )
    ''');


    await db.execute('''
      CREATE TABLE $tblLearningSession (
        LearningSessionId INTEGER PRIMARY KEY AUTOINCREMENT,
        Title   TEXT NOT NULL,
        Content TEXT NOT NULL,
        Date    TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $tblLearningItem (
        LearningItemId    INTEGER PRIMARY KEY AUTOINCREMENT,
        LearningSessionId INTEGER NOT NULL,
        Lang     TEXT NOT NULL,
        ConvLang TEXT NOT NULL,
        Text     TEXT NOT NULL,
        ConvText TEXT,
        Example  TEXT,
        EntryType TEXT NOT NULL DEFAULT 'vocab',
        FOREIGN KEY (LearningSessionId)
          REFERENCES $tblLearningSession(LearningSessionId) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE $tblTestSession (
        TestSessionID INTEGER PRIMARY KEY AUTOINCREMENT,
        SourceLearningSessionId INTEGER,
        Title TEXT NOT NULL,
        Content TEXT NOT NULL,
        Date  TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE $tblTestItem (
        TestItemID    INTEGER PRIMARY KEY AUTOINCREMENT,
        TestSessionID INTEGER NOT NULL,
        Question      TEXT NOT NULL,
        FOREIGN KEY (TestSessionId)
          REFERENCES $tblTestSession(TestSessionId) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE $tblTestOption (
        TestOptionId INTEGER PRIMARY KEY AUTOINCREMENT,
        TestItemId   INTEGER NOT NULL,
        Option       TEXT NOT NULL,
        IsCorrect    INTEGER NOT NULL CHECK (IsCorrect IN (0, 1)),
        Explanation  TEXT,
        FOREIGN KEY (TestItemId)
          REFERENCES $tblTestItem(TestItemId) ON DELETE CASCADE
      )
    ''');
  }


  @visibleForTesting
  static Future<void> setInMemoryDatabaseForTesting() async {
    await _database?.close();
    _database = await openDatabase(
      inMemoryDatabasePath,
      version: 3,
      onCreate: (db, version) => DatabaseHelper.instance._onCreate(db, version),
      onOpen: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  String today() => DateTime.now().toIso8601String().split('T')[0];

  Future<int> dbInsert(String table, Map<String, Object?> values) async {
    final db = await database;
    return await db.insert(table, values);
  }

  (String table, String col) sessionTableAndCol(String type) {
    switch (type) {
      case 'translation':
        return (tblTranslationSession, 'TranslationSessionId');
      case 'chatbot':
        return (tblChatbotSession, 'ChatbotSessionId');
      case 'learning':
        return (tblLearningSession, 'LearningSessionId');
      case 'test':
        return (tblTestSession, 'TestSessionId');
      default:
        throw ArgumentError('Unknown session type: $type');
    }
  }

  (String itemTable, String sessionCol) itemTableAndSessionCol(String type) {
    switch (type) {
      case 'translation':
        return (tblTranslationItem, 'TranslationSessionId');
      case 'chatbot':
        return (tblChatbotItem, 'ChatbotSessionId');
      case 'learning':
        return (tblLearningItem, 'LearningSessionId');
      case 'test':
        return (tblTestItem, 'TestSessionId');
      default:
        throw ArgumentError('Unknown session type: $type');
    }
  }

  Future<void> softReset() async {
    final db = await database;
    await db.delete(tblTestOption);
    await db.delete(tblTestItem);
    await db.delete(tblTestSession);
    await db.delete(tblChatbotItem);
    await db.delete(tblChatbotSession);
    await db.delete(tblLearningItem);
    await db.delete(tblLearningSession);
    await db.delete(tblTranslationItem);
    await db.delete(tblTranslationSession);
  }

  Future<void> hardReset() async {
    final db = await database;
    await db.execute('DROP TABLE IF EXISTS $tblTestOption');
    await db.execute('DROP TABLE IF EXISTS $tblTestItem');
    await db.execute('DROP TABLE IF EXISTS $tblTestSession');
    await db.execute('DROP TABLE IF EXISTS $tblChatbotItem');
    await db.execute('DROP TABLE IF EXISTS $tblChatbotSession');
    await db.execute('DROP TABLE IF EXISTS $tblLearningItem');
    await db.execute('DROP TABLE IF EXISTS $tblLearningSession');
    await db.execute('DROP TABLE IF EXISTS $tblTranslationItem');
    await db.execute('DROP TABLE IF EXISTS $tblTranslationSession');
    await _onCreate(db, 1);
  }
}
