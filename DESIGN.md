# TradeWorks One mobile design

The approved Iteration 1 guest screens are the PNG files in
`.repo_ref/mobile-app-ui-20261003/mobile-app/screens/`. Those images are the
visual source of truth.

## Direction

- White, calm homeowner marketplace UI with hairline borders and one soft
  shadow only for floating navigation.
- Outfit for headings and important numbers; Inter for reading and controls.
- Navy `#16233F` for primary text, body `#3B4456`, secondary `#667085`.
- Orange `#E8761E` is the primary action and always uses a navy label.
- Blue `#1F5BD6` indicates links, selection, focus, and navigation.
- Green communicates trust and availability. Gold is reserved for ratings.
- Cards use a 12 px radius. Content uses 16–20 px side padding and 44 px
  minimum touch targets.

## Guest journey

Guest users can browse services, inspect results and pro profiles, compare up
to three pros, read homeowner guides, enter a browsing ZIP, and use photo or
voice intake. Booking, messaging, bookings, rewards, and profile management
lead to the supplied account gate without changing the requested destination.

Search opens on recent and popular services. Pro results are requested only
after the user chooses or submits a service and are rendered in pages. Missing
backend facts are hidden or shown as `Not listed`; the UI never invents them.
