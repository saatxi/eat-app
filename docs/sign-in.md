# Sign-in (account code)

The app signs in with no email and no password the user has to remember. On
first use it mints a random **account code** — a short, human-typable secret —
which *is* the account. The code is shown in **Settings → Account** (with a
copy button), kept on the device, and can be written into an account backup.
Typing the same code on another phone restores the same account, its groups and
their shared restaurants.

Everything happens inside the app: there is no magic link, no browser, and no
custom URL callback to keep in step between Android and iOS.

## How it works

1. The app generates a 16-character code (~80 bits of entropy) from an
   unambiguous alphabet (no `O`, `I`, `L`, `0` or `1`), and groups it in fours
   for display — `ABCD-EFGH-2345-WXYZ`. See
   `lib/data/supabase/account_code.dart`.
2. `createAccount()` (or `signInWithCode(code)`) calls the `adopt-account` Edge
   Function with the code.
3. The function derives a synthetic email and password from the code with two
   HMAC secrets it holds (`ACCOUNT_EMAIL_SECRET`, `ACCOUNT_PASSWORD_SECRET`),
   creates the user auto-confirmed, and returns the credentials. No message is
   ever sent — the address is undeliverable (`.invalid`).
4. The app signs in with the ordinary password grant
   (`auth.signInWithPassword`) and stores the resulting session in
   `SharedPreferences`, so the user stays signed in across launches.

Because the credentials are derived deterministically, the same code always
resolves to the same `auth.users.id` on any device. That id is the stable
identity the whole groups backend is keyed on, so adopting the code again brings
ownership and membership back.

## Supabase setup

1. Open the project at <https://supabase.com/dashboard>.
2. Go to **Authentication → Providers → Email** and make sure **Email** is
   enabled — the derived identity is an email/password user, it just never
   receives mail.
3. Set the two derivation secrets as Edge Function secrets, each a long random
   string, and **never change them** without accepting that existing codes stop
   resolving to their accounts:

   ```powershell
   supabase secrets set ACCOUNT_EMAIL_SECRET=<random> ACCOUNT_PASSWORD_SECRET=<random>
   ```

4. Deploy the function, which must run **without** a JWT check (the caller has
   no session yet — adopting is how they get one):

   ```powershell
   supabase functions deploy adopt-account --no-verify-jwt
   ```

That is the whole setup. No SMTP sender, no email template, no redirect URLs,
no OAuth client.

## Security

The code **is** the credential: anyone who has it can adopt the account, so it
must be treated like a password.

- Adoption is rate-limited per code (10 per 10 minutes) and per client IP (30
  per 10 minutes) by `record_account_attempt`, so guessing is throttled even
  against a single account.
- The `adopt-account` function is the only unauthenticated endpoint; it derives
  credentials and nothing else.
- The account code is deliberately **kept out** of the shareable restaurant
  export. It travels only inside an **account backup** ("Back up my data and
  account" in Settings), whose file grants the account to whoever holds it.

## Recovering on a new phone

1. Open **Settings → Account**.
2. Type the code into the field and tap **Sign in**, or
3. Import an account backup file; the review screen offers a "sign in with this
   account" step (never automatic).

Signing out clears the session but keeps the code on the device, so signing
back in is one tap.

## What is and is not recovered

- **Recovered**: the account, group memberships and every shared restaurant,
  because they live in Supabase keyed by the signed-in user id.
- **Not recovered by the code**: private restaurants that were only ever on the
  phone. Those depend on the platform's own backup (Android Auto Backup) or on
  the app's export, not on signing in.

## Adding Google later (optional)

If a Google button is wanted later, native Google sign-in (`google_sign_in`)
feeding `auth.signInWithIdToken` is a separate decision — a new plugin and a
Google Cloud project. It would have to be linked to the same identity to share
an account with the code flow.
