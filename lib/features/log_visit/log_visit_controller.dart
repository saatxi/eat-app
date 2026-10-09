import 'package:flutter/foundation.dart';

import '../../core/widgets/presentation_bounds.dart';
import '../../data/db/app_database.dart';
import '../../data/photo/photo_picker.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/sync/shared_write.dart';
import '../../data/sync/shared_writes.dart';

/// One photo on the form, either already in the database or just picked.
///
/// The form has to tell the two apart at save time: a stored photo is kept (or,
/// by its absence, removed) by *id*, while a picked one is a temporary file the
/// repository still has to persist. Both are just a path to the widget drawing
/// the thumbnail.
@immutable
class VisitPhoto {
  const VisitPhoto.stored({required String this.id, required this.path});

  const VisitPhoto.picked(this.path) : id = null;

  /// The `photos` row's id, or null for a photo the picker just returned.
  final String? id;

  final String path;

  bool get isStored => id != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisitPhoto && other.id == id && other.path == path;

  @override
  int get hashCode => Object.hash(id, path);
}

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
    this.photos = const <VisitPhoto>[],
    this.isLoading = false,
    this.isSaving = false,
  });

  final int visitDate;

  /// 0-5, 0 meaning "not rated".
  final int rating;

  /// 0-6, 0 meaning "not set".
  final int priceRange;

  final String notes;

  /// Every photo on the form, stored and freshly picked alike, in the order the
  /// strip shows them.
  final List<VisitPhoto> photos;

  /// True only while an existing visit is being read back, so the form can wait
  /// rather than flash its empty defaults first.
  final bool isLoading;

  final bool isSaving;

  /// The temporary paths the picker has returned so far, in the order they were
  /// added. Persisted into the app's photo store when the visit is saved.
  List<String> get photoSourcePaths => <String>[
    for (final VisitPhoto photo in photos)
      if (!photo.isStored) photo.path,
  ];

  /// The ids of the stored photos the form still shows; anything missing from
  /// this was removed by the user.
  List<String> get keptPhotoIds => <String>[
    for (final VisitPhoto photo in photos)
      if (photo.id case final String id) id,
  ];

  LogVisitState copyWith({
    int? visitDate,
    int? rating,
    int? priceRange,
    String? notes,
    List<VisitPhoto>? photos,
    bool? isLoading,
    bool? isSaving,
  }) => LogVisitState(
    visitDate: visitDate ?? this.visitDate,
    rating: rating ?? this.rating,
    priceRange: priceRange ?? this.priceRange,
    notes: notes ?? this.notes,
    photos: photos ?? this.photos,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
  );
}

/// Backs the "log a visit" form, opened from the detail screen's action for one
/// restaurant — and, with [visitId] given, the same form editing a visit that
/// is already in the history.
///
/// The two modes differ only at the ends: edit mode reads the row and its
/// photos back through [load] before the form is shown, and [save] rewrites
/// that visit in place instead of adding one. Everything between is the same
/// form, which is why it is one controller and not two. The Flutter
/// counterpart of the Android `LogVisitViewModel`. Photos are picked through
/// [photoPicker] (optional, so a unit test can build a controller with none)
/// and carried on the state until the save persists them.
class LogVisitController extends ChangeNotifier {
  LogVisitController({
    required this.repository,
    required this.restaurantId,
    this.visitId,
    this.photoPicker,
    this.sharedWrites,
    DateTime? now,
  }) : _state = LogVisitState(
         visitDate: (now ?? DateTime.now()).millisecondsSinceEpoch,
         isLoading: visitId != null,
       );

  final RestaurantRepository repository;
  final String restaurantId;

  /// The visit being edited, or null for the "log a new visit" mode.
  final String? visitId;

  bool get isEditing => visitId != null;

  /// Opens the system picker for a visit photo. Null in a unit test that never
  /// picks one, in which case [pickPhoto] is a no-op.
  final PhotoPicker? photoPicker;

  /// Resolves the group a new visit should carry, or null in Personal mode. The
  /// visit's group comes from its restaurant, so a visit never widens a private
  /// restaurant's reach.
  final SharedWrites? sharedWrites;

  LogVisitState _state;
  bool _disposed = false;

  LogVisitState get state => _state;

  /// Reads the edited visit and its photos back onto the form. A no-op in
  /// "log a new visit" mode, and a no-op again if the visit has gone since —
  /// the form then simply stays on its defaults rather than failing.
  Future<void> load() async {
    final String? id = visitId;
    if (id == null) {
      return;
    }
    final List<Visit> visits = await repository
        .observeVisitsForRestaurant(restaurantId)
        .first;
    final Visit? visit = visits.where((Visit row) => row.id == id).firstOrNull;
    if (visit == null) {
      _set(_state.copyWith(isLoading: false));
      return;
    }
    final List<Photo> photos = await repository.observePhotosForVisit(id).first;
    _set(
      LogVisitState(
        visitDate: visit.visitDate,
        rating: visit.rating,
        priceRange: visit.priceRange,
        notes: visit.notes ?? '',
        photos: <VisitPhoto>[
          for (final Photo photo in photos)
            VisitPhoto.stored(id: photo.id, path: photo.path),
        ],
      ),
    );
  }

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
        photos: <VisitPhoto>[..._state.photos, VisitPhoto.picked(path)],
      ),
    );
  }

  /// Drops the photo at [path], whether it is stored or only staged. A stored
  /// one is merely taken off the form here; the row and its file go when the
  /// save runs, so backing out of the form leaves it untouched.
  void removePhoto(String path) => _set(
    _state.copyWith(
      photos: <VisitPhoto>[
        for (final VisitPhoto candidate in _state.photos)
          if (candidate.path != path) candidate,
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
    // The visit belongs to whatever group its restaurant is in — a private
    // restaurant's visit stays private even while a group is selected.
    final Restaurant? parent = await repository.observeById(restaurantId).first;
    final SharedWrite? shared = await sharedWrites?.forChildOf(parent?.groupId);
    final String? id = visitId;
    if (id == null) {
      await repository.addVisit(
        restaurantId: restaurantId,
        visitDate: _state.visitDate,
        rating: _state.rating,
        notes: notes.isEmpty ? null : notes,
        priceRange: _state.priceRange,
        photoSourcePaths: _state.photoSourcePaths,
        shared: shared,
      );
      return;
    }
    await repository.updateVisit(
      visitId: id,
      visitDate: _state.visitDate,
      rating: _state.rating,
      notes: notes.isEmpty ? null : notes,
      priceRange: _state.priceRange,
      keptPhotoIds: _state.keptPhotoIds,
      addedPhotoSourcePaths: _state.photoSourcePaths,
      shared: shared,
    );
  }

  /// Removes the visit being edited, photos and all. Only reachable in edit
  /// mode, and guarded like [save] so a double tap cannot delete twice.
  Future<void> delete() async {
    final String? id = visitId;
    if (id == null || _state.isSaving) {
      return;
    }
    _set(_state.copyWith(isSaving: true));
    await repository.deleteVisit(id);
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
