// create-invite — Edge Function that mints an invitation for a group.
//
// Why a function: invites carry a token that must be hashed server-side and
// the row must be created with service authority — clients have no INSERT
// policy on invites by design, so a leaked anon key cannot mint invitations.
//
// Request (authenticated as an owner of the group):
//   POST { "groupId": "...", "maxUses": 5, "expiresInDays": 7 }
//
// Responses:
//   200 { "token": "<raw token>", "expiresAt": "...", "maxUses": 5 }
//   400 { "error": "invalid_request" }
//   401 { "error": "unauthenticated" }
//   403 { "error": "not_owner" }
//   429 { "error": "rate_limited" }
//   500 { "error": "internal" }
//
// The raw token is returned exactly once; only its SHA-256 hash is stored.
import { createHash, randomBytes } from 'node:crypto';
import { callerClient, json, serviceClient } from '../_shared/mod.ts';

// 128-bit token, base32-style alphabet without ambiguous characters — kept in
// step with inviteTokenAlphabet / inviteTokenLength in
// lib/data/groups/invite_link.dart.
const TOKEN_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const TOKEN_LENGTH = 16;

// The largest multiple of the alphabet length that fits in a byte (248 for 31
// characters). Bytes at or above it are discarded rather than folded with a
// modulo, which would make the first 256 % 31 characters likelier than the rest.
const UNBIASED_BYTE_LIMIT =
  Math.floor(256 / TOKEN_ALPHABET.length) * TOKEN_ALPHABET.length;

function mintToken() {
  let token = '';
  while (token.length < TOKEN_LENGTH) {
    for (const byte of randomBytes(TOKEN_LENGTH)) {
      if (byte < UNBIASED_BYTE_LIMIT) {
        token += TOKEN_ALPHABET[byte % TOKEN_ALPHABET.length];
        if (token.length === TOKEN_LENGTH) break;
      }
    }
  }
  return token;
}

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
  const groupId = typeof body?.groupId === 'string' ? body.groupId : '';
  const maxUses = Number.isInteger(body?.maxUses)
    ? Math.min(Math.max(body.maxUses, 1), 50)
    : 10;
  const expiresInDays = Number.isInteger(body?.expiresInDays)
    ? Math.min(Math.max(body.expiresInDays, 1), 30)
    : 7;
  if (!groupId) {
    return json(400, { error: 'invalid_request' });
  }

  // Caller-bound client: the ownership check below runs as the caller, so
  // RLS's is_group_owner() decides it — no trust in the request body.
  const supabase = callerClient(req);

  const { data: authUser } = await supabase.auth.getUser();
  if (!authUser?.user) {
    return json(401, { error: 'unauthenticated' });
  }

  // Rate limit: at most 20 invitations minted per user per hour. The attempt is
  // recorded before the ownership check, so a non-owner probing the endpoint is
  // throttled too.
  const { error: rateError } = await supabase.rpc('record_rate_attempt', {
    attempt_kind: 'invite',
  });
  if (rateError) {
    return json(429, { error: 'rate_limited' });
  }

  const { data: membership } = await supabase
    .from('group_members')
    .select('role')
    .eq('group_id', groupId)
    .eq('user_id', authUser.user.id)
    .maybeSingle();
  if (!membership || membership.role !== 'owner') {
    return json(403, { error: 'not_owner' });
  }

  const token = mintToken();
  const tokenHash = createHash('sha256').update(token).digest('hex');

  const expiresAt = new Date(
    Date.now() + expiresInDays * 24 * 60 * 60 * 1000,
  ).toISOString();

  // Service role: invites have no client INSERT policy by design.
  const admin = serviceClient();

  const { error: insertError } = await admin.from('invites').insert({
    group_id: groupId,
    token_hash: tokenHash,
    expires_at: expiresAt,
    max_uses: maxUses,
    created_by: authUser.user.id,
  });
  if (insertError) {
    return json(500, { error: 'internal' });
  }

  return json(200, { token, expiresAt, maxUses });
});
