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
    // The one place a photo is bounded: the platform scales it natively to the
    // size the app stores, so the file is a few hundred KB rather than a
    // multi-megabyte camera original, and `FilePhotoStorage.persist` keeps it
    // as it is. 1600px is enough for a full-screen detail view; the EXIF
    // orientation tag survives the resize and Flutter applies it when drawing.
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    return file?.path;
  }
}
