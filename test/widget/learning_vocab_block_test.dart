import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:SLMTranslator/base/base_block.dart';
import 'package:SLMTranslator/types/chatbot_suggestion.dart';
import 'package:SLMTranslator/learning/learning_vocab_block.dart';
import 'package:SLMTranslator/learning/vocab_entry.dart';
import 'package:SLMTranslator/types/language_choose.dart';

void main() {
  Future<void> pumpBlock(WidgetTester tester, LearningVocabBlock block) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: block))),
    );
    await tester.pump();
  }

  LearningVocabBlock makeBlock({
    LanguageChoose language = LanguageChoose.english,
    LanguageChoose convLanguage = LanguageChoose.chineseTraditional,
    String text = 'apple',
    String convText = '蘋果',
    String? example,
    EntryType entryType = EntryType.vocab,
    VoidCallback? onDelete,
    void Function(String, {ChatbotSuggestion? suggestion})? onSendToChatbot,
  }) =>
      LearningVocabBlock(
        blockId: 0,
        text: text,
        language: language,
        convLanguage: convLanguage,
        convText: convText,
        example: example,
        entryType: entryType,
        onDelete: onDelete,
        onSendToChatbot: onSendToChatbot,
      );

  group('Widget Test: LearningVocabBlock — rendering', () {
    testWidgets('does NOT show a TextField (display-only block)', (tester) async {
      await pumpBlock(tester, makeBlock());
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows source language label', (tester) async {
      await pumpBlock(tester, makeBlock(language: LanguageChoose.english));
      expect(find.text(LanguageChoose.english.label), findsOneWidget);
    });

    testWidgets('shows source word text', (tester) async {
      await pumpBlock(tester, makeBlock(text: 'banana'));
      expect(find.text('banana'), findsOneWidget);
    });

    testWidgets('shows translated (convText) text', (tester) async {
      await pumpBlock(tester, makeBlock(convText: '香蕉'));
      expect(find.text('香蕉'), findsOneWidget);
    });

    testWidgets('shows target language name in output header', (tester) async {
      await pumpBlock(tester, makeBlock(convLanguage: LanguageChoose.japanese));
      expect(find.text(LanguageChoose.japanese.name), findsOneWidget);
    });

    testWidgets('shows example text when provided', (tester) async {
      await pumpBlock(tester, makeBlock(example: 'I eat a banana.'));
      expect(find.text('I eat a banana.'), findsOneWidget);
    });

    testWidgets('hides example section when example is null', (tester) async {
      await pumpBlock(tester, makeBlock(example: null));
      expect(find.text('apple'), findsOneWidget); // word still shown
      expect(find.text('Example:'), findsNothing);
    });

    testWidgets('hides example section when example is empty string', (tester) async {
      await pumpBlock(tester, makeBlock(example: ''));
      expect(find.text(''), findsNothing);
    });
  });

  group('Widget Test: LearningVocabBlock — TTS buttons', () {
    testWidgets('source TTS button is enabled for English (hasTtsSupport = true)',
        (tester) async {
      await pumpBlock(tester, makeBlock(language: LanguageChoose.english));
      final buttons = tester.widgetList<OutlinedButton>(find.byType(OutlinedButton));
      final srcButton = buttons.first;
      expect(srcButton.onPressed, isNotNull);
    });

    testWidgets('source TTS button is disabled for Japanese (hasTtsSupport = false)',
        (tester) async {
      await pumpBlock(tester, makeBlock(language: LanguageChoose.japanese));
      final buttons = tester.widgetList<OutlinedButton>(find.byType(OutlinedButton));
      final srcButton = buttons.first;
      expect(srcButton.onPressed, isNull);
    });

    testWidgets('target TTS button is enabled when convLanguage supports TTS',
        (tester) async {
      await pumpBlock(
        tester,
        makeBlock(
          language: LanguageChoose.japanese,
          convLanguage: LanguageChoose.chineseTraditional,
        ),
      );
      final buttons = tester.widgetList<OutlinedButton>(find.byType(OutlinedButton)).toList();
      expect(buttons[1].onPressed, isNotNull);
    });

    testWidgets('target TTS button is disabled when convLanguage is Japanese',
        (tester) async {
      await pumpBlock(
        tester,
        makeBlock(
          language: LanguageChoose.english,
          convLanguage: LanguageChoose.japanese,
        ),
      );
      final buttons = tester.widgetList<OutlinedButton>(find.byType(OutlinedButton)).toList();
      expect(buttons[1].onPressed, isNull);
    });
  });

  group('Widget Test: LearningVocabBlock — menu & buildSendToChatbotText', () {
    testWidgets('menu is visible (display-only block always has menu content)',
        (tester) async {
      await pumpBlock(tester, makeBlock(onDelete: () {}));
      expect(find.byTooltip('Block options'), findsOneWidget);
    });

    testWidgets('delete action invokes onDelete callback', (tester) async {
      var deleted = 0;
      await pumpBlock(tester, makeBlock(onDelete: () => deleted++));
      await tester.tap(find.byTooltip('Block options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(deleted, equals(1));
    });

    testWidgets('buildSendToChatbotText includes source, target and example',
        (tester) async {
      await pumpBlock(
        tester,
        makeBlock(text: 'cat', convText: '猫', example: 'The cat is cute.'),
      );
      final state = tester.state(find.byType(LearningVocabBlock))
          as BaseBlockState<LearningVocabBlock>;
      final result = state.buildSendToChatbotText();
      expect(result, contains('cat'));
      expect(result, contains('猫'));
      expect(result, contains('The cat is cute.'));
    });

    testWidgets('buildSendToChatbotText omits example line when example is null',
        (tester) async {
      await pumpBlock(
        tester,
        makeBlock(text: 'cat', convText: '猫', example: null),
      );
      final state = tester.state(find.byType(LearningVocabBlock))
          as BaseBlockState<LearningVocabBlock>;
      final result = state.buildSendToChatbotText();
      expect(result, contains('cat'));
      expect(result, contains('猫'));
      expect(result, isNot(contains('Example:')));
    });
  });
}


