import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:SLMTranslator/database/database_helper.dart';
import 'package:SLMTranslator/types/language_choose.dart';
import 'package:SLMTranslator/learning/vocab_entry.dart';
import 'package:SLMTranslator/chatbot/chatbot_suggestions.dart';


void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.setInMemoryDatabaseForTesting();
  });
	group('Unit Test 1: SLM — ChatbotSuggestion pure logic', () {
		test('chatbotSuggestions list is non-empty', () {
			expect(ChatbotSuggestion.values, isNotEmpty);
		});

		test('every suggestion has a non-empty label and prompt', () {
			for (final s in ChatbotSuggestion.values) {
				expect(s.label, isNotEmpty);
				expect(s.prompt, isNotEmpty);
			}
		});

		test('detectSuggestionFromText returns matching suggestion', () {
			final s = detectSuggestion('Explain this to me: recursion');
			expect(s, isNotNull);
			expect(s!.label, equals('Explain'));
		});

		test('detectSuggestionFromText returns null for unrecognised text', () {
			expect(detectSuggestion('Random sentence'), isNull);
		});

		test('detectSuggestionFromText is case-insensitive', () {
			final s = detectSuggestion('EXPLAIN THIS TO ME: test');
			expect(s, isNotNull);
		});

		test('detectSuggestionFromText returns null for empty string', () {
			expect(detectSuggestion(''), isNull);
		});

		test('prompt prefix is correctly prepended when building chatbot query', () {
			const userText = 'cherry blossom';
			const suggestion = ChatbotSuggestion.definition;
			final finalPrompt = '${suggestion.prompt}$userText';
			expect(finalPrompt, equals('Define the word: cherry blossom'));
		});

		test('all predefined suggestions are detectable from their own prompt', () {
			for (final s in ChatbotSuggestion.values) {
				final detected = detectSuggestion('${s.prompt}anything');
				expect(detected, isNotNull,
						reason: 'Suggestion "${s.label}" should be self-detectable');
				expect(detected!.label, equals(s.label));
			}
		});
	});

	group('Unit Test 2: OCR — VocabEntry parsing', () {
		test('parses a single vocab entry (V| prefix)', () {
			const raw = 'V|apple|蘋果|I eat an apple every day.';
			final entries = VocabEntry.parseModelResponse(raw);
			expect(entries, hasLength(1));
			expect(entries.first.text, equals('apple'));
			expect(entries.first.convText, equals('蘋果'));
			expect(entries.first.example, equals('I eat an apple every day.'));
			expect(entries.first.entryType, equals(EntryType.vocab));
		});

		test('parses a grammar entry (G| prefix)', () {
			const raw = 'G|て-form|Used to connect verbs|食べて、寝ます';
			final entries = VocabEntry.parseModelResponse(raw);
			expect(entries, hasLength(1));
			expect(entries.first.entryType, equals(EntryType.grammar));
			expect(entries.first.text, equals('て-form'));
			expect(entries.first.convText, equals('Used to connect verbs'));
		});

		test('parses multi-line mixed response', () {
			const raw = '''
V|cat|猫|The cat is sleeping.
G|は-particle|Topic marker|私は学生です。
V|dog|犬|The dog is running.
''';
			final entries = VocabEntry.parseModelResponse(raw);
			expect(entries, hasLength(3));
			expect(entries[0].entryType, equals(EntryType.vocab));
			expect(entries[1].entryType, equals(EntryType.grammar));
		});

		test('caps result at 10 entries', () {
			final lines = List.generate(15, (i) => 'V|word$i|訳$i').join('\n');
			final entries = VocabEntry.parseModelResponse(lines);
			expect(entries.length, lessThanOrEqualTo(10));
		});

		test('ignores malformed lines (no pipe character)', () {
			const raw = 'not a valid line\nV|valid|有効|example';
			final entries = VocabEntry.parseModelResponse(raw);
			expect(entries, hasLength(1));
			expect(entries.first.text, equals('valid'));
		});

		test('ignores lines with empty text or convText', () {
			const raw = 'V||empty text|\nV|word||empty conv';
			final entries = VocabEntry.parseModelResponse(raw);
			expect(entries, isEmpty);
		});

		test('entry with no example stores null for example', () {
			const raw = 'V|book|本';
			final entries = VocabEntry.parseModelResponse(raw);
			expect(entries, hasLength(1));
			expect(entries.first.example, isNull);
		});

		test('VocabEntry.fromMap constructs correct object', () {
			final map = {
				'Text': 'hello',
				'ConvText': 'こんにちは',
				'Lang': 'English',
				'ConvLang': 'Japanese',
				'Example': 'Hello, world!',
				'EntryType': 'vocab',
			};
			final entry = VocabEntry.fromMap(map);
			expect(entry.text, equals('hello'));
			expect(entry.convText, equals('こんにちは'));
			expect(entry.lang, equals('English'));
			expect(entry.entryType, equals(EntryType.vocab));
		});

		test('VocabEntry.fromMap defaults entryType to vocab for unknown value', () {
			final map = {
				'LearningItemId': 1,
				'Text': 'x',
				'ConvText': 'y',
				'Lang': 'en',
				'ConvLang': 'ja',
				'EntryType': 'unknown_type',
			};
			final entry = VocabEntry.fromMap(map);
			expect(entry.entryType, equals(EntryType.vocab));
		});
	});

	group('Unit Test 3: TTS — LanguageChoose utilities', () {
		test('LanguageChoose.tryParse returns correct enum for all valid names', () {
			for (final lang in LanguageChoose.values) {
				final parsed = LanguageChoose.tryParse(lang.name);
				expect(parsed, equals(lang),
						reason: '${lang.name} should round-trip correctly');
			}
		});

		test('LanguageChoose.tryParse returns null for null input', () {
			expect(LanguageChoose.tryParse(null), isNull);
		});

		test('LanguageChoose.tryParse returns null for empty string', () {
			expect(LanguageChoose.tryParse(''), isNull);
		});

		test('LanguageChoose.tryParse returns null for unrecognised language', () {
			expect(LanguageChoose.tryParse('Klingon'), isNull);
		});

		test('shorten returns correct BCP-47 codes', () {
			expect(LanguageChoose.english.shorten,    equals('en-us'));
			expect(LanguageChoose.japanese.shorten,   equals('ja'));
			expect(LanguageChoose.chineseSimplified.shorten,    equals('zh-hans'));
			expect(LanguageChoose.chineseTraditional.shorten,   equals('zh-hant'));
			expect(LanguageChoose.spanish.shorten,    equals('es'));
			expect(LanguageChoose.french.shorten,     equals('fr-fr'));
			expect(LanguageChoose.hindi.shorten,      equals('hi'));
			expect(LanguageChoose.italian.shorten,    equals('it'));
			expect(LanguageChoose.portuguese.shorten, equals('pt-br'));
		});

		test('every LanguageChoose value produces a non-empty shortcode', () {
			for (final lang in LanguageChoose.values) {
				expect(lang.shorten, isNotEmpty,
						reason: '${lang.name} must have a BCP-47 shortcode');
			}
		});

		test('LanguageChoose enum covers expected languages', () {
			final labels = LanguageChoose.values.map((l) => l.label).toSet();
			expect(
				labels,
				containsAll([
					'English',
					'Japanese',
					'Chinese (Simplified)',
					'Chinese (Traditional)',
					'French',
				]),
			);
		});
	});

	group('Unit Test 4: SQL — DatabaseHelper CRUD', () {

		group('TranslationDAO', () {
			test('createTranslationSession returns a positive ID', () async {
				final id = await DatabaseHelper.instance
						.createTranslationSession('Session A', 'Desc');
				expect(id, greaterThan(0));
			});

			test('getAllTranslationSessions returns rows in DESC order', () async {
				final db = DatabaseHelper.instance;
				await db.createTranslationSession('First', 'D');
				await db.createTranslationSession('Second', 'D');
				final sessions = await db.getAllTranslationSessions();
				expect(sessions.length, equals(2));
				expect(sessions.first['Title'], equals('Second')); 
			});

			test('getAllTranslationSessions row has Id, Title, Content, Date', () async {
				final db = DatabaseHelper.instance;
				await db.createTranslationSession('T', 'C');
				final row = (await db.getAllTranslationSessions()).first;
				expect(row.containsKey('Id'), isTrue);
				expect(row.containsKey('Title'), isTrue);
				expect(row.containsKey('Content'), isTrue);
				expect(row.containsKey('Date'), isTrue);
			});

			test('createTranslationItem inserts under correct session', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createTranslationSession('S', 'D');
				await db.createTranslationItem(
					sessionId: sid,
					lang: 'English',
					convLang: 'Japanese',
					text: 'hello',
					convText: 'こんにちは',
				);
				final items = await db.getTranslationSessionItems(sid);
				expect(items, hasLength(1));
				expect(items.first['Text'], equals('hello'));
				expect(items.first['ConvText'], equals('こんにちは'));
			});


			test('deleteTranslationItem removes only that item', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createTranslationSession('S', 'D');
				final iid = await db.createTranslationItem(
					sessionId: sid, lang: 'en', convLang: 'ja', text: 'hi',
				);
				await db.createTranslationItem(
					sessionId: sid, lang: 'en', convLang: 'ja', text: 'bye',
				);
				await db.deleteTranslationItem(iid);
				final items = await db.getTranslationSessionItems(sid);
				expect(items, hasLength(1));
				expect(items.first['Text'], equals('bye'));
			});

			test('deleteSession(translation) cascades to items', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createTranslationSession('S', 'D');
				await db.createTranslationItem(
					sessionId: sid, lang: 'en', convLang: 'ja', text: 'hi',
				);
				await db.deleteSession(sid, 'translation');
				expect(await db.getAllTranslationSessions(), isEmpty);
				expect(await db.getTranslationSessionItems(sid), isEmpty);
			});
		});

		group('ChatbotDAO', () {
			test('createChatbotSession and getAllChatbotSessions work', () async {
				final db = DatabaseHelper.instance;
				await db.createChatbotSession('Chat 1', 'Desc');
				final sessions = await db.getAllChatbotSessions();
				expect(sessions.length, equals(1));
				expect(sessions.first['Title'], equals('Chat 1'));
			});

			test('createChatbotItem stores text and answer', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createChatbotSession('C', 'D');
				await db.createChatbotItem(
					sessionId: sid,
					text: 'What is Flutter?',
					answer: 'Flutter is a UI toolkit.',
				);
				final items = await db.getChatbotSessionItems(sid);
				expect(items, hasLength(1));
				expect(items.first['Text'], equals('What is Flutter?'));
				expect(items.first['Answer'], equals('Flutter is a UI toolkit.'));
			});

			test('getChatbotSessionItems returns messages in ASC order', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createChatbotSession('C', 'D');
				await db.createChatbotItem(sessionId: sid, text: 'Q1', answer: 'A1');
				await db.createChatbotItem(sessionId: sid, text: 'Q2', answer: 'A2');
				final items = await db.getChatbotSessionItems(sid);
				expect(items[0]['Text'], equals('Q1'));
				expect(items[1]['Text'], equals('Q2'));
			});


			test('deleteChatbotItem removes only that item', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createChatbotSession('C', 'D');
				final iid = await db.createChatbotItem(
					sessionId: sid, text: 'Q1', answer: 'A1',
				);
				await db.createChatbotItem(sessionId: sid, text: 'Q2', answer: 'A2');
				await db.deleteChatbotItem(iid);
				final items = await db.getChatbotSessionItems(sid);
				expect(items, hasLength(1));
				expect(items.first['Text'], equals('Q2'));
			});
		});

		group('LearningDAO', () {
			test('createLearningSession and getAllLearningSessions work', () async {
				final db = DatabaseHelper.instance;
				await db.createLearningSession('Animals', 'Learn animals');
				final sessions = await db.getAllLearningSessions();
				expect(sessions.length, equals(1));
				expect(sessions.first['Title'], equals('Animals'));
			});

			test('getLearningSession returns the correct session by ID', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createLearningSession('Fruits', 'D');
				final session = await db.getLearningSession(sid);
				expect(session, isNotNull);
				expect(session!['Title'], equals('Fruits'));
			});

			test('getLearningSession returns null for non-existent ID', () async {
				final session = await DatabaseHelper.instance.getLearningSession(9999);
				expect(session, isNull);
			});

			test('createLearningItem stores vocab with correct fields', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createLearningSession('Animals', 'D');
				await db.createLearningItem(
					sessionId: sid,
					lang: 'English',
					convLang: 'Japanese',
					text: 'cat',
					convText: '猫',
					example: 'The cat is cute.',
					entryType: 'vocab',
				);
				final items = await db.getLearningSessionItems(sid);
				expect(items, hasLength(1));
				expect(items.first['Text'], equals('cat'));
				expect(items.first['ConvText'], equals('猫'));
				expect(items.first['EntryType'], equals('vocab'));
			});

			test('createLearningItem stores grammar entryType', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createLearningSession('Grammar', 'D');
				await db.createLearningItem(
					sessionId: sid,
					lang: 'English',
					convLang: 'Japanese',
					text: 'て-form',
					convText: '連用形',
					entryType: 'grammar',
				);
				final items = await db.getLearningSessionItems(sid);
				expect(items.first['EntryType'], equals('grammar'));
			});


			test('deleteLearningItem removes only that item', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createLearningSession('S', 'D');
				final iid = await db.createLearningItem(
					sessionId: sid, lang: 'en', convLang: 'ja', text: 'apple',
				);
				await db.createLearningItem(
					sessionId: sid, lang: 'en', convLang: 'ja', text: 'banana',
				);
				await db.deleteLearningItem(iid);
				final items = await db.getLearningSessionItems(sid);
				expect(items, hasLength(1));
				expect(items.first['Text'], equals('banana'));
			});

			test('deleteSession(learning) cascades to items', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createLearningSession('S', 'D');
				await db.createLearningItem(
					sessionId: sid, lang: 'en', convLang: 'ja', text: 'cat',
				);
				await db.deleteSession(sid, 'learning');
				expect(await db.getAllLearningSessions(), isEmpty);
				expect(await db.getLearningSessionItems(sid), isEmpty);
			});
		});

		group('TestDAO', () {
			test('createTestSession returns a valid ID', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createTestSession('Quiz 1', 'Test description');
				expect(sid, greaterThan(0));
			});

			test('createTestItemWithOptions creates question with options', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createTestSession('Quiz', 'D');
				final iid = await db.createTestItemWithOptions(
					sessionId: sid,
					question: 'What is 猫?',
					options: [
						{'option': 'dog', 'isCorrect': false, 'explanation': 'Wrong'},
						{'option': 'cat', 'isCorrect': true, 'explanation': 'Correct!'},
						{'option': 'bird', 'isCorrect': false, 'explanation': 'Wrong'},
					],
				);
				expect(iid, greaterThan(0));
				final full = await db.getFullTest(sid);
				expect(full, hasLength(3)); 
				final correct = full.where((r) => r['IsCorrect'] == 1).toList();
				expect(correct, hasLength(1));
				expect(correct.first['Option'], equals('cat'));
			});

			test('getFullTest returns joined question-option rows', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createTestSession('Quiz', 'D');
				await db.createTestItemWithOptions(
					sessionId: sid,
					question: 'What is 犬?',
					options: [
						{'option': 'cat', 'isCorrect': false, 'explanation': null},
						{'option': 'dog', 'isCorrect': true, 'explanation': 'Correct!'},
					],
				);
				final full = await db.getFullTest(sid);
				expect(full, hasLength(2));
				expect(full.first['Question'], equals('What is 犬?'));
			});

			test('getTestSessionByLearningSessionId finds linked session', () async {
				final db = DatabaseHelper.instance;
				final learnSid = await db.createLearningSession('Vocab', 'D');
				final testSid = await db.createTestSession(
					'Vocab Quiz', 'D', sourceLearningSessionId: learnSid,
				);
				final found = await db.getTestSessionByLearningSessionId(learnSid);
				expect(found, isNotNull);
				expect(found!['TestSessionID'], equals(testSid));
			});

			test('getTestSessionByLearningSessionId returns null when no link', () async {
				final found =
						await DatabaseHelper.instance.getTestSessionByLearningSessionId(999);
				expect(found, isNull);
			});

			test('deleteTestItem cascades to options', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createTestSession('Q', 'D');
				final iid = await db.createTestItemWithOptions(
					sessionId: sid,
					question: 'Q?',
					options: [
						{'option': 'A', 'isCorrect': true, 'explanation': null},
						{'option': 'B', 'isCorrect': false, 'explanation': null},
					],
				);
				await db.deleteTestItem(iid);
				expect(await db.getFullTest(sid), isEmpty);
			});
		});

		group('SessionHelper', () {
			test('updateSessionTitle updates the title', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createTranslationSession('Old', 'D');
				await db.updateSessionTitle(sid, 'translation', 'New Title');
				final sessions = await db.getAllTranslationSessions();
				expect(sessions.first['Title'], equals('New Title'));
			});

			test('updateSessionContent updates the content', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createChatbotSession('Chat', 'Old content');
				await db.updateSessionContent(sid, 'chatbot', 'Updated content');
				final sessions = await db.getAllChatbotSessions();
				expect(sessions.first['Content'], equals('Updated content'));
			});

			test('getSessionLength counts items correctly', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createLearningSession('S', 'D');
				await db.createLearningItem(
					sessionId: sid, lang: 'en', convLang: 'ja', text: 'w1',
				);
				await db.createLearningItem(
					sessionId: sid, lang: 'en', convLang: 'ja', text: 'w2',
				);
				expect(await db.getSessionLength(sid, 'learning'), equals(2));
			});

			test('getSessionLength returns 0 for empty session', () async {
				final db = DatabaseHelper.instance;
				final sid = await db.createLearningSession('Empty', 'D');
				expect(await db.getSessionLength(sid, 'learning'), equals(0));
			});


			test('deleteAllSessions removes all sessions of that type', () async {
				final db = DatabaseHelper.instance;
				await db.createTranslationSession('S1', 'D');
				await db.createTranslationSession('S2', 'D');
				await db.deleteAllSessions('translation');
				expect(await db.getAllTranslationSessions(), isEmpty);
			});

			test('softReset clears all rows across all tables', () async {
				final db = DatabaseHelper.instance;
				await db.createTranslationSession('T', 'D');
				await db.createChatbotSession('C', 'D');
				await db.createLearningSession('L', 'D');
				await db.softReset();
				expect(await db.getAllTranslationSessions(), isEmpty);
				expect(await db.getAllChatbotSessions(), isEmpty);
				expect(await db.getAllLearningSessions(), isEmpty);
			});

			test('today() returns an ISO date string (YYYY-MM-DD)', () {
				final today = DatabaseHelper.instance.today();
				expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(today), isTrue);
			});
		});
	});


}
