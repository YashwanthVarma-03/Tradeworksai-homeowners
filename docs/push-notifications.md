# Homeowner notifications: iOS build and verification

Updated 15 October 2026. Based on the 14 October Firebase Push From-Zero guide.

## Current status

The Flutter notification code supports Android and iOS. **Real iPhone delivery is not yet verified here.** Automated tests do not prove APNs delivery.

| Item | Status |
| --- | --- |
| Firebase project | `tradeworksai-senthil-dev-env` |
| iOS bundle ID | `com.tradeworksai.homeownersapp` |
| Registered iOS Firebase app ID | `1:71668222585:ios:346d80f26849d80fb222a8`; live Firebase listing confirms ACTIVE and the correct bundle ID |
| Saved Firebase plist | Matching bundle, project and sender verified locally in `.firebase-config` |
| APNs key in Firebase | User confirmed uploaded; not independently inspected |
| Mac and physical iPhone | User confirmed available; no connected Mac build session here |
| Firebase CLI live check | Reauthenticated; iOS app listing succeeded on 15 October 2026 |
| Native project | Runner already references the plist and push entitlement |
| APNs environments | Debug: development. Profile/Release: production |
| Background modes | Remote notifications present. Background fetch still needs enabling on the Mac |
| IPA/TestFlight delivery test | Pending |

No backend files or services were changed. No APNs private key belongs in the app.

Validation on Windows: 43 focused tests passed (33 notification/token checks and
10 existing account/data regression checks). Targeted analysis found no errors
or warnings; existing dashboard style suggestions remain. Both shell scripts
passed Bash syntax checks. These checks do not replace a signed iPhone build.

## App changes

- TradeWorks and Stream share one permission/APNs token gate. iOS waits up to ten seconds for APNs before requesting FCM.
- The wait stops if the active account changes. TradeWorks also cancels the wait when backgrounded.
- Returning to the foreground retries registration and reloads server preferences. It does not ask for permission again on resume.
- Firebase initialization is shared between simultaneous callers. Transient failure can be retried.
- Notification listeners start while signed out. Pending destinations can open after login.
- Token registration calls are serialized. Sign-out waits for in-flight cleanup while the old session is available, then clears local alerts and pending navigation.
- An Activity row's `id` is not a work-order ID. Invalid destinations fall back to Activity.
- The IPA build reads Firebase values from the iOS plist, preventing accidental use of Android Firebase values.

No new background polling timer was added. The existing no-Firebase fallback checks Activity once per minute only while foregrounded and stops when backgrounded. Configured FCM builds do not run that timer.

## Prepare the Mac

Use this updated source with Flutter, Node, Xcode, Swift and Apple signing configured.

```bash
npx -y firebase-tools@latest login --reauth
bash tool/configure-ios-push.sh
```

The script downloads the existing iOS app's public Firebase plist to `ios/Runner/GoogleService-Info.plist`. It does not create another app, change the bundle ID, overwrite an existing plist, or rewrite the Xcode project. Runner already links that filename.

Open `ios/Runner.xcworkspace` and check:

1. The bundle ID is exactly `com.tradeworksai.homeownersapp`.
2. The signing team and provisioning profile include Push Notifications.
3. Background Modes includes Remote notifications **and Background fetch**.
4. The Firebase plist is in Runner's Copy Bundle Resources.
5. Firebase method swizzling is not disabled.
6. Firebase Cloud Messaging has the correct APNs Key ID and Apple Team ID.
7. Stream's Firebase push provider uses this project. TradeWorks token registration does not configure Stream's server-side provider.

The saved plist has no Google iOS OAuth client ID. The existing release script also requires `TRADEWORKS_GOOGLE_IOS_CLIENT_ID` for Google sign-in. Supply the real iOS OAuth client in the Mac environment or `.env.push`, not an Android or web client.

```bash
bash tool/build.sh --build-number <next-TestFlight-build-number>
```

This runs `flutter build ipa --release`. It checks the Firebase project, sender, bundle and iOS app-ID format before building. Upload using the team's normal TestFlight process. An APK does not update iOS.

## APIs used

TradeWorks calls use the signed-in homeowner's Supabase bearer token. These are contracts, **not new live iPhone response captures**.

| Action | API | Request | Response used |
| --- | --- | --- | --- |
| Register phone | `POST /homeowner/push-tokens` | `{"provider":"fcm","platform":"ios","token":"<FCM token>"}` | Token-record ID; missing ID is an error |
| Remove phone | `DELETE /homeowner/push-tokens/<tokenId>` | No extra user ID | Success before session clear; failed deletion queued for that account |
| Read preferences | `GET /homeowner/account` | No body | `account.preferences.push` and `.email` |
| Save preferences | `PATCH /homeowner/account/notification-preferences` | `{"preferences":{"push":{"messages":true}}}` | Success, then update local cache |
| Open Activity | `POST /homeowner/notifications-list` | `{"limit":50,"offset":0}` | `notifications[]`, `unreadCount`, `read_at` |
| Mark one read | `POST /homeowner/notifications-read` | `{"id":1056}` | Success; update unread state |
| Mark all read | Same read API | `{"all":true}` | Success; update unread state |
| Enable chat push | Stream `addDevice(token, PushProvider.firebase)` | FCM token and connected user | Stream registration success |
| Disable chat push | Stream `removeDevice(token)` | Registered token | Stream removal success |

The old `homeowner/profile` actions `register_push_device` and `update_notification_settings` are invalid and must not be used.

## Tap destinations

| Payload | Screen |
| --- | --- |
| `cap` + valid `work_order_id` | Cap approval |
| `reschedule` + valid `work_order_id` | Reschedule proposal |
| `receipt` / `expiring_soon` | Rewards |
| `message` + valid `channel_id` | Matching Stream conversation |
| Other work-order event + valid `work_order_id` | Work-order detail |
| Missing or invalid destination | Activity |

iOS uses native foreground presentation; the app does not create a second local banner for the same FCM notification. Background and terminated alerts require a visible notification payload from the sender.

## Physical-iPhone acceptance checks

Use dedicated test accounts/jobs. Do not modify real customer bookings or send test messages to real pros. Record TestFlight version, iOS version, timestamp, app state, expected result and actual result. Redact tokens, JWTs and customer details.

| Check | Expected result | Evidence still needed |
| --- | --- | --- |
| Sign in; allow notifications | APNs then FCM; POST has `platform: ios`; token ID returned | Device trace + redacted response |
| Foreground En route | One native banner; Activity updates | Screenshot/video |
| Background cap; tap | Correct Cap approval opens | Video |
| Terminated reschedule; tap | Session restores; correct proposal opens | Video |
| Receipt / expiry | Rewards opens | Video |
| Stream message in background | Alert arrives; correct chat opens | Video + Stream result |
| Deny permission | No repeated prompt; Activity still works | Device observation |
| Enable permission in Settings; return | Registration retries | Redacted POST/response |
| Disable status push | No status push; Activity row remains | Device + Activity response |
| Disable message push | Stream device removed | Stream response |
| Change preference on second device | Preferences reload on resume | Account response |
| Sign out | Stream removal and TradeWorks DELETE precede session clear; no new old-account alerts | Responses + test push |
| Sign in as different user | No cross-account delivery | Device test |

Native project edits/build verification were paused because the Xcode setup skill requires Swift and this Windows machine has no Swift/Xcode. Perform the native checks on the available Mac.

References: [Firebase setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started), [Receiving messages](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).
