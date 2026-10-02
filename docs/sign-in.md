# Sign-in methods (Google and email)

The app signs in only through a verified identity: there is no password-less
anonymous account, because ownership has to be recoverable after a reinstall.
Two methods are supported, both free:

- **Google** — an OAuth provider.
- **Email** — a one-time sign-in link ("magic link").

Apple was dropped deliberately: Sign in with Apple needs a paid Apple Developer
account, and the email method covers the same "sign in without Google" need for
nothing.

Almost nothing here lives in source code. The only fixed values are the redirect
string (`authRedirectUri` in `lib/data/supabase/identity.dart`) and the
`eatapp://` scheme, already registered on both platforms. Client IDs and secrets
are project configuration and must never be committed.

## What the app expects

- For Google, it asks Supabase for the provider URL
  (`auth.getOAuthSignInUrl`) and opens it in the system browser.
- For email, it asks Supabase to send a one-time link to the address
  (`auth.signInWithOtp`).
- Either way, the user ends up back in the app with
  `eatapp://login-callback`, which the app hands to the identity gateway to turn
  into a session (`getSessionFromUrl`).

So the Supabase project must list `eatapp://login-callback` as an allowed
redirect, and (for Google only) the provider must call back to Supabase, not to
the app.

## 1. Supabase: allow the redirect

1. Open the project at <https://supabase.com/dashboard>.
2. Go to **Authentication → URL Configuration**.
3. Under **Redirect URLs**, add `eatapp://login-callback` and save.
4. Leave the **Site URL** as it is: it is only the fallback for links opened in
   a browser, which this flow never uses.

The `eatapp://` scheme is custom, so it needs no domain verification. It must be
listed exactly, in lowercase, with no trailing slash. This one entry covers both
Google and email.

## 2. Email (no extra setup, but read the note)

Email sign-in works with Supabase's built-in sender as soon as the redirect
above is listed — there is nothing to create in Google or Apple.

One caveat: the built-in sender is rate-limited (a few messages per hour per
project) and meant for testing. It is enough for a personal app, but for a real
release set up a custom SMTP sender under **Authentication → Settings → SMTP
Settings** (for example the free tiers of Resend, Brevo or Postmark). That is a
deliverability concern, not a cost or a code change.

Under **Authentication → Providers → Email**, make sure **Email** is enabled.
Leaving **Confirm email** off is fine here: a magic link already proves the
address is the user's.

## 3. Google

1. In the same project, go to **Authentication → Providers → Google** and turn
   it on.
2. Paste the **Client ID** and **Client Secret** from Google (below).
3. Save.

### Create the Google credentials

1. Open the [Google Cloud Console](https://console.cloud.google.com/) and pick
   or create a project.
2. Configure the **OAuth consent screen** (External, with the app name and your
   support email). While it is in "Testing", add your own Google account under
   **Test users**.
3. Go to **APIs & Services → Credentials → Create credentials → OAuth client
   ID**.
4. Choose **Web application** (not Android or iOS): Supabase performs the token
   exchange on the server, so the client is a web one.
5. Add an **Authorized redirect URI**:

   ```text
   https://<project-ref>.supabase.co/auth/v1/callback
   ```

   `<project-ref>` is the project's reference (here `gswzrfmppbgjbgwhoruq`).
6. Create it and copy the **Client ID** and **Client secret** into the Supabase
   Google provider from the section above.

## 4. Build and try it

The rest is already wired: the redirect host is registered in the Android
manifest, the `eatapp` scheme is in the iOS `CFBundleURLTypes`, and the redirect
is routed to the gateway in `main()`.

Run the app with the backend configuration compiled in (the same two values a
release build needs):

```powershell
flutter run --dart-define-from-file=dart_defines.json
```

Then open **Settings → Account** and either tap **Continue with Google** or type
an address and tap **Email me a sign-in link**. If it comes back without a
session, the three usual causes are:

- `eatapp://login-callback` is not in the Supabase redirect list, or is spelled
  differently there.
- For Google, the provider's own redirect still points at the app instead of
  `https://<project-ref>.supabase.co/auth/v1/callback`.
- The Google consent screen is still in "Testing" and your account is not a test
  user.

## Why a verified identity and not a password

The stable identity is the provider subject or the email address, which Supabase
maps to a fixed `auth.users.id`. Signing in again the same way — on a reinstall
or a new phone — resolves to the same id, and every `group_members` row and
`createdBy` column keyed on it comes back. A password could not promise that as
simply, and an anonymous id could promise it at all: reinstalling would mint a
brand-new identity the backend had never seen.
