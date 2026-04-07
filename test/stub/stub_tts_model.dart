import 'dart:typed_data';
import 'package:SLMTranslator/model/tts_model.dart';
import 'package:SLMTranslator/types/language_choose.dart';

class StubTTSModel implements AbstractTTSModel {

  Int16List? overrideAudioData;
  Exception? throwOnNextCall;

  final List<({String word, LanguageChoose language})> receivedRequests = [];

  int callCount = 0;


  @override
  Future<Int16List> pronunciationResponse(
      String word, LanguageChoose language) async {
    _checkThrow();
    callCount++;
    receivedRequests.add((word: word, language: language));
    return overrideAudioData ?? _silence();
  }

  static Int16List _silence() => Int16List(2400);

  void _checkThrow() {
    if (throwOnNextCall != null) {
      final ex = throwOnNextCall!;
      throwOnNextCall = null;
      throw ex;
    }
  }
}

