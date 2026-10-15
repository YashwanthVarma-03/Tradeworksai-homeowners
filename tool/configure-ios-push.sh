#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
destination="$project_root/ios/Runner/GoogleService-Info.plist"
app_id="1:71668222585:ios:346d80f26849d80fb222a8"
project_id="tradeworksai-senthil-dev-env"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Run iOS project setup on the Mac used for TestFlight." >&2
  exit 1
fi
swift --version >/dev/null

if [[ ! -s "$destination" ]]; then
  # The Runner project already links this exact resource. No project rewrite
  # or extra native Firebase package is needed; Flutter manages the plugins.
  npx -y firebase-tools@latest apps:sdkconfig IOS "$app_id" \
    --project "$project_id" --out "$destination" --non-interactive
fi
read_value() { /usr/libexec/PlistBuddy -c "Print :$1" "$destination"; }
if [[ "$(read_value BUNDLE_ID)" != "com.tradeworksai.homeownersapp" ||
      "$(read_value PROJECT_ID)" != "$project_id" ||
      "$(read_value GOOGLE_APP_ID)" != "$app_id" ]]; then
  echo "Existing iOS Firebase configuration does not match. It was not overwritten." >&2
  exit 1
fi
echo "Validated Firebase configuration for com.tradeworksai.homeownersapp."
echo "APNs credentials, Apple signing, and real delivery still require verification."
