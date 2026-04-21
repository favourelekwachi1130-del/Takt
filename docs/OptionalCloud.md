# Optional cloud services (deferred)

The app is **local-first**: timers, presets, and haptics do not require a network. When you are ready to add optional capabilities, use this as a checklist.

## Sign in with Apple

- Use for identity only; store opaque user id server-side.
- Keep **presentation presets** exportable as JSON without an account.

## Preset sync API (BFF)

- Small REST or GraphQL API; JWT from Apple.
- Payload: preset metadata + version; optional encrypted blob for large content.
- Conflict policy: last-write-wins or simple version integers.

## StoreKit 2 and App Store Server API

- For subscriptions or one-time unlocks: validate receipts server-side at scale.
- Do not gate core offline timer behavior on subscription status without a generous offline grace period.

## Analytics and crash reporting

- Replace or extend `CrashReporting` in `Services/CrashReporting.swift` with Firebase Crashlytics, Sentry, or similar.
- Keep events minimal; disclose categories in App Store privacy labels.

## Push (APNs)

- Not required for in-session timing. Optional for marketing or reminders only.
