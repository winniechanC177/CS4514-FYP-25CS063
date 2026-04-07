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
	group('System Test: full app data lifecycle', () {
		test('translation + learning + quiz + chatbot all persist and cross-link', () async {
			final db = DatabaseHelper.instance;

			final transSid = await db.createTranslationSession('Morning Phrases', '');
			await db.createTranslationItem(
				sessionId: transSid,
				lang: 'English', convLang: 'Japanese',
				text: 'Good morning', convText: 'おはようございます',
			);
			await db.createTranslationItem(
				sessionId: transSid,
				lang: 'English', convLang: 'Japanese',
				text: 'Good night', convText: 'おやすみなさい',
			);
			final transCount = await db.getSessionLength(transSid, 'translation');
			await db.updateSessionContent(
				transSid, 'translation',
				'English -> Japanese · $transCount translations',
			);

			final learnSid = await db.createLearningSession('Greetings', '');
			await db.createLearningItem(
				sessionId: learnSid,
				lang: 'English', convLang: 'Japanese',
				text: 'Good morning', convText: 'おはようございます',
				example: 'おはようございます！今日もよろしく。',
				entryType: 'vocab',
			);
			await db.createLearningItem(
				sessionId: learnSid,
				lang: 'English', convLang: 'Japanese',
				text: 'Good night', convText: 'おやすみなさい',
				entryType: 'vocab',
			);
			final learnCount = await db.getSessionLength(learnSid, 'learning');
			await db.updateSessionContent(
				learnSid, 'learning',
				'English -> Japanese · $learnCount words',
			);

			final testSid = await db.createTestSession(
				'Greetings Quiz', '2 questions',
				sourceLearningSessionId: learnSid,
			);
			await db.createTestItemWithOptions(
				sessionId: testSid,
				question: 'How do you say "Good morning" in Japanese?',
				options: [
					{'option': 'こんにちは', 'isCorrect': false, 'explanation': 'That is hello'},
					{'option': 'おはようございます', 'isCorrect': true, 'explanation': 'Correct!'},
					{'option': 'おやすみなさい', 'isCorrect': false, 'explanation': 'That is good night'},
					{'option': 'さようなら', 'isCorrect': false, 'explanation': 'That is goodbye'},
				],
			);
			await db.createTestItemWithOptions(
				sessionId: testSid,
				question: 'How do you say "Good night" in Japanese?',
				options: [
					{'option': 'おはようございます', 'isCorrect': false, 'explanation': 'That is good morning'},
					{'option': 'おやすみなさい', 'isCorrect': true, 'explanation': 'Correct!'},
					{'option': 'こんにちは', 'isCorrect': false, 'explanation': 'That is hello'},
					{'option': 'さようなら', 'isCorrect': false, 'explanation': 'That is goodbye'},
				],
			);

			final chatSid = await db.createChatbotSession('', '');
			await db.createChatbotItem(
				sessionId: chatSid,
				text: 'Can you teach me more Japanese greetings?',
				answer: 'Sure! こんにちは is used during the day.',
			);
			await db.updateSessionTitle(
				chatSid, 'chatbot', 'Can you teach me more Japanese greetings?',
			);
			await db.updateSessionContent(chatSid, 'chatbot', '1 message');


			expect(await db.getAllTranslationSessions(), hasLength(1));
			expect(await db.getAllLearningSessions(), hasLength(1));
			expect(await db.getTestSessionByLearningSessionId(learnSid), isNotNull);
			expect(await db.getAllChatbotSessions(), hasLength(1));

			final transHistory = await db.getAllTranslationSessions();
			expect(transHistory.first['Content'], contains('2 translations'));
			final learnHistory = await db.getAllLearningSessions();
			expect(learnHistory.first['Content'], contains('2 words'));

			final linked = await db.getTestSessionByLearningSessionId(learnSid);
			expect(linked, isNotNull);

			final fullTest = await db.getFullTest(testSid);
			expect(fullTest, hasLength(8));
			final correctOpts = fullTest.where((r) => r['IsCorrect'] == 1).toList();
			expect(correctOpts, hasLength(2));

			final vocabItems = await db.getLearningSessionItems(learnSid);
			final entries = vocabItems.map(VocabEntry.fromMap).toList();
			expect(entries.every((e) => e.entryType == EntryType.vocab), isTrue);
			expect(entries.map((e) => e.text).toList(),
					containsAll(['Good morning', 'Good night']));

			final chatHistory = await db.getAllChatbotSessions();
			expect(chatHistory.first['Title'], contains('Japanese greetings'));

			await db.softReset();
			expect(await db.getAllTranslationSessions(), isEmpty);
			expect(await db.getAllLearningSessions(), isEmpty);
			expect(await db.getTestSessionByLearningSessionId(learnSid), isNull);
			expect(await db.getAllChatbotSessions(), isEmpty);
		});
	});
}
