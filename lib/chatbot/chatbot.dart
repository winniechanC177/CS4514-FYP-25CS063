import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'chatbot_block.dart';
import '../database/database_helper.dart' as dbHelper;
import '../base/base_conversation_screen.dart';
import 'chatbot_suggestions.dart';

class Chatbot extends StatefulWidget {
  final int? sessionId;
  final List<Map<String, dynamic>>? chatbotHistory;
  final VoidCallback? onNewSession;
  final ValueChanged<int>? onSessionCreated;
  final String? initialQuery;
  final ChatbotSuggestion? initialSuggestion;

  const Chatbot({
    super.key,
    this.sessionId,
    this.chatbotHistory,
    this.onNewSession,
    this.onSessionCreated,
    this.initialQuery,
    this.initialSuggestion,
  });

  @override
  State<Chatbot> createState() => _ChatbotState();
}

class _ChatbotState extends BaseConversationScreenState<Chatbot> {
  int? _sessionId;
  bool _initialQueryUsed = false;
  final Map<int, int> _blockItemIds = {};

  @override
  void initState() {
    _sessionId = widget.sessionId;
    super.initState();
  }

  @override
  bool hasHistory() => widget.chatbotHistory != null;

  @override
  Widget createNewBlock({required int blockId}) {
    final seedQuery = !_initialQueryUsed ? widget.initialQuery : null;
    if (seedQuery != null && seedQuery.trim().isNotEmpty) {
      _initialQueryUsed = true;
    }

    return ChatbotBlock(
      blockId: blockId,
      text: seedQuery,
      suggestion: seedQuery != null ? widget.initialSuggestion : null,
      autoSubmit: seedQuery != null,
      onBusyChanged: onBlockBusyChanged,
      onDelete: () async {
        final itemId = _blockItemIds[blockId];
        if (itemId != null) {
          await dbHelper.DatabaseHelper.instance.deleteChatbotItem(itemId);
          _blockItemIds.remove(blockId);
          await _refreshSessionMetadata();
        }
        deleteBlock(blockId);
      },
      onReplied: ({
        required int blockId,
        required String text,
        required String answer,
        Uint8List? imageBytes,
      }) async {
        updateLatestBlockReply(blockId: blockId, hasReply: answer.trim().isNotEmpty);
        await onBlockReplied(
          blockId: blockId,
          data: {'text': text, 'answer': answer, 'imageBytes': imageBytes},
        );
      },
    );
  }

  @override
  List<Widget> createHistoryBlocks() {
    return widget.chatbotHistory!.map((item) {
      final id = nextBlockId++;
      final itemId = item['ChatbotItemID'] as int?;
      if (itemId != null) _blockItemIds[id] = itemId;
      final suggestion = ChatbotSuggestion.tryFromName(item['Suggestion'] as String?);
      final imageBase64 = item['Image'] as String?;
      final imageBytes = imageBase64 != null ? base64Decode(imageBase64) : null;
      return ChatbotBlock(
        blockId: id,
        text: _stripSuggestionPrefix(item['Text'] as String? ?? ''),
        answer: item['Answer'] as String?,
        suggestion: suggestion,
        imageBytes: imageBytes,
        onBusyChanged: onBlockBusyChanged,
        onDelete: () async {
          if (itemId != null) {
            await dbHelper.DatabaseHelper.instance.deleteChatbotItem(itemId);
            await _refreshSessionMetadata();
          }
          deleteBlock(id);
        },
        onReplied: ({
          required int blockId,
          required String text,
          required String answer,
          Uint8List? imageBytes,
        }) async {
          updateLatestBlockReply(blockId: blockId, hasReply: answer.trim().isNotEmpty);
          await onBlockReplied(
            blockId: blockId,
            data: {'text': text, 'answer': answer, 'imageBytes': imageBytes},
          );
        },
      );
    }).toList();
  }

  @override
  Future<void> onBlockReplied({
    required int blockId,
    required Map<String, dynamic> data,
  }) async {

    final existingItemId = _blockItemIds[blockId];
    if (existingItemId == null && blockId != latestBlockId) return;

    final text = data['text'] as String;
    final answer = data['answer'] as String;
    final imageBytes = data['imageBytes'] as Uint8List?;

    if (answer.trim().isEmpty) return;

    final isNewSession = _sessionId == null;
    _sessionId ??= await dbHelper.DatabaseHelper.instance.createChatbotSession(
      'Chatbot',
      '0 chats',
    );
    if (isNewSession) widget.onSessionCreated?.call(_sessionId!);

    final suggestion = detectSuggestion(text);
    if (existingItemId != null) {
      await dbHelper.DatabaseHelper.instance.updateChatbotItem(
        itemId: existingItemId,
        text: text,
        answer: answer,
        suggestion: suggestion,
        image: imageBytes != null ? base64Encode(imageBytes) : null,
      );
    } else {
      final newItemId = await dbHelper.DatabaseHelper.instance.createChatbotItem(
        sessionId: _sessionId!,
        text: text,
        answer: answer,
        suggestion: suggestion,
        image: imageBytes != null ? base64Encode(imageBytes) : null,
      );
      _blockItemIds[blockId] = newItemId;
    }
    await _refreshSessionMetadata();
  }

  Future<void> _refreshSessionMetadata() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;

    final db = dbHelper.DatabaseHelper.instance;
    final items = await db.getChatbotSessionItems(sessionId);
    final title = _buildHistoryTitleFromItems(items);
    final description = _buildHistoryDescriptionFromItems(items);

    await db.updateSessionTitle(sessionId, 'chatbot', title);
    await db.updateSessionContent(sessionId, 'chatbot', description);
  }

  String _buildHistoryTitleFromItems(List<Map<String, dynamic>> items) {
    final texts = items.reversed
        .map((i) => _stripSuggestionPrefix((i['Text'] as String? ?? '').trim()))
        .where((t) => t.isNotEmpty)
        .toList();
    if (texts.isEmpty) return 'Chatbot';
    return ellipsis(texts.join(' | '), maxTitleLength);
  }

  String _buildHistoryDescriptionFromItems(List<Map<String, dynamic>> items) {
    final labels = <String>[];
    for (final item in items) {
      final text = (item['Text'] as String? ?? '').trim();
      if (text.isEmpty) continue;
      final label = detectSuggestion(text)?.label ?? 'Free Chat';
      if (!labels.contains(label)) labels.add(label);
    }
    final count = items.length;
    final unit = count == 1 ? 'chat' : 'chats';
    final labelStr = labels.isEmpty ? 'Free Chat' : labels.join(' + ');
    return ellipsis('$labelStr · $count $unit', maxContentLength);
  }

  String _stripSuggestionPrefix(String text) {
    final suggestion = detectSuggestion(text);
    if (suggestion == null) return text.trim();
    final trimmed = text.trim();
    if (trimmed.length <= suggestion.prompt.length) return trimmed;
    return trimmed.substring(suggestion.prompt.length).trim();
  }

  @override
  VoidCallback? get onNewSession => widget.onNewSession;

  @override
  Future<void> onBlocksEmpty() async {
    final sessionId = _sessionId;
    if (sessionId != null) {
      await dbHelper.DatabaseHelper.instance.deleteSession(sessionId, 'chatbot');
      _sessionId = null;
    }
    widget.onNewSession?.call();
  }
}
