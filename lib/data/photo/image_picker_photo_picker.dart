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
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    return file?.path;
  }
}
