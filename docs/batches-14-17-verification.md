# Batches 14–17 implementation record

The homeowner app now includes the supplied changes for decisions, guides and notifications, Orange Pass, and pro comparison.

## Delivered behavior

- Activity is a read-only, timestamped work-order timeline. Payment options and the existing Messages Activity remain available, following the product decision made during implementation.
- Customer no-show cases provide a private homeowner reply of up to 2,000 characters. The API stores the reply without closing or deciding the case.
- Select-certified information is available from search, contractor profiles, and Support. The profile deletion path submits a deletion request through the authenticated account API.
- Rewards use the sign-up anniversary rewards year and disclose the stated annual $2,665 credit ceiling and manual redemption process.
- Guides use the approved booking language and support telephone number. Notifications route reward-expiry notices to the Rewards tab.
- Orange is limited to deliberate calls to action and selected service-category treatment; system states use the application status colors. Busy states use navy and star ratings use gold.
- Compare Pros supports two or three selected pros, displays the required neutral attributes, keeps the comparison unranked, and provides Book, Message, and Profile actions. Message opens the existing chat screen without a work-order reference.

## Backend handoff

The gateway changes and local SQL migrations are packaged by `backend/export_platform_patch.py` as `backend/platform-batches-1-17-current.patch`, rebased on platform main `4973243`. The patch includes the no-show reply handler and migration, the review and arrival endpoints, home-context access, and compare fields. Applying it remains a deployment task because no Supabase staging project or credentials have been provided.

## Automated verification

- Flutter widget and contract tests cover the app shell, authentication, booking timing, work-order status, rewards payloads, review states, and comparison compilation.
- `backend.tests.test_platform_contracts` parses the edited gateway sources and exercises ownership, arrivals, reviews, notification delivery, and customer no-show replies.
