# Production push notification handoff

The app now requests customer consent from **Notification settings**, registers
the current FCM/Web Push token, refreshes that registration whenever FCM rotates
the token, and filters foreground alerts against the homeowner's saved choices.

Before releasing, configure a Firebase project for the Android, iOS, and web
app IDs with FlutterFire. Keep generated credentials outside source control or
provide the following compile-time values to every production build:

```text
FIREBASE_API_KEY
FIREBASE_APP_ID
FIREBASE_MESSAGING_SENDER_ID
FIREBASE_PROJECT_ID
FIREBASE_AUTH_DOMAIN             # web
FIREBASE_STORAGE_BUCKET          # web, when applicable
FIREBASE_WEB_VAPID_KEY           # web push
```

The API must implement these authenticated actions on `homeowner/profile`:

```json
{
  "action": "update_notification_settings",
  "notificationSettings": {
    "pushStatus": true,
    "pushMessages": true,
    "pushCredits": false,
    "pushPromos": false,
    "emailReceipts": true,
    "emailPromos": false
  }
}
```

```json
{
  "action": "register_push_device",
  "deviceToken": "fcm-or-web-push-token",
  "platform": "android|ios|web",
  "notificationSettings": { "...": true }
}
```

The server must derive the homeowner from the access token, never from the
submitted `userId`, store tokens encrypted, replace duplicate tokens, remove
invalid-token responses from FCM, and check the relevant preference before it
sends. Use these FCM `data.notification_type` values:

- `work_order_status`
- `message`
- `credit` or `reward`
- `promotion`

Send a visible `notification` payload as well as the data payload for background
and terminated-app delivery. Include a work-order identifier or destination tab
for deep-link routing. Test release builds on physical Android and iOS devices;
browser and simulator behavior is not proof of phone delivery.
