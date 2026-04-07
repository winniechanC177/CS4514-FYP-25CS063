import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import '../model/model_response.dart';

class VoiceRecorder extends StatefulWidget {
  final void Function(String text)? onTranscribed;

  const VoiceRecorder({super.key, this.onTranscribed});

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  final _recorder = AudioRecorder();
  final _model = ModelResponse();
  bool _recording = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_recording) {
      final path = await _recorder.stop();
      setState(() => _recording = false);
      if (path == null) return;

      setState(() => _isLoading = true);
      try {
        await _model.initWhisper();
        final text = await _model.transcribeAudio(path);
        if (text != null && text.isNotEmpty) {
          widget.onTranscribed?.call(text);
        }
      } finally {
        try { File(path).deleteSync(); } catch (_) {}
        setState(() => _isLoading = false);
      }
    } else {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final file = '${dir.path}/my_record.wav';
        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: file,
        );
        setState(() => _recording = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _isLoading ? null: _toggle,
          child: Icon(_recording ? Icons.stop : Icons.mic),
        ),
      ],
    );
  }
}
