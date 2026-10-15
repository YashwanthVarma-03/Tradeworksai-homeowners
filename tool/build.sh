#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="$project_root/.env.push"

if [[ ! -f "$env_file" ]]; then
  echo "Missing .env.push. Copy .env.push.example and add the Firebase values." >&2
  exit 1
fi

if [[ ! -s "$project_root/ios/Runner/GoogleService-Info.plist" ]]; then
  echo "Missing ios/Runner/GoogleService-Info.plist. Add the iOS app from Firebase project tradeworksai-senthil-dev-env before building a release IPA." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$env_file"
set +a

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
