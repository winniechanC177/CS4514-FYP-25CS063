import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:SLMTranslator/base/long_press_fab.dart';
import 'package:SLMTranslator/translation/translation.dart';
import 'package:SLMTranslator/translation/translation_block.dart';
import 'package:SLMTranslator/types/language_choose.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpTranslation(
    WidgetTester tester, {
    Translation? widget,
  }) async {
    await tester.pumpWidget(
      MaterialApp(home: widget ?? const Translation()),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('Widget Test: Translation screen', () {
    testWidgets('creates one initial block when there is no history',
        (tester) async {
      await pumpTranslation(tester);
      expect(find.byType(TranslationBlock), findsOneWidget);
    });

    testWidgets('loads history blocks from translationHistory',
        (tester) async {
      await pumpTranslation(
        tester,
        widget: Translation(
          translationHistory: [
            {
              'TranslationItemID': 1,
              'Text': 'hello',
              'ConvText': '你好',
              'Lang': LanguageChoose.english.name,
              'ConvLang': LanguageChoose.chineseSimplified.name,
            },
            {
              'TranslationItemID': 2,
              'Text': 'goodbye',
              'ConvText': '再見',
              'Lang': LanguageChoose.english.name,
              'ConvLang': LanguageChoose.chineseTraditional.name,
            },
          ],
        ),
      );

      expect(find.byType(TranslationBlock), findsAtLeastNWidgets(2));
      expect(find.text('hello'), findsOneWidget);
      expect(find.text('goodbye'), findsOneWidget);
    });

    testWidgets('uses normal FloatingActionButton when onNewSession is null',
        (tester) async {
      await pumpTranslation(tester);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byType(LongPressFab), findsNothing);
    });

    testWidgets('uses LongPressFab when onNewSession is provided',
        (tester) async {
      await pumpTranslation(
        tester,
        widget: Translation(onNewSession: () {}),
      );

      expect(find.byType(LongPressFab), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });
}

