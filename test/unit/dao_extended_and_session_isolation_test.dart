import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:SLMTranslator/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.setInMemoryDatabaseForTesting();
  });
	group('Unit Test 4b: SQL — Extended coverage', () {

		group('TranslationDAO extended', () {
			test('createTranslationItem without convText stores null', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createTranslationSession('S', 'D');
				await db.createTranslationItem(
					sessionId: sid, lang: 'en', convLang: 'ja', text: 'hello',
				);
				final items = await db.getTranslationSessionItems(sid);
				expect(items.first['ConvText'], isNull);
			});


			test('items from different sessions are isolated', () async {
				final db = DatabaseHelper.instance;
				final sid1 = await db.createTranslationSession('S1', 'D');
				final sid2 = await db.createTranslationSession('S2', 'D');
				await db.createTranslationItem(
					sessionId: sid1, lang: 'en', convLang: 'ja', text: 'session-one-word',
				);
				await db.createTranslationItem(
					sessionId: sid2, lang: 'en', convLang: 'ja', text: 'session-two-word',
				);
				final items1 = await db.getTranslationSessionItems(sid1);
				final items2 = await db.getTranslationSessionItems(sid2);
				expect(items1, hasLength(1));
				expect(items2, hasLength(1));
				expect(items1.first['Text'], equals('session-one-word'));
				expect(items2.first['Text'], equals('session-two-word'));
			});
		});

		group('ChatbotDAO extended', () {
			test('createChatbotItem stores image path when provided', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createChatbotSession('C', 'D');
				await db.createChatbotItem(
					sessionId: sid,
					text: 'What is in this photo?',
					answer: 'I see a cat.',
					image: '/path/to/image.jpg',
				);
				final items = await db.getChatbotSessionItems(sid);
				expect(items.first['Image'], equals('/path/to/image.jpg'));
			});

			test('createChatbotItem stores null image when not provided', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createChatbotSession('C', 'D');
				await db.createChatbotItem(sessionId: sid, text: 'Q', answer: 'A');
				final items = await db.getChatbotSessionItems(sid);
				expect(items.first['Image'], isNull);
			});


			test('deleteSession(chatbot) cascades to chatbot items', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createChatbotSession('C', 'D');
				await db.createChatbotItem(sessionId: sid, text: 'Q1', answer: 'A1');
				await db.createChatbotItem(sessionId: sid, text: 'Q2', answer: 'A2');
				await db.deleteSession(sid, 'chatbot');
				expect(await db.getAllChatbotSessions(), isEmpty);
				expect(await db.getChatbotSessionItems(sid), isEmpty);
			});


			test('chatbot items from different sessions are isolated', () async {
				final db = DatabaseHelper.instance;
				final sid1 = await db.createChatbotSession('S1', 'D');
				final sid2 = await db.createChatbotSession('S2', 'D');
				await db.createChatbotItem(sessionId: sid1, text: 'Q-A', answer: 'A');
				await db.createChatbotItem(sessionId: sid2, text: 'Q-B', answer: 'B');
				expect(await db.getChatbotSessionItems(sid1), hasLength(1));
				expect(await db.getChatbotSessionItems(sid2), hasLength(1));
				expect(
					(await db.getChatbotSessionItems(sid1)).first['Text'],
					equals('Q-A'),
				);
			});
		});

		group('LearningDAO extended', () {

			test('learning items from different sessions are isolated', () async {
				final db = DatabaseHelper.instance;
				final sid1 = await db.createLearningSession('S1', 'D');
				final sid2 = await db.createLearningSession('S2', 'D');
				await db.createLearningItem(
					sessionId: sid1, lang: 'en', convLang: 'ja', text: 'cat',
				);
				await db.createLearningItem(
					sessionId: sid2, lang: 'en', convLang: 'zh', text: '猫',
				);
				final items1 = await db.getLearningSessionItems(sid1);
				final items2 = await db.getLearningSessionItems(sid2);
				expect(items1, hasLength(1));
				expect(items2, hasLength(1));
				expect(items1.first['Text'], equals('cat'));
				expect(items2.first['Text'], equals('猫'));
			});
		});

		group('TestDAO extended', () {
			test('deleteSession(test) cascades to test items and options', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createTestSession('Q', 'D');
				await db.createTestItemWithOptions(
					sessionId: sid,
					question: 'Q?',
					options: [
						{'option': 'A', 'isCorrect': true, 'explanation': null},
					],
				);
				await db.deleteSession(sid, 'test');
				expect(await db.getFullTest(sid), isEmpty);
			});

			test('getTestSessionByLearningSessionId returns most recent when multiple tests linked', () async {
				final db = DatabaseHelper.instance;
				final learnSid = await db.createLearningSession('Vocab', 'D');
				final testSid1 = await db.createTestSession(
					'Quiz v1', 'D', sourceLearningSessionId: learnSid,
				);
				final testSid2 = await db.createTestSession(
					'Quiz v2', 'D', sourceLearningSessionId: learnSid,
				);
				final found = await db.getTestSessionByLearningSessionId(learnSid);
				expect(found, isNotNull);
				expect(found!['TestSessionID'], equals(testSid2));
				expect(testSid2, greaterThan(testSid1));
			});

			test('multiple independent test sessions do not interfere', () async {
				final db = DatabaseHelper.instance;
				final sid1 = await db.createTestSession('Quiz 1', 'D');
				final sid2 = await db.createTestSession('Quiz 2', 'D');
				await db.createTestItemWithOptions(
					sessionId: sid1,
					question: 'Q for quiz 1?',
					options: [
						{'option': 'A1', 'isCorrect': true, 'explanation': null},
					],
				);
				await db.createTestItemWithOptions(
					sessionId: sid2,
					question: 'Q for quiz 2?',
					options: [
						{'option': 'A2', 'isCorrect': true, 'explanation': null},
					],
				);
				final full1 = await db.getFullTest(sid1);
				final full2 = await db.getFullTest(sid2);
				expect(full1, hasLength(1));
				expect(full2, hasLength(1));
				expect(full1.first['Question'], equals('Q for quiz 1?'));
			});
		});

		group('SessionHelper extended', () {

			test('getSessionLength counts translation items correctly', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createTranslationSession('S', 'D');
				await db.createTranslationItem(
					sessionId: sid, lang: 'en', convLang: 'ja', text: 'w1',
				);
				await db.createTranslationItem(
					sessionId: sid, lang: 'en', convLang: 'ja', text: 'w2',
				);
				expect(await db.getSessionLength(sid, 'translation'), equals(2));
			});

			test('getSessionLength counts chatbot items correctly', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createChatbotSession('S', 'D');
				await db.createChatbotItem(sessionId: sid, text: 'Q1', answer: 'A1');
				await db.createChatbotItem(sessionId: sid, text: 'Q2', answer: 'A2');
				await db.createChatbotItem(sessionId: sid, text: 'Q3', answer: 'A3');
				expect(await db.getSessionLength(sid, 'chatbot'), equals(3));
			});

			test('getSessionLength counts test items correctly', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createTestSession('Q', 'D');
				await db.createTestItemWithOptions(
					sessionId: sid,
					question: 'Q1?',
					options: [{'option': 'A', 'isCorrect': true, 'explanation': null}],
				);
				await db.createTestItemWithOptions(
					sessionId: sid,
					question: 'Q2?',
					options: [{'option': 'B', 'isCorrect': true, 'explanation': null}],
				);
				expect(await db.getSessionLength(sid, 'test'), equals(2));
			});

			test('deleteAllSessions(learning) removes all learning sessions', () async {
				final db = DatabaseHelper.instance;
				await db.createLearningSession('L1', 'D');
				await db.createLearningSession('L2', 'D');
				await db.deleteAllSessions('learning');
				expect(await db.getAllLearningSessions(), isEmpty);
			});

			test('deleteAllSessions(chatbot) removes all chatbot sessions', () async {
				final db = DatabaseHelper.instance;
				await db.createChatbotSession('C1', 'D');
				await db.createChatbotSession('C2', 'D');
				await db.deleteAllSessions('chatbot');
				expect(await db.getAllChatbotSessions(), isEmpty);
			});

			test('deleteAllSessions(test) removes all test sessions', () async {
				final db = DatabaseHelper.instance;
				final learnSid = await db.createLearningSession('Vocab', 'D');
				await db.createTestSession('T1', 'D', sourceLearningSessionId: learnSid);
				await db.createTestSession('T2', 'D', sourceLearningSessionId: learnSid);
				await db.deleteAllSessions('test');
				expect(await db.getTestSessionByLearningSessionId(learnSid), isNull);
			});

			test('deleteAllSessions of one type does not affect other types', () async {
				final db = DatabaseHelper.instance;
				await db.createTranslationSession('Trans', 'D');
				await db.createChatbotSession('Chat', 'D');
				await db.deleteAllSessions('chatbot');
				expect(await db.getAllTranslationSessions(), hasLength(1));
				expect(await db.getAllChatbotSessions(), isEmpty);
			});

			test('softReset also clears test sessions and options', () async {
				final db = DatabaseHelper.instance;
				final learnSid = await db.createLearningSession('L', 'D');
				final sid = await db.createTestSession('Q', 'D', sourceLearningSessionId: learnSid);
				await db.createTestItemWithOptions(
					sessionId: sid,
					question: 'Q?',
					options: [{'option': 'A', 'isCorrect': true, 'explanation': null}],
				);
				await db.softReset();
				expect(await db.getTestSessionByLearningSessionId(learnSid), isNull);
				expect(await db.getFullTest(sid), isEmpty);
			});
		});
	});

	group('Integration Test 6: session isolation, multi-session, content format', () {

		test('translation session items do not bleed into other translation sessions', () async {
			final db = DatabaseHelper.instance;
			final sid1 = await db.createTranslationSession('Trip vocab', '');
			final sid2 = await db.createTranslationSession('Food vocab', '');
			await db.createTranslationItem(
				sessionId: sid1, lang: 'en', convLang: 'ja',
				text: 'airport', convText: '空港',
			);
			await db.createTranslationItem(
				sessionId: sid2, lang: 'en', convLang: 'ja',
				text: 'sushi', convText: '寿司',
			);
			final items1 = await db.getTranslationSessionItems(sid1);
			final items2 = await db.getTranslationSessionItems(sid2);
			expect(items1.every((i) => i['Text'] == 'airport'), isTrue);
			expect(items2.every((i) => i['Text'] == 'sushi'), isTrue);
		});

		test('chatbot sessions are isolated per session ID', () async {
			final db = DatabaseHelper.instance;
			final sid1 = await db.createChatbotSession('Session A', '');
			final sid2 = await db.createChatbotSession('Session B', '');
			for (var i = 1; i <= 3; i++) {
				await db.createChatbotItem(sessionId: sid1, text: 'A-Q$i', answer: 'A-Ans$i');
			}
			for (var i = 1; i <= 2; i++) {
				await db.createChatbotItem(sessionId: sid2, text: 'B-Q$i', answer: 'B-Ans$i');
			}
			expect(await db.getSessionLength(sid1, 'chatbot'), equals(3));
			expect(await db.getSessionLength(sid2, 'chatbot'), equals(2));
			final items1 = await db.getChatbotSessionItems(sid1);
			final items2 = await db.getChatbotSessionItems(sid2);
			expect(items1.last['Text'], equals('A-Q3'));
			expect(items2.last['Text'], equals('B-Q2'));
		});

		test('deleting one session does not affect sibling sessions', () async {
			final db = DatabaseHelper.instance;
			final sid1 = await db.createTranslationSession('Keep A', '');
			final sid2 = await db.createTranslationSession('Delete B', '');
			final sid3 = await db.createTranslationSession('Keep C', '');
			await db.createTranslationItem(
				sessionId: sid1, lang: 'en', convLang: 'ja', text: 'word-A',
			);
			await db.createTranslationItem(
				sessionId: sid3, lang: 'en', convLang: 'ja', text: 'word-C',
			);
			await db.deleteSession(sid2, 'translation');
			final history = await db.getAllTranslationSessions();
			expect(history, hasLength(2));
			final titles = history.map((s) => s['Title'] as String).toSet();
			expect(titles, containsAll(['Keep A', 'Keep C']));
			expect(titles, isNot(contains('Delete B')));
			expect(await db.getTranslationSessionItems(sid1), hasLength(1));
			expect(await db.getTranslationSessionItems(sid3), hasLength(1));
		});

		test('content string with · splits correctly into two display lines', () {
			const content = 'English -> Japanese · 3 translations';
			final parts = content.split('·').map((s) => s.trim()).toList();
			expect(parts, hasLength(2));
			expect(parts[0], equals('English -> Japanese'));
			expect(parts[1], equals('3 translations'));
		});

		test('content string without · shows as single line', () {
			const content = 'No separator here';
			final parts = content.split('·').map((s) => s.trim()).toList();
			expect(parts, hasLength(1));
			expect(parts[0], equals('No separator here'));
		});

		test('content string with multiple · is split at first and rest rejoined', () {
			const content = 'en · ja · 5 words';
			final parts = content.split('·').map((s) => s.trim()).toList();
			final line1 = parts[0];
			final line2 = parts.length > 1 ? parts.sublist(1).join(' · ') : '';
			expect(line1, equals('en'));
			expect(line2, equals('ja · 5 words'));
		});

		test('session content string is persisted and retrieved intact', () async {
			final db = DatabaseHelper.instance;
			const content = 'English -> Japanese · 5 translations';
			final _ = await db.createTranslationSession('My Trip', content);
			final sessions = await db.getAllTranslationSessions();
			expect(sessions.first['Content'], equals(content));
		});

		test('exactly one option per question is marked correct', () async {
			final db = DatabaseHelper.instance;
			final sid = await db.createTestSession('Vocab Quiz', 'D');
			await db.createTestItemWithOptions(
				sessionId: sid,
				question: 'What is 猫?',
				options: [
					{'option': 'dog', 'isCorrect': false, 'explanation': 'Wrong'},
					{'option': 'cat', 'isCorrect': true, 'explanation': 'Correct'},
					{'option': 'bird', 'isCorrect': false, 'explanation': 'Wrong'},
					{'option': 'fish', 'isCorrect': false, 'explanation': 'Wrong'},
				],
			);
			final full = await db.getFullTest(sid);
			final correctOpts = full.where((r) => r['IsCorrect'] == 1).toList();
			expect(correctOpts, hasLength(1));
			expect(correctOpts.first['Option'], equals('cat'));
		});

		test('all incorrect options are retrievable and properly marked', () async {
			final db = DatabaseHelper.instance;
			final sid = await db.createTestSession('Quiz', 'D');
			await db.createTestItemWithOptions(
				sessionId: sid,
				question: 'What is 犬?',
				options: [
					{'option': 'cat', 'isCorrect': false, 'explanation': 'That is cat'},
					{'option': 'dog', 'isCorrect': true, 'explanation': 'Correct!'},
					{'option': 'bird', 'isCorrect': false, 'explanation': 'That is bird'},
				],
			);
			final full = await db.getFullTest(sid);
			final wrong = full.where((r) => r['IsCorrect'] == 0).toList();
			expect(wrong, hasLength(2));
			final explanations = wrong.map((r) => r['Explanation'] as String?).toList();
			expect(explanations, containsAll(['That is cat', 'That is bird']));
		});


		test('learning session description updates reflect in history content', () async {
			final db = DatabaseHelper.instance;
			final sid = await db.createLearningSession('Daily Vocab', '');
			for (var i = 1; i <= 5; i++) {
				await db.createLearningItem(
					sessionId: sid, lang: 'en', convLang: 'ja', text: 'word$i',
				);
			}
			final count = await db.getSessionLength(sid, 'learning');
			await db.updateSessionContent(
				sid, 'learning', 'English -> Japanese · $count words',
			);
			final sessions = await db.getAllLearningSessions();
			expect(sessions.first['Content'], equals('English -> Japanese · 5 words'));
			final parts = (sessions.first['Content'] as String)
					.split('·')
					.map((s) => s.trim())
					.toList();
			expect(parts[0], equals('English -> Japanese'));
			expect(parts[1], equals('5 words'));
		});

		test('chatbot session history shows correct turn count after updates', () async {
			final db = DatabaseHelper.instance;
			final sid = await db.createChatbotSession('', '');
			final questions = ['Q1', 'Q2', 'Q3'];
			for (final q in questions) {
				await db.createChatbotItem(sessionId: sid, text: q, answer: 'A');
			}
			final count = await db.getSessionLength(sid, 'chatbot');
			await db.updateSessionTitle(sid, 'chatbot', questions.first);
			await db.updateSessionContent(sid, 'chatbot', '$count messages');
			final history = await db.getAllChatbotSessions();
			expect(history.first['Title'], equals('Q1'));
			expect(history.first['Content'], equals('3 messages'));
		});

		test('translation session title uses ellipsis convention for long text', () async {
			final db = DatabaseHelper.instance;
			final sid = await db.createTranslationSession('', '');
			final longText = 'A' * 90; 
			await db.createTranslationItem(
				sessionId: sid, lang: 'en', convLang: 'ja', text: longText,
			);
			final truncated = longText.length > 80
					? '${longText.substring(0, 77)}...'
					: longText;
			await db.updateSessionTitle(sid, 'translation', truncated);
			final sessions = await db.getAllTranslationSessions();
			expect(sessions.first['Title']!.length, lessThanOrEqualTo(80));
			expect(sessions.first['Title'], endsWith('...'));
		});
	});


}
