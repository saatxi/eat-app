import 'palettes/garden_palette.dart';
import 'palettes/indigo_palette.dart';
import 'palettes/mercado_fresco_palette.dart';
import 'tokens/palette_tones.dart';

/// The palettes the user can pick between in Settings.
///
/// [id] is what gets persisted, so entries must not be renamed without a
/// migration; [fromId] resolves an unrecognised or absent value to
/// [fallback] instead of throwing, the same graceful degradation the Android
/// app's `DataStoreUserPreferencesRepository` applies to a stored palette name
/// it no longer recognises.
enum AppPalette {
  mercadoFresco('mercado_fresco', mercadoFrescoTones),
  garden('garden', gardenTones),
  indigo('indigo', indigoTones);

  const AppPalette(this.id, this.tones);

  /// Stable, language-independent key used for persistence.
  final String id;

  final PaletteTones tones;

  /// The palette a fresh install starts on, and the one an unknown stored
  /// value falls back to.
  static const AppPalette fallback = AppPalette.mercadoFresco;

  /// Resolves a persisted [id], falling back rather than throwing so stale
  /// preference data can never crash startup.
  static AppPalette fromId(String? id) {
    for (final AppPalette palette in values) {
      if (palette.id == id) {
        return palette;
      }
    }
    return fallback;
  }
}
