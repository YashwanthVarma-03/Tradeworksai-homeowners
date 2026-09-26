# Homeowners App Sitemap

`main.dart` opens `DashboardShell` for both visitors and signed-in homeowners.
Authentication unlocks account data and booking submission.

## Authentication

- `LoginPage`: email/password, Google, Apple, password reset, signup.
- `SignupPage`: email/password, Google, Apple, published Privacy Policy.
- `PasswordResetPage`: request a code, set a new password.
- Authentication opened during booking returns to the originating feature.

## Main shell

- Home: `HomeTab`
- Browse: `SearchTab`
- Messages: `InboxTab` → `ChatScreen`
- Bookings: `BookingsTab`
- Rewards: `RewardTab`
- Profile: `ProfileTab`

## Browse and booking

`HomeTab` / `SearchTab` → `ProProfileScreen` → `BookFlowScreen`
(`lib/screens/book_flow.dart`) → `BookingSuccessScreen` → Browse.

Category guides open `CategoryGuidesScreen`. Guest entry points request
authentication before a booking can be submitted.

## Work orders

- Bookings → `WorkOrderDetailScreen`
- Bookings or work-order details → `CapApprovalScreen`
- Cap approval can open the shared availability selector when the backend
  requires a time that is missing from the work order.
- Rescheduling → `openRescheduleWorkOrder` → `RescheduleWorkOrderScreen`
- Completed work → receipt modal within work-order details / `LeaveReviewScreen`

## Profile and account

- `PersonalInfoScreen`
- `ManageAddressesScreen`
- `HomeProfileScreen`
- `PaymentMethodsScreen`
- `NotificationSettingsScreen`
- `SupportPage`
- Sign out → public app shell

Account deletion and verified email changes remain pending backend support.
See `docs/batches-1-4-implementation.md` for implementation details and exceptions.
