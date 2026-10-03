import 'package:flutter/foundation.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../../data/repositories/user_preferences_repository.dart';
import '../../data/share/content_files.dart';
import '../../data/share/restaurant_import_reader.dart';
import '../../data/share/restaurant_share_models.dart';

/// What the user chose to do with one row of a shared file.
enum ImportDecision { add, skip, replace }

/// One validated import row: the restaurant itself, its own validated visits,
/// the existing restaurant it looks like a duplicate of (if any), and the
/// decision currently applied to it.
class ImportCandidate {
  ImportCandidate({
    required this.restaurant,
    required this.visits,
    required this.duplicateOf,
    required this.decision,
    this.isFavorite = false,
  });

  final Restaurant restaurant;
  final List<VisitExport> visits;

  /// The existing row this looks like a duplicate of, by name and address, or
  /// null when it is new.
  final Restaurant? duplicateOf;

  /// Whether the file marked this restaurant a favourite, so confirming can
  /// put it back in the user's favourites under its new id.
  final bool isFavorite;

  ImportDecision decision;

  ImportCandidate withDecision(ImportDecision decision) => ImportCandidate(
    restaurant: restaurant,
    visits: visits,
    duplicateOf: duplicateOf,
    isFavorite: isFavorite,
    decision: decision,
  );
}

/// The import screen's whole state, in one immutable snapshot.
class ImportUiState {
  const ImportUiState({
    this.isLoading = true,
    this.error,
    this.candidates = const <ImportCandidate>[],
    this.skippedInvalidCount = 0,
    this.isImporting = false,
    this.accountCode,
  });

  final bool isLoading;
  final ImportFailureReason? error;
  final List<ImportCandidate> candidates;

  /// How many rows the reader dropped as invalid, shown as a quiet note rather
  /// than failing the whole file.
  final int skippedInvalidCount;
  final bool isImporting;

  /// The account code an account backup carried, offered on the review screen
  /// as an opt-in adopt. Null for every other file.
  final String? accountCode;

  ImportUiState copyWith({
    bool? isLoading,
    ImportFailureReason? error,
    List<ImportCandidate>? candidates,
    int? skippedInvalidCount,
    bool? isImporting,
    String? accountCode,
  }) => ImportUiState(
    isLoading: isLoading ?? this.isLoading,
    // Only ever set from null to a value, so no "clear the error" sentinel is
    // needed.
    error: error ?? this.error,
    candidates: candidates ?? this.candidates,
    skippedInvalidCount: skippedInvalidCount ?? this.skippedInvalidCount,
    isImporting: isImporting ?? this.isImporting,
    accountCode: accountCode ?? this.accountCode,
  );
}

/// Loads and validates the file at [filePath], flags likely duplicates against
/// what [repository] already holds, and — only once [confirm] is called —
/// writes the chosen decisions.
///
/// Nothing reaches the database before that: the review screen is the last line
/// of defence against a file that is not what it claims to be.
class ImportController extends ChangeNotifier {
  ImportController({
    required this.repository,
    required this.filePath,
    this.preferences,
  });

  final RestaurantRepository repository;
  final String filePath;

  /// Where an imported favourite flag is written back to. Null in a bare unit
  /// test, where nothing holds preferences and the flag is simply dropped.
  final UserPreferencesRepository? preferences;

  ImportUiState _state = const ImportUiState();
  ImportUiState get state => _state;

  bool _disposed = false;

  /// Runs once, when the screen is first mounted.
  Future<void> load() async {
    final ContentReadResult content = await readFileCapped(filePath);
    if (_disposed) {
      return;
    }

    switch (content) {
      case ContentReadTooLarge():
        _emit(
          _state.copyWith(
            isLoading: false,
            error: ImportFailureReason.tooLarge,
          ),
        );
      case ContentReadIoError():
        _emit(
          _state.copyWith(isLoading: false, error: ImportFailureReason.ioError),
        );
      case ContentReadSuccess(:final String text):
        await _read(text);
    }
  }

  Future<void> _read(String rawJson) async {
    final ImportOutcome outcome = readRestaurantImport(rawJson);
    switch (outcome) {
      case ImportError(:final ImportFailureReason reason):
        _emit(_state.copyWith(isLoading: false, error: reason));
      case ImportSuccess(
        :final List<ImportedRestaurant> restaurants,
        :final int skippedCount,
        :final String? accountCode,
      ):
        final List<Restaurant> existing = await repository.getAllRestaurants();
        if (_disposed) {
          return;
        }
        _emit(
          _state.copyWith(
            isLoading: false,
            candidates: <ImportCandidate>[
              for (final ImportedRestaurant imported in restaurants)
                _candidateFor(imported, existing),
            ],
            skippedInvalidCount: skippedCount,
            accountCode: accountCode,
          ),
        );
    }
  }

  ImportCandidate _candidateFor(
    ImportedRestaurant imported,
    List<Restaurant> existing,
  ) {
    Restaurant? duplicate;
    for (final Restaurant candidate in existing) {
      if (isLikelyDuplicateOf(imported.restaurant, candidate)) {
        duplicate = candidate;
        break;
      }
    }
    return ImportCandidate(
      restaurant: imported.restaurant,
      visits: imported.visits,
      duplicateOf: duplicate,
      isFavorite: imported.isFavorite,
      // A likely duplicate defaults to Skip, so the safe path is the one the
      // user has to actively leave.
      decision: duplicate == null ? ImportDecision.add : ImportDecision.skip,
    );
  }

  void onDecisionChange(int index, ImportDecision decision) {
    if (index < 0 || index >= _state.candidates.length) {
      return;
    }
    final List<ImportCandidate> updated = List<ImportCandidate>.of(
      _state.candidates,
    );
    updated[index] = updated[index].withDecision(decision);
    _emit(_state.copyWith(candidates: updated));
  }

  /// Writes the chosen decisions. Adds and replaces go in with their whole
  /// visit history and, when the file marked the row a favourite, back into the
  /// favourites; skipped rows are left untouched.
  Future<void> confirm() async {
    _emit(_state.copyWith(isImporting: true));
    // Favourites are collected and written once, after the rows exist, since
    // the ids they are keyed by are only known once each row has landed.
    final Set<String> favorites = <String>{};
    for (final ImportCandidate candidate in _state.candidates) {
      final String? restaurantId = await _apply(candidate);
      if (restaurantId == null) {
        continue;
      }
      if (candidate.isFavorite) {
        favorites.add(restaurantId);
      }
      for (final VisitExport visit in candidate.visits) {
        await repository.addVisit(
          restaurantId: restaurantId,
          visitDate: visit.visitDate,
          rating: visit.rating,
          notes: visit.notes,
          priceRange: visit.priceRange,
        );
      }
    }
    if (favorites.isNotEmpty) {
      await preferences?.addFavorites(favorites);
    }
    _emit(_state.copyWith(isImporting: false));
  }

  Future<String?> _apply(ImportCandidate candidate) async {
    switch (candidate.decision) {
      case ImportDecision.add:
        await repository.insert(candidate.restaurant);
        return candidate.restaurant.id;
      case ImportDecision.replace:
        final Restaurant? duplicate = candidate.duplicateOf;
        if (duplicate == null) {
          return null;
        }
        // The imported row's own id is meaningless in this database; it takes
        // the duplicate's id so the replacement lands on the existing row.
        await repository.update(
          candidate.restaurant.copyWith(id: duplicate.id),
        );
        return duplicate.id;
      case ImportDecision.skip:
        return null;
    }
  }

  void _emit(ImportUiState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
