# October 16 review fixes — homeowner app

Implemented October 19, 2026 against the current Flutter working tree. Existing uncommitted changes were preserved.

## Coverage

| Request | App result |
| --- | --- |
| A1 / R16-001 | Booking and credit share the same UUID. The service also writes the booking key into `creditRequestId`; covered by booking payload tests. |
| A2 / R16-004 | Live support requests enabled, topic labels retained, reference displayed. Null/error responses retain the email handoff. The backend must accept the supplied topic labels. |
| A3 / R16-006 | Dedicated no-show reply route retained and tested. Work orders now GET the private no-show case and display the pro reply below the status. |
| B1 / R16-030 | Cap scope/note and description-based items render; legacy label/name items remain supported. |
| B2 / R16-031 | ISO earliest expiry and `sourceAmount` supported, along with the older map shape. |
| B3 / R16-042 | Empty, invalid-only and failed feeds use derived events. Booked jobs produce a booking-confirmed event even outside the reminder window. |
| B4 / R16-041 | Review edits/deletes use review timestamps only. Both editor entry points require loaded review details. Cached reviews missing timestamps are fetched again. |
| B5 / R16-025–026 | Existing `POST notifications/read-all` and `DELETE push-tokens/{id}` retained and tested. |
| C1 / R16-060 | Bookings and Rewards titles restored; rewards golden expectations updated. |
| C2 / R16-061 | Decline-cap confirmation says the booking stays as it is. |
| C3 / R16-062 | Credits explanation reflects immediate application, diagnostic/cap/estimate limits and unused-credit returns. The referenced Batch 29 E3 document was not supplied; wording follows the supplied settled decisions. |
| C4 | Delete-account text uses the shared typography token. |
| D / R16-063 | Release script invokes Firebase plist setup/validation on every build. Push registration logs platform, result and duration without logging tokens. Device proof remains outstanding. |
| E / R16-072 | Removed all nine obsolete `*-v2-supabase` paths and their retries from the homeowner service. |
| Shared decisions G-38 | Free visits require a Standard two-hour calendar window and send it in `quote_request`, including confirmation times. This follows the October 16 decision, superseding the October 12 contract's no-window wording. |

## External work still required

The supplied tracker spans multiple repositories. This checkout contains the Flutter app and historical backend companion patches/reference copies, not the current October 16 platform/web source. No production database, backend, web portal, deployment, seed data or permissions were changed.

Backend/database/web findings remain with their listed owners: R16-002–005 (server portions), R16-006 (RPC portions), R16-007–011, R16-020–024, R16-027–029, R16-032–040, R16-043, R16-064–071 and R16-073 onward. In particular, verify credit RPCs/grants, cap decline, support topic mapping, free-visit reservations and estimate acceptance, credit returns, card aliases and push triggers against the live backend. Do not apply historical patches as substitutes for those fixes.

The supplied documents do not specify the no-show case response fields. The reader accepts `case`, `noShowCase` or `no_show_case` containers and explicitly named pro/contractor reply fields; confirm the deployed response in the device pass.

## iOS evidence to collect on the signing Mac

Run `bash tool/build.sh --build-number=<release-number>`. Retain the `Validated Firebase configuration for com.tradeworksai.homeownersapp.` line. Record the actual archive/TestFlight version and build number (the checked-in default remains `1.0.0+1`). On a fresh signed-in iPhone install, grant notifications and retain the `PERF` log for `POST homeowner/push-tokens platform=ios registered=true`. Confirm a matching server token row and receipt of an `en_route` push. Windows cannot produce this device evidence.

## Verification

Regression coverage includes booking/credit identity, free-visit windows, canonical routes without obsolete retries, support references, review concurrency timestamps, no-show case reads, empty Activity feeds, cap descriptions and rewards expiry. Rewards goldens cover 320, 390 and 768 logical pixels with enlarged text.

Full-repository `flutter analyze` also traverses vendored speech plugin examples/tests that lack their own dependencies (`speech_to_text_example`, `mockito`). Those unrelated errors are reported separately from app analysis.

Final app/test analysis (`flutter analyze --no-pub --no-fatal-infos lib test`) exits successfully with 75 informational lints and no errors or warnings. `git diff --check` passes. The full `flutter test --no-pub` run reports 192 passed and three failures on surfaces outside this batch:

- `guest_iteration_one_visual_test.dart`: login screenshot mismatch, 8.94%.
- `home_profile_visual_test.dart`: Home Profile screenshot mismatch, 11.45%.
- `input_field_style_test.dart`: ZIP dialog field expects 52 px; existing control measures 48 px.

The login, Home Profile and ZIP control implementations were not changed by this batch. Their golden baselines were not regenerated. The new regression cases pass in the full suite, as do the updated Rewards goldens.

The final focused run of `booking_service_test.dart`, `cap_approval_test.dart`, `rewards_contract_test.dart` and `rewards_visual_test.dart` passes all 68 tests without updating goldens. Bash syntax checks pass for both iOS scripts.
