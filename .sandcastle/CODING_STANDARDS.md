# Coding Standards — DynamicNotch

Swift 6 / SwiftUI macOS app. `CONTRIBUTING.md` and `CONTEXT.md` at the repo root
are the long form; this file is what a reviewer must enforce on a diff.

## Hardware constraint — the physical notch

The MacBook screen has a physical notch. It is the reason this app exists and the
easiest thing to get silently wrong:

- Never place critical content behind the notch (top-centre area).
- Layout maths must compensate for the space the notch occupies — no hard-coded
  offsets that only hold on one display.
- Anything positional must stay correct on an external display with no notch.

## Swift style

- `camelCase` for properties and functions, `UpperCamelCase` for types.
- No force-unwrapping (`!`) and no force-casting outside tests; prefer `guard let`.
- Explicit `private` / `internal`; expose the smallest surface that works.
- No `@unchecked Sendable` and no new `@preconcurrency` imports to silence Swift 6
  concurrency diagnostics — fix the actor isolation instead.
- UI state mutations belong on `@MainActor`.

## SwiftUI

- Views stay declarative and thin: no business logic, no I/O in `body`.
- State lives in an `@Observable` view model, not scattered across `@State`.
- Animations use springs, matching the app's native physics feel.
- No blocking work on the main thread — the notch overlay must never stutter.

## Architecture

- One responsibility per type; features stay inside their `Features/<Name>` folder.
- Depend on protocols at feature boundaries so tests can substitute doubles.
- Prefer composition over inheritance; avoid singletons beyond what already exists.

## Testing

- Every behaviour change comes with a test in
  `DynamicNotchTests/Features/[FeatureName]`.
- Test names describe the expected behaviour, not the implementation.
- No test may depend on this machine's real display geometry, on wall-clock
  sleeps, or on another test having run first.
- `./scripts/sandcastle-verify.sh` must exit 0 before any commit. Do not widen its
  skip list, and do not "fix" the tests it skips — they are environmental.
- That script is the **only** gate. Never `killall DynamicNotch` and never `open`
  the built app: agent runs share the host with the user's running instance, so the
  rebuild-and-relaunch loop in `CLAUDE.md` does not apply here.

## Comments

Only where intent is non-obvious, and one line. No comments restating the code.
