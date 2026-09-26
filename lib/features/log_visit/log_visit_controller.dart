import 'package:flutter/foundation.dart';

import '../../core/widgets/presentation_bounds.dart';
import '../../data/photo/photo_picker.dart';
import '../../data/repositories/restaurant_repository.dart';

/// The log-visit form's fields.
///
/// [visitDate] is epoch millis and defaults to "now"; it only ever moves through
/// the date picker.
@immutable
class LogVisitState {
  const LogVisitState({
    required this.visitDate,
    this.rating = 0,
    this.priceRange = 0,
    this.notes = '',
    this.photoSourcePaths = const <String>[],
    this.isSaving = false,
  });

  final int visitDate;

  /// 0-5, 0 meaning "not rated".
  final int rating;

  /// 0-6, 0 meaning "not set".
  final int priceRange;

  final String notes;

  /// The temporary paths the picker has returned so far, in the order they were
  /// added. Persisted into the app's photo store when the visit is saved.
  final List<String> photoSourcePaths;

  final bool isSaving;

  LogVisitState copyWith({
    int? visitDate,
    int? rating,
    int? priceRange,
    String? notes,
    List<String>? photoSourcePaths,
    bool? isSaving,
  }) => LogVisitState(
    visitDate: visitDate ?? this.visitDate,
    rating: rating ?? this.rating,
    priceRange: priceRange ?? this.priceRange,
    notes: notes ?? this.notes,
    photoSourcePaths: photoSourcePaths ?? this.photoSourcePaths,
    isSaving: isSaving ?? this.isSaving,
  );
}

/// Backs the "log a visit" form, opened from the detail screen's action for one
/// restaurant.
///
/// Unlike the restaurant form this always creates a brand-new visit rather than
/// editing place-level data, so there is no "load an existing row" branch. The
/// Flutter counterpart of the Android `LogVisitViewModel`. Photos are picked
/// through [photoPicker] (optional, so a unit test can build a controller with
/// none) and carried on the state until the save persists them.
class LogVisitController extends ChangeNotifier {
  LogVisitController({
    required this.repository,
    required this.restaurantId,
    this.photoPicker,
    DateTime? now,
  }) : _state = LogVisitState(
         visitDate: (now ?? DateTime.now()).millisecondsSinceEpoch,
       );

  final RestaurantRepository repository;
  final String restaurantId;

  /// Opens the system picker for a visit photo. Null in a unit test that never
  /// picks one, in which case [pickPhoto] is a no-op.
  final PhotoPicker? photoPicker;

  LogVisitState _state;
  bool _disposed = false;

  LogVisitState get state => _state;

  void onDateChange(int visitDate) => _set(_state.copyWith(visitDate: visitDate));

  void onRatingChange(int rating) =>
      _set(_state.copyWith(rating: rating.clamp(0, maxRating)));

  void onPriceRangeChange(int priceRange) =>
      _set(_state.copyWith(priceRange: priceRange.clamp(0, maxPriceRange)));

  void onNotesChange(String notes) => _set(_state.copyWith(notes: notes));

  /// Opens the picker and appends whatever comes back, so a visit can carry
  /// several photos. A back-out adds nothing.
  Future<void> pickPhoto() async {
    final String? path = await photoPicker?.pickFromGallery();
    if (path == null || _disposed) {
      return;
    }
    _set(
      _state.copyWith(
        photoSourcePaths: <String>[..._state.photoSourcePaths, path],
      ),
    );
  }

  void removePhoto(String path) => _set(
    _state.copyWith(
      photoSourcePaths: <String>[
        for (final String candidate in _state.photoSourcePaths)
          if (candidate != path) candidate,
      ],
    ),
  );

  /// Saves the visit. Guarded against a second tap while the write is in
  /// flight — a double tap would otherwise log the visit twice.
  Future<void> save() async {
    if (_state.isSaving) {
      return;
    }
    _set(_state.copyWith(isSaving: true));
    final String notes = _state.notes.trim();
    await repository.addVisit(
      restaurantId: restaurantId,
      visitDate: _state.visitDate,
      rating: _state.rating,
      notes: notes.isEmpty ? null : notes,
      priceRange: _state.priceRange,
      photoSourcePaths: _state.photoSourcePaths,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _set(LogVisitState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }
}
