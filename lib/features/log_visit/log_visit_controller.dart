import 'package:flutter/foundation.dart';

import '../../core/widgets/presentation_bounds.dart';
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
    this.isSaving = false,
  });

  final int visitDate;

  /// 0-5, 0 meaning "not rated".
  final int rating;

  /// 0-6, 0 meaning "not set".
  final int priceRange;

  final String notes;
  final bool isSaving;

  LogVisitState copyWith({
    int? visitDate,
    int? rating,
    int? priceRange,
    String? notes,
    bool? isSaving,
  }) => LogVisitState(
    visitDate: visitDate ?? this.visitDate,
    rating: rating ?? this.rating,
    priceRange: priceRange ?? this.priceRange,
    notes: notes ?? this.notes,
    isSaving: isSaving ?? this.isSaving,
  );
}

/// Backs the "log a visit" form, opened from the detail screen's action for one
/// restaurant.
///
/// Unlike the restaurant form this always creates a brand-new visit rather than
/// editing place-level data, so there is no "load an existing row" branch. The
/// Flutter counterpart of the Android `LogVisitViewModel`; photos are left to
/// the photos block.
class LogVisitController extends ChangeNotifier {
  LogVisitController({
    required this.repository,
    required this.restaurantId,
    DateTime? now,
  }) : _state = LogVisitState(
         visitDate: (now ?? DateTime.now()).millisecondsSinceEpoch,
       );

  final RestaurantRepository repository;
  final String restaurantId;

  LogVisitState _state;
  bool _disposed = false;

  LogVisitState get state => _state;

  void onDateChange(int visitDate) => _set(_state.copyWith(visitDate: visitDate));

  void onRatingChange(int rating) =>
      _set(_state.copyWith(rating: rating.clamp(0, maxRating)));

  void onPriceRangeChange(int priceRange) =>
      _set(_state.copyWith(priceRange: priceRange.clamp(0, maxPriceRange)));

  void onNotesChange(String notes) => _set(_state.copyWith(notes: notes));

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
