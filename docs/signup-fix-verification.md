# Signup fix verification

- The email validator now accepts standard addresses such as
  `person@example.com` and `first.last+tag@sub.example.co`, and rejects
  `invalid@`, `invalid`, and `@nodomain.com`.
- A valid form calls `AuthService.signUp`.
- When Supabase returns a user without a session, the app treats this as a
  confirmation-pending account, shows an informational message, and does not
  navigate to the dashboard or attempt password sign-in.
- When Supabase returns a session, the existing authenticated-session flow is
  unchanged and navigates to the dashboard.
- A missing user or a Supabase exception continues through the existing error
  notification path.
