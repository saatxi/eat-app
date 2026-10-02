# Sign-in providers (Google and Apple)

The app signs in only through a provider: there is no password and no anonymous
identity, because ownership has to be recoverable after a reinstall. That means
two things have to be configured outside the repository: the providers
themselves, and the redirect the app listens for.

Nothing here lives in source code except the redirect string
(`authRedirectUri` in `lib/data/supabase/identity.dart`) and the `eatapp://`
scheme, which is already registered on both platforms. The client IDs, secrets
and keys are project configuration and must never be committed.

## What the app expects

- It asks Supabase for a provider sign-in URL
  (`auth.getOAuthSignInUrl`) and opens it in the system browser.
- The provider sends the user back to Supabase, which redirects to the app with
  `eatapp://login-callback`.
- The app hands that URI back to the identity gateway, which turns it into a
  session (`getSessionFromUrl`).

So the Supabase project must list `eatapp://login-callback` as an allowed
redirect, and each provider must call back to Supabase, not to the app.

## 1. Supabase: allow the redirect

1. Open the project at <https://supabase.com/dashboard>.
2. Go to **Authentication → URL Configuration**.
3. Under **Redirect URLs**, add `eatapp://login-callback` and save.
4. Leave the **Site URL** as it is: it is only the fallback for links opened in
   a browser, which this flow never uses.

The `eatapp://` scheme is custom, so it needs no domain verification. It must be
listed exactly, in lowercase, with no trailing slash.

## 2. Supabase: enable Google

1. In the same project, go to **Authentication → Providers → Google** and turn
   it on.
2. Paste the **Client ID** and **Client Secret** from Google (see below).
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
   Google provider from the previous section.

## 3. Supabase: enable Apple

Apple is more involved and needs a paid Apple Developer account.

1. In **Apple Developer → Certificates, Identifiers & Profiles → Identifiers**,
   create a **Services ID** (for example `com.saatxi.eatapp.web`). Configure its
   **Sign in with Apple** return URL as
   `https://<project-ref>.supabase.co/auth/v1/callback`.
2. Create a **Key** with **Sign in with Apple** enabled, and note the **Key ID**
   and download the `.p8` file (you can only download it once).
3. Note your **Team ID** (top-right of the developer portal).
4. In Supabase, go to **Authentication → Providers → Apple** and fill in:
   - **Services ID** — the identifier from step 1 (this is the Client ID).
   - **Team ID** and **Key ID** — from step 3 and step 2.
   - **Private Key** — the contents of the `.p8` file.
   - **Authorized Client IDs** — add the app's bundle id
     (`com.saatxi.eatapp`) so a native Apple sign-in token would also be
     accepted.
5. Save.

## 4. Build and try it

The rest is already wired: the redirect host is registered in the Android
manifest, the `eatapp` scheme is in the iOS `CFBundleURLTypes`, and the redirect
is routed to the gateway in `main()`.

Run the app with the backend configuration compiled in (the same two values a
release build needs):

```powershell
flutter run --dart-define-from-file=dart_defines.json
```

Then open **Settings → Account** and tap **Continue with Google** (or Apple). A
browser opens, you approve, and control returns to the app signed in. If it
comes back without a session, the three usual causes are:

- `eatapp://login-callback` is not in the Supabase redirect list, or is spelled
  differently there.
- The provider's own redirect still points at the app instead of
  `https://<project-ref>.supabase.co/auth/v1/callback`.
- The provider is still in "Testing" and your account is not a test user.

## Why a provider and not a password

The stable identity is the provider's subject (the Google or Apple account),
which Supabase maps to a fixed `auth.users.id`. Signing in again with the same
account — on a reinstall or a new phone — resolves to the same id, and every
`group_members` row and `createdBy` column keyed on it comes back. A password or
an anonymous id could not promise that: reinstalling would either lose the
secret or mint a brand-new identity the backend had never seen.
