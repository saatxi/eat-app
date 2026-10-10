/// How much each Journal card shows.
///
/// [comfortable] is the full card — large photo, the whole address, the status
/// on a line of its own, rating and price. [compact] keeps only the name, the
/// cuisine and the town on a much shorter card, so far more restaurants fit on
/// screen.
/// Only the list's layout changes: the detail screen always shows everything.
enum JournalDensity {
  comfortable('comfortable'),
  compact('compact');

  const JournalDensity(this.id);

  /// Stable, language-independent key used for persistence.
  final String id;

  static const JournalDensity fallback = JournalDensity.comfortable;

  /// Resolves a persisted [id], falling back rather than throwing.
  static JournalDensity fromId(String? id) {
    for (final JournalDensity density in values) {
      if (density.id == id) {
        return density;
      }
    }
    return fallback;
  }
}
