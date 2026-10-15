#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="$project_root/.env.push"
ios_plist="$project_root/ios/Runner/GoogleService-Info.plist"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "An iOS release must be built on a Mac with Xcode and signing configured." >&2
  exit 1
fi

if [[ ! -s "$ios_plist" ]]; then
  echo "Missing ios/Runner/GoogleService-Info.plist. Run bash tool/configure-ios-push.sh first." >&2
  exit 1
fi

if [[ -f "$env_file" ]]; then
  set -a
# shellcheck disable=SC1090
  source "$env_file"
  set +a
fi

# Always derive iOS Firebase values from the iOS plist. An Android .env.push
# must never silently compile its Android Firebase app ID into the iPhone app.
plist_value() { /usr/libexec/PlistBuddy -c "Print :$1" "$ios_plist"; }
FIREBASE_API_KEY="$(plist_value API_KEY)"
FIREBASE_APP_ID="$(plist_value GOOGLE_APP_ID)"
FIREBASE_MESSAGING_SENDER_ID="$(plist_value GCM_SENDER_ID)"
FIREBASE_PROJECT_ID="$(plist_value PROJECT_ID)"
if [[ "$(plist_value BUNDLE_ID)" != "com.tradeworksai.homeownersapp" ||
      "$FIREBASE_APP_ID" != 1:71668222585:ios:* ||
      "$FIREBASE_MESSAGING_SENDER_ID" != "71668222585" ]]; then
  echo "Firebase plist does not match the homeowner iOS app/project." >&2
  exit 1
fi
TRADEWORKS_GOOGLE_IOS_CLIENT_ID="${TRADEWORKS_GOOGLE_IOS_CLIENT_ID:-$(plist_value CLIENT_ID 2>/dev/null || true)}"

required=(
  FIREBASE_API_KEY
  FIREBASE_APP_ID
  FIREBASE_MESSAGING_SENDER_ID
  FIREBASE_PROJECT_ID
  TRADEWORKS_GOOGLE_IOS_CLIENT_ID
)
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    echo "Missing $name in .env.push" >&2
    exit 1
  fi
done

if [[ "$FIREBASE_PROJECT_ID" != "tradeworksai-senthil-dev-env" ]]; then
  echo "FIREBASE_PROJECT_ID must be tradeworksai-senthil-dev-env for this build." >&2
  exit 1
fi

if [[ ! "$TRADEWORKS_GOOGLE_IOS_CLIENT_ID" =~ ^([0-9]+-[A-Za-z0-9_-]+)\.apps\.googleusercontent\.com$ ]]; then
  echo "TRADEWORKS_GOOGLE_IOS_CLIENT_ID must be an iOS OAuth client ID." >&2
  exit 1
fi
google_client_prefix="${BASH_REMATCH[1]}"
printf 'GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.%s\n' \
  "$google_client_prefix" > "$project_root/ios/Flutter/GoogleOAuth.xcconfig"

cd "$project_root"
flutter build ipa --release \
  --dart-define="FIREBASE_API_KEY=$FIREBASE_API_KEY" \
  --dart-define="FIREBASE_APP_ID=$FIREBASE_APP_ID" \
  --dart-define="FIREBASE_MESSAGING_SENDER_ID=$FIREBASE_MESSAGING_SENDER_ID" \
  --dart-define="FIREBASE_PROJECT_ID=$FIREBASE_PROJECT_ID" \
  --dart-define="TRADEWORKS_GOOGLE_IOS_CLIENT_ID=$TRADEWORKS_GOOGLE_IOS_CLIENT_ID" \
  "$@"
