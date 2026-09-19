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

The app uses the same Supabase-hosted Google OAuth flow as the website. Before
testing a new web origin or mobile build, add these redirect URLs in Supabase
Authentication → URL Configuration:

- `com.tradeworksai.homeowners://login-callback`
- the exact web origin being tested, such as `http://localhost:port`

Google must be enabled in the Supabase Google provider settings with the same
web OAuth client and secret used by the Tradeworks One website.
