import 'package:flutter/material.dart';
import 'package:SLMTranslator/base/base_conversation_screen.dart';
import 'stub_block.dart';

class StubConversationScreen extends StatefulWidget {
  final bool hasHistoryValue;
  final bool needsInitialBlockValue;
  final List<int> historyBlockIds;
  final VoidCallback? onNewSessionCallback;

  const StubConversationScreen({
    super.key,
    this.hasHistoryValue = false,
    this.needsInitialBlockValue = true,
    this.historyBlockIds = const [],
    this.onNewSessionCallback,
  });

  @override
  State<StubConversationScreen> createState() => StubConversationScreenState();
}

class StubConversationScreenState
    extends BaseConversationScreenState<StubConversationScreen> {
  final List<({int blockId, Map<String, dynamic> data})> repliedEvents = [];
  int createNewBlockCallCount = 0;
  int createHistoryBlocksCallCount = 0;

  @override
  bool get needsInitialBlock => widget.needsInitialBlockValue;

  @override
  bool hasHistory() => widget.hasHistoryValue;

  @override
  VoidCallback? get onNewSession => widget.onNewSessionCallback;

  @override
  PreferredSizeWidget? buildAppBar() =>
      AppBar(title: const Text('Stub Conversation Screen'));

  @override
  Widget createNewBlock({required int blockId}) {
    createNewBlockCallCount++;
    return StubBlock(
      key: ValueKey('new-block-$blockId'),
      blockId: blockId,
      text: 'new-$blockId',
      onBusyChanged: onBlockBusyChanged,
      onDelete: () => deleteBlock(blockId),
    );
  }

  @override
  List<Widget> createHistoryBlocks() {
    createHistoryBlocksCallCount++;
    return widget.historyBlockIds.map((_) {
      final id = nextBlockId++;
      return StubBlock(
        key: ValueKey('history-block-$id'),
        blockId: id,
        text: 'history-$id',
        onBusyChanged: onBlockBusyChanged,
        onDelete: () => deleteBlock(id),
      );
    }).toList();
  }

  @override
  Future<void> onBlockReplied({
    required int blockId,
    required Map<String, dynamic> data,
  }) async {
    repliedEvents.add((blockId: blockId, data: data));
  }

  Widget buildLongPressFabForTest({
    required VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return buildLongPressFab(
      onTap: onTap,
      onLongPress: onLongPress,
      tooltip: 'stub fab',
    );
  }
}

