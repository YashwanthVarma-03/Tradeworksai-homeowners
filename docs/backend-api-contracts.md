# Supplied backend contracts

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
