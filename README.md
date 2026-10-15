# homeowners_app

## Web dev setup

For Flutter web on `localhost`, the app now expects a local API proxy at
`http://localhost:8787/` by default. Start it in one terminal:

```bash
dart run tool/dev_api_proxy.dart
```

Then run the app in another:

```bash
flutter run -d chrome
```

Optional env vars for the proxy:

```bash
TRADEWORKS_PROXY_TARGET=https://tradeworks-api-71668222585.us-east1.run.app/
TRADEWORKS_PROXY_PORT=8787
```

Optional app overrides:

```bash
flutter run -d chrome \
  --dart-define=TRADEWORKS_API_BASE_URL=http://localhost:8787/
```

## Google sign-in

Android and iOS use the native Google account chooser and exchange its ID and
access tokens for a Supabase session. Mobile Google sign-in never opens the
website or falls back to hosted OAuth. Web builds still use the website's
Supabase-hosted OAuth flow.

The default `TRADEWORKS_GOOGLE_WEB_CLIENT_ID` in `lib/services/api_config.dart`
is the public web client ID returned by the live website's Supabase Google
provider. If the provider changes, update that ID or supply the matching
`--dart-define=TRADEWORKS_GOOGLE_WEB_CLIENT_ID=...` at build time. The older
`google-signup-v2-supabase` endpoint uses a different audience and does not
create a Supabase Auth session; do not use its client ID for native sign-in.

For Android, register an Android OAuth client in the same Google Cloud project
for package `com.tradeworksai.homeownersapp` and each certificate SHA-1 used
to sign a build (debug, release, and Play App Signing where applicable). The
web client ID above is passed as the Google Sign-In server client ID. A build
with missing or mismatched Android OAuth registration reports a sign-in error
inside the app instead of redirecting to a website.
The former `com.tradeworksai.homeowners_app` package is a separate Android app;
installations of it will not be upgraded by the new package.

For iOS, open Google Cloud Console → APIs & Services → Credentials and create
an OAuth client of type **iOS** in the same project as the website's Google
provider. Use Runner's bundle ID. Set
`TRADEWORKS_GOOGLE_IOS_CLIENT_ID` in `.env.push` for `tool/build.sh`. The
confirmed TestFlight bundle ID is `com.tradeworksai.homeownersapp` (lowercase
`a`). The imported Runner project currently spells `homeownersApp` with an
uppercase `A`; correct and verify that Xcode target on a Mac before shipping
an IPA. These are different app identities.
The build script derives its
reversed URL scheme in ignored `ios/Flutter/GoogleOAuth.xcconfig`, which the
Runner `Info.plist` reads. For a local Xcode/Flutter run, create that xcconfig
with the same scheme and pass the iOS client ID with
`--dart-define=TRADEWORKS_GOOGLE_IOS_CLIENT_ID=...`. The iOS client ID is the
app client; the default web client ID remains the server client. Without the
iOS client ID, the app shows a configuration error instead of sending the user
to the website.

For web builds, allow the exact tested origin in Supabase Authentication → URL
Configuration. Mobile Google token sign-in does not use a redirect URL.

## Push notifications

Push uses Firebase Cloud Messaging on web, Android, and iOS. The app is
registered in Firebase project `tradeworksai-senthil-dev-env` as Android app
`1:71668222585:android:8ddee47a91ae4215b222a8` for package
`com.tradeworksai.homeownersapp` and iOS app
`1:71668222585:ios:346d80f26849d80fb222a8`. Client configuration is
environment-specific and is kept out of Git; never put server keys or APNs
private keys in the app.

1. Copy `.env.push.example` to `.env.push` and fill the Firebase values and
   iOS Google client ID.
2. Android's ignored `android/app/google-services.json` is fetched from the
   registered homeowner app. The matching iOS plist is currently staged at
   `.firebase-config/GoogleService-Info.plist`. On a Mac, correct the Runner
   bundle ID to the confirmed lowercase value, place the plist at
   `ios/Runner/GoogleService-Info.plist`, and verify it belongs to Runner.
   Refresh the GitHub `FIREBASE_ANDROID_CONFIG_BASE64` secret from this config
   before running the Android release workflow.
3. In Xcode, enable **Push Notifications** and **Background Modes → Background
   fetch / Remote notifications** for Runner, then configure the APNs
   authentication key in Firebase Cloud Messaging.
4. On macOS, run `bash tool/build.sh` to create the TestFlight IPA. The
   script stops before building if any required value is missing.

Release builds also report a startup configuration error when these
dart-defines are absent. The rest of the app remains available, but device
registration and push delivery stay disabled.
