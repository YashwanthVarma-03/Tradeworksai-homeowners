# Google Calendar: homeowner app handoff

Implements Part E of `GOOGLE-CALENDAR-SPEC-2026-10-18 (1).md`, following the homeowner app track in `00-DEV-ORDER-OF-WORK (1).md`. Builds on the existing Batch 31 and Batch 32 changes in this working tree.

## App behavior

- **E1 complete:** search cards show rating on the left and `Next: {day}` on the right. Null search availability never produces a capsule. Signed-in availability refreshes can remove a stale capsule when the API returns null, no slots, paused status, or an ineligible response time. Empty labels never render `Next:` on its own. Dates remain day-only.
- **E2 complete:** rejected holds carrying `CALENDAR_BLOCKED` show “That time was just taken. Pick another window.” HTTP failures and `ok:false` responses preserve the error code even alongside generic error text. A rejected hold never proceeds to commit. The wizard reloads availability, clears the rejected time, and returns to time selection (or response-time selection for urgent/emergency bookings). Description, address, access notes, photos, pricing and credit selection remain in the existing wizard state.
- **E3 retained:** “Pick a 2-hour window that works for you” copy remains unchanged.

## Validation

- Service tests cover `CALENDAR_BLOCKED` in error, reason and code fields for HTTP 200 and 409, including no subsequent commit.
- Widget coverage checks null/empty availability, day-only capsules aligned opposite ratings, and a rejected hold followed by fresh availability and a successful retry. The retry asserts preserved description, address, access notes and selected service.
- Targeted verification: **65 tests passed** across booking service, Browse lazy-loading/visual, and booking timing tests (`flutter test --no-pub test/booking_service_test.dart test/browse_lazy_loading_test.dart test/booking_timing_test.dart`).
- `dart analyze lib test`: no errors or warnings; 91 existing informational lints.
- `git diff --check`: passed.

## External work

Parts B, C and D belong to the backend, contractor app and contractor portal. Google OAuth verification, busy-block sync and the live hold check require those projects. This change consumes their documented conflict response; it does not deploy or verify a live Google Calendar connection.

No release build, production deployment or signed iPhone device recording is included.
