import 'package:flutter/material.dart';
import 'base_block.dart';
import 'long_press_fab.dart';

abstract class BaseConversationScreenState<T extends StatefulWidget>
    extends State<T> {
  final List<Widget> bodyBlocks = [];
  bool canAddBlock = false;
  int latestBlockId = -1;
  int nextBlockId = 0;
  late final ScrollController scrollController;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    _initialize();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void _initialize() {
    if (hasHistory()) {
      for (final w in createHistoryBlocks()) {
        bodyBlocks.add(w);
      }
    }
    if (needsInitialBlock) {
      _createAndAddNewBlock();
    }
  }

  void _createAndAddNewBlock() {
    final id = nextBlockId++;
    latestBlockId = id;
    setState(() {
      canAddBlock = false;
      bodyBlocks.add(createNewBlock(blockId: id));
    });
  }

  void onAddBlockPressed() {
    _createAndAddNewBlock();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool get needsInitialBlock => true;
  bool hasHistory();
  Widget createNewBlock({required int blockId});
  List<Widget> createHistoryBlocks();

  Future<void> onBlockReplied({
    required int blockId,
    required Map<String, dynamic> data,
  });

  VoidCallback? get onNewSession => null;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(),
      body: buildBody(),
      floatingActionButton: buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget? buildAppBar() => null;

  Widget buildBody() {
    return Scrollbar(
      child: ListView.builder(
        controller: scrollController,
        itemCount: bodyBlocks.length,
        itemBuilder: (context, index) {
          final w = bodyBlocks[index];
          final key = w is BaseBlock ? ValueKey(w.blockId) : ValueKey(index);
          return KeyedSubtree(key: key, child: w);
        },
      ),
    );
  }

  Widget buildFloatingActionButton() {
    return buildLongPressFab(
      onTap: canAddBlock ? onAddBlockPressed : null,
      onLongPress: onNewSession,
      tooltip: 'Tap to add block · Long press for new session',
    );
  }

  Widget buildLongPressFab({
    required VoidCallback? onTap,
    VoidCallback? onLongPress,
    String tooltip = '',
    Object? heroTag,
    IconData icon = Icons.add,
  }) {
    if (onLongPress == null) {
      return FloatingActionButton(
        heroTag: heroTag,
        onPressed: onTap,
        tooltip: tooltip,
        child: Icon(icon),
      );
    }
    return LongPressFab(
      onTap: onTap,
      onLongPressCompleted: onLongPress,
      tooltip: tooltip,
      icon: icon,
    );
  }

  String ellipsis(String text, int maxLen) {
    final trimmed = text.trim();
    if (trimmed.length <= maxLen) return trimmed;
    return '${trimmed.substring(0, maxLen - 3)}...';
  }

  int get maxTitleLength   => 48;
  int get maxContentLength => 120;

  void onBlockBusyChanged(int blockId, bool isBusy) {
    if (blockId != latestBlockId) return;
    if (!isBusy) return;
    if (mounted) {
      setState(() {
        canAddBlock = false;
      });
    }
  }

  Future<void> onBlocksEmpty() async {}

  void deleteBlock(int blockId) {
    if (!mounted) return;
    bool becameEmpty = false;
    setState(() {
      bodyBlocks.removeWhere((w) => w is BaseBlock && w.blockId == blockId);

      final hasOnlyTail = bodyBlocks.length == 1 &&
          bodyBlocks.first is BaseBlock &&
          (bodyBlocks.first as BaseBlock).blockId == latestBlockId &&
          !canAddBlock;

      if (hasOnlyTail) bodyBlocks.clear();

      becameEmpty = bodyBlocks.isEmpty;

      if (!becameEmpty && blockId == latestBlockId) {
        final last = bodyBlocks.last;
        if (last is BaseBlock) latestBlockId = last.blockId;
        canAddBlock = true;
      }
    });
    if (becameEmpty) _handleBlocksEmpty();
  }

  bool get createBlockOnEmpty => true;

  Future<void> _handleBlocksEmpty() async {
    await onBlocksEmpty();
    if (mounted && bodyBlocks.isEmpty && createBlockOnEmpty) {
      setState(() {
        final id = nextBlockId++;
        latestBlockId = id;
        canAddBlock = false;
        bodyBlocks.add(createNewBlock(blockId: id));
      });
    }
  }

  void updateLatestBlockReply({
    required int blockId,
    required bool hasReply,
  }) {
    if (blockId != latestBlockId) return;
    if (mounted) {
      setState(() {
        canAddBlock = hasReply;
      });
    }
  }
}
