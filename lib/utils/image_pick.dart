import 'package:image_picker/image_picker.dart';
import 'dart:io';

abstract class AbstractImagePicker {
  Future<File?> pickFromGallery();
}

class DefaultImagePicker implements AbstractImagePicker {
  @override
  Future<File?> pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    return image != null ? File(image.path) : null;
  }
}

Future<File?> pickImageFromGallery() => DefaultImagePicker().pickFromGallery();
