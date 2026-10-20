# Batch 32 implementation — October 19, 2026

Implemented against `batch-32-oct-17-manual-review-app.md`, after the existing Batch 31 edits. The newer brief supersedes the derived Activity fallback and the Rewards tab. Existing unrelated working-tree changes were preserved.

## Delivery status

| Item | App implementation | Remaining external work |
| --- | --- | --- |
| A1 | Camera/photo/add-library permission strings; microphone and speech descriptions for voice input. Chat exposes Photos, Camera and Files with document/image extensions only. | Fresh-install permission checks on a real iPhone. |
| A2 | Removed implementation copy; Push settings require configured push and server-provided preferences. Existing FCM startup/sign-in/token-refresh registration and sign-out removal retained. | APNs key/Firebase signing configuration and test-environment delivery must be enabled and verified by the signing/backend owners. |
| A3 | Empty Browse always shows B01; tab re-entry resets to B01 and focuses search. Removed all-pro rail and Filters. All opens the category list. | Real-iPhone keyboard recording. |
| A4 | Booking-only radio address sheet; add/select without changing default. Same-ZIP selection preserves time without fetching availability. Changed ZIP reloads availability and retains the matching window; missing windows return to When with the requested message. | Real-iPhone two-address recording. |
| A5 | 44px header Back/Close controls. Selected service/time or progressed flow requires Keep booking / Leave confirmation. Untouched first step closes directly. | None for app code. |
| A6 | Removed pro-calendar promises and updated booking validation copy. | None. |
| A7 | Shared route/tab unfocus, outside-tap/drag dismissal, numeric Done accessory, keyboard-aware sticky Save bars, form Next/Done actions, formatted US phone display and E.164 storage. | Real-iPhone pass across keyboard types and Profile/chat/booking screens. |
| A8 | Server-only Activity with retry error; shared alias/action routing for Activity and push; correct icon families; informational rows only mark read, resolved actions open their work order. Receipt actions scroll to the upload section. | Backend must supply durable notification/work-order/channel IDs, action state, and deliveries. Real-iPhone action/push recording. |
| A9 | Removed Stream commands button. | Backend must disable the channel-type `giphy` command. |
| A10 | No legacy reward tier; server available balance, positive reserved/locked explanatory lines, percentage band copy, annual-cap/reset message and completed checks. | Server supplies accurate balances, bands, cap and reset date. |
| A11 | Three-second Home service ticker pauses for focus/inactive tab and resumes afterward. | Device timing check. |
| A12 | Shared search control owns blue 1.5px focus border and neutral 1px rest border. | None. |
| A13 | Rating left, day-only availability right, single nonwrapping row. | None. |
| A14 | Compare/Added to compare/View profile share Inter 15/600 link typography. | None. |
| A15 | Shared paired actions use equal 52px dimensions and stack when measured labels cannot fit. Applied to History, shared sticky bars, booking and Home proposal actions. | None. |
| B1 | Home, Browse, Bookings, Inbox, Profile tabs; combined live message/Activity badge; removed Home inbox control. | Live unread-count verification with backend/Stream accounts. |
| B2 | Home purple gift and Profile Rewards entry open Rewards as a pushed screen with Back. | None. |
| B3 | Grey Search prefix and ink rotating service; offline/empty fallback. | None. |
| B4 | Borderless pin/location/chevron beneath Browse search; city/state/ZIP when provided. | None. |
| B5 | One selected property, default initial choice, per-account remembered selection, pills/default tag and property-specific Save. Single-property view retained. | Two-property live-account save verification. |
| B6 | Deleted Payment methods screen/row; added How do I pay FAQ. Pro payment information remains. | None. |
| B7 | Removed Help search/filter; grouped FAQs and contact remain. | None. |
| B8 | Job summaries wording; only server-advertised preference keys are displayed and PATCHed. Failed loads do not display cached toggles as working server settings. | Backend must expose supported preferences and persist updates; omit email.receipts if job-summary emails are unsupported. |
| B9 | Combined rating/count used only when both server fields exist. Combined bars and source counts; verified TradeWorks reviews followed by Google cards/date/G marks and external review link. Existing review display remains when fields are absent. | Backend Google sync and final review metadata payload. Supported fields are recorded below. |

## Conditional review fields

The app consumes `rating_combined`, `review_count_combined`, `rating_distribution_combined` (or `rating_breakdown_combined`), `tradeworks_review_count` (or `review_count_tradeworks`), `google_review_count` (or `review_count_google`), `google_rating`, `google_reviews`, and `google_review_url` (or `google_reviews_url`). It never calculates a combined average from a partial list of reviews. Google cards do not acquire a verified-job badge or a service label.

## Validation

- Full suite: **204 passed, 3 pre-existing failures**. The unchanged failures are the login golden (8.94% mismatch), single-home-profile golden (11.45% mismatch), and ZIP field height (expected 52px, existing 48px).
- Final targeted checks after the last form/navigation edits: **10 passed** (`batch32_ui_test`, `batch_25_responsive_test`, `transaction_navigation_test`, `auth_forms_test`).
- `dart analyze lib test`: **0 errors, 0 warnings**, 91 informational lints. Repository-wide vendor analysis was not used as a passing gate.
- `git diff --check`: passed. Git emitted only the existing Windows line-ending notices.
- Local logs: `batch32-verification.log`, `batch32-late-checks.log`, and `batch32-final-analyze.log` (ignored development artifacts).

Automated coverage includes phone normalization, keyboard Done/Save position, equal stacked buttons, remembered property choice, server-only Activity/error behavior, push aliases and resolved actions, booking address changes/exit confirmation, annual rewards cap, and combined-review source rendering. Updated golden images cover the changed Home/navigation, Browse, profile, Rewards and Help screens; representative images were visually inspected.

## Build and device evidence

- Base commit: `da75c4d`; changes are uncommitted in the existing working tree.
- Declared app version remains `1.0.0+1`; this is not a newly produced release build.
- No signed iOS build or iPhone screen recordings were produced in this Windows environment.
- No backend, Firebase/APNs credential, Stream channel configuration, or production deployment was changed.
