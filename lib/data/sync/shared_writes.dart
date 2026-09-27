import '../repositories/user_preferences_repository.dart';
import '../supabase/identity.dart';
import 'shared_write.dart';

/// Resolves the [SharedWrite] a screen's write should carry, from the selected
/// group and the signed-in identity.
///
/// A controller that owns a form takes one of these and asks it at save time,
/// rather than reaching into the preferences and the identity itself. Everything
/// resolves to null in Personal mode — no group selected, or no backend — which
/// is exactly what keeps a private write private.
class SharedWrites {
  const SharedWrites({required this.preferences, this.identity});

  final UserPreferencesRepository preferences;
  final IdentityGateway? identity;

  /// The context for a brand-new top-level row (a restaurant): the group the
  /// user is working in, authored by the current user.
  Future<SharedWrite?> forNewRow() =>
      _resolve(preferences.current.selectedGroupId);

  /// The context for a new child of an existing row (a visit, a photo): the
  /// parent's own group, authored by the current user. Null when the parent is
  /// private, so a visit or photo never widens a private restaurant's reach.
  Future<SharedWrite?> forChildOf(String? groupId) => _resolve(groupId);

  Future<SharedWrite?> _resolve(String? groupId) async {
    if (groupId == null) {
      return null;
    }
    final Identity? me = await identity?.current();
    if (me == null) {
      return null;
    }
    return SharedWrite(groupId: groupId, createdBy: me.userId);
  }
}
