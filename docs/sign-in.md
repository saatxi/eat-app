# Sign-in (email code)

The app signs in with a short code sent by email. There is no password, no
social provider and no browser redirect: the user types an address, receives a
code, and types it into the app. Everything happens inside the app, so the
behaviour is identical on Android and iOS and there is no custom URL callback to
keep in step between them.

Apple (and any OAuth provider) was dropped deliberately: Apple's sign-in needs a
paid developer account, and the email code covers the same need for nothing. A
few small settings on the Supabase side are all that is required.

The only fixed value in code is the sign-in mechanism itself, in
`lib/data/supabase/identity.dart`. There is no client ID or secret to keep.

## What the app does

1. `sendEmailCode(email)` asks Supabase for a one-time code
   (`auth.signInWithOtp`).
2. `verifyEmailCode(email, code)` exchanges it for a session
   (`auth.verifyOTP` with `OtpType.email`) and stores it.
3. The session is kept in `SharedPreferences` and re-established on the next
   launch, so the user stays signed in until they sign out.

The verified email is the stable identity: signing in again with the same
address — after reinstalling or on a new phone — resolves to the same
`auth.users.id`, which is what brings back ownership and the groups.

## Supabase setup

1. Open the project at <https://supabase.com/dashboard>.
2. Go to **Authentication → Providers → Email** and make sure **Email** is
   enabled.
3. Leave **Confirm email** off: a one-time code already proves the address is
   the user's, so a second confirmation step is pure friction.

That is the whole setup. No redirect URLs, no OAuth client, no keys.

### Email delivery

Out of the box, Supabase uses its built-in sender, capped at a few messages per
hour and meant for testing. For a real release, add a custom SMTP sender under
**Authentication → Settings → SMTP Settings** (Resend, Brevo and Postmark all
have free tiers). That is a deliverability concern, not a code change or a
cost.

## Trying it

Run the app with the backend configuration compiled in (the same two values a
release build needs), then open **Settings → Account**:

```powershell
flutter run --dart-define-from-file=dart_defines.json
```

Type an address, tap **Email me a sign-in code**, and enter the code from the
message. The row switches to "You're signed in".

If no code arrives, the two usual causes are a project still on the built-in
sender hitting its hourly limit, and a spam filter.

## What is and is not recovered

- **Recovered**: the account, group memberships and every shared restaurant,
  because they live in Supabase keyed by the signed-in user.
- **Not recovered by signing in**: private restaurants that were only ever on
  the phone. Those depend on the platform's own backup (Android Auto Backup) or
  on the app's export, not on sign-in.

## Adding Google later (optional)

If a Google button is wanted later, the clean way without any redirect is native
Google sign-in (`google_sign_in`) feeding `auth.signInWithIdToken`. That is a
new plugin and a Google Cloud project, so it is a separate decision — not
needed for the email flow described here.
