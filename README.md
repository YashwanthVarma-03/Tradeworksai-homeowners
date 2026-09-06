# homeowners_app

## Web dev setup

For Flutter web on `localhost`, the app now expects a local API proxy at
`http://localhost:8787/` by default. Start it in one terminal:

```bash
dart run tool/dev_api_proxy.dart
```

Then run the app in another:

```bash
flutter run -d chrome \
  --dart-define=TRADEWORKS_GOOGLE_WEB_CLIENT_ID=your-google-web-client-id
```

Optional env vars for the proxy:

```bash
TRADEWORKS_PROXY_TARGET=https://tradeworks-api-71668222585.us-east1.run.app/
TRADEWORKS_PROXY_PORT=8787
```

Optional app overrides:

```bash
flutter run -d chrome \
  --dart-define=TRADEWORKS_API_BASE_URL=http://localhost:8787/ \
  --dart-define=TRADEWORKS_GOOGLE_WEB_CLIENT_ID=your-google-web-client-id
```
