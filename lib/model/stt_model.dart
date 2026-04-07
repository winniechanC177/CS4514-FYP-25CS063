import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../types/language_choose.dart';

abstract class AbstractSTTModel {
  Future<String?> transcribeAudio(String audioPath, {LanguageChoose? language});
  Future<void> initWhisper({dynamic model});
}

class STTModel implements AbstractSTTModel {
  static OfflineRecognizer? _recognizer;
  static VoiceActivityDetector? _vad;
  static Future<void>? _initFuture;
  static String? _docDir;

  static const _whisperDir = 'assets/whisper';
  static const _vadAsset   = 'assets/silero_vad.onnx';

  static Future<String> _assetFile(String asset) async {
    _docDir ??= (await getApplicationDocumentsDirectory()).path;
    final dest = File('$_docDir/$asset');
    if (!dest.existsSync()) {
      final data = await rootBundle.load(asset);
      await dest.parent.create(recursive: true);
      await dest.writeAsBytes(data.buffer.asUint8List());
    }
    return dest.path;
  }

  @override
  Future<void> initWhisper({dynamic model}) {
    return _initFuture ??= _init();
  }

  static Future<void> _init() async {
    final encoder = await _assetFile('$_whisperDir/base-encoder.int8.onnx');
    final decoder = await _assetFile('$_whisperDir/base-decoder.int8.onnx');
    final tokens  = await _assetFile('$_whisperDir/base-tokens.txt');
    final vadPath = await _assetFile(_vadAsset);

    _recognizer = OfflineRecognizer(
      OfflineRecognizerConfig(
        model: OfflineModelConfig(
          whisper: OfflineWhisperModelConfig(
            encoder: encoder,
            decoder: decoder,
            language: '',
            task: 'transcribe',
          ),
          tokens: tokens,
          numThreads: 2,
          debug: false,
          provider: 'cpu',
        ),
      ),
    );

    _vad = VoiceActivityDetector(
      config: VadModelConfig(
        sileroVad: SileroVadModelConfig(
          model: vadPath,
          minSilenceDuration: 0.5,
          minSpeechDuration: 0.25,
          windowSize: 512,
        ),
        sampleRate: 16000,
        numThreads: 1,
      ),
      bufferSizeInSeconds: 30,
    );
  }

  @override
  Future<String?> transcribeAudio(String audioPath,
      {LanguageChoose? language}) async {
    await initWhisper();
    if (_recognizer == null || _vad == null) return null;

    try {
      final samples = await _readWavSamples(audioPath);
      if (samples == null || samples.isEmpty) return null;

      _vad!.reset();

      const chunkSize = 512;
      for (var i = 0; i < samples.length; i += chunkSize) {
        final end = (i + chunkSize).clamp(0, samples.length);
        _vad!.acceptWaveform(samples.sublist(i, end));
      }
      _vad!.flush();

      final results = <String>[];
      while (!_vad!.isEmpty()) {
        final segment = _vad!.front();
        _vad!.pop();

        final stream = _recognizer!.createStream();
        stream.acceptWaveform(samples: segment.samples, sampleRate: 16000);
        _recognizer!.decode(stream);
        final text = _recognizer!.getResult(stream).text.trim();
        stream.free();

        if (text.isNotEmpty) results.add(text);
      }

      return results.isEmpty ? null : results.join(' ');
    } catch (e) {
      return null;
    } finally {
      _vad?.reset();
    }
  }

  static Future<Float32List?> _readWavSamples(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.length < 44) return null;

      int dataOffset = 44;
      for (int i = 12; i < bytes.length - 8; i++) {
        if (bytes[i] == 0x64 && bytes[i + 1] == 0x61 &&
            bytes[i + 2] == 0x74 && bytes[i + 3] == 0x61) {
          dataOffset = i + 8;
          break;
        }
      }

      final numSamples = (bytes.length - dataOffset) ~/ 2;
      final out = Float32List(numSamples);
      final bd = ByteData.sublistView(bytes);
      for (int i = 0; i < numSamples; i++) {
        out[i] = bd.getInt16(dataOffset + i * 2, Endian.little) / 32768.0;
      }
      return out;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static Future<Float32List?> readWavSamplesForTest(String path) =>
      _readWavSamples(path);
}
