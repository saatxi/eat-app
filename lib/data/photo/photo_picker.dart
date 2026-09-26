/// Opens the platform's photo picker for the two screens that add a photo: the
/// add/edit form (a restaurant's one photo) and the log-visit form (a visit's
/// photos).
///
/// Kept as its own interface, separate from the `image_picker` implementation,
/// so a widget or controller test can drive the flow with a fake that returns a
/// path without a platform channel being involved.
abstract interface class PhotoPicker {
  /// Returns the temporary path of the image the user chose, or null when they
  /// backed out without picking one.
  ///
  /// The path is a staging copy the OS owns — callers hand it to `PhotoStorage`
  /// to persist rather than storing it.
  Future<String?> pickFromGallery();
}
