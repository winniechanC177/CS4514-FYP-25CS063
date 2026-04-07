import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:SLMTranslator/database/database_helper.dart';
import 'package:SLMTranslator/chatbot/chatbot.dart';
import 'package:SLMTranslator/chatbot/chatbot_block.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.setInMemoryDatabaseForTesting();
  });

  Future<void> pumpChatbot(
    WidgetTester tester, {
    Chatbot? widget,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: widget ?? const Chatbot(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('Widget Test: Chatbot screen', () {
    testWidgets('creates one ChatbotBlock on init with no history', (tester) async {
      await pumpChatbot(tester);
      expect(find.byType(ChatbotBlock), findsOneWidget);
    });

    testWidgets('loads correct number of blocks from chatbotHistory', (tester) async {
      await pumpChatbot(
        tester,
        widget: Chatbot(
          chatbotHistory: [
            {
              'ChatbotItemID': 1,
              'Text': 'hello',
              'Answer': 'hi there',
              'Suggestion': null,
              'Image': null,
            },
            {
              'ChatbotItemID': 2,
              'Text': 'how are you?',
              'Answer': 'good thanks',
              'Suggestion': null,
              'Image': null,
            },
          ],
        ),
      );

      expect(find.byType(ChatbotBlock), findsNWidgets(3));
    });

    testWidgets('pre-fills text when initialQuery is provided', (tester) async {
      await pumpChatbot(
        tester,
        widget: const Chatbot(initialQuery: 'Explain grammar'),
      );

      expect(find.text('Explain grammar'), findsOneWidget);
    });

    testWidgets('renders without crashing when chatbotHistory is empty', (tester) async {
      await pumpChatbot(
        tester,
        widget: const Chatbot(chatbotHistory: []),
      );
      expect(find.byType(ChatbotBlock), findsAtLeastNWidgets(1));
    });

    testWidgets('onNewSession callback is wired to the FAB long-press', (tester) async {
      var called = 0;
      await pumpChatbot(
        tester,
        widget: Chatbot(onNewSession: () => called++),
      );

      expect(find.byTooltip('New session'), findsOneWidget);
    });
  });
}

