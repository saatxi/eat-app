import 'package:image_picker/image_picker.dart';

import 'photo_picker.dart';

/// The real [PhotoPicker], backed by `image_picker`'s system picker (the Android
/// Photo Picker on modern Android, `PHPickerViewController` on iOS).
///
/// Both use the system picker rather than a broad library read, which is why the
/// app needs no runtime permission for this.
class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pickFromGallery() async {
    // Bounded natively to the size the app stores at, so the temporary file is
    // a few hundred KB rather than a multi-megabyte camera original, and the
    // pure-Dart re-encode in `FilePhotoStorage.persist` decodes a 1600px image
    // instead of a 12 MP one. The quality is kept above the stored 85 so the
    // second encode is not compounding a heavy first one.
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    return file?.path;
  }
}
