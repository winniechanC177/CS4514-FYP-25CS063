import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:SLMTranslator/base/base_block.dart';
import 'package:SLMTranslator/chatbot/chatbot_suggestions.dart';
import 'package:SLMTranslator/translation/translation_block.dart';
import 'package:SLMTranslator/types/language_choose.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpBlock(WidgetTester tester, TranslationBlock block) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: block))),
    );
    await tester.pump();
  }

  TranslationBlock makeBlock({
    LanguageChoose? language,
    LanguageChoose? convLanguage,
    String? text,
    String? convText,
    VoidCallback? onDelete,
    void Function(String, {ChatbotSuggestion? suggestion})? onSendToChatbot,
  }) =>
      TranslationBlock(
        blockId: 0,
        language: language,
        convLanguage: convLanguage,
        text: text,
        convText: convText,
        onDelete: onDelete,
        onSendToChatbot: onSendToChatbot,
      );

  group('Widget Test: TranslationBlock — language dropdowns', () {
    testWidgets('renders two DropdownButtons (source + target)', (tester) async {
      await pumpBlock(tester, makeBlock());
      expect(find.byType(DropdownButton<LanguageChoose?>), findsOneWidget);
      expect(find.byType(DropdownButton<LanguageChoose>), findsOneWidget);
    });

    testWidgets('swap button is DISABLED when source language is null (auto-detect)',
        (tester) async {
      await pumpBlock(tester, makeBlock(language: null));
      final swap = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.swap_horiz),
      );
      expect(swap.onPressed, isNull);
    });

    testWidgets('swap button is ENABLED when source language is set', (tester) async {
      await pumpBlock(
        tester,
        makeBlock(language: LanguageChoose.english),
      );
      final swap = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.swap_horiz),
      );
      expect(swap.onPressed, isNotNull);
    });

    testWidgets('shows selected source language label in dropdown', (tester) async {
      await pumpBlock(
        tester,
        makeBlock(language: LanguageChoose.french),
      );
      expect(find.text(LanguageChoose.french.label), findsAtLeastNWidgets(1));
    });

    testWidgets('shows selected target language label in dropdown', (tester) async {
      await pumpBlock(
        tester,
        makeBlock(convLanguage: LanguageChoose.japanese),
      );
      expect(find.text(LanguageChoose.japanese.label), findsAtLeastNWidgets(1));
    });
  });

  group('Widget Test: TranslationBlock — output section', () {
    testWidgets('hides output section when convText is null', (tester) async {
      await pumpBlock(tester, makeBlock(convText: null));
      expect(find.text('Translate Response:'), findsNothing);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('hides output section for whitespace-only convText', (tester) async {
      await pumpBlock(tester, makeBlock(convText: '   '));
      expect(find.text('Translate Response:'), findsNothing);
    });

    testWidgets('shows "Translate Response:" label when convText is pre-filled',
        (tester) async {
      await pumpBlock(tester, makeBlock(convText: '你好'));
      expect(find.text('Translate Response:'), findsOneWidget);
    });

    testWidgets('shows pre-filled convText in output', (tester) async {
      await pumpBlock(tester, makeBlock(convText: '你好'));
      expect(find.text('你好'), findsOneWidget);
    });

    testWidgets('shows Divider when convText is pre-filled', (tester) async {
      await pumpBlock(tester, makeBlock(convText: '你好'));
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('shows TTS play button when convText is set and convLanguage supports TTS',
        (tester) async {
      await pumpBlock(
        tester,
        makeBlock(
          convText: '你好',
          convLanguage: LanguageChoose.chineseTraditional,
        ),
      );
      expect(find.byIcon(Icons.play_arrow_outlined), findsOneWidget);
    });

    testWidgets('TTS play button is disabled when convLanguage has no TTS support',
        (tester) async {
      await pumpBlock(
        tester,
        makeBlock(
          convText: 'こんにちは',
          convLanguage: LanguageChoose.japanese,
        ),
      );
      final ttsButton = tester.widget<OutlinedButton>(
        find.widgetWithIcon(OutlinedButton, Icons.play_arrow_outlined),
      );
      expect(ttsButton.onPressed, isNull);
    });
  });

  group('Widget Test: TranslationBlock — menu & buildSendToChatbotText', () {
    testWidgets('menu is hidden when no callbacks are provided', (tester) async {
      await pumpBlock(tester, makeBlock(text: 'hello'));
      expect(find.byTooltip('Block options'), findsNothing);
    });

    testWidgets('menu is visible when onDelete is provided and block has text',
        (tester) async {
      await pumpBlock(tester, makeBlock(text: 'hello', onDelete: () {}));
      expect(find.byTooltip('Block options'), findsOneWidget);
    });

    testWidgets('delete action invokes onDelete', (tester) async {
      var deleted = 0;
      await pumpBlock(tester, makeBlock(text: 'hi', onDelete: () => deleted++));
      await tester.tap(find.byTooltip('Block options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(deleted, equals(1));
    });

    testWidgets(
        'buildSendToChatbotText returns "Original + Translation" when both are set',
        (tester) async {
      await pumpBlock(
        tester,
        makeBlock(text: 'hello', convText: '你好'),
      );
      final state = tester.state(find.byType(TranslationBlock))
          as BaseBlockState<TranslationBlock>;
      final result = state.buildSendToChatbotText();
      expect(result, contains('hello'));
      expect(result, contains('你好'));
      expect(result, contains('Original:'));
      expect(result, contains('Translation:'));
    });

    testWidgets(
        'buildSendToChatbotText returns only source text when convText is empty',
        (tester) async {
      await pumpBlock(tester, makeBlock(text: 'hello', convText: null));
      final state = tester.state(find.byType(TranslationBlock))
          as BaseBlockState<TranslationBlock>;
      final result = state.buildSendToChatbotText();
      expect(result, equals('hello'));
      expect(result, isNot(contains('Translation:')));
    });
  });
}


