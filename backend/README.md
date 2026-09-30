# Backend companion changes

`platform-batches-1-17-current.patch` is the reviewed gateway and migration
patch rebased on `tradeworksai/tradeworks-platform` main at
`4973243675bff795f180413d2dd4df4f24961c6c`. It preserves the website's
newer attachment and anniversary-rewards handlers. Generate it with
`python backend/export_platform_patch.py`; verify against that exact commit
before applying in a platform checkout. These changes have only been tested
locally and have not been deployed to Supabase or the website service.

The older files below are retained as reference material.
`platform-batches-1-13.patch` targets the superseded platform commit and must
not be applied to current main.

**Do not deploy the older website package as-is.** The subsequently supplied Flask
`routes.py` and the platform repository's `homeowner/home_profile_routes.py`
provide normalized Home Profile and receipt APIs. The app now uses those actual
routes. In particular, `home_profiles/main.py` and its `home_profiles_v2`
migration would introduce a competing data model and are superseded.

The older website patch is preserved for review of requirements still missing
from the newer gateway, not as a patch for the current platform checkout.
See `docs/backend-api-contracts.md` for authoritative sources and current gaps.

These files are prepared source changes, **not deployed services**. The user has
said Supabase details will be supplied later. The financial-accounting work is
not complete, so this directory is not a complete production deployment package.

## Files

- `website-batches-6-13.patch`: patch against website main
  `ba5b0c8ddcea08eec18a897cbce308151443cb13`. Includes authenticated review
  mutation/read actions, review dates/tags/response metadata, unranked paged
  contractor search, arrival answers/private notifications/list fields, durable
  booking-address linking, and homeowner-only creation of direct Stream channels.
- `home_profiles/main.py`: new function entry `home_profile` for the website's
  `/homeowner/home-profile-get` and `/homeowner/home-profile-action` route names,
  plus `/contractor/home-profile-get`. Preserve the original route path at the
  gateway. If the gateway strips it, use separate entrypoints; do not route
  contractor reads through homeowner authorization.
- `migrations/*.sql`: review metadata, private arrival cases and profile store.
  Review these against the actual schema before applying. They have not been
  executed against Postgres.
- `configure_stream.py`: defaults to read-only policy inspection. `--apply`
  removes client channel-creation/membership-mutation grants and disables read
  events on messaging. It preserves unrelated grants. Never apply before the
  server token handler and all clients are coordinated.
- `tests/test_home_profiles.py`: credential-free boundary tests.

Apply the website patch in a clean checkout with:

```powershell
git apply --check --ignore-space-change PATH/website-batches-6-13.patch
git apply --ignore-space-change PATH/website-batches-6-13.patch
```

The ignored local reference checkout already contains the changes. Do not apply
there a second time. `export_website_patch.py` regenerates the patch from that
checkout, excluding environment/config/credential files.

## Required integration checks

The current app uses a Supabase bearer token. The inspected website token/action
functions relied on supplied numeric IDs; patched functions derive those IDs
from a verified Supabase identity. Existing website clients must send bearer
tokens before these handlers replace their current deployment. Confirm the
email-to-legacy-ID mapping is unique and matches the test project's auth model.

Private home-profile storage has RLS enabled and no anon/authenticated table
access. The server checks address ownership, or a contractor's active confirmed
booking, before returning data. Files use private storage with signed URLs.
`lastServicedAt` comes only from completed work orders linked with `system_id`.
Legacy jobs need a reviewed address/system association; no fuzzy backfill is
performed. Address linking after an existing booking RPC is additive and reports
`homeProfileLinked=false` if it fails, rather than falsely claiming the already
committed booking failed. Move that binding into the existing atomic RPC once
its definition is available.

Arrival grace is provisionally two hours. The migration locks the work order,
checks ownership and cutoff, and records an idempotent answer for the exact
scheduled window. A no-show creates a private case and uses the existing website
notification helper. The helper is best-effort: validate delivery/retries and
support operations, including the pro's right to reply, before release. No job
or case is closed by silence.

Stream channels use the same sorted numeric-user pair ID as the Flutter app.
Only the authenticated homeowner can create a new pair with a public contractor;
existing members may return to their existing channel. The server check must be
combined with the grants update; a token-handler check alone cannot stop a client
from calling Stream directly. See the official
[Stream permission model](https://getstream.io/chat/docs/python/chat-permission-policies/)
and [Python SDK](https://github.com/GetStream/stream-chat-python).
The Python script targets the `stream-chat` package used by the website, not the
newer `getstream` SDK. Validate against the deployed version.

## Still missing — do not infer a working deployment

- Existing `book_slot`/credit/rewards SQL definitions are absent from the website
  checkout. The anniversary-period accounting, held rates, milestone awards,
  immutable earning snapshots, spending/expiry reconciliation and receipt upload
  transaction are not implemented here. The app consumes their required fields
  and does not substitute legacy calendar-year totals.
- The website's homeowner work-order handler has no `upload_paid_receipt` action.
  Complete that server path with receipt ownership, file validation, idempotency
  and atomic credit unlocking before enabling the feature in production.
- Contractor review-response creation and private case-reply lifecycle need
  verified server handlers and a staging exercise; schema/UI display alone is
  insufficient.
- Booking photos currently originate as local paths in the app. Verify and
  finish actual upload/storage in the booking integration.
- Migrations, storage, handlers, grant changes and live cross-device tests have
  not been run. No existing production data was migrated or changed.
