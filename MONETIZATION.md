# Monetization Notes

Working notes on turning AltSplit into something others can use, with a paid unlock. Nothing here is implemented yet — this is a plan to revisit later.

Would want to add supersets, cloudkit account sync on pro version 

## Apple's payment system (the basics)

- **In-App Purchase (IAP)** is required for any digital feature/content unlocked within the app (premium features, subscriptions, one-time unlocks). Apple handles payment processing, receipts, and refunds.
- Apple takes a **30% cut** (or **15%** under the Small Business Program — under $1M revenue/year — or after year 1 of a subscriber's tenure for subscriptions).
- Payouts go to you monthly via Apple, deposited to a linked bank account, typically ~30-45 days after the sale.
- You can't use Stripe/PayPal as the primary payment method for digital content inside the app — IAP is the default path.
- Setup: configure products in App Store Connect, use StoreKit (or StoreKit 2) to implement. Requires a signed tax/banking agreement in App Store Connect before payouts start, and the **$99/year Apple Developer Program membership**.

## What AltSplit actually is

A personal, local-first iOS workout tracker (Swift 6 / SwiftUI / SwiftData, iOS 26, XcodeGen-managed, bundle ID `com.adamodeven.AltSplit`) built around a two-week alternating (A/B) muscle-group split, with a notification/alarm-based accountability layer. Explicitly "local first. No accounts, no server, no social features" (`DESIGN.md:20`). No monetization code exists today.

Feature areas: `Home/` (dashboard), `Workout/` (session logging), `CheckIn/` (weight/photo check-ins, Face ID gated), `Progress/` (lifting & body progress charts), `Builder/` (custom split/exercise editing), `Notifications/` (local notifications + AlarmKit).

## Chosen direction

- **Model**: single **non-consumable, one-time "Pro" unlock** via StoreKit (not a subscription) — fits the local-first, no-server design, no backend needed.
- **Gating**: free tier = basic tracking (Home, Workout logging, CheckIn, Builder). **Pro unlock = the Progress tab** (lifting charts, body/photo progress history).

## Implementation sketch (for later)

### StoreKit product
- Product ID: `com.adamodeven.AltSplit.pro` (non-consumable), matching the bundle ID convention.
- Local StoreKit Configuration file (`AltSplit/AltSplit.storekit`) for Simulator/Debug testing, wired into the scheme via `project.yml` (`storeKitConfiguration: AltSplit.storekit` under `schemes.AltSplit.run`/`test`), then `xcodegen generate`.
- No entitlement needed — `AltSplit.entitlements` is currently empty (AlarmKit's entitlement had to be stripped for personal-team signing reasons) but non-consumable IAPs don't require one anyway.
- **App Store Connect product creation and real sandbox/TestFlight testing require the paid $99 Apple Developer Program membership** — same blocker already noted for AlarmKit in `DESIGN.md`. Everything else is testable today on free provisioning via the local StoreKit config file.

### Entitlement / purchase state
- New `AltSplit/Store/PurchaseManager.swift`: `@MainActor final class PurchaseManager: NSObject, ObservableObject` (matches the existing `CameraSessionController` pattern).
- `@Published isProUnlocked`, `hasCheckedEntitlements` (avoids paywall flash on cold launch), `product`, `purchaseError`.
- Source of truth: StoreKit 2's local `Transaction.currentEntitlements` check — no server-side receipt validation needed, consistent with "no accounts, no server." Plus a `Transaction.updates` listener for out-of-band purchases.
- Must auto-unlock under the existing `UITEST_RESET` launch argument (same bypass convention as `AccountabilityCoordinator`/`BiometricGate`) so `ProgressFlowUITests.swift` keeps passing; a separate `UITEST_RESET_LOCKED` argument would drive a new locked-state UI test.

### Gating point
- In `AltSplit/App/RootTabView.swift`: own the `PurchaseManager` as a `@StateObject`, start it in `.task`, inject via `.environmentObject`.
- The Progress tab is the single entry point to that feature area (confirmed — `HomeView`'s check-in tap handler only flips tab selection, it doesn't push a separate view), so gate just that tab's content closure: loading state → `ProgressTabView()` if unlocked → `ProPaywallView()` if not.
- No changes needed anywhere else (`Home/`, `Workout/`, `CheckIn/`, `Builder/`, `Notifications/`, `Models/` stay untouched).

### Paywall UI
- New `AltSplit/Store/ProPaywallView.swift`, styled like the existing `ContentUnavailableView`-based locked states (see `CheckInCaptureView`).
- Feature bullets describing what Pro unlocks, price from `product.displayPrice`, primary "Unlock Pro" button (`.buttonStyle(.glassProminent)`, matching `CameraCaptureBox.swift`), plus a **Restore Purchases** button (required by App Store guideline 3.1.1 for non-consumables).

### Tests
- `AltSplitTests/PurchaseManagerTests.swift` using `StoreKitTest.SKTestSession` to drive purchase/refund and assert state transitions (avoids scripting the flaky system purchase sheet in UI tests).
- `AltSplitUITests/PaywallFlowUITests.swift` using a new `UITEST_RESET_LOCKED` launch mode to assert the locked paywall renders.

### Verification path
1. Local StoreKit config in Simulator — purchase/relaunch/restore flow, all free-tier testable today.
2. Unit tests via `SKTestSession`.
3. Real sandbox/TestFlight testing — blocked on the $99 Apple Developer Program membership, same as AlarmKit.
