# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Homeowners who need to find vetted local service professionals, compare their real service details, and manage work on their homes. Iteration 1 covers people browsing before they create an account or sign in.

## Product Purpose

TradeWorksOne helps a homeowner describe a need, find professionals serving the homeowner's ZIP code, compare those professionals without rankings, understand service pricing and response options, and continue into booking after authentication.

## Positioning

The marketplace presents pros in a neutral random order and lets the homeowner compare verified job history, pricing model, response times, credentials, and recent work. TradeWorks does not rank pros and does not take payment from the homeowner; the homeowner pays the pro directly.

## Operating Context

The app is a Flutter mobile application for iOS and Android. A signed-out homeowner can browse by ZIP code for the current session, search by service or describe a problem with text, voice, or photos, read category guides, compare pros, view a pro profile, and enter authentication flows. Account, booking submission, messaging, rewards, and work-order management require authentication.

## Capabilities and Constraints

- Preserve the existing backend services, payloads, authentication flows, navigation, and error handling.
- Preserve one screen per booking step and the existing navigation structure.
- Keep the terminology established by the product decisions: cap, Free visit, band, apply credits, and `WO-#####`.
- Pros appear in a random order; no ranking score or implied recommendation may be added.
- Missing backend data hides its line instead of displaying invented values or screenshot placeholders.
- Orange is reserved for the one primary action on a screen. Blue communicates links, selection, and focus. Green communicates trust. Purple is reserved for rewards.
- Iteration 1 redesign scope is the signed-out experience and its gates. Authenticated account, rewards, inbox content, bookings, and work-order screens remain behaviorally and visually outside this iteration except where a guest gate is shown.

## Brand Commitments

The product name is TradeWorksOne. The approved October 1, 2026 v3.3 screen set and design standard in `.repo_ref/mobile-app-ui-20261003/mobile-app/` are binding visual references for this redesign. The approved system uses Outfit for headings, Inter for reading text, a white page, navy ink, orange primary actions, blue interactions, and restrained bordered surfaces.

## Evidence on Hand

- Approved screen images: `.repo_ref/mobile-app-ui-20261003/mobile-app/screens/`
- Design standard: `.repo_ref/mobile-app-ui-20261003/mobile-app/TW-DESIGN-STANDARD.md`
- Settled product decisions and seed data: `.repo_ref/mobile-app-ui-20261003/mobile-app/TW-SHARED-DECISIONS-AND-SEED.md`
- Screen implementation instructions: `.repo_ref/mobile-app-ui-20261003/mobile-app/batch-21-match-v3.3-screens.md`
- Rating and availability capsule amendment: `.repo_ref/mobile-app-ui-20261003/mobile-app/batch-21-amendment-1-rating-capsules.md`

## Product Principles

- Let homeowners choose with transparent facts and no ranking.
- Keep product truth in one place and never fabricate missing data.
- Make the path from describing a need to choosing a pro direct and understandable.
- Keep guest browsing useful while clearly gating account-only actions.
- Protect existing backend behavior while changing presentation.

## Accessibility & Inclusion

Use native semantics, support dynamic type without clipping, preserve keyboard and screen-reader labels, maintain minimum touch targets, and never communicate state by color alone.
