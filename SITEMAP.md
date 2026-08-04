# Homeowners App Sitemap

This sitemap reflects the current Flutter app navigation in this repository.

## Entry

- `main.dart`
  - If authenticated: `DashboardShell`
  - If not authenticated: `OnboardingSlider`

## Onboarding and Auth

- `OnboardingSlider`
  - `LoginPage`
  - `SignupPage`
- `LoginPage`
  - `PasswordResetPage`
  - `DashboardShell` on success
- `SignupPage`
  - `DashboardShell` on success
- `PasswordResetPage`
  - returns to `LoginPage`

## Main App Shell

- `DashboardShell`
  - Bottom tabs
    - `HomeTab`
    - `InboxTab`
    - `BookingsTab`
    - `RewardTab`
    - `ProfileTab`

## Home Flow

- `HomeTab`
  - Browse services
    - `BrowseScreen`
      - `SearchTab`
      - `BookingStepper`
      - returns to `DashboardShell`
  - Pro/job action
    - `BookingStepper` in modal bottom sheet
  - Inbox shortcut
    - `InboxTab`

## Inbox Flow

- `InboxTab`
  - Conversation thread
    - `ChatScreen`
  - Work-order context from related booking

## Bookings Flow

- `BookingsTab`
  - Work-order details
    - `WorkOrderDetail`
      - `Receipt`
      - `NTEApproval`
      - `QuoteReview`
  - Book now
    - `BrowseScreen`
    - `BookingStepper`

## Rewards Flow

- `RewardTab`
  - Book services shortcut
    - `BrowseScreen`

## Profile and Account

- `ProfileTab`
  - `PersonalInfo`
  - `ManageAddresses`
  - `PaymentMethods`
  - `HomeProfile`
  - `NotificationSettings`
  - `SupportPage`
  - logout
    - returns to `OnboardingSlider`

## Secondary Screens

- Browse and booking
  - `BrowseScreen`
  - `SearchTab`
  - `ProProfile`
  - `BookingStepper`
  - `BookingSuccessScreen`
- Work orders
  - `WorkOrderDetail`
  - `NTEApproval`
  - `QuoteReview`
  - `Receipt`
- Messaging
  - `ChatScreen`
- Account
  - `PersonalInfo`
  - `ManageAddresses`
  - `PaymentMethods`
  - `HomeProfile`
  - `NotificationSettings`
- Support
  - `SupportPage`

## Route Relationships

- Browse, pro detail, booking, work orders, and chat are all secondary flows pushed above the main tab shell.
- Booking completion returns the user to `BookingsTab`.
- Logout resets the stack and returns the user to onboarding.
