import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:SLMTranslator/database/database_helper.dart';
import 'package:SLMTranslator/settings/settings.dart';
import 'package:SLMTranslator/types/language_choose.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.setInMemoryDatabaseForTesting();
  });

  Future<void> pumpSettings(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Settings())),
    );
  }

  group('Widget Test: Settings screen', () {
    testWidgets('shows loading indicator before prefs are loaded', (tester) async {
      await pumpSettings(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows source language subtitle as Auto detect when no pref saved',
        (tester) async {
      await pumpSettings(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Auto detect'), findsOneWidget);
    });

    testWidgets('shows saved source language subtitle from SharedPreferences',
        (tester) async {
      await pumpSettings(
        tester,
        prefs: {'default_source_language': LanguageChoose.english.name},
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(LanguageChoose.english.label), findsAtLeastNWidgets(1));
    });

    testWidgets('shows saved target language subtitle from SharedPreferences',
        (tester) async {
      await pumpSettings(
        tester,
        prefs: {
          'default_target_language': LanguageChoose.japanese.name,
        },
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(LanguageChoose.japanese.label), findsAtLeastNWidgets(1));
    });

    testWidgets('defaults target language to Chinese (Traditional) when no pref saved',
        (tester) async {
      await pumpSettings(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text(LanguageChoose.chineseTraditional.label),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('shows all four clear history list tiles', (tester) async {
      await pumpSettings(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Clear Translation history'), findsOneWidget);
      expect(find.text('Clear Learning history'), findsOneWidget);
      expect(find.text('Clear Testing history'), findsOneWidget);
      expect(find.text('Clear Chatbot history'), findsOneWidget);
    });

    testWidgets('shows Soft Reset DB and Hard Reset DB buttons', (tester) async {
      await pumpSettings(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Soft Reset DB'), findsOneWidget);
      expect(find.text('Hard Reset DB'), findsOneWidget);
    });

    testWidgets('shows Default source language and Default target language tiles',
        (tester) async {
      await pumpSettings(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Default source language'), findsOneWidget);
      expect(find.text('Default target language'), findsOneWidget);
    });
  });
}

