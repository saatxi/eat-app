// join-group — Edge Function that redeems an invitation token.
//
// Why a function and not plain RLS: validating the token (hash comparison,
// expiry, use limit, rate limiting) and then atomically inserting the new
// group_members row must happen with server authority. RLS can describe *who
// may read what*, but the join flow is a server-side transaction.
//
// Request (authenticated with the caller's anon-signup JWT):
//   POST { "token": "<raw invitation token>", "displayName": "Maria" }
//
// Responses:
//   200 { "groupId": "...", "groupName": "..." }        joined
//   400 { "error": "invalid_request" }                  malformed body
//   401 { "error": "unauthenticated" }                  no valid JWT
//   404 { "error": "invite_not_found" }                 unknown/expired/exhausted
//   409 { "error": "already_member" }                   caller is in the group
//   429 { "error": "rate_limited" }                     too many attempts
//   500 { "error": "internal" }                         unexpected failure
//
// The raw token is SHA-256 hashed before lookup; invites stores only hashes.
// A short-window per-user attempt counter lives in the shared rate_attempts
// table, so brute-forcing tokens is throttled even across function instances.
import { createHash } from 'node:crypto';
import { callerClient, json, serviceClient } from '../_shared/mod.ts';

const SHA256 = (raw) => createHash('sha256').update(raw).digest('hex');

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return json(400, { error: 'invalid_request' });
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) {
    return json(401, { error: 'unauthenticated' });
  }

  let body;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: 'invalid_request' });
  }
  const token = typeof body?.token === 'string' ? body.token.trim() : '';
  const displayName =
    typeof body?.displayName === 'string' ? body.displayName.trim() : '';
  if (!token || !displayName || displayName.length > 40) {
    return json(400, { error: 'invalid_request' });
  }

  // Client bound to the caller's own JWT: every query below runs as the
  // caller, so RLS still applies to anything we touch through it.
  const supabase = callerClient(req);

  const { data: authUser } = await supabase.auth.getUser();
  if (!authUser?.user) {
    return json(401, { error: 'unauthenticated' });
  }
  const userId = authUser.user.id;

  // Rate limit: at most 10 join attempts per user per 10 minutes. Attempts
  // are recorded even when they fail, so guessing tokens is throttled.
  const { error: rateError } = await supabase.rpc('record_rate_attempt', {
    attempt_kind: 'join',
  });
  if (rateError) {
    return json(429, { error: 'rate_limited' });
  }

  const admin = serviceClient();

  // The invite lookup must use the service role: invites' RLS only shows a
  // group's invites to that group's members, and the caller is by definition
  // not a member yet. The lookup leaks nothing — it matches an opaque hash.
  const tokenHash = SHA256(token);
  const { data: invite, error: inviteError } = await admin
    .from('invites')
    .select('id, group_id, expires_at, max_uses, uses_count')
    .eq('token_hash', tokenHash)
    .maybeSingle();

  if (inviteError || !invite) {
    return json(404, { error: 'invite_not_found' });
  }
  if (new Date(invite.expires_at).getTime() < Date.now()) {
    return json(404, { error: 'invite_not_found' });
  }
  if (invite.uses_count >= invite.max_uses) {
    return json(404, { error: 'invite_not_found' });
  }

  const { data: existing } = await supabase
    .from('group_members')
    .select('user_id')
    .eq('group_id', invite.group_id)
    .eq('user_id', userId)
    .maybeSingle();
  if (existing) {
    return json(409, { error: 'already_member' });
  }

  // Insert the membership and bump the invite counter with the service-role
  // client created above: the caller is not yet a member, so RLS would
  // reject the insert through their own credentials.
  const { error: insertError } = await admin.from('group_members').insert({
    group_id: invite.group_id,
    user_id: userId,
    // A person who redeems an invitation joins as an editor: they may add and
    // edit the group's restaurants but cannot manage members or the group.
    // An owner can promote them to owner, or demote them to reader, later.
    role: 'editor',
  });
  if (insertError) {
    // A concurrent join may have inserted the row first; that is success.
    const duplicate = insertError.code === '23505';
    if (!duplicate) {
      return json(500, { error: 'internal' });
    }
  }

  await admin
    .from('invites')
    .update({ uses_count: invite.uses_count + 1 })
    .eq('id', invite.id);

  // Keep the display name in sync with what the caller just sent.
  await admin.from('profiles').upsert({
    id: userId,
    display_name: displayName,
  });

  const { data: group } = await admin
    .from('groups')
    .select('id, name')
    .eq('id', invite.group_id)
    .single();

  return json(200, { groupId: group.id, groupName: group.name });
});
