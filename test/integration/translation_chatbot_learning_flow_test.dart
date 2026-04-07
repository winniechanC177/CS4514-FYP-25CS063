import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:SLMTranslator/database/database_helper.dart';
import 'package:SLMTranslator/learning/vocab_entry.dart';


void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.setInMemoryDatabaseForTesting();
  });
	group('Integration Test 1: SQL + input component (translation block data flow)', () {
		test('user input is persisted to a translation session', () async {
			final db = DatabaseHelper.instance;
			final sid = await db.createTranslationSession('', '');
			await db.createTranslationItem(
				sessionId: sid,
				lang: 'English',
				convLang: 'Japanese',
				text: 'Good morning',
				convText: 'おはようございます',
			);
			final items = await db.getTranslationSessionItems(sid);
			expect(items, hasLength(1));
			expect(items.first['Text'], equals('Good morning'));
			expect(items.first['ConvText'], equals('おはようございます'));
		});

		test('session metadata is updated after first reply', () async {
			final db = DatabaseHelper.instance;
			final sid = await db.createTranslationSession('', '');
			await db.createTranslationItem(
				sessionId: sid,
				lang: 'English', convLang: 'Japanese',
				text: 'Good morning', convText: 'おはようございます',
			);
			final items = await db.getTranslationSessionItems(sid);
			final title = items.map((i) => i['Text']).join(' | ');
			await db.updateSessionTitle(sid, 'translation', title);
			await db.updateSessionContent(
				sid, 'translation',
				'English -> Japanese · ${items.length} translation',
			);
			final sessions = await db.getAllTranslationSessions();
			expect(sessions.first['Title'], contains('Good morning'));
			expect(sessions.first['Content'], contains('English -> Japanese'));
		});

		test('multiple input items accumulate in one session', () async {
			final db = DatabaseHelper.instance;
			final sid = await db.createTranslationSession('Multi', '');
			for (final word in ['cat', 'dog', 'bird']) {
				await db.createTranslationItem(
					sessionId: sid, lang: 'en', convLang: 'ja', text: word,
				);
			}
			expect(await db.getSessionLength(sid, 'translation'), equals(3));
		});

	});

	group('Integration Test 2: SQL + previous history component', () {
		test('sessions are returned newest-first for the drawer', () async {
			final db = DatabaseHelper.instance;
			await db.createTranslationSession('Oldest', 'D');
			await db.createTranslationSession('Middle', 'D');
			await db.createTranslationSession('Newest', 'D');
			final history = await db.getAllTranslationSessions();
			expect(history.first['Title'], equals('Newest'));
			expect(history.last['Title'], equals('Oldest'));
		});

		test('each history row has the fields HistoryTile requires', () async {
			final db = DatabaseHelper.instance;
			await db.createTranslationSession('My Session', 'en → ja · 2 translations');
			final row = (await db.getAllTranslationSessions()).first;
			expect(row.containsKey('Id'), isTrue);
			expect(row.containsKey('Title'), isTrue);
			expect(row.containsKey('Content'), isTrue);
			expect(row['Id'], isA<int>());
			expect(row['Title'], isA<String>());
		});

		test('deleting a session removes it from the history list', () async {
			final db = DatabaseHelper.instance;
			await db.createTranslationSession('Keep me', 'D');
			final sid = await db.createTranslationSession('Delete me', 'D');
			await db.deleteSession(sid, 'translation');
			final history = await db.getAllTranslationSessions();
			expect(history, hasLength(1));
			expect(history.first['Title'], equals('Keep me'));
		});

		test('clearing all sessions empties the history list', () async {
			final db = DatabaseHelper.instance;
			await db.createChatbotSession('Chat A', 'D');
			await db.createChatbotSession('Chat B', 'D');
			await db.deleteAllSessions('chatbot');
			expect(await db.getAllChatbotSessions(), isEmpty);
		});

		test('each session type has an independent history list', () async {
			final db = DatabaseHelper.instance;
			await db.createTranslationSession('Trans', 'D');
			await db.createChatbotSession('Chat', 'D');
			await db.createLearningSession('Learn', 'D');
			expect(await db.getAllTranslationSessions(), hasLength(1));
			expect(await db.getAllChatbotSessions(), hasLength(1));
			expect(await db.getAllLearningSessions(), hasLength(1));
		});
	});

	group('Integration Test 3: SQL + input + history + translation component', () {
		test('full translation session lifecycle', () async {
			final db = DatabaseHelper.instance;
			final sid = await db.createTranslationSession('', '');
			await db.createTranslationItem(
				sessionId: sid,
				lang: 'English', convLang: 'Chinese',
				text: 'Where is the library?', convText: '圖書館在哪裡？',
			);
			await db.createTranslationItem(
				sessionId: sid,
				lang: 'English', convLang: 'Chinese',
				text: 'How much does it cost?', convText: '多少錢？',
			);
			final items = await db.getTranslationSessionItems(sid);
			final title =
					items.map((i) => i['Text'] as String).take(2).join(' | ');
			await db.updateSessionTitle(sid, 'translation', title);
			await db.updateSessionContent(
				sid, 'translation',
				'English -> Chinese · ${items.length} translations',
			);
			final history = await db.getAllTranslationSessions();
			expect(history.first['Title'], contains('Where is the library?'));
			expect(history.first['Content'], contains('2 translations'));
		});

		test('reopening a session from history loads all its items', () async {
			final db = DatabaseHelper.instance;
			final sid = await db.createTranslationSession('Animals', 'D');
			await db.createTranslationItem(
				sessionId: sid, lang: 'en', convLang: 'ja', text: 'cat', convText: '猫',
			);
			await db.createTranslationItem(
				sessionId: sid, lang: 'en', convLang: 'ja', text: 'dog', convText: '犬',
			);
			final loaded = await db.getTranslationSessionItems(sid);
			expect(loaded, hasLength(2));
		});

		test('item-level delete removes entry without affecting sibling items', () async {
			final db = DatabaseHelper.instance;
			final sid = await db.createTranslationSession('S', 'D');
			final iid = await db.createTranslationItem(
				sessionId: sid, lang: 'en', convLang: 'ja', text: 'first',
			);
			await db.createTranslationItem(
				sessionId: sid, lang: 'en', convLang: 'ja', text: 'second',
			);
			await db.deleteTranslationItem(iid);
			final remaining = await db.getTranslationSessionItems(sid);
			expect(remaining, hasLength(1));
			expect(remaining.first['Text'], equals('second'));
		});
	});

	group('Integration Test 4: SQL + input + history + word card component', () {
		test('vocab word card is saved and fully retrievable', () async {
			final db = DatabaseHelper.instance;
			final sid = await db.createLearningSession('Daily Vocab', '');
			await db.createLearningItem(
				sessionId: sid,
				lang: 'English', convLang: 'Japanese',
				text: 'cherry blossom', convText: '桜',
				example: '桜が咲いています。',
				entryType: 'vocab',
			);
			final items = await db.getLearningSessionItems(sid);
			final entry = VocabEntry.fromMap(items.first);
			expect(entry.text, equals('cherry blossom'));
			expect(entry.convText, equals('桜'));
			expect(entry.example, equals('桜が咲いています。'));
			expect(entry.entryType, equals(EntryType.vocab));
		});

		test('grammar card entryType is stored and round-trips through VocabEntry', () async {
			final db = DatabaseHelper.instance;
			final sid = await db.createLearningSession('Grammar', 'D');
			await db.createLearningItem(
				sessionId: sid,
				lang: 'English', convLang: 'Japanese',
				text: 'て-form', convText: '連用形',
				entryType: 'grammar',
			);
			final items = await db.getLearningSessionItems(sid);
			expect(VocabEntry.fromMap(items.first).entryType, equals(EntryType.grammar));
		});

		test('learning session appears in history and items load on reopen', () async {
			final db = DatabaseHelper.instance;
			final sid = await db.createLearningSession('Fruits', 'en → zh');
			for (final pair in [
				('mango', '芒果'),
				('grape', '葡萄'),
				('peach', '桃'),
			]) {
				await db.createLearningItem(
					sessionId: sid, lang: 'en', convLang: 'zh',
					text: pair.$1, convText: pair.$2,
				);
			}
			final count = await db.getSessionLength(sid, 'learning');
			await db.updateSessionContent(
				sid, 'learning', 'English -> Chinese · $count words',
			);
			final history = await db.getAllLearningSessions();
			expect(history.any((s) => s['Title'] == 'Fruits'), isTrue);
			expect(history.first['Content'], contains('3 words'));
			final loaded = await db.getLearningSessionItems(sid);
			expect(loaded, hasLength(3));
		});

		test('quiz is generated from a learning session and linked correctly', () async {
			final db = DatabaseHelper.instance;
			final learnSid = await db.createLearningSession('Animals', 'D');
			await db.createLearningItem(
				sessionId: learnSid, lang: 'en', convLang: 'ja', text: 'cat', convText: '猫',
			);
			final testSid = await db.createTestSession(
				'Animals Quiz', '1 question', sourceLearningSessionId: learnSid,
			);
			await db.createTestItemWithOptions(
				sessionId: testSid,
				question: 'What is the Japanese word for "cat"?',
				options: [
					{'option': '犬', 'isCorrect': false, 'explanation': 'That is dog'},
					{'option': '猫', 'isCorrect': true, 'explanation': 'Correct!'},
					{'option': '鳥', 'isCorrect': false, 'explanation': 'That is bird'},
				],
			);
			final linked = await db.getTestSessionByLearningSessionId(learnSid);
			expect(linked, isNotNull);
			final fullTest = await db.getFullTest(testSid);
			expect(fullTest.map((r) => r['TestItemID']).toSet(), hasLength(1));
			expect(fullTest.where((r) => r['IsCorrect'] == 1), hasLength(1));
		});
	});

	group('Integration Test 5: SQL + input + history + chatbot component', () {
		test('single Q&A pair is saved and retrieved', () async {
			final db = DatabaseHelper.instance;
			final sid = await db.createChatbotSession('Help', '');
			await db.createChatbotItem(
				sessionId: sid,
				text: 'What does 桜 mean?',
				answer: '桜 means cherry blossom in Japanese.',
			);
			final items = await db.getChatbotSessionItems(sid);
			expect(items, hasLength(1));
			expect(items.first['Text'], equals('What does 桜 mean?'));
			expect(items.first['Answer'], contains('cherry blossom'));
		});

		test('multi-turn conversation preserves message order', () async {
			final db = DatabaseHelper.instance;
			final sid = await db.createChatbotSession('Multi-turn', '');
			await db.createChatbotItem(sessionId: sid, text: 'Q1', answer: 'A1');
			await db.createChatbotItem(sessionId: sid, text: 'Q2', answer: 'A2');
			await db.createChatbotItem(sessionId: sid, text: 'Q3', answer: 'A3');
			final items = await db.getChatbotSessionItems(sid);
			expect(items, hasLength(3));
			expect(items[0]['Text'], equals('Q1'));
			expect(items[2]['Text'], equals('Q3'));
		});


		test('session title and content are updated after first reply', () async {
			final db = DatabaseHelper.instance;
			final sid = await db.createChatbotSession('', '');
			await db.createChatbotItem(
				sessionId: sid,
				text: 'Tell me about Japan.',
				answer: 'Japan is an island nation.',
			);
			await db.updateSessionTitle(sid, 'chatbot', 'Tell me about Japan.');
			await db.updateSessionContent(sid, 'chatbot', '1 message');
			final history = await db.getAllChatbotSessions();
			expect(history.first['Title'], equals('Tell me about Japan.'));
			expect(history.first['Content'], equals('1 message'));
		});

		test('deleting a chatbot session cascades to all its messages', () async {
			final db = DatabaseHelper.instance;
			final sid = await db.createChatbotSession('Del', 'D');
			await db.createChatbotItem(sessionId: sid, text: 'Q1', answer: 'A1');
			await db.createChatbotItem(sessionId: sid, text: 'Q2', answer: 'A2');
			await db.deleteSession(sid, 'chatbot');
			expect(await db.getAllChatbotSessions(), isEmpty);
			expect(await db.getChatbotSessionItems(sid), isEmpty);
		});
	});


}
