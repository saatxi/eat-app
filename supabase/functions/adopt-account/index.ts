// adopt-account — Edge Function that turns an account code into credentials.
//
// The app signs in with no email and no password of its own: it holds a random
// account code, and this function deterministically derives a synthetic email
// and password from it. The client then performs a normal password sign-in, so
// the session (and its own refresh token) never leaves the device.
//
// Request (unauthenticated — the caller has no session yet, so this function
// must be deployed with verify_jwt = false):
//   POST { "code": "XXXX-XXXX-XXXX-XXXX" }
//
// Responses:
//   200 { "email": "...", "password": "..." }
//   400 { "error": "invalid_request" }
//   429 { "error": "rate_limited" }
//   500 { "error": "internal" }
//
// The derivation secrets live only as function secrets (ACCOUNT_EMAIL_SECRET /
// ACCOUNT_PASSWORD_SECRET), so no credential table exists and rotating a secret
// simply versions the account space. The synthetic address is undeliverable
// (`.invalid`), and email_confirm means no message is ever sent.
import { createHash, createHmac } from 'node:crypto';
import { json, serviceClient } from '../_shared/mod.ts';

// RFC 4648 base32 without padding, lowercase.
const B32 = 'abcdefghijklmnopqrstuvwxyz234567';

// The account code alphabet and length, kept in step with
// accountCodeAlphabet / accountCodeLength in lib/data/supabase/account_code.dart.
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LENGTH = 16;

/** Encodes bytes as unpadded lowercase base32. */
function base32(bytes) {
  let bits = 0;
  let value = 0;
  let out = '';
  for (const byte of bytes) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      out += B32[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) {
    out += B32[(value << (5 - bits)) & 31];
  }
  return out;
}

/** Uppercases and drops every separator, so `abcd-efgh` and `ABCDEFGH` match. */
function normalizeCode(raw) {
  return raw.toUpperCase().replace(/[^A-Z0-9]/g, '');
}

function isValidCode(code) {
  if (code.length !== CODE_LENGTH) {
    return false;
  }
  for (const char of code) {
    if (!CODE_ALPHABET.includes(char)) {
      return false;
    }
  }
  return true;
}

/** HMAC-SHA256(secret, "<label>:<code>") as base32 — one value per label. */
const derive = (secret, code, label) =>
  base32(createHmac('sha256', secret).update(`${label}:${code}`).digest());

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return json(400, { error: 'invalid_request' });
  }

  let body;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: 'invalid_request' });
  }

  const raw = typeof body?.code === 'string' ? body.code : '';
  const code = normalizeCode(raw);
  if (!isValidCode(code)) {
    return json(400, { error: 'invalid_request' });
  }

  const emailSecret = Deno.env.get('ACCOUNT_EMAIL_SECRET');
  const passwordSecret = Deno.env.get('ACCOUNT_PASSWORD_SECRET');
  if (!emailSecret || !passwordSecret) {
    return json(500, { error: 'internal' });
  }

  // Rate limit first: the code hash keys the per-code window without storing
  // the code, and the client key is the caller's IP.
  const admin = serviceClient();
  const codeHash = createHash('sha256').update(code).digest('hex');
  const forwarded = req.headers.get('x-forwarded-for') ?? '';
  const clientIp = forwarded.split(',')[0].trim() || 'unknown';
  const clientKey = createHash('sha256').update(clientIp).digest('hex');

  const { error: rateError } = await admin.rpc('record_account_attempt', {
    p_code_hash: codeHash,
    p_client_key: clientKey,
  });
  if (rateError) {
    return json(429, { error: 'rate_limited' });
  }

  const email = `a${derive(emailSecret, code, 'email')}@eatapp.invalid`;
  const password = derive(passwordSecret, code, 'password');

  // Deterministic credentials: a re-adopt converges on the same user, so the
  // "already registered" error is the expected idempotent case.
  const { error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });
  if (createError) {
    const alreadyRegistered =
      createError.code === 'email_exists' ||
      /already/i.test(createError.message ?? '');
    if (!alreadyRegistered) {
      return json(500, { error: 'internal' });
    }
  }

  return json(200, { email, password });
});
