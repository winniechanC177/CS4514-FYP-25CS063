import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:SLMTranslator/database/database_helper.dart';
import 'package:SLMTranslator/base/long_press_fab.dart';
import '../stub/stub_block.dart';
import '../stub/stub_conversation_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.setInMemoryDatabaseForTesting();
  });
	group('Widget Test: BaseBlock — StubBlock behaviour', () {
		Future<void> pumpStubBlock(
			WidgetTester tester, {
			required StubBlock block,
		}) async {
			await tester.pumpWidget(
				MaterialApp(
					home: Scaffold(body: block),
				),
			);
		}

		testWidgets('dynamicFontSize returns 28 for very short text', (
			tester,
		) async {
			await pumpStubBlock(tester, block: const StubBlock(blockId: 1));
			final state = tester.state<StubBlockState>(find.byType(StubBlock));
			expect(state.dynamicFontSize('short'), equals(28));
		});

		testWidgets('dynamicFontSize returns 22 for short phrases', (
			tester,
		) async {
			await pumpStubBlock(tester, block: const StubBlock(blockId: 1));
			final state = tester.state<StubBlockState>(find.byType(StubBlock));
			expect(state.dynamicFontSize('1234567890123456789012345'), equals(22));
		});

		testWidgets('dynamicFontSize returns 18 for medium text', (tester) async {
			await pumpStubBlock(tester, block: const StubBlock(blockId: 1));
			final state = tester.state<StubBlockState>(find.byType(StubBlock));
			expect(
				state.dynamicFontSize('x' * 50),
				equals(18),
			);
		});

		testWidgets('dynamicFontSize returns 16 for longer text', (tester) async {
			await pumpStubBlock(tester, block: const StubBlock(blockId: 1));
			final state = tester.state<StubBlockState>(find.byType(StubBlock));
			expect(
				state.dynamicFontSize('x' * 150),
				equals(16),
			);
		});

		testWidgets('dynamicFontSize returns 14 for long passages', (tester) async {
			await pumpStubBlock(tester, block: const StubBlock(blockId: 1));
			final state = tester.state<StubBlockState>(find.byType(StubBlock));
			expect(
				state.dynamicFontSize('x' * 250),
				equals(14),
			);
		});

		testWidgets('shows TextField when showTextField is true', (tester) async {
			await pumpStubBlock(
				tester,
				block: const StubBlock(blockId: 1, overrideShowTextField: true),
			);
			expect(find.byType(TextField), findsOneWidget);
		});

		testWidgets('hides TextField when showTextField is false', (tester) async {
			await pumpStubBlock(
				tester,
				block: const StubBlock(blockId: 1, overrideShowTextField: false),
			);
			expect(find.byType(TextField), findsNothing);
		});

		testWidgets('shows output section when hasOutputContent is true', (
			tester,
		) async {
			await pumpStubBlock(
				tester,
				block: const StubBlock(
					blockId: 1,
					overrideHasOutputContent: true,
				),
			);
			expect(find.byKey(const Key('stub_output')), findsOneWidget);
			expect(find.byType(Divider), findsOneWidget);
		});

		testWidgets('hides output section when not loading and no output content', (
			tester,
		) async {
			await pumpStubBlock(
				tester,
				block: const StubBlock(
					blockId: 1,
					overrideShowTextField: true,
					overrideHasOutputContent: false,
				),
			);
			expect(find.byKey(const Key('stub_output')), findsNothing);
			expect(find.byType(Divider), findsNothing);
		});

		testWidgets('menu is hidden on a brand-new empty editable block', (
			tester,
		) async {
			await pumpStubBlock(
				tester,
				block: StubBlock(
					blockId: 1,
					onDelete: () {},
					overrideShowTextField: true,
					overrideHasOutputContent: false,
				),
			);
			expect(find.byTooltip('Block options'), findsNothing);
		});

		testWidgets('menu is visible when editable block has input text', (
			tester,
		) async {
			await pumpStubBlock(
				tester,
				block: StubBlock(
					blockId: 1,
					text: 'hello',
					onDelete: () {},
				),
			);
			expect(find.byTooltip('Block options'), findsOneWidget);
		});

		testWidgets('menu is visible for display-only blocks even when empty', (
			tester,
		) async {
			await pumpStubBlock(
				tester,
				block: StubBlock(
					blockId: 1,
					onDelete: () {},
					overrideShowTextField: false,
					overrideHasOutputContent: true,
				),
			);
			expect(find.byTooltip('Block options'), findsOneWidget);
		});

		testWidgets('delete menu action invokes onDelete callback', (tester) async {
			var deleted = 0;
			await pumpStubBlock(
				tester,
				block: StubBlock(
					blockId: 1,
					text: 'hello',
					onDelete: () => deleted++,
				),
			);

			await tester.tap(find.byTooltip('Block options'));
			await tester.pumpAndSettle();
			await tester.tap(find.text('Delete').last);
			await tester.pumpAndSettle();

			expect(deleted, equals(1));
		});

		testWidgets('triggerResponse ignores empty text', (tester) async {
			await pumpStubBlock(tester, block: const StubBlock(blockId: 1));
			final state = tester.state<StubBlockState>(find.byType(StubBlock));

			await state.triggerResponse('   ');
			await tester.pump();

			expect(state.fetchCallCount, equals(0));
			expect(state.isLoading, isFalse);
		});

		testWidgets('triggerResponse calls fetchResponse with provided text', (
			tester,
		) async {
			await pumpStubBlock(tester, block: const StubBlock(blockId: 1));
			final state = tester.state<StubBlockState>(find.byType(StubBlock));

			await state.triggerResponse('hello world');
			await tester.pump();

			expect(state.fetchCallCount, equals(1));
			expect(state.fetchedTexts, equals(['hello world']));
		});

		testWidgets('triggerResponse notifies busy true then false', (tester) async {
			final events = <String>[];
			await pumpStubBlock(
				tester,
				block: StubBlock(
					blockId: 7,
					fetchDelay: const Duration(milliseconds: 20),
					onBusyChanged: (id, busy) => events.add('$id:$busy'),
				),
			);
			final state = tester.state<StubBlockState>(find.byType(StubBlock));

			final future = state.triggerResponse('hello');
			expect(events, equals(['7:true']));

			await tester.pump();
			await tester.pump(const Duration(milliseconds: 25));
			await future;
			await tester.pump();

			expect(events, equals(['7:true', '7:false']));
		});

		testWidgets('triggerResponse shows loading indicator while fetch is running', (
			tester,
		) async {
			await pumpStubBlock(
				tester,
				block: const StubBlock(
					blockId: 1,
					fetchDelay: Duration(milliseconds: 30),
				),
			);
			final state = tester.state<StubBlockState>(find.byType(StubBlock));

			final future = state.triggerResponse('loading');
			await tester.pump();
			expect(find.byType(CircularProgressIndicator), findsOneWidget);

			await tester.pump(const Duration(milliseconds: 35));
			await future;
			await tester.pump();
			expect(state.isLoading, isFalse);
		});

		testWidgets('triggerResponse prevents double submission while loading', (
			tester,
		) async {
			await pumpStubBlock(
				tester,
				block: const StubBlock(
					blockId: 1,
					fetchDelay: Duration(milliseconds: 40),
				),
			);
			final state = tester.state<StubBlockState>(find.byType(StubBlock));

			final future1 = state.triggerResponse('first');
			await tester.pump();
			final future2 = state.triggerResponse('second');
			await tester.pump(const Duration(milliseconds: 45));
			await future1;
			await future2;
			await tester.pump();

			expect(state.fetchCallCount, equals(1));
			expect(state.fetchedTexts, equals(['first']));
		});

		testWidgets('triggerResponse resets loading state even when fetch throws', (
			tester,
		) async {
			await pumpStubBlock(
				tester,
				block: StubBlock(
					blockId: 1,
					throwOnFetch: Exception('boom'),
				),
			);
			final state = tester.state<StubBlockState>(find.byType(StubBlock));

			await expectLater(
				() => state.triggerResponse('explode'),
				throwsA(isA<Exception>()),
			);
			await tester.pump();

			expect(state.isLoading, isFalse);
			expect(state.fetchCallCount, equals(1));
		});

		testWidgets('autoSubmit triggers fetchResponse on first frame', (
			tester,
		) async {
			await pumpStubBlock(
				tester,
				block: const StubBlock(
					blockId: 1,
					autoSubmit: true,
					text: 'auto text',
				),
			);

			await tester.pump();
			final state = tester.state<StubBlockState>(find.byType(StubBlock));

			expect(state.fetchCallCount, equals(1));
			expect(state.fetchedTexts, equals(['auto text']));
		});

		testWidgets('autoSubmit does not run when initial text is empty', (
			tester,
		) async {
			await pumpStubBlock(
				tester,
				block: const StubBlock(
					blockId: 1,
					autoSubmit: true,
					text: '   ',
				),
			);

			await tester.pump();
			final state = tester.state<StubBlockState>(find.byType(StubBlock));

			expect(state.fetchCallCount, equals(0));
		});

		testWidgets('header is rendered from subclass implementation', (tester) async {
			await pumpStubBlock(tester, block: const StubBlock(blockId: 1));
			expect(find.byKey(const Key('stub_header')), findsOneWidget);
			expect(find.text('Stub Header'), findsOneWidget);
		});

		testWidgets('buildSendToChatbotText returns textController contents by default', (
			tester,
		) async {
			await pumpStubBlock(
				tester,
				block: const StubBlock(blockId: 1, text: 'send me'),
			);
			final state = tester.state<StubBlockState>(find.byType(StubBlock));
			expect(state.buildSendToChatbotText(), equals('send me'));
		});
	});

	group('Widget Test: BaseConversationScreen — StubConversationScreen behaviour', () {
		Future<void> pumpStubScreen(
			WidgetTester tester, {
			required StubConversationScreen screen,
		}) async {
			await tester.pumpWidget(MaterialApp(home: screen));
		}

		testWidgets('creates one initial block by default on init', (tester) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(),
			);

			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);

			expect(state.bodyBlocks.length, equals(1));
			expect(state.latestBlockId, equals(0));
			expect(state.nextBlockId, equals(1));
			expect(state.canAddBlock, isFalse);
			expect(state.createNewBlockCallCount, equals(1));
		});

		testWidgets('loads history blocks when hasHistory is true', (tester) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(
					hasHistoryValue: true,
					needsInitialBlockValue: false,
					historyBlockIds: [10, 20, 30],
				),
			);

			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);

			expect(state.createHistoryBlocksCallCount, equals(1));
			expect(state.bodyBlocks.length, equals(3));
			expect(find.byType(StubBlock), findsNWidgets(3));
			expect(state.nextBlockId, equals(3));
		});

		testWidgets('loads history and still creates initial block when enabled', (
			tester,
		) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(
					hasHistoryValue: true,
					needsInitialBlockValue: true,
					historyBlockIds: [1, 2],
				),
			);

			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);

			expect(state.bodyBlocks.length, equals(3));
			expect(state.latestBlockId, equals(2));
			expect(state.nextBlockId, equals(3));
			expect(state.createHistoryBlocksCallCount, equals(1));
			expect(state.createNewBlockCallCount, equals(1));
		});

		testWidgets('does not create initial block when needsInitialBlock is false', (
			tester,
		) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(
					needsInitialBlockValue: false,
				),
			);

			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);

			expect(state.bodyBlocks, isEmpty);
			expect(state.createNewBlockCallCount, equals(0));
		});

		testWidgets('onAddBlockPressed appends a new block and updates IDs', (
			tester,
		) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(),
			);

			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);
			state.canAddBlock = true;

			state.onAddBlockPressed();
			await tester.pump();

			expect(state.bodyBlocks.length, equals(2));
			expect(state.latestBlockId, equals(1));
			expect(state.nextBlockId, equals(2));
			expect(state.canAddBlock, isFalse);
		});

		testWidgets('updateLatestBlockReply enables add when latest block has reply', (
			tester,
		) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(),
			);
			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);

			state.updateLatestBlockReply(blockId: 0, hasReply: true);
			await tester.pump();

			expect(state.canAddBlock, isTrue);
		});

		testWidgets('updateLatestBlockReply disables add when latest block has no reply', (
			tester,
		) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(),
			);
			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);

			state.updateLatestBlockReply(blockId: 0, hasReply: false);
			await tester.pump();

			expect(state.canAddBlock, isFalse);
		});

		testWidgets('updateLatestBlockReply ignores non-latest block IDs', (
			tester,
		) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(),
			);
			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);

			state.canAddBlock = false;
			state.onAddBlockPressed();
			await tester.pump();
			state.updateLatestBlockReply(blockId: 0, hasReply: true);
			await tester.pump();

			expect(state.canAddBlock, isFalse);
		});

		testWidgets('onBlockBusyChanged disables add only for latest block busy=true', (
			tester,
		) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(),
			);
			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);

			state.canAddBlock = true;
			state.onBlockBusyChanged(0, true);
			await tester.pump();

			expect(state.canAddBlock, isFalse);
		});

		testWidgets('onBlockBusyChanged ignores busy=false', (tester) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(),
			);
			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);

			state.canAddBlock = true;
			state.onBlockBusyChanged(0, false);
			await tester.pump();

			expect(state.canAddBlock, isTrue);
		});

		testWidgets('onBlockBusyChanged ignores non-latest block IDs', (
			tester,
		) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(),
			);
			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);
			state.onAddBlockPressed();
			await tester.pump();

			state.canAddBlock = true;
			state.onBlockBusyChanged(0, true);
			await tester.pump();

			expect(state.canAddBlock, isTrue);
		});

		testWidgets('deleteBlock removes a middle block without recreating list', (
			tester,
		) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(
					hasHistoryValue: true,
					needsInitialBlockValue: false,
					historyBlockIds: [1, 2, 3],
				),
			);
			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);

			state.deleteBlock(1);
			await tester.pump();

			expect(state.bodyBlocks.length, equals(2));
		});

		testWidgets('deleteBlock recreates a new block when list becomes empty', (
			tester,
		) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(),
			);
			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);

			state.deleteBlock(0);
			await tester.pump();

			expect(state.bodyBlocks.length, equals(1));
			expect(state.latestBlockId, equals(1));
			expect(state.nextBlockId, equals(2));
		});

		testWidgets('deleteBlock updates latestBlockId to last remaining block', (
			tester,
		) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(),
			);
			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);
			state.onAddBlockPressed();
			await tester.pump();
			state.onAddBlockPressed();
			await tester.pump();

			expect(state.latestBlockId, equals(2));
			state.deleteBlock(2);
			await tester.pump();

			expect(state.latestBlockId, equals(1));
			expect(state.canAddBlock, isTrue);
		});

		testWidgets(
			'deleteBlock on latest block re-enables FAB when previous block had a reply',
			(tester) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(),
			);
			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);


			state.updateLatestBlockReply(blockId: 0, hasReply: true);
			await tester.pump();
			expect(state.canAddBlock, isTrue);

			state.onAddBlockPressed();
			await tester.pump();
			expect(state.latestBlockId, equals(1));
			expect(state.canAddBlock, isFalse);

			state.deleteBlock(1);
			await tester.pump();

			expect(state.latestBlockId, equals(0));
			expect(state.canAddBlock, isTrue);

			final fab = tester.widget<FloatingActionButton>(
				find.byType(FloatingActionButton),
			);
			expect(fab.onPressed, isNotNull);
		});

		testWidgets('ellipsis trims whitespace without truncating short strings', (
			tester,
		) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(),
			);
			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);

			expect(state.ellipsis('  hello  ', 10), equals('hello'));
		});

		testWidgets('ellipsis truncates long strings and appends ...', (
			tester,
		) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(),
			);
			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);

			final result = state.ellipsis('abcdefghijklmnopqrstuvwxyz', 10);
			expect(result, equals('abcdefg...'));
			expect(result.length, equals(10));
		});

		testWidgets('buildBody renders a Scrollbar and the body blocks', (
			tester,
		) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(
					hasHistoryValue: true,
					needsInitialBlockValue: false,
					historyBlockIds: [1, 2],
				),
			);

			expect(find.byType(Scrollbar), findsOneWidget);
			expect(find.byType(ListView), findsOneWidget);
			expect(find.byType(StubBlock), findsNWidgets(2));
		});

		testWidgets('uses FloatingActionButton when onNewSession is null', (
			tester,
		) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(),
			);

			expect(find.byType(FloatingActionButton), findsOneWidget);
			expect(find.byType(LongPressFab), findsNothing);
		});

		testWidgets('uses LongPressFab when onNewSession is provided', (
			tester,
		) async {
			await pumpStubScreen(
				tester,
				screen: StubConversationScreen(onNewSessionCallback: () {}),
			);

			expect(find.byType(LongPressFab), findsOneWidget);
			expect(find.byType(FloatingActionButton), findsNothing);
		});

		testWidgets('FAB is disabled until canAddBlock becomes true', (tester) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(),
			);
			final fab = tester.widget<FloatingActionButton>(
				find.byType(FloatingActionButton),
			);
			expect(fab.onPressed, isNull);

			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);
			state.updateLatestBlockReply(blockId: 0, hasReply: true);
			await tester.pump();

			final updatedFab = tester.widget<FloatingActionButton>(
				find.byType(FloatingActionButton),
			);
			expect(updatedFab.onPressed, isNotNull);
		});

		testWidgets('tapping enabled FAB adds a block', (tester) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(),
			);
			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);
			state.updateLatestBlockReply(blockId: 0, hasReply: true);
			await tester.pump();

			await tester.tap(find.byType(FloatingActionButton));
			await tester.pump();

			expect(state.bodyBlocks.length, equals(2));
			expect(state.latestBlockId, equals(1));
		});

		testWidgets('handleNewSession long-press invokes callback', (
			tester,
		) async {
			var called = 0;
			await pumpStubScreen(
				tester,
				screen: StubConversationScreen(onNewSessionCallback: () => called++),
			);
			await tester.pump();
			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);
			expect(find.byType(LongPressFab), findsOneWidget);
			state.onNewSession?.call();
			await tester.pump();

			expect(called, equals(1));
		});

		testWidgets('handleNewSession release-early does not invoke callback', (
			tester,
		) async {
			var called = 0;
			await pumpStubScreen(
				tester,
				screen: StubConversationScreen(onNewSessionCallback: () => called++),
			);
			await tester.pump();
			await tester.tap(find.byType(LongPressFab));
			await tester.pump();

			expect(called, equals(0));
		});

		testWidgets('onBlockReplied implementation records reply payloads', (
			tester,
		) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(),
			);
			final state = tester.state<StubConversationScreenState>(
				find.byType(StubConversationScreen),
			);

			await state.onBlockReplied(
				blockId: 0,
				data: {'text': 'hello', 'answer': 'world'},
			);

			expect(state.repliedEvents.length, equals(1));
			expect(state.repliedEvents.first.blockId, equals(0));
			expect(state.repliedEvents.first.data['text'], equals('hello'));
		});

		testWidgets('scaffold renders stub app bar title', (tester) async {
			await pumpStubScreen(
				tester,
				screen: const StubConversationScreen(),
			);

			expect(find.text('Stub Conversation Screen'), findsOneWidget);
			expect(find.byType(AppBar), findsOneWidget);
		});
	});


}
