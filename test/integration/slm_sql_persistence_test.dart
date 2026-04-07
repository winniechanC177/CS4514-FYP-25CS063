import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:SLMTranslator/database/database_helper.dart';
import 'package:SLMTranslator/types/language_choose.dart';
import 'package:SLMTranslator/learning/vocab_entry.dart';
import '../stub/stub_gemma_model.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.setInMemoryDatabaseForTesting();
  });
	group('Integration Test 7: FakeGemmaModel + SQL (SLM output persisted to DB)', () {
		late StubGemmaModel fake;

		setUp(() => fake = StubGemmaModel());

		test('fake translate → save to translation DB → appears in history', () async {
			final db = DatabaseHelper.instance;
			const inputText = 'Good morning';
			final translation = await fake.translateResponse(
					LanguageChoose.english, LanguageChoose.japanese, inputText);
			expect(translation, isNotEmpty);
			final sid = await db.createTranslationSession('Morning', '');
			await db.createTranslationItem(
				sessionId: sid,
				lang: 'English', convLang: 'Japanese',
				text: inputText, convText: translation,
			);
			await db.updateSessionContent(sid, 'translation',
					'English -> Japanese · 1 translation');
			final history = await db.getAllTranslationSessions();
			expect(history, hasLength(1));
			final items = await db.getTranslationSessionItems(sid);
			expect(items.first['Text'], equals(inputText));
			expect(items.first['ConvText'], equals(translation));
		});

		test('fake translate records the language pair', () async {
			await fake.translateResponse(null, LanguageChoose.french, 'Hello');
			await fake.translateResponse(null, LanguageChoose.chineseSimplified, 'Thank you');
			expect(fake.receivedTranslations[0].lang, equals('french'));
			expect(fake.receivedTranslations[1].lang, equals('chineseSimplified'));
		});

		test('overrideTranslateResponse flows through to DB correctly', () async {
			final db = DatabaseHelper.instance;
			fake.overrideTranslateResponse = 'こんにちは';
			final translation = await fake.translateResponse(
					null, LanguageChoose.japanese, 'Hello');
			final sid = await db.createTranslationSession('S', '');
			await db.createTranslationItem(
				sessionId: sid, lang: 'en', convLang: 'ja',
				text: 'Hello', convText: translation,
			);
			final items = await db.getTranslationSessionItems(sid);
			expect(items.first['ConvText'], equals('こんにちは'));
		});

		test('fake chatbot Q&A → save to chatbot DB → history and last message correct', () async {
			final db = DatabaseHelper.instance;
			final sid = await db.createChatbotSession('', '');
			const questions = ['What is sushi?', 'Tell me about Japan.', 'How do I say hello?'];
			for (final q in questions) {
				final answer = await fake.chatbotResponse(q, null);
				await db.createChatbotItem(sessionId: sid, text: q, answer: answer);
			}
			await db.updateSessionTitle(sid, 'chatbot', questions.first);
			await db.updateSessionContent(sid, 'chatbot', '${questions.length} messages');
			final items = await db.getChatbotSessionItems(sid);
			expect(items, hasLength(3));
			expect(items[0]['Text'], equals('What is sushi?'));
			expect(items.last['Text'], equals('How do I say hello?'));
			final history = await db.getAllChatbotSessions();
			expect(history.first['Title'], equals('What is sushi?'));
			expect(history.first['Content'], equals('3 messages'));
		});

		test('fake chatbot with image path stored in DB', () async {
			final db = DatabaseHelper.instance;
			final sid = await db.createChatbotSession('Image chat', '');
			final answer = await fake.chatbotResponse('What is in the image?', null);
			await db.createChatbotItem(
				sessionId: sid,
				text: 'What is in the image?',
				answer: answer,
				image: '/path/to/photo.jpg',
			);
			final items = await db.getChatbotSessionItems(sid);
			expect(items.first['Image'], equals('/path/to/photo.jpg'));
		});

		test('resetChat clears history and counter increments', () async {
			await fake.chatbotResponse('Q1', null);
			await fake.chatbotResponse('Q2', null);
			await fake.resetChat();
			expect(fake.chatHistory, isEmpty);
			expect(fake.resetChatCallCount, equals(1));
			await fake.chatbotResponse('Q3', null);
			expect(fake.chatHistory, hasLength(2));
		});

		test('fake vocab response → save to learning DB → VocabEntry round-trip', () async {
			final db = DatabaseHelper.instance;
			final entries = await fake.learningVocabResponse(
					'Japanese animals', LanguageChoose.english, LanguageChoose.japanese);
			final sid = await db.createLearningSession('Animals', '');
			for (final e in entries) {
				await db.createLearningItem(
					sessionId: sid,
					lang: e.lang.isEmpty ? 'English' : e.lang,
					convLang: e.convLang.isEmpty ? 'Japanese' : e.convLang,
					text: e.text,
					convText: e.convText,
					example: e.example,
					entryType: e.entryType.name,
				);
			}
			final count = await db.getSessionLength(sid, 'learning');
			await db.updateSessionContent(
					sid, 'learning', 'English -> Japanese · $count words');
			final dbItems = await db.getLearningSessionItems(sid);
			final restored = dbItems.map(VocabEntry.fromMap).toList();
			expect(restored, hasLength(entries.length));
			expect(restored.any((e) => e.entryType == EntryType.vocab), isTrue);
			expect(restored.any((e) => e.entryType == EntryType.grammar), isTrue);
			final history = await db.getAllLearningSessions();
			expect(history.first['Content'], contains('words'));
		});

		test('fake quiz questions → save to test DB → correct answers retrievable', () async {
			final db = DatabaseHelper.instance;
			final learnSid = await db.createLearningSession('Animals', '');
			final vocabPairs = [
				('cat', '猫'),
				('dog', '犬'),
				('bird', '鳥'),
			];
			for (final pair in vocabPairs) {
				await db.createLearningItem(
					sessionId: learnSid, lang: 'en', convLang: 'ja',
					text: pair.$1, convText: pair.$2,
				);
			}
			final testSid = await db.createTestSession(
					'Animals Quiz', '${vocabPairs.length} questions',
					sourceLearningSessionId: learnSid);
			for (final pair in vocabPairs) {
				final allTargets = vocabPairs.map((p) => p.$2).toList();
				final distractors = allTargets.where((t) => t != pair.$2).toList();
				final question = await fake.generateQuizQuestion(
					correctWord: pair.$1,
					correctTranslation: pair.$2,
					distractorOptions: distractors,
					language: 'English',
					convLanguage: 'Japanese',
				);
				await db.createTestItemWithOptions(
					sessionId: testSid,
					question: question,
					options: [
						{'option': pair.$2, 'isCorrect': true, 'explanation': 'Correct!'},
						...distractors.map((d) =>
								{'option': d, 'isCorrect': false, 'explanation': 'Incorrect'}),
					],
				);
			}
			final full = await db.getFullTest(testSid);
			expect(full.map((r) => r['TestItemID']).toSet(), hasLength(3));
			final correctOpts = full.where((r) => r['IsCorrect'] == 1).toList();
			expect(correctOpts, hasLength(3)); 
			final linked = await db.getTestSessionByLearningSessionId(learnSid);
			expect(linked, isNotNull);
		});

		test('full flow: translate → learn → quiz → chat all persisted correctly', () async {
			final db = DatabaseHelper.instance;
			final translated = await fake.translateResponse(
					LanguageChoose.english, LanguageChoose.japanese, 'cherry blossom');
			final transSid = await db.createTranslationSession('Nature', '');
			await db.createTranslationItem(
				sessionId: transSid, lang: 'English', convLang: 'Japanese',
				text: 'cherry blossom', convText: translated,
			);
			final vocabEntries = await fake.learningVocabResponse(
					'nature', LanguageChoose.english, LanguageChoose.japanese);
			final learnSid = await db.createLearningSession('Nature Vocab', '');
			for (final e in vocabEntries) {
				await db.createLearningItem(
					sessionId: learnSid, lang: 'English', convLang: 'Japanese',
					text: e.text, convText: e.convText, entryType: e.entryType.name,
				);
			}
			final testSid = await db.createTestSession(
					'Nature Quiz', 'D', sourceLearningSessionId: learnSid);
			final q = await fake.generateQuizQuestion(
				correctWord: 'cherry blossom',
				correctTranslation: '桜',
				distractorOptions: ['梅', '竹'],
				language: 'English',
				convLanguage: 'Japanese',
			);
			await db.createTestItemWithOptions(
				sessionId: testSid,
				question: q,
				options: [
					{'option': '桜', 'isCorrect': true, 'explanation': 'Cherry blossom'},
					{'option': '梅', 'isCorrect': false, 'explanation': 'Plum'},
					{'option': '竹', 'isCorrect': false, 'explanation': 'Bamboo'},
				],
			);
			final chatAnswer = await fake.chatbotResponse(
					'Tell me about cherry blossoms.', null);
			final chatSid = await db.createChatbotSession('', '');
			await db.createChatbotItem(
				sessionId: chatSid,
				text: 'Tell me about cherry blossoms.',
				answer: chatAnswer,
			);
			expect(await db.getAllTranslationSessions(), hasLength(1));
			expect(await db.getAllLearningSessions(), hasLength(1));
			expect(await db.getAllChatbotSessions(), hasLength(1));
			expect(await db.getTestSessionByLearningSessionId(learnSid), isNotNull);
			final transItems = await db.getTranslationSessionItems(transSid);
			expect(transItems.first['ConvText'], equals(translated));
			final chatItems = await db.getChatbotSessionItems(chatSid);
			expect(chatItems.first['Answer'], equals(chatAnswer));
		});
	});


}
