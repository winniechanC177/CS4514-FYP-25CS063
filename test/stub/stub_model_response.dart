import 'package:SLMTranslator/model/model_response.dart';
import 'stub_gemma_model.dart';
import 'stub_tts_model.dart';
import 'stub_stt_model.dart';

class StubModelResponse {
  final StubGemmaModel gemma = StubGemmaModel();
  final StubTTSModel tts = StubTTSModel();
  final StubSTTModel stt = StubSTTModel();

  late final ModelResponse response;

  StubModelResponse() {
    response = ModelResponse(
      gemmaModel: gemma,
      ttsModel: tts,
      sttModel: stt,
    );
  }
}

