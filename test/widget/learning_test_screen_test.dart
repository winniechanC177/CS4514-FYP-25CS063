import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:SLMTranslator/learning_Test/learning_test.dart';
import 'package:SLMTranslator/learning_Test/learning_test_block.dart';

void main() {
  Future<void> pumpLearningTest(
    WidgetTester tester, {
    LearningTest? widget,
  }) async {
    await tester.pumpWidget(
      MaterialApp(home: widget ?? const LearningTest()),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  LearningTestBlock makeHistoryBlock({
    int blockId = 1,
    String question = 'What is cat?',
    List<String> options = const ['cat', 'dog', 'bird', 'fish'],
    int correctIndex = 0,
  }) {
    return LearningTestBlock(
      blockId: blockId,
      question: question,
      options: options,
      correctIndex: correctIndex,
    );
  }

  group('Widget Test: LearningTest screen', () {
    testWidgets('shows empty state when no test is loaded', (tester) async {
      await pumpLearningTest(tester);

      expect(find.text('No test loaded'), findsOneWidget);
      expect(
        find.text('Tap here or open the drawer\nto select a vocabulary session'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.quiz_outlined), findsOneWidget);
    });

    testWidgets('renders history test blocks from testBlocks', (tester) async {
      final widget = LearningTest(
        testBlocks: [
          makeHistoryBlock(
            blockId: 10,
            question: 'Q1',
            options: const ['a', 'b', 'c', 'd'],
            correctIndex: 0,
          ),
          makeHistoryBlock(
            blockId: 11,
            question: 'Q2',
            options: const ['w', 'x', 'y', 'z'],
            correctIndex: 2,
          ),
        ],
      );

      await pumpLearningTest(tester, widget: widget);

      expect(find.byType(LearningTestBlock), findsNWidgets(2));
      expect(find.text('Q1'), findsOneWidget);
      expect(find.text('Q2'), findsOneWidget);
    });

    testWidgets('hides FAB when no session is active', (tester) async {
      await pumpLearningTest(
        tester,
        widget: LearningTest(
          testBlocks: [
            makeHistoryBlock(
              question: 'Only block',
              options: const ['1', '2', '3', '4'],
              correctIndex: 1,
            ),
          ],
        ),
      );

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byTooltip('Add more questions'), findsNothing);
    });

    testWidgets('shows add-more FAB when test and source sessions exist',
        (tester) async {
      await pumpLearningTest(
        tester,
        widget: LearningTest(
          testSessionId: 100,
          sourceLearningSessionId: 50,
          testBlocks: [
            makeHistoryBlock(
              question: 'Persisted block',
              options: const ['A', 'B', 'C', 'D'],
              correctIndex: 2,
            ),
          ],
        ),
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byTooltip('Add more questions'), findsOneWidget);
    });
  });
}
