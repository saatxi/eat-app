// delete-account — Edge Function that erases the caller's account.
//
// Deleting an auth.users row cascades most of a user's footprint, but the four
// shared tables keyed on created_by (restaurants, visits, photos,
// restaurant_groups) have no ON DELETE action, so the public rows are cleared
// first with delete_account_data() and the auth user is removed afterwards, its
// cascade taking the rest.
//
// Request (authenticated with the caller's JWT):
//   POST {}  (empty body)
//
// Responses:
//   200 { "deleted": true }
//   400 { "error": "invalid_request" }
//   401 { "error": "unauthenticated" }
//   500 { "error": "internal" }
import { callerClient, json, serviceClient } from '../_shared/mod.ts';

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return json(400, { error: 'invalid_request' });
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) {
    return json(401, { error: 'unauthenticated' });
  }

  // Caller-bound client: getUser() verifies the JWT and tells us who to delete.
  const supabase = callerClient(req);
  const { data: authUser } = await supabase.auth.getUser();
  if (!authUser?.user) {
    return json(401, { error: 'unauthenticated' });
  }
  const userId = authUser.user.id;

  const admin = serviceClient();

  // Clear the public rows the auth-user cascade cannot reach (the NO ACTION
  // created_by foreign keys) before removing the user itself.
  const { error: cleanupError } = await admin.rpc('delete_account_data', {
    p_user_id: userId,
  });
  if (cleanupError) {
    return json(500, { error: 'internal' });
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
  if (deleteError) {
    return json(500, { error: 'internal' });
  }

  return json(200, { deleted: true });
});
