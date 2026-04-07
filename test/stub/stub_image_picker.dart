import 'dart:io';
import 'package:SLMTranslator/utils/image_pick.dart';

class FakeImagePicker implements AbstractImagePicker {
  File? fileToReturn;
  bool returnNull = false;
  Exception? throwOnNextCall;
  int callCount = 0;

  @override
  Future<File?> pickFromGallery() async {
    if (throwOnNextCall != null) {
      final ex = throwOnNextCall!;
      throwOnNextCall = null;
      throw ex;
    }
    callCount++;
    if (returnNull) return null;
    return fileToReturn;
  }
}
