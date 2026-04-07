import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:SLMTranslator/base/base_block.dart';
import 'package:SLMTranslator/chatbot/chatbot_block.dart';
import 'package:SLMTranslator/chatbot/chatbot_suggestions.dart';

void main() {
  Future<void> pumpBlock(WidgetTester tester, ChatbotBlock block) async {
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SingleChildScrollView(child: block))));
    await tester.pump();
  }

  group('Widget Test: ChatbotBlock — rendering', () {
    testWidgets('shows "Your Question:" header', (tester) async {
      await pumpBlock(tester, const ChatbotBlock(blockId: 0));
      expect(find.text('Your Question:'), findsOneWidget);
    });

    testWidgets('shows TextField for user input', (tester) async {
      await pumpBlock(tester, const ChatbotBlock(blockId: 0));
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows ChatbotSuggestionsBar', (tester) async {
      await pumpBlock(tester, const ChatbotBlock(blockId: 0));
      expect(find.byType(ChatbotSuggestionsBar), findsOneWidget);
    });

    testWidgets('shows image picker button', (tester) async {
      await pumpBlock(tester, const ChatbotBlock(blockId: 0));
      expect(find.byIcon(Icons.image), findsOneWidget);
    });
  });

  group('Widget Test: ChatbotBlock — output section', () {
    testWidgets('hides output section and Divider when answer is null',
        (tester) async {
      await pumpBlock(tester, const ChatbotBlock(blockId: 0));
      expect(find.text('Chatbot Response:'), findsNothing);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('shows "Chatbot Response:" label when answer is pre-filled',
        (tester) async {
      await pumpBlock(tester, const ChatbotBlock(blockId: 0, answer: 'Hello!'));
      expect(find.text('Chatbot Response:'), findsOneWidget);
    });

    testWidgets('shows the pre-filled answer text', (tester) async {
      await pumpBlock(
          tester, const ChatbotBlock(blockId: 0, answer: 'Hi there!'));
      expect(find.text('Hi there!'), findsOneWidget);
    });

    testWidgets('shows Divider when answer is pre-filled', (tester) async {
      await pumpBlock(
          tester, const ChatbotBlock(blockId: 0, answer: 'response'));
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('hides output section for whitespace-only answer',
        (tester) async {
      await pumpBlock(tester, const ChatbotBlock(blockId: 0, answer: '   '));
      expect(find.text('Chatbot Response:'), findsNothing);
    });
  });

  group('Widget Test: ChatbotBlock — menu', () {
    testWidgets('menu is hidden when no callbacks are provided', (tester) async {
      await pumpBlock(tester, const ChatbotBlock(blockId: 0, text: 'hello'));
      expect(find.byTooltip('Block options'), findsNothing);
    });

    testWidgets('menu is visible when onDelete is provided and block has text',
        (tester) async {
      await pumpBlock(
          tester, ChatbotBlock(blockId: 0, text: 'hello', onDelete: () {}));
      expect(find.byTooltip('Block options'), findsOneWidget);
    });

    testWidgets('menu is visible when answer exists even if text is empty',
        (tester) async {
      await pumpBlock(
        tester,
        ChatbotBlock(
          blockId: 0,
          text: '',
          answer: 'existing response',
          onDelete: () {},
        ),
      );
      expect(find.byTooltip('Block options'), findsOneWidget);
    });

    testWidgets('delete menu action invokes onDelete callback', (tester) async {
      var deleted = 0;
      await pumpBlock(tester,
          ChatbotBlock(blockId: 0, text: 'hello', onDelete: () => deleted++));
      await tester.tap(find.byTooltip('Block options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(deleted, equals(1));
    });

    testWidgets('menu shows only Delete — no Ask Chatbot item', (tester) async {
      await pumpBlock(
        tester,
        ChatbotBlock(
          blockId: 0,
          text: 'hi',
          answer: 'reply',
          onDelete: () {},
        ),
      );
      await tester.tap(find.byTooltip('Block options'));
      await tester.pumpAndSettle();
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Ask Chatbot'), findsNothing);
    });

    testWidgets('buildSendToChatbotText defaults to input text', (tester) async {
      await pumpBlock(
        tester,
        const ChatbotBlock(blockId: 0, text: 'Explain this topic'),
      );

      final state = tester.state(find.byType(ChatbotBlock))
          as BaseBlockState<ChatbotBlock>;
      final result = state.buildSendToChatbotText();
      expect(result, equals('Explain this topic'));
    });
  });
}
