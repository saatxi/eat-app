/// The group a write belongs to, when the user is working inside a shared
/// group rather than their private list.
///
/// The repository's write methods that build rows on the caller's behalf —
/// visits and photos, whose group is not part of the value the caller passes —
/// take one of these to attribute those rows. A restaurant the caller inserts
/// or updates already carries its own `groupId`/`createdBy`, so those methods
/// read the context straight off the row instead of taking one of these.
///
/// A `null` context is the whole of "personal mode": the write is private, no
/// group is stamped, and nothing is queued. That is what keeps every existing
/// caller and test working unchanged.
class SharedWrite {
  const SharedWrite({required this.groupId, required this.createdBy});

  /// The group the written rows belong to.
  final String groupId;

  /// Auth user id of whoever is writing. Every shared row needs an author, or
  /// the sync layer refuses to push it.
  final String createdBy;
}
