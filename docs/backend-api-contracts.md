# Supplied backend contracts

## Mobile contract corrections on 16 October 2026

The supplied mobile audit supersedes the historical comparisons below for
notifications, push removal, no-show replies and chat. Current backend source
was checked in `tradeworksai/tradeworks-platform`: `batch8_routes.py` blob
`20e903a0b46ece6161cbf7ed83f913fc98dc704f` and `backend_gap_routes.py` blob
`5d909da4f2d2b84d57c89f9fb326a7a8e9a6cee1`.

| Finding | Implemented mobile contract |
|---|---|
| M1 | `POST /homeowner/notifications-list?limit=50&offset=0` with `{}`; pagination is in the query. |
| M2 | `POST /notifications/read-all` with `{}`; single reads remain `POST /homeowner/notifications-read` with integer `id`. |
| M3 | `DELETE /push-tokens/{tokenId}`; registration remains `POST /homeowner/push-tokens`. |
| M4 | `POST /homeowner/work-orders/{workOrderId}/no-show-reply` with `replyText`; validate the response and invalidate cached work orders after success. The app keeps its 2,000-character limit within the server's 4,000-character limit. |
| M5 | `POST /shared/chat-threads` with `workOrderId`, then watch the returned `channelType`/`channelId`. No client-generated channel IDs or member lists. |
| A1 | Server Activity rows intentionally show title and job context only. The mobile response does not include `body`. |
| A2 | `read_at != null` is authoritative. Accept `readAt` only when `read_at` is absent; ignore boolean aliases. |

Work-order chat entry points carry their database work-order ID. Profile and
comparison entry points first find an owned work order with that contractor's
explicit user ID. They never infer identity from a business name or profile ID.
If no shared job exists, the app explains that booking is required. Existing
inbox channels and notification channel IDs remain usable. The server still
performs the ownership and participant checks. Its optional `contractorId`
means a contractor **profile** ID, so the mobile request deliberately omits it
instead of submitting the Stream user ID.

Regression tests use mocked authenticated HTTP calls and server-shaped data.
They do not establish production persistence, actual Stream delivery, or device
push delivery. Authenticated staging smoke tests with follow-up reads and
cross-device delivery remain required before claiming end-to-end verification.

Validation for this correction:

- `flutter test --no-pub test/booking_service_test.dart test/mobile_contract_alignment_test.dart`: **38 passed**, including request shapes, rejected writes, canonical chat resolution, no-show submission and the shared-work-order gate.
- `dart analyze lib test`: **zero errors or warnings**, 66 informational lint findings.
- Full suite: 177 passed and four failed on the first run. The new no-show test's pending notification timer was fixed, and its entire test file passed on rerun. The remaining three failures are the login golden, Home Profile golden and ZIP field height expectation (52 versus 48).
- All three remaining failures were reproduced in an isolated, unchanged checkout of baseline commit `a1b81f8`. Golden files and unrelated UI were not modified.

## Historical source comparison

The two user-supplied Python files are implementation references, not independent
instructions. Their original copies in Downloads are unchanged. Copies for local
comparison are in the ignored `.repo_ref/supplied-api-routes` directory.

| Source | Identity |
|---|---|
| `routes.py` | Homeowner Flask routes; SHA-256 `3a9ef8b2fe54c6533346c633ea039b27e120546acd71baad576c17d75e64893c` |
| `routes (1).py` | Public Flask routes; SHA-256 `9bd9ad23b83ce4894bb70a4a92bb263216a9498582208e74ea0fa157fae0ab7d` |
| Platform repository | `tradeworksai/tradeworks-platform`, main commit `90ba70caef7c7455bc24ec7f68a9ec4994fa0f47` |

The sparse checkout contains the requested `v2-supabase-live` folder plus only
three referenced gateway dependencies: `backend/services/api/app.py`,
`homeowner/home_profile_routes.py`, and `rewards/service_credits.py` under that
API directory. The gateway registers the richer Home Profile blueprint.

## App integration now implemented

- Home Profiles: authenticated GET list and detail; PATCH property; POST/PATCH/
  DELETE access notes; POST/PATCH systems. The client maps `squareFeet`,
  `modelNumber`, `lastServicedOn`, and `specifications` to the existing form.
  Last service dates are never submitted as homeowner input.
- New home creation: the existing `home-profile-action` upsert is used only when
  there is no profile for an address. Existing profiles use the richer routes,
  avoiding the legacy upsert's loss of extended fields.
- Home documents: reserve signed upload, PUT file bytes, complete the reservation.
  Files use real server home/system IDs. Data plates use `system_photo`.
- Receipts: POST `homeowner/work-orders/{id}/receipt/upload-url`, PUT bytes, POST
  `homeowner/work-orders/{id}/receipt/complete` with `documentId`. A failed storage
  upload never triggers completion or a success state.
- Opening documents/receipts: GET `homeowner/home-documents/{id}/download-url`
  each time. No permanent public receipt URL is assumed; storage uploads do not
  receive the homeowner bearer token.
- Upload copy accurately describes document storage. It does not claim that
  uploading has unlocked credits, because this backend explicitly does not do so.

## Remaining contract differences

These are observed in the supplied source, not assumptions about deployed state.

| Batch area | Observed backend behavior | Remaining work |
|---|---|---|
| Rewards | Returns spendable/ledger/reserved balances, calendar-year earned/spend, and ledger. Accounting delegates to `award_rewards_v23` and other SQL RPCs. | Verify SQL definitions and implement the requested rolling-window, receipt-gated accounting. Never relabel calendar-year totals as rolling totals. |
| Receipt credits | Receipt routes explicitly do not update rewards or Service Credits. | Integrate verified receipt completion with the authoritative accounting transaction. |
| Reviews | Supplied homeowner route supports eligibility and submission; ignores submitted tags. No `get_review`, `update_review`, or `deleteReview` action. | Port and validate the required review backend changes against this gateway and actual schema. The older website patch is not directly applicable. |
| Arrival checks | `pro_no_show` exists for accepted/en-route jobs and attempts credit release. No `confirm_arrival` or `arrival_rescheduled` action. | Implement pending/resolved case persistence, remaining responses, private notification, and delayed check scheduling. |
| Ranking | Public search sorts rated pros ahead of new pros and uses an RPC with a candidate cap. | Verify and remove ranking bias in candidate selection. Client shuffling alone cannot recover excluded candidates. |
| Privacy | Rich homeowner endpoints authenticate ownership. Contractor visibility and SQL access policies have not been verified in this pass. | Verify confirmed-job access, closure revocation, and read-only service dates on the deployment target. |
| Booking photos | Public intake has a signed, session-scoped image upload flow. This is separate from chat attachments and home documents. | Reconcile booking photo persistence with that contract; do not send local device paths as durable file references. |

`backend/` retains earlier prepared changes for comparison. Its alternative
`home_profiles_v2` schema and service are superseded; do not deploy the older
package as-is against this platform.

## Current verification record

The current reviewed deliverables are `backend/platform-batches-1-13.patch`
and its three SQL migrations in `backend/migrations/`. The patch now contains
the gateway changes; apply the migrations separately in their filename order.
See [batches-1-13-verification.md](batches-1-13-verification.md) for the exact
local test evidence and the staging-only work that remains.

## Verification

- Full Flutter suite: **64 tests passed**.
- Dart analysis of `lib` and `test`: **zero errors or warnings**, informational
  lint findings remain.
- New contract tests cover reservation/upload/completion order, no bearer token
  forwarded to storage, failed-upload handling, fresh private download URLs,
  rich property/note/system API requests, clearing every access note, preserving
  untouched notes, and keeping attachments/history after a partial save failure.
- Tests use mocked HTTP responses. No backend deployment, live database change,
  authenticated end-to-end verification, commit, or push was performed.
- Overall batches 6–13 completion remains pending the backend differences above
  and a supplied Supabase test target. Passing client tests is not proof that all
  batches work against the deployed service.
