import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:SLMTranslator/base/base_block.dart';
import 'package:SLMTranslator/learning_Test/learning_test_block.dart';

void main() {
  Future<void> pumpBlock(WidgetTester tester, LearningTestBlock block) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SingleChildScrollView(child: block))),
    );
    await tester.pump();
  }

  LearningTestBlock makeBlock({
    String question = 'What is the translation of apple?',
    List<String> options = const ['apple', 'banana', 'orange', 'grape'],
    int correctIndex = 0,
    VoidCallback? onDelete,
  }) {
    return LearningTestBlock(
      blockId: 1,
      question: question,
      options: options,
      correctIndex: correctIndex,
      onDelete: onDelete,
    );
  }

  group('Widget Test: LearningTestBlock - rendering', () {
    testWidgets('shows question and all options', (tester) async {
      await pumpBlock(
        tester,
        makeBlock(
          question: 'Pick the correct option',
          options: const ['A', 'B', 'C', 'D'],
        ),
      );

      expect(find.text('Pick the correct option'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('does not show a TextField', (tester) async {
      await pumpBlock(tester, makeBlock());
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('Widget Test: LearningTestBlock - answer flow', () {
    testWidgets('shows correct result when selecting the right answer',
        (tester) async {
      await pumpBlock(
        tester,
        makeBlock(options: const ['Correct', 'Wrong 1', 'Wrong 2'], correctIndex: 0),
      );

      await tester.tap(find.text('Correct'));
      await tester.pumpAndSettle();

      expect(find.text('Correct!'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('shows incorrect result and reveals correct answer',
        (tester) async {
      await pumpBlock(
        tester,
        makeBlock(options: const ['Right', 'Wrong'], correctIndex: 0),
      );

      await tester.tap(find.text('Wrong'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Incorrect'), findsOneWidget);
      expect(find.textContaining('Right'), findsWidgets);
    });

    testWidgets('reset clears result state', (tester) async {
      await pumpBlock(
        tester,
        makeBlock(options: const ['Right', 'Wrong'], correctIndex: 0),
      );

      await tester.tap(find.text('Wrong'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Incorrect'), findsOneWidget);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      expect(find.text('Correct!'), findsNothing);
      expect(find.textContaining('Incorrect'), findsNothing);
      expect(find.text('Reset'), findsNothing);
    });
  });

  group('Widget Test: LearningTestBlock - menu and chatbot text', () {
    testWidgets('menu is visible when delete callback exists', (tester) async {
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

    testWidgets('buildSendToChatbotText contains question/options/answer',
        (tester) async {
      await pumpBlock(
        tester,
        makeBlock(
          question: 'Q?',
          options: const ['First', 'Second', 'Third'],
          correctIndex: 1,
        ),
      );

      final state = tester.state(find.byType(LearningTestBlock))
          as BaseBlockState<LearningTestBlock>;
      final text = state.buildSendToChatbotText();

      expect(text, contains('Question: Q?'));
      expect(text, contains('A. First'));
      expect(text, contains('B. Second'));
      expect(text, contains('C. Third'));
      expect(text, contains('Correct answer: Second'));
    });
  });
}
