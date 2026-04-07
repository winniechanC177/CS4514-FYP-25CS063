import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import '../types/language_choose.dart';

abstract class AbstractTTSModel {
  Future<Int16List> pronunciationResponse(String word, LanguageChoose language);
}

class TTSModel implements AbstractTTSModel {
  static OfflineTts? _tts;
  static Future<void>? _initFuture;
  static String? _docDir;

  static const _dir = 'assets/kokoro-int8-multi-lang-v1_0';

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

  static Future<String> _assetDirExtract(String assetDir) async {
    _docDir ??= (await getApplicationDocumentsDirectory()).path;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final files = manifest.listAssets()
        .where((k) => k.startsWith('$assetDir/'))
        .toList();
    for (final asset in files) {
      final dest = File('$_docDir/$asset');
      if (!dest.existsSync()) {
        final data = await rootBundle.load(asset);
        await dest.parent.create(recursive: true);
        await dest.writeAsBytes(data.buffer.asUint8List());
      }
    }
    return '$_docDir/$assetDir';
  }

  static Future<void> initTtsOnce() {
    return _initFuture ??= () async {
      final files = await Future.wait([
        _assetFile('$_dir/model.int8.onnx'),
        _assetFile('$_dir/voices.bin'),
        _assetFile('$_dir/tokens.txt'),
        _assetFile('$_dir/lexicon-us-en.txt'),
        _assetFile('$_dir/lexicon-zh.txt'),
        _assetFile('$_dir/date-zh.fst'),
        _assetFile('$_dir/number-zh.fst'),
        _assetFile('$_dir/phone-zh.fst'),
      ]);
      final model     = files[0];
      final voices    = files[1];
      final tokens    = files[2];
      final lexiconEn = files[3];
      final lexiconZh = files[4];
      final dateZh    = files[5];
      final numberZh  = files[6];
      final phoneZh   = files[7];

      final dirs = await Future.wait([
        _assetDirExtract('$_dir/espeak-ng-data'),
        _assetDirExtract('$_dir/dict'),
      ]);
      final dataDir = dirs[0];
      final dictDir = dirs[1];

      final config = OfflineTtsConfig(
        model: OfflineTtsModelConfig(
          kokoro: OfflineTtsKokoroModelConfig(
            model: model,
            voices: voices,
            tokens: tokens,
            dataDir: dataDir,
            dictDir: dictDir,
            lexicon: '$lexiconEn,$lexiconZh',
          ),
          numThreads: 2,
          debug: false,
          provider: 'cpu',
        ),
        ruleFsts: '$dateZh,$numberZh,$phoneZh',
      );
      _tts = OfflineTts(config);
    }();
  }

  @override
  Future<Int16List> pronunciationResponse(
      String word, LanguageChoose language) async {
    final sid = language.sid;
    if (sid == null) return Int16List(0);
    await initTtsOnce();
    final audio = _tts!.generate(
      text: word,
      sid: sid,
      speed: 1.0,
    );
    return _float32ToInt16(audio.samples);
  }

  static Int16List _float32ToInt16(Float32List samples) {
    final out = Int16List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      out[i] = (samples[i] * 32767.0).clamp(-32768.0, 32767.0).toInt();
    }
    return out;
  }

  @visibleForTesting
  static int? speakerSidForTest(LanguageChoose language) => language.sid;

  @visibleForTesting
  static Int16List float32ToInt16ForTest(Float32List samples) =>
      _float32ToInt16(samples);
}
