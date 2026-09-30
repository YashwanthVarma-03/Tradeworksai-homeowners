# Batches 1–13 verification record

Date: 2026-09-28. This records evidence from the local app and reviewed platform
source; it does not claim that an unconfigured production Supabase deployment was tested.

| Scope | Verified locally | Delivery state |
| --- | --- | --- |
| 1–4 | Authentication validation, Apple/OAuth navigation, theme, booking/cap flows, terms/privacy handling and preserved quote requests. | App code and mocked API checks pass; Apple entitlement/device setup requires the iOS project and Apple configuration. |
| 5 | Standard, urgent and emergency booking timing; fourteen-day availability; 120-minute server duration; stale availability protection. | Flutter timing tests and local PostgreSQL conflict/deadline checks pass. |
| 6 | Credit request IDs, client-side credit validation and booking payload contract. | Gateway contract tests pass. The authoritative reward/settlement RPC definitions are absent, so receipt-gated earning, rolling windows and live balances cannot be verified or safely rewritten. |
| 7 | Stream-backed Messages, dated Activity, direct-payment options and job-context messaging remain available. | App contracts pass; production Stream permissions and service credentials remain to be deployed/tested. |
| 8 | Four-state work-order mapping, cancellation actor, waiting states and terminal-state handling. | Flutter state tests pass. |
| 9 | Create/edit/delete review flow, immutable original date, tags and pro response metadata. | Gateway ownership/validation tests pass; migration is packaged for staging. |
| 10 | Session-stable random browse ordering, unranked search gateway and complete candidate retrieval. | Source reviewed and client tests pass; large live-dataset behavior needs staging. |
| 11 | Persistent pending arrival checks, idempotent answers, no-show case notification and contractor reply discovery. | Local PostgreSQL and gateway tests pass; migration and notification configuration need staging deployment. |
| 12 | Address-based home profiles, systems, private documents, active-job contractor context and short-lived contractor document links. | Auth/boundary tests pass; storage/RLS behavior needs staging validation. |
| 13 | Privacy redaction, scoped intake photo upload references, retained payment methods/messages, and account security APIs. | Client/API contract tests pass; live booking-photo persistence and account mutations need staging tests. |

## Executed checks

- `flutter test`: **73 passed** after the quote, rewards, compare and Orange Pass fixes.
- Gateway and home-profile Python tests: **15 passed** against the current platform checkout.
- Existing Service Credit gateway tests: **14 passed**.
- Disposable local PostgreSQL checks: arrival privacy/idempotency plus concurrent
  booking conflict, duration and urgency-window enforcement passed.
- Dart analysis of `lib test` contains no error or warning diagnostics; it
  reports 92 informational lint findings. Whole-repository analysis still
  encounters dependency/example errors in the vendored speech package.

## Deployment inputs still required

The supplied platform source calls `award_rewards_v23`, `book_slot_with_optional_credit`,
and `settle_work_order_financials`, but their SQL definitions are not in the checkout.
A non-production Supabase project is required to inspect and test those existing functions
without inventing financial behavior. Staging is also required to apply the packaged
migrations, configure Stream, validate RLS/private storage, and run real homeowner and
contractor flows. A signed iOS build additionally needs macOS/Xcode and the Apple signing
configuration.
