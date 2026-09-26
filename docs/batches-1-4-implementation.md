# Batches 1–4 implementation

The six supplied files were read before editing. Their instructions were checked
against this checkout and the local backend source. The user's requirement to
preserve functioning features takes precedence over outdated assumptions in the
batch documents.

## Implemented

- Eight-character password minimum for signup and password reset. Existing
  password login remains compatible with older accounts.
- Apple sign-in above Google on both authentication screens. Native Apple
  devices use nonce-verified ID tokens; other platforms use Supabase's hosted
  OAuth flow. Both providers retain return-to-booking navigation and remember-me.
  First-authorization Apple names are saved to auth metadata.
- Password reset requests revocation of other sessions while preserving the
  current session. A revocation failure is reported truthfully after the password
  change succeeds.
- Signup links to the published Privacy Policy at
  <https://www.tradeworksai.com/privacy-policy/> with launch-error handling.
- Unreachable onboarding, booking-stepper and standalone receipt screens,
  legacy private builders, unused widget classes, disabled demo branches, mock
  data and the unused direct SVG dependency were removed. The real address cache
  was retained as `_cachedAddresses`.
- Supplied theme installed, dark-mode wrapper removed, specified color literals
  replaced by theme tokens, white panels given borders where needed.
- Both cap entry points use `CapApprovalScreen`. Fabricated prices, diagnosis,
  line items, ratings and competitor cards were removed. Missing, malformed,
  negative or non-finite caps cannot be approved. Real line items are displayed.
- Decline confirms cancellation first. Approval preserves the existing wire
  actions and uses a real available time if the existing backend requires a slot
  that is absent or in the past. The shared picker has a selection-only mode;
  ordinary rescheduling still submits the existing reschedule action.
- Cap-related display terminology updated in bookings, home and work-order
  details. Backend field names and actions remain unchanged.
- Sitemap corrected. Obsolete demo tests replaced by mocked API contract tests;
  cap-state, confirmation, navigation and signup validation tests added.

## Changes deliberately withheld to preserve features

| Requested change | Evidence and decision |
| --- | --- |
| Delete the two `custom_widgets.dart` auth imports | Both screens use `createPremiumRoute`. Kept the imports and that live navigation helper, which also sits inside the document's proposed class-deletion span. |
| Remove `quote_request` and its pricing/booking behavior | `../v2-supabase/v2-supabase/booking-commit-v2-supabase/main.py` implements this action around lines 187–226. Kept the current booking branch and its estimate wording, including the booking-success price parser. Removing it would change a supported feature. |
| Wire account deletion | Local `homeowner-profile-v2-supabase/main.py` has no `delete_account` action and rejects unknown actions. No misleading deletion button or client-only logout was added. |
| Wire email changes to `homeowner/verify` | Local `homeowner-verify-v2-supabase/main.py` looks up an existing email and only marks that profile verified. Unknown emails intentionally return success without sending mail. It does not update Supabase sign-in email or notify the old address. Kept the existing save function and replaced its misleading verification promise with a support instruction. |
| Link signup to Terms | The published homeowner page links to `https://www.tradeworksai.com/terms/`, but a readable Terms page could not be verified. No fabricated consent statement or unresolved Terms link was added. A confirmed Terms URL is still needed. |
| Submit a cap without a schedule | Current `quote_accept` rejects requests missing `startsAt` or `endsAt` (backend lines 229–232). Reused real availability selection instead of the old invented tomorrow appointment or the supplied null times. |

Local backend source is evidence of the available contract, not proof of the
currently deployed version. No production account, booking or backend was mutated.

## External setup and deferred product decisions

- Enable Apple in Supabase, register the Apple identifiers/callbacks and enable
  Sign in with Apple in the actual iOS target. This checkout contains generated
  iOS files but no Xcode project, so an entitlement cannot be attached here.
  Real-device Apple sign-in and second-device session revocation remain untested.
- Server-side cap enforcement and any diagnostic-fee credit/waiver require
  backend/product confirmation. No fee-waiver amount is invented.
- Batch 3 explicitly defers service-category tints, red warning surfaces, black
  and gray roles, and orange placement across existing screens. Those design
  decisions remain unchanged; therefore the deferred red/purple hex literals
  remain outside `theme.dart`. The new cap screen follows the supplied palette.
- Inbox message synthesis, rewards rules, and payment functionality remain
  outside these batches as specified in the documents.

## Validation

- `flutter pub get` completed and the lockfile includes Apple sign-in.
- `flutter test --no-pub`: **43 tests passed**, including preserved quote-request
  submissions, cap acceptance/decline wire payloads, application-level failures,
  malformed cap data, cancelable decline confirmation, shared detail navigation,
  signup password validation, and existing app regression tests.
- `flutter build web --no-pub`: release build succeeded (`build/web`).
- `flutter analyze --no-pub lib test`: no errors, warnings, or unused elements;
  informational style lints remain. Full-root analysis also includes existing
  errors in the vendored `third_party/speech_to_text` example/tests, which were
  not modified.
- Phone layout smoke renders covered signup and cap ready/empty states at
  390 × 844, plus a compact cap screen at 320 × 568, with no layout exceptions.
  Test rendering uses local substitute fonts and does not verify production
  font rendering or every authenticated screen.
- `git diff --check`: clean.

Live authenticated end-to-end flows require a test account and backend
environment; automated tests use local fixtures and mocked HTTP responses.

References for Apple integration:
[Supabase native ID-token sign-in](https://supabase.com/docs/reference/dart/auth-signinwithidtoken),
[Apple provider setup](https://supabase.com/docs/guides/auth/social-login/auth-apple).
