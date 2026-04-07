import 'package:flutter/material.dart';
import '../utils/voice_recorder.dart';
import '../model/model_response.dart' as modelResponse;
import 'dart:io';
import 'dart:typed_data';
import '../utils/image_pick.dart';
import '../base/base_block.dart';
import 'chatbot_suggestions.dart';

class ChatbotBlock extends BaseBlock {
  final String? answer;
  final ChatbotSuggestion? suggestion;
  final Uint8List? imageBytes;
  final Future<void> Function({
    required int blockId,
    required String text,
    required String answer,
    Uint8List? imageBytes,
  })? onReplied;

  const ChatbotBlock({
    super.key,
    required super.blockId,
    super.text,
    super.onBusyChanged,
    super.onDelete,
    super.autoSubmit,
    this.answer,
    this.suggestion,
    this.imageBytes,
    this.onReplied,
  });

  @override
  State<ChatbotBlock> createState() => _ChatbotBlockState();
}

class _ChatbotBlockState extends BaseBlockState<ChatbotBlock> {
  final _modelResponse = modelResponse.ModelResponse();

  String? _answer;
  File? _imageFile;
  Uint8List? _imageBytes;
  ChatbotSuggestion? _selectedSuggestion;

  @override
  bool get hasOutputContent => (_answer ?? '').trim().isNotEmpty;

  bool get _hasImage => _imageFile != null || _imageBytes != null;

  Future<Uint8List?> get _resolvedImageBytes async {
    if (_imageFile != null) return await _imageFile!.readAsBytes();
    return _imageBytes;
  }

  void _showFullImage() {
    final file = _imageFile;
    final bytes = _imageBytes;
    if (file == null && bytes == null) return;

    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: file != null
                ? Image.file(file, fit: BoxFit.contain)
                : Image.memory(bytes!, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  @override
  void onInitExtra() {
    _answer = widget.answer;
    _selectedSuggestion = widget.suggestion;
    _imageBytes = widget.imageBytes;
  }

  @override
  Future<void> fetchResponse(String text) async {
    final fullText = _selectedSuggestion != null
        ? '${_selectedSuggestion!.prompt}$text'
        : text;

    try {
      final imageBytes = await _resolvedImageBytes;
      final response = await _modelResponse.chatbotResponse(fullText, imageBytes);
      if (!mounted) return;
      setState(() => _answer = response);
      await widget.onReplied?.call(
        blockId: widget.blockId,
        text: fullText,
        answer: _answer ?? '',
        imageBytes: imageBytes,
      );
    } catch (e) {
      if (mounted) setState(() => _answer = 'error: $e');
    }
  }

  @override
  Widget buildInputHeader() => const Text(
        'Your Question:',
        style: TextStyle(fontWeight: FontWeight.bold),
      );

  @override
  Widget buildInputFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatbotSuggestionsBar(
          selected: _selectedSuggestion,
          onChanged: (s) {
            setState(() => _selectedSuggestion = s);
            if (s != null) FocusScope.of(context).requestFocus(focusNode);
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton(
              onPressed: () async {
                final picked = await pickImageFromGallery();
                setState(() {
                  _imageFile = picked;
                  if (picked != null) _imageBytes = null;
                });
              },
              child: const Icon(Icons.image),
            ),
            if (_hasImage)
              ElevatedButton(
                onPressed: () => setState(() {
                  _imageFile = null;
                  _imageBytes = null;
                }),
                child: const Text('Clear Image'),
              ),
            VoiceRecorder(
              onTranscribed: (t) {
                textController.text = t;
                triggerResponse(t);
              },
            ),
          ],
        ),
        if (_hasImage) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _showFullImage,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _imageFile != null
                  ? Image.file(_imageFile!, width: 96, height: 96, fit: BoxFit.cover)
                  : Image.memory(_imageBytes!, width: 96, height: 96, fit: BoxFit.cover),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget buildOutputContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chatbot Response:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(_answer ?? '', style: TextStyle(fontSize: dynamicFontSize(_answer ?? ''))),
      ],
    );
  }
}
