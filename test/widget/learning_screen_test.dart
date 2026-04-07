import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:SLMTranslator/database/database_helper.dart';
import 'package:SLMTranslator/learning/learning.dart';
import 'package:SLMTranslator/learning/learning_vocab_block.dart';
import 'package:SLMTranslator/types/language_choose.dart';
import 'package:SLMTranslator/learning/vocab_entry.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.setInMemoryDatabaseForTesting();
  });

  Future<void> pumpLearning(WidgetTester tester, {Learning? widget}) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: widget ?? const Learning())),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('Widget Test: Learning screen', () {
    testWidgets('shows no blocks by default (needsInitialBlock is false)',
        (tester) async {
      await pumpLearning(tester);
      expect(find.byType(LearningVocabBlock), findsNothing);
    });

    testWidgets('renders correct number of blocks from learningBlocks',
        (tester) async {
      final blocks = [
        LearningVocabBlock(
          blockId: 0,
          text: 'apple',
          language: LanguageChoose.english,
          convLanguage: LanguageChoose.japanese,
          convText: 'apple-jp',
          entryType: EntryType.vocab,
        ),
        LearningVocabBlock(
          blockId: 1,
          text: 'to be + adj',
          language: LanguageChoose.english,
          convLanguage: LanguageChoose.japanese,
          convText: 'pattern-jp',
          entryType: EntryType.grammar,
        ),
      ];
      await pumpLearning(tester, widget: Learning(learningBlocks: blocks));
      expect(find.byType(LearningVocabBlock), findsNWidgets(2));
    });

    testWidgets('vocab block displays source word', (tester) async {
      final blocks = [
        LearningVocabBlock(
          blockId: 0,
          text: 'banana',
          language: LanguageChoose.english,
          convLanguage: LanguageChoose.chineseSimplified,
          convText: 'banana-zh',
          entryType: EntryType.vocab,
        ),
      ];
      await pumpLearning(tester, widget: Learning(learningBlocks: blocks));
      expect(find.text('banana'), findsOneWidget);
    });

    testWidgets('vocab block displays translated text', (tester) async {
      final blocks = [
        LearningVocabBlock(
          blockId: 0,
          text: 'cat',
          language: LanguageChoose.english,
          convLanguage: LanguageChoose.chineseSimplified,
          convText: 'neko',
          entryType: EntryType.vocab,
        ),
      ];
      await pumpLearning(tester, widget: Learning(learningBlocks: blocks));
      expect(find.text('neko'), findsOneWidget);
    });

    testWidgets('onNewSession wires the LongPressFab', (tester) async {
      var called = 0;
      await pumpLearning(
          tester, widget: Learning(onNewSession: () => called++));
      expect(find.byTooltip('New session'), findsOneWidget);
    });
  });
}

