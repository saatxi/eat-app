// Shared helpers for the groups Edge Functions.
//
// Kept under an underscore-prefixed directory so the Supabase CLI does not treat
// it as a function of its own; the deploy bundler inlines these relative imports
// into each function that uses them.
import { createClient } from 'npm:@supabase/supabase-js@2';

/** A JSON response with the given status. */
export const json = (status, body) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

/**
 * A client bound to the caller's own JWT, so every query it makes runs as the
 * caller and row-level security still applies to it.
 */
export const callerClient = (req) =>
  createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    {
      global: {
        headers: { Authorization: req.headers.get('Authorization') ?? '' },
      },
    },
  );

/**
 * A client with service authority, for the privileged reads and writes clients
 * are not allowed (looking up an invite by hash, inserting a membership,
 * minting an invite row).
 */
export const serviceClient = () =>
  createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );
