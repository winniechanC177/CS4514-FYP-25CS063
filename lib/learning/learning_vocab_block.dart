import 'package:flutter/material.dart';
import '../base/base_block.dart';
import '../types/language_choose.dart';

import 'vocab_entry.dart';
import 'dart:typed_data';
import '../utils/audio_player.dart';
import '../model/model_response.dart' as modelResponse;

class LearningVocabBlock extends BaseBlock {
  final LanguageChoose language;
  final LanguageChoose convLanguage;
  final String convText;
  final String? example;
  final EntryType entryType;

  const LearningVocabBlock({
    super.key,
    required super.blockId,
    required super.text,
    super.onDelete,
    super.onSendToChatbot,
    required this.language,
    required this.convLanguage,
    required this.convText,
    this.example,
    this.entryType = EntryType.vocab,
  });

  @override
  State<LearningVocabBlock> createState() => _LearningVocabBlockState();
}

class _LearningVocabBlockState extends BaseBlockState<LearningVocabBlock> {
  Int16List? _srcSoundData;
  bool _srcVoiceLoading = false;
  Int16List? _convSoundData;
  bool _convVoiceLoading = false;

  @override
  void dispose() {
    _srcSoundData = null;
    _convSoundData = null;
    super.dispose();
  }

  @override
  bool get showTextField => false;

  @override
  Future<void> fetchResponse(String text) async {}

  @override
  String buildSendToChatbotText() {
    final src = (widget.text ?? '').trim();
    final dst = widget.convText.trim();
    final ex = (widget.example ?? '').trim();
    final base = 'Help me study this vocabulary.\n'
        'Source (${widget.language.label}): $src\n'
        'Target (${widget.convLanguage.label}): $dst';
    if (ex.isEmpty) return base;
    return '$base\nExample: $ex';
  }

  Future<void> _generateVoice(String text, LanguageChoose lang, bool isSrc) async {
    if (isSrc ? _srcVoiceLoading : _convVoiceLoading) return;
    setState(() => isSrc ? _srcVoiceLoading = true : _convVoiceLoading = true);
    try {
      final data = await modelResponse.ModelResponse()
          .pronunciationResponse(text, lang);
      if (mounted) setState(() => isSrc ? _srcSoundData = data : _convSoundData = data);
    } catch (e) {
      debugPrint('Voice generation failed: $e');
    } finally {
      if (mounted) setState(() => isSrc ? _srcVoiceLoading = false : _convVoiceLoading = false);
    }
  }

  Widget _buildAudioRow({
    required Int16List? soundData,
    required bool isLoading,
    required VoidCallback? onPlay,
  }) {
    if (isLoading) {
      return const Row(children: [
        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 8),
        Text('Generating voice...', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]);
    }
    if (soundData != null) return AudioPlayer(soundData: soundData);
    return OutlinedButton(
      onPressed: onPlay,
      child: const Icon(Icons.volume_up_outlined),
    );
  }

  @override
  Widget buildInputHeader() {
    final displayText = widget.text ?? '';
    final audioLang = widget.language;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.language.label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(displayText, style: const TextStyle(fontSize: 36)),
        const SizedBox(height: 4),
        _buildAudioRow(
          soundData: _srcSoundData,
          isLoading: _srcVoiceLoading,
          onPlay: audioLang.hasTtsSupport
              ? () => _generateVoice(displayText, audioLang, true)
              : null,
        ),
      ],
    );
  }

  @override
  Widget buildInputFooter() => const SizedBox.shrink();

  @override
  Widget buildOutputContent() {
    final displayText = widget.convText;
    final audioLang = widget.convLanguage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.convLanguage.label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(displayText, style: const TextStyle(fontSize: 28)),
        if (widget.example != null && widget.example!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            widget.example!,
            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
          ),
        ],
        const SizedBox(height: 4),
        _buildAudioRow(
          soundData: _convSoundData,
          isLoading: _convVoiceLoading,
          onPlay: audioLang.hasTtsSupport
              ? () => _generateVoice(displayText, audioLang, false)
              : null,
        ),
      ],
    );
  }
}
