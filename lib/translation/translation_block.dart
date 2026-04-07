import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../types/language_choose.dart';
import '../model/model_response.dart' as modelResponse;
import '../utils/audio_player.dart';
import '../utils/voice_recorder.dart';
import '../base/base_block.dart';

class TranslationBlock extends BaseBlock {
  final LanguageChoose? language;
  final LanguageChoose? convLanguage;
  final String? convText;
  final Future<void> Function({
    required int blockId,
    required LanguageChoose lang,
    required LanguageChoose convLang,
    required String text,
    required String convText,
  })? onReplied;
  final void Function(LanguageChoose? lang, LanguageChoose convLang)? onLanguageChanged;

  const TranslationBlock({
    super.key,
    required super.blockId,
    super.text,
    super.onBusyChanged,
    super.onDelete,
    super.onSendToChatbot,
    this.language,
    this.convLanguage,
    this.convText,
    this.onReplied,
    this.onLanguageChanged,
  });

  @override
  State<TranslationBlock> createState() => _TranslationBlockState();
}

class _TranslationBlockState extends BaseBlockState<TranslationBlock> {
  LanguageChoose? _language;
  LanguageChoose _convLanguage = LanguageChoose.chineseTraditional;
  String? _convText;
  Int16List? _soundData;
  bool _isVoiceLoading = false;

  @override
  bool get hasOutputContent =>
      (_convText ?? '').trim().isNotEmpty ||
      _soundData != null ||
      _isVoiceLoading;

  @override
  void dispose() {
    _soundData = null;
    super.dispose();
  }

  @override
  void onInitExtra() {
    _language = widget.language;
    _convLanguage = widget.convLanguage ?? LanguageChoose.chineseTraditional;
    _convText = widget.convText;
  }

  Future<void> _generateVoice(String text, LanguageChoose lang) async {
    if (mounted) setState(() => _isVoiceLoading = true);
    final sw = Stopwatch()..start();
    try {
      final data = await modelResponse.ModelResponse().pronunciationResponse(text, lang);
      sw.stop();
      debugPrint('[Timer] Voice generation took ${sw.elapsedMilliseconds} ms');
      if (mounted) setState(() => _soundData = data);
    } catch (e) {
      sw.stop();
      debugPrint('Voice generation failed: $e');
    } finally {
      if (mounted) setState(() => _isVoiceLoading = false);
    }
  }

  @override
  Future<void> fetchResponse(String text) async {
    final sw = Stopwatch()..start();
    try {
      final response = await modelResponse.ModelResponse()
          .translateResponse(
            _language,
            _convLanguage,
            text,
          );
      sw.stop();
      debugPrint('[Timer] Translation model took ${sw.elapsedMilliseconds} ms');
      if (!mounted) return;
      setState(() {
        _convText = response;
        _soundData = null;
      });
      await widget.onReplied?.call(
        blockId: widget.blockId,
        text: text,
        convText: response,
        lang: _language ?? LanguageChoose.english,
        convLang: _convLanguage,
      );
    } catch (e) {
      sw.stop();
      debugPrint('[Timer] Translation model failed after ${sw.elapsedMilliseconds} ms');
      if (mounted) {
        final msg = 'error: $e';
        setState(() => _convText = msg);
      }
    }
  }

  @override
  String buildSendToChatbotText() {
    final source = textController.text.trim();
    final translated = (_convText ?? '').trim();
    if (translated.isEmpty) return source;
    return 'Original: $source\n'
        'Translation: $translated';
  }

  List<DropdownMenuItem<LanguageChoose?>> _buildSrcItems() => [
        const DropdownMenuItem(
          value: null,
          child: Text('Auto detect', overflow: TextOverflow.ellipsis),
        ),
        ...LanguageChoose.values
            .where((l) => l == _language || l != _convLanguage)
            .map((l) => DropdownMenuItem(
                  value: l,
                  child: Text(l.label, overflow: TextOverflow.ellipsis),
                )),
      ];

  List<DropdownMenuItem<LanguageChoose>> _buildDstItems() => LanguageChoose
      .values
      .where((l) => l == _convLanguage || l != _language)
      .map((l) => DropdownMenuItem(
            value: l,
            child: Text(l.label, overflow: TextOverflow.ellipsis),
          ))
      .toList();


  Widget _buildLangDropdown() => DropdownButton<LanguageChoose?>(
        isExpanded: true,
        value: _language,
        items: _buildSrcItems(),
        onChanged: (v) {
          setState(() => _language = v);
          widget.onLanguageChanged?.call(v, _convLanguage);
          final text = textController.text.trim();
          if (text.isNotEmpty) triggerResponse(text);
        },
      );

  Widget _buildConvLangDropdown() => DropdownButton<LanguageChoose>(
        isExpanded: true,
        value: _convLanguage,
        items: _buildDstItems(),
        onChanged: (v) {
          if (v != null) {
            setState(() => _convLanguage = v);
            widget.onLanguageChanged?.call(_language, v);
            final text = textController.text.trim();
            if (text.isNotEmpty) triggerResponse(text);
          }
        },
      );

  @override
  Widget buildInputHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _buildLangDropdown()),
        IconButton(
          onPressed: _language == null
              ? null
              : () {
                  setState(() {
                    final temp = _language!;
                    _language = _convLanguage;
                    _convLanguage = temp;
                  });
                  widget.onLanguageChanged?.call(_language, _convLanguage);
                  final text = textController.text.trim();
                  if (text.isNotEmpty) triggerResponse(text);
                },
          icon: const Icon(Icons.swap_horiz, color: Colors.grey),
        ),
        Expanded(child: _buildConvLangDropdown()),
      ],
    );
  }

  @override
  Widget buildInputFooter() => VoiceRecorder(
        onTranscribed: (t) {
          textController.text = t;
          triggerResponse(t);
        },
      );

  @override
  Widget buildOutputContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Translate Response:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
              _convText ?? '',
              style: TextStyle(
                fontSize: dynamicFontSize(_convText ?? ''),
              ),
            ),
        if (_isVoiceLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('Generating voice...', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        if (_soundData != null && !_isVoiceLoading)
          AudioPlayer(soundData: _soundData!),
        if (_soundData == null && !_isVoiceLoading && (_convText ?? '').isNotEmpty)
          OutlinedButton(
            onPressed: _convLanguage.hasTtsSupport
                ? () => _generateVoice(_convText!, _convLanguage)
                : null,
            child: const Icon(Icons.play_arrow_outlined),
          ),
      ],
    );
  }
}
