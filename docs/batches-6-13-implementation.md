# Batches 6–13 — implementation and remaining work

Status: **app implementation in progress; the overall request is not yet complete**.
The user will provide Supabase details later. No backend migrations, cloud
functions, Stream permissions, or production data were changed in this session.
No Git commit or push was made for this batch implementation.

## Source and user decisions

Requirements came from batches 6–13 and the two supplied Dart references in
`C:\Users\yashw\Downloads`. Their suggested removals were overridden by the user:
Messages **Activity** and **Payment Methods** remain in the app.

Backend reference: `https://github.com/Abbhinov/TradeWorksAI-Website-FULL-CODE`,
main commit `ba5b0c8ddcea08eec18a897cbce308151443cb13`.
The inspected checkout is ignored at `.repo_ref/website-batches-6-13`;
backend edits are exported into **tracked deliverables** under `backend/`.

## New backend reference takes precedence

The supplied homeowner/public route files and the platform checkout now supersede
previously inferred contracts. See [backend-api-contracts.md](backend-api-contracts.md).
Home Profile and receipt uploads now use the normalized, authenticated gateway
APIs and signed storage uploads. Earlier descriptions below of a missing receipt
endpoint or a required `home_profiles_v2` service are superseded. The older backend
package must not be deployed as-is.

## Coverage

| Batch | Implemented locally | Remaining before completion |
|---|---|---|
| 6 — Rewards | Rolling-window field contract; no relabelled calendar totals; conditional bands, milestones and expiry; seven ledger types; expired rows last; paid basis; zero-paid receipt suppression; money-block navigation; real document opening; receipt-upload client. | Website rewards still implements the old calendar-year model. Implement and validate transactional marginal earning, held bands, immutable job-date rates, milestone grants/expiry, application of credits and `upload_paid_receipt`. This needs the existing database functions/schema. |
| 7 — Messaging | Real Stream channels/unread state; retained Activity uses dated booking events; one pair-based channel; dismissible per-message job reference, cleared after send; no receipt indicators or invented chats; server creation guard and Stream grant configuration prepared. | Deploy authenticated token/channel creation and coordinated Stream grants; update website clients to send bearer tokens. Verify homeowner initiation, pro cold-contact rejection, replies, attachments and retries against a test Stream app. |
| 8 — States | Shared four-state mapping; legacy aliases; waiting overlay; explicit cancellation actor or neutral Cancelled; detail-only timeline; no fake live update label, ETA or list progress; terminal states hide progress. Skipped intermediate states are not falsely checked off without timestamps. | Live API/device checks after deployment. |
| 9 — Reviews | No default stars/tags/praise; invoice-gated cap tag; published-name disclosure; tags in payload; edit/delete; edited date and one pro response in profile/full list/history; credits independence; missing review details do not open an empty edit form. Website patch adds review actions/metadata and preserves original date on edits. | Apply metadata migration and deploy handlers. Validate ownership, moderation, cache invalidation and author actions live. Contractor response authoring is not present in the inspected website handler; verify its writer/endpoint before claiming the full response lifecycle works. |
| 10 — Browse | Stable random order for the session, including filters and refresh; no quality adjectives/sort controls; facts and no-review state; truthful coverage; newest-first reviews; raw review dates and fully paged unranked candidate/service/review loading in website patch. | Deploy and verify full-result behavior on a sufficiently large test dataset. |
| 11 — Arrival | Arrival answers, no-show confirmation and recovery browse scoped to category/ZIP; Home/detail entry; once-per-user/check app-open prompt; persisted seen state; unanswered checks remain visible; customer-no-show explanation. Prepared atomic arrival-answer migration, private cases, pending flag and pro notification. | Apply/verify migration and notifications. Two-hour grace is provisional. Validate contractor right-of-reply handling and operational support-case review in the deployment. |
| 12 — Home profile | Server-backed address profiles; property fields; add/edit systems; manual data-plate photos; getting-in notes; documents associated with systems; read-only service date; signed URLs renewed on open/retry; no completion percentage; no false maintenance claims. New authenticated handler/private storage schema prepared. | Deploy routes/storage/migration. Confirm real schema, durable booking-address association and system/work-order association. Review legacy address backfill; verify cross-device persistence and access revocation when jobs close. |
| 13 — Privacy/sweep | Removed booking access notes and dead pricing/location steps; scoped intake description survives filters and reaches editable booking field; explicit Inter family; updated sitemap; retained Payment Methods now shows booked pros’ published options and messaging, with no fake stored-card workflow. | Device visual check and live end-to-end booking/photo verification. Existing booking code sends local photo paths; real remote upload acceptance must be verified against the booking RPC/storage contract before claiming photos reach the pro. |

## Verification

- Original 43 Flutter tests passed after the main changes.
- Added status/arrival/session-order/review/widget/API contract tests, including
  failure states and compact-screen rewards. Final results are recorded below.
- Six Python tests passed for authenticated identity, property-value validation,
  note limits, immutable service dates, file ownership and MIME validation.
- Backend Python syntax validated; website patch checked against the modified
  reference checkout with `git apply --reverse --check --ignore-space-change`.
- Flutter production web build succeeded. This is a compilation check, not a
  signed iOS build or a production backend verification.
- Static analysis has no errors or warnings; informational style lints remain.
- Browser visual verification was attempted, but the browser tool reports an
  empty browser inventory; both in-app browser and Chrome were unavailable.
  No device/screenshots or authenticated live flows have been verified.

## Finish review — changes required

A separate read-only reviewer identified six app/source issues: chronological
review dates, intake-description retention, history review annotations, expiring
document links, placeholder Call behavior and list-formatted tags. All six have
been addressed; the final reviewer rescore is recorded separately below.
The visual disposition remains **not assessed**, and backend completion remains
pending. These limitations must not be described as a full pass.

## Resume when Supabase details arrive

1. Read `backend/README.md` and inspect the actual SQL schema/RPC definitions in
   the designated non-production project. Reconcile types and ownership mapping.
2. Complete receipt/rewards accounting and booking photo storage atomically with
   the current booking/credit functions. Do not replace production balances or
   reinterpret legacy transactions without a reviewed migration.
3. Apply the reviewed migrations and deploy the website patch/new profile routes
   to staging; configure the Stream grants only with the compatible clients.
4. Exercise all batch definitions of done using test homeowner/pro accounts,
   including second-device persistence, job-close access denial, retry/idempotency,
   no-show replies, grant/expiry boundaries and zero-paid bookings.
5. Complete visual QA, then update every remaining item with deployment/test
   evidence before marking all batches complete.
## Final local results

- **58 Flutter tests passed** in the final full suite.
- Static analysis (`--no-fatal-infos`): **zero errors and zero warnings**;
  informational style lints remain.
- Production web build passed before the final small client refinements; the
  final refinements passed analysis and the full test suite.
- **Six Python boundary tests passed**; SQL migrations are not yet executed.

### Final reviewer verdict: six code findings resolved; visual finish unverified

| Finding | Final status |
|---|---|
| Chronological review order | Resolved in source and exported backend patch |
| Intake description lost after filtering | Resolved |
| History missing review annotations | Resolved |
| Expired document/photo URLs | Resolved |
| Placeholder Call action | Resolved |
| Raw list formatting for tags | Resolved |

This verdict covers those six corrections. Backend deployment, rewards accounting
and live end-to-end verification remain pending the Supabase details that the
user will supply later. Visual review is unverified because no browser was
available to the automation tool.


## Verification after supplied API integration

- Full Flutter suite: **64 tests passed**. The final targeted API suite has 16
  tests, including private upload and multi-note/partial-save regressions.
- Analysis: no errors or warnings; informational lints remain.
- Read-only finish review: API mapping findings resolved in source. Live and
  visual verification remain pending.
- Home Profile uses the normalized gateway APIs. Receipt upload uses signed
  storage and completion, with work-order cache invalidation afterwards.
- Backend gaps are tracked in `backend-api-contracts.md`; this is not a claim
  that the full batches request is complete or deployed.
