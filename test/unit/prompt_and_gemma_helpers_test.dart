import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:SLMTranslator/database/database_helper.dart';
import 'package:SLMTranslator/types/language_choose.dart';
import 'package:SLMTranslator/types/quiz_question_type.dart';
import 'package:SLMTranslator/learning/vocab_entry.dart';
import 'package:SLMTranslator/model/model_response.dart';
import '../stub/stub_gemma_model.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.setInMemoryDatabaseForTesting();
  });
	group('Unit Test 1b: SLM — PromptBuilder pure logic', () {

		group('TranslationPromptBuilder', () {
			test('build() contains the source text', () {
				final b = TranslationPromptBuilder(
					textToTranslate: 'Good morning',
					convLanguage: 'Japanese',
				);
				expect(b.build(), contains('Good morning'));
			});

			test('build() contains the target language', () {
				final b = TranslationPromptBuilder(
					textToTranslate: 'Hello',
					convLanguage: 'French',
				);
				expect(b.build(), contains('French'));
			});

			test('build() mentions source language when provided', () {
				final b = TranslationPromptBuilder(
					textToTranslate: 'Hello',
					convLanguage: 'Japanese',
					language: 'English',
				);
				expect(b.build(), contains('English'));
			});

			test('build() contains auto-detect wording when language is null', () {
				final b = TranslationPromptBuilder(
					textToTranslate: 'Hello',
					convLanguage: 'Japanese',
				);
				expect(b.build(), contains('detecting the source language'));
			});

			test('build() includes translation memory when provided', () {
				final b = TranslationPromptBuilder(
					textToTranslate: 'Hello',
					convLanguage: 'Japanese',
					translationMemory: 'Hello → こんにちは',
				);
				final built = b.build();
				expect(built, contains('Hello → こんにちは'));
				expect(built, contains('Translation memory'));
			});

			test('build() omits memory section when translationMemory is null', () {
				final b = TranslationPromptBuilder(
					textToTranslate: 'Hello',
					convLanguage: 'Japanese',
				);
				expect(b.build(), isNot(contains('Translation memory')));
			});

			test('build() is non-empty', () {
				final b = TranslationPromptBuilder(
					textToTranslate: 'x',
					convLanguage: 'Chinese',
				);
				expect(b.build().trim(), isNotEmpty);
			});
		});

		group('TranslationMemoryBuilder', () {
			test('build() contains existing memory when provided', () {
				final b = TranslationMemoryBuilder(
					text: 'Hello',
					convText: 'こんにちは',
					convLanguage: 'Japanese',
					existingMemory: 'Glossary:\n- Apple → りんご',
				);
				final built = b.build();
				expect(built, contains('Existing memory:'));
				expect(built, contains('Apple → りんご'));
			});

			test('build() contains source and translated text', () {
				final b = TranslationMemoryBuilder(
					text: 'Good morning',
					convText: 'おはようございます',
					convLanguage: 'Japanese',
					language: 'English',
				);
				final built = b.build();
				expect(built, contains('Source (English): Good morning'));
				expect(built, contains('Translation (Japanese): おはようございます'));
			});

			test('build() asks for concise plain-text output', () {
				final b = TranslationMemoryBuilder(
					text: 'Thanks',
					convText: '謝謝',
					convLanguage: 'Chinese',
				);
				final built = b.build();
				expect(built, contains('plain text'));
				expect(built, contains('max 60 words'));
				expect(built, contains('Do NOT store full sentence-to-sentence mappings'));
			});
		});

		group('ChatbotPromptBuilder', () {
			test('build() contains the user message', () {
				final b = ChatbotPromptBuilder(userMessage: 'What is sushi?');
				expect(b.build(), contains('What is sushi?'));
			});

			test('build() contains the plain-text instruction', () {
				final b = ChatbotPromptBuilder(userMessage: 'test');
				expect(b.build(), contains('plain text'));
			});
		});


		group('LearningVocabStep1PromptBuilder', () {
			test('build() contains the topic', () {
				final b = LearningVocabFirstPromptBuilder(
						topic: 'Japanese animals', language: 'Japanese');
				expect(b.build(), contains('Japanese animals'));
			});

			test('build() contains the language', () {
				final b = LearningVocabFirstPromptBuilder(
						topic: 'food', language: 'Spanish');
				expect(b.build(), contains('Spanish'));
			});

			test('build() requests V and G prefixes', () {
				final b = LearningVocabFirstPromptBuilder(
						topic: 'travel', language: 'French');
				final built = b.build();
				expect(built, contains('V|'));
				expect(built, contains('G|'));
			});
		});

		group('LearningVocabStep2PromptBuilder', () {
			test('build() contains the target language', () {
				final b = LearningVocabNextPromptBuilder(
					convLanguage: 'Japanese',
					language: 'English',
					firstLines: ['V|cat', 'G|て-form'],
				);
				expect(b.build(), contains('Japanese'));
			});

			test('build() echoes step1Lines back into the prompt', () {
				final b = LearningVocabNextPromptBuilder(
					convLanguage: 'Japanese',
					language: 'English',
					firstLines: ['V|cat', 'V|dog'],
				);
				final built = b.build();
				expect(built, contains('V|cat'));
				expect(built, contains('V|dog'));
			});

			test('build() handles empty step1Lines gracefully', () {
				final b = LearningVocabNextPromptBuilder(
					convLanguage: 'Chinese',
					language: 'English',
					firstLines: [],
				);
				expect(b.build().trim(), isNotEmpty);
			});
		});

		group('QuizQuestionPromptBuilder', () {
			test('targetWord build() contains the correct word', () {
				final b = QuizQuestionPromptBuilder(
					correctWord: 'cat',
					correctTranslation: '猫',
					distractorOptions: ['犬', '鳥'],
					language: 'English',
					convLanguage: 'Japanese',
					type: QuizQuestionType.targetWord,
				);
				expect(b.build(), contains('cat'));
				expect(b.build(), contains('Japanese'));
			});

			test('sourceWord build() contains the correct translation', () {
				final b = QuizQuestionPromptBuilder(
					correctWord: 'cat',
					correctTranslation: '猫',
					distractorOptions: ['dog', 'bird'],
					language: 'English',
					convLanguage: 'Japanese',
					type: QuizQuestionType.sourceWord,
				);
				expect(b.build(), contains('猫'));
				expect(b.build(), contains('English'));
			});

			test('travelConversation build() contains travel scenario wording', () {
				final b = QuizQuestionPromptBuilder(
					correctWord: 'hotel',
					correctTranslation: 'ホテル',
					distractorOptions: ['空港', '駅'],
					language: 'English',
					convLanguage: 'Japanese',
					type: QuizQuestionType.travelConversation,
				);
				final built = b.build();
				expect(built, contains('hotel'));
				expect(built, contains('travel'));
			});

			test('all three QuizQuestionType values produce non-empty prompts', () {
				for (final type in QuizQuestionType.values) {
					final b = QuizQuestionPromptBuilder(
						correctWord: 'word',
						correctTranslation: 'translation',
						distractorOptions: ['d1', 'd2'],
						language: 'English',
						convLanguage: 'Japanese',
						type: type,
					);
					expect(b.build().trim(), isNotEmpty,
							reason: '${type.name} should produce a non-empty prompt');
				}
			});
		});
	});

	group('Unit Test 1c: SLM — GemmaModel static parsing helpers', () {

		group('parseStep1ItemsForTest (vocab/grammar line parser)', () {
			test('parses V| lines as vocab', () {
				final items = GemmaModel.parseFirstItemsForTest('V|apple\nV|dog');
				expect(items, hasLength(2));
				expect(items[0].type, equals(EntryType.vocab));
				expect(items[0].word, equals('apple'));
			});

			test('parses G| lines as grammar', () {
				final items = GemmaModel.parseFirstItemsForTest('G|て-form\nG|は-particle');
				expect(items, hasLength(2));
				expect(items[0].type, equals(EntryType.grammar));
				expect(items[0].word, equals('て-form'));
			});

			test('handles mixed V| and G| lines', () {
				const raw = 'V|cat\nG|て-form\nV|dog\nG|は-particle';
				final items = GemmaModel.parseFirstItemsForTest(raw);
				expect(items, hasLength(4));
				expect(items[0].type, equals(EntryType.vocab));
				expect(items[1].type, equals(EntryType.grammar));
			});

			test('strips numbered prefix before parsing', () {
				const raw = '1. V|cherry\n2. G|て-form';
				final items = GemmaModel.parseFirstItemsForTest(raw);
				expect(items, hasLength(2));
				expect(items[0].word, equals('cherry'));
			});

			test('strips bullet prefix before parsing', () {
				const raw = '- V|grape\n* G|は-particle';
				final items = GemmaModel.parseFirstItemsForTest(raw);
				expect(items, hasLength(2));
				expect(items[0].word, equals('grape'));
			});

			test('ignores malformed lines', () {
				const raw = 'no pipe here\nV|valid_word\nbad';
				final items = GemmaModel.parseFirstItemsForTest(raw);
				expect(items, hasLength(1));
				expect(items.first.word, equals('valid_word'));
			});

			test('ignores lines with empty word after pipe', () {
				const raw = 'V|\nG|\nV|real_word';
				final items = GemmaModel.parseFirstItemsForTest(raw);
				expect(items, hasLength(1));
				expect(items.first.word, equals('real_word'));
			});

			test('caps result at 10 items', () {
				final raw = List.generate(15, (i) => 'V|word$i').join('\n');
				final items = GemmaModel.parseFirstItemsForTest(raw);
				expect(items.length, lessThanOrEqualTo(10));
			});
		});

		group('applyStep1WordsForTest (ground-truth word pin)', () {
			test('overwrites entry text with step1 source word', () {
				final entries = [
					VocabEntry(text: 'wrong_text', convText: '猫',
							lang: 'en', convLang: 'ja'),
				];
				final step1 = [(type: EntryType.vocab, word: 'cat')];
				final result = GemmaModel.applyFirstWordsForTest(entries, step1);
				expect(result.first.text, equals('cat'));
				expect(result.first.convText, equals('猫'));
			});

			test('corrects entryType to match step1 type', () {
				final entries = [
					VocabEntry(text: 'x', convText: 'y',
							lang: 'en', convLang: 'ja', entryType: EntryType.vocab),
				];
				final step1 = [(type: EntryType.grammar, word: 'て-form')];
				final result = GemmaModel.applyFirstWordsForTest(entries, step1);
				expect(result.first.entryType, equals(EntryType.grammar));
			});

			test('entries beyond step1 list are kept as-is', () {
				final entries = [
					VocabEntry(text: 'pinned', convText: '猫', lang: 'en', convLang: 'ja'),
					VocabEntry(text: 'extra', convText: '犬', lang: 'en', convLang: 'ja'),
				];
				final step1 = [(type: EntryType.vocab, word: 'cat')];
				final result = GemmaModel.applyFirstWordsForTest(entries, step1);
				expect(result[0].text, equals('cat'));
				expect(result[1].text, equals('extra')); 
			});

			test('returns empty list when entries is empty', () {
				final result = GemmaModel.applyFirstWordsForTest(
						[], [(type: EntryType.vocab, word: 'x')]);
				expect(result, isEmpty);
			});
		});

		group('parseQuizQuestionForTest (quiz question extractor)', () {
			test('returns first line ending with ?', () {
				final model = GemmaModel();
				const raw = 'Some preamble\nWhat is the Japanese word for "cat"?';
				final q = model.parseQuizQuestionForTest(raw, 'cat', 'Japanese');
				expect(q, equals('What is the Japanese word for "cat"?'));
			});

			test('skips lines starting with known skip prefixes', () {
				final model = GemmaModel();
				const raw = 'You are a quiz generator.\nWhat does "犬" mean in English?';
				final q = model.parseQuizQuestionForTest(raw, '犬', 'English');
				expect(q, equals('What does "犬" mean in English?'));
			});

			test('falls back to default question when no valid line found', () {
				final model = GemmaModel();
				const raw = 'You are correct.\nGenerate a question.\nOutput only one line.';
				final q = model.parseQuizQuestionForTest(raw, 'cat', 'Japanese');
				expect(q, contains('cat'));
				expect(q, contains('Japanese'));
			});

			test('accepts lines with ___ as fill-in-the-blank questions', () {
				final model = GemmaModel();
				const raw = 'Fill in: ___ is the Japanese word for cat.';
				final q = model.parseQuizQuestionForTest(raw, 'cat', 'Japanese');
				expect(q, contains('___'));
			});
		});
	});

	group('Unit Test 1d: SLM — FakeGemmaModel stub behaviour', () {
		late StubGemmaModel fake;

		setUp(() => fake = StubGemmaModel());

		test('chatbotResponse returns non-empty string', () async {
			final r = await fake.chatbotResponse('Hello', null);
			expect(r, isNotEmpty);
		});

		test('chatbotResponse echoes prompt in default response', () async {
			final r = await fake.chatbotResponse('What is sushi?', null);
			expect(r, contains('What is sushi?'));
		});

		test('overrideChatbotResponse is returned instead of default', () async {
			fake.overrideChatbotResponse = 'Custom reply';
			final r = await fake.chatbotResponse('anything', null);
			expect(r, equals('Custom reply'));
		});

		test('chatbotResponse records received prompts', () async {
			await fake.chatbotResponse('Q1', null);
			await fake.chatbotResponse('Q2', null);
			expect(fake.receivedChatPrompts, equals(['Q1', 'Q2']));
		});


		test('translateResponse returns non-empty string', () async {
			final r = await fake.translateResponse(
					LanguageChoose.english, LanguageChoose.japanese, 'Good morning');
			expect(r, isNotEmpty);
		});

		test('translateResponse includes target language in default response', () async {
			final r = await fake.translateResponse(
					null, LanguageChoose.french, 'Hello');
			expect(r, contains('french'));
		});

		test('overrideTranslateResponse is returned instead of default', () async {
			fake.overrideTranslateResponse = 'Bonjour';
			final r = await fake.translateResponse(
					null, LanguageChoose.french, 'Hello');
			expect(r, equals('Bonjour'));
		});

		test('translateResponse records received (text, lang) pairs', () async {
			await fake.translateResponse(null, LanguageChoose.japanese, 'apple');
			await fake.translateResponse(null, LanguageChoose.chineseSimplified, 'dog');
			expect(fake.receivedTranslations[0].text, equals('apple'));
			expect(fake.receivedTranslations[0].lang, equals('japanese'));
			expect(fake.receivedTranslations[1].lang, equals('chineseSimplified'));
		});


		test('learningVocabResponse returns list of VocabEntry', () async {
			final entries = await fake.learningVocabResponse(
					'animals', LanguageChoose.english, LanguageChoose.japanese);
			expect(entries, isNotEmpty);
			expect(entries, everyElement(isA<VocabEntry>()));
		});

		test('learningVocabResponse includes topic in convText', () async {
			final entries = await fake.learningVocabResponse(
					'food', LanguageChoose.english, LanguageChoose.chineseSimplified);
			expect(entries.any((e) => e.convText.contains('food')), isTrue);
		});

		test('learningVocabResponse returns both vocab and grammar entries', () async {
			final entries = await fake.learningVocabResponse(
					'grammar', LanguageChoose.english, LanguageChoose.japanese);
			expect(entries.any((e) => e.entryType == EntryType.vocab), isTrue);
			expect(entries.any((e) => e.entryType == EntryType.grammar), isTrue);
		});


		test('generateQuizQuestion (targetWord) ends with ?', () async {
			final q = await fake.generateQuizQuestion(
				correctWord: 'cat',
				correctTranslation: '猫',
				distractorOptions: ['犬', '鳥'],
				language: 'English',
				convLanguage: 'Japanese',
				type: QuizQuestionType.targetWord,
			);
			expect(q, endsWith('?'));
			expect(q, contains('cat'));
		});

		test('generateQuizQuestion (sourceWord) contains translation', () async {
			final q = await fake.generateQuizQuestion(
				correctWord: 'cat',
				correctTranslation: '猫',
				distractorOptions: ['dog', 'bird'],
				language: 'English',
				convLanguage: 'Japanese',
				type: QuizQuestionType.sourceWord,
			);
			expect(q, contains('猫'));
		});

		test('generateQuizQuestion (travelConversation) mentions travel', () async {
			final q = await fake.generateQuizQuestion(
				correctWord: 'hotel',
				correctTranslation: 'ホテル',
				distractorOptions: ['空港', '駅'],
				language: 'English',
				convLanguage: 'Japanese',
				type: QuizQuestionType.travelConversation,
			);
			expect(q.toLowerCase(), contains('travel'));
		});

		test('chatHistory starts empty', () {
			expect(fake.chatHistory, isEmpty);
		});

		test('chatHistory grows after chatbotResponse calls', () async {
			await fake.chatbotResponse('Q1', null);
			await fake.chatbotResponse('Q2', null);
			expect(fake.chatHistory.length, equals(4));
		});

		test('chatHistory entries have role and text keys', () async {
			await fake.chatbotResponse('Hello', null);
			final history = fake.chatHistory;
			expect(history.every((m) => m.containsKey('role')), isTrue);
			expect(history.every((m) => m.containsKey('text')), isTrue);
		});

		test('resetChat clears history and increments counter', () async {
			await fake.chatbotResponse('Q', null);
			await fake.resetChat();
			expect(fake.chatHistory, isEmpty);
			expect(fake.resetChatCallCount, equals(1));
		});


		test('throwOnNextCall causes next call to throw', () async {
			fake.throwOnNextCall = Exception('network error');
			expect(
				() => fake.chatbotResponse('Q', null),
				throwsA(isA<Exception>()),
			);
		});

		test('throwOnNextCall clears after one throw', () async {
			fake.throwOnNextCall = Exception('once');
			try { await fake.chatbotResponse('Q', null); } catch (_) {}
			final r = await fake.chatbotResponse('Q2', null);
			expect(r, isNotEmpty);
		});

		test('dispose completes without error', () async {
			await expectLater(fake.dispose(), completes);
		});


		test('ModelResponse accepts FakeGemmaModel via constructor injection', () {
			final mr = ModelResponse(gemmaModel: fake);
			expect(mr, isNotNull);
		});

		test('ModelResponse injects imported translation memory into translation calls', () async {
			fake.overrideTranslateResponse = 'こんにちは';
			final mr = ModelResponse(gemmaModel: fake);

			await mr.importTranslationMemoryEntries(
				const [
					TranslationMemoryEntry(
						text: 'Apple',
						convText: 'りんご',
						language: 'English',
						convLanguage: 'Japanese',
					),
				],
				replaceExisting: true,
			);

			await mr.translateResponse(
				LanguageChoose.english,
				LanguageChoose.japanese,
				'Hello',
			);
			await mr.dispose();

			expect(fake.receivedTranslationMemories.single, isNotNull);
			expect(fake.receivedTranslationMemories.single!, contains('Glossary:'));
			expect(fake.receivedTranslationMemories.single!, contains('Apple → りんご'));
		});

		test('ModelResponse skips full-sentence pairs when importing translation history', () async {
			fake.overrideTranslateResponse = '再見，世界';
			final mr = ModelResponse(gemmaModel: fake);

			await mr.importTranslationMemoryEntries(
				const [
					TranslationMemoryEntry(
						text: 'hello world',
						convText: '你好，世界',
						language: 'English',
						convLanguage: 'Chinese',
					),
					TranslationMemoryEntry(
						text: 'world',
						convText: '世界',
						language: 'English',
						convLanguage: 'Chinese',
					),
				],
				replaceExisting: true,
			);

			await mr.translateResponse(
				LanguageChoose.english,
				LanguageChoose.chineseSimplified,
				'bye world',
			);
			await mr.dispose();

			expect(fake.receivedTranslationMemories.single, isNotNull);
			expect(fake.receivedTranslationMemories.single!, contains('hello world → 你好，世界'));
			expect(fake.receivedTranslationMemories.single!, contains('world → 世界'));
		});

		test('ModelResponse updates chatbot prompt with translation memory once per context', () async {
			fake.overrideChatbotResponse = 'stub answer';
			final mr = ModelResponse(gemmaModel: fake);

			await mr.importTranslationMemoryEntries(
				const [
					TranslationMemoryEntry(
						text: 'Tokyo',
						convText: '東京',
						language: 'English',
						convLanguage: 'Japanese',
					),
				],
				replaceExisting: true,
			);

			await mr.switchContext('chatbot');
			await mr.chatbotResponse('Tell me about Tokyo', null);
			await mr.chatbotResponse('And transport?', null);
			await mr.dispose();

			expect(fake.receivedChatPrompts.first, contains('Reference memory for glossary'));
			expect(fake.receivedChatPrompts.first, contains('Tokyo → 東京'));
			expect(fake.receivedChatPrompts.last, isNot(contains('Reference memory for glossary')));
		});

		test('latestTranslationMemory waits for background summary update', () async {
			fake.overrideTranslateResponse = 'Bonjour';
			fake.overrideTranslationMemoryResponse = 'Glossary:\n- Hello → Bonjour';
			final mr = ModelResponse(gemmaModel: fake);

			await mr.translateResponse(
				LanguageChoose.english,
				LanguageChoose.french,
				'Hello',
			);

			final memory = await mr.latestTranslationMemory();
			await mr.dispose();

			expect(memory, equals('Glossary:\n- Hello → Bonjour'));
			expect(fake.receivedTranslationMemoryUpdates.single.text, equals('Hello'));
		});
	});


}
