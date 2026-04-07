// ============================================================
//  FakeSTTModel — deterministic stub for AbstractSTTModel
//
//  Returns instant transcriptions without touching the ONNX
//  Whisper / Silero VAD engines.
//
//  Usage:
//    final fake = FakeSTTModel();
//    final mr   = ModelResponse(sttModel: fake);
//
//  Configurable per-test:
//    fake.overrideTranscription = 'hello world';
//    fake.returnNull            = true;   // simulate no speech detected
//    fake.throwOnNextCall       = Exception('STT failed');
// ============================================================

import 'package:SLMTranslator/model/stt_model.dart';
import 'package:SLMTranslator/types/language_choose.dart';

class StubSTTModel implements AbstractSTTModel {
  String? overrideTranscription;
  bool returnNull = false;
  Exception? throwOnNextCall;
  final List<String> receivedAudioPaths = [];
  int transcribeCallCount = 0;
  int initCallCount = 0;

  @override
  Future<String?> transcribeAudio(String audioPath,
      {LanguageChoose? language}) async {
    _checkThrow();
    transcribeCallCount++;
    receivedAudioPaths.add(audioPath);
    if (returnNull) return null;
    return overrideTranscription ?? '[stub transcription]';
  }

  @override
  Future<void> initWhisper({dynamic model}) async {
    initCallCount++;
  }

  void _checkThrow() {
    if (throwOnNextCall != null) {
      final ex = throwOnNextCall!;
      throwOnNextCall = null;
      throw ex;
    }
  }
}

