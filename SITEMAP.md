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
- Messages: `InboxTab` → real Stream channels → `ChatScreen`; Activity shows dated booking events.
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
- Completed work → invoice/paid-receipt modal and paid-receipt upload within work-order details.
- Reviews → `LeaveReviewScreen` (create, edit, delete).
- Home, work-order details or once-per-check app-open prompt → `ArrivalCheckScreen` → `NoShowConfirmScreen` → `RecoveryScreen` → Browse.
- Rewards ledger → work-order details scrolled to Job money.

## Profile and account

- `PersonalInfoScreen`
- `ManageAddressesScreen`
- `HomeProfileScreen` → `HomeSystemEditor`, getting-in notes and documents
- `PaymentMethodsScreen`: booked pros’ published direct-payment options, with messaging
- `NotificationSettingsScreen`
- `AccountSecurityScreen`: password change and account-closure preflight/request
- `SupportPage`
- Sign out → public app shell

Verified email changes and account-closure requests use the authenticated account APIs.
See `docs/backend-api-contracts.md` for deployment and verification constraints.
