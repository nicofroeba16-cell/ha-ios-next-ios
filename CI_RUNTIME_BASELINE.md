# CI Runtime Baseline

## Global Health reconciliation checkpoint — 2026-09-16

This workstream was revalidated against the current active product base before any refresh.

- Active base: `codex/ios27-owner-control` @ `4882a3e7fa639c6ad7c21ab8df4c9ed1ca45efa4`
- Stale optimization head: `codex/ci-runtime-optimization` @ `39669f27403debd8472955a85d63ec3a60916617`
- Relationship at discovery: **14 ahead / 12 behind**, PR #2 mergeable=false.
- Exact-head Fast Gate #23 / run 35107207234: **success**.
- Exact-head Mac Gate #50 / run 35107207268: **failure** at `Run real product UI acceptance matrix`.
- The older measurements below remain historical performance evidence; they are not proof that the stale optimization head is integration-ready.
- Visual/UI single-session changes from the stale optimization line are no longer owned by this workstream and must not be replayed over the current Visual-READY implementation without an explicit integration decision.


## iPhone 18 Pro Max delivery target — 2026-09-17

The Native-iOS delivery target is now **iPhone 18 Pro Max / iOS 27.0**.

Current exact-head CI branch: `codex/ci-runtime-fullgate-reconciled`.

- `cf64da59b698efa3a4e5d9429c677bb9f60af94b`: Fast Gate run `35220768853` failed during environment proof on GitHub runner image `20260907.0173.1`.
- `b9d4cfd6d2a0280da2f0c6caaf33c3150513fdf6`: Fast Gate run `35220928666` reproduced the same external blocker with explicit diagnostics.
- Portable security/backend validation remained green (`39/39`).
- The older GitHub `xcode-27-arm64` image `20260907.0173.1` exposes iOS 27.0 and Xcode 27 beta 6, but does **not** contain the `iPhone 18 Pro Max` CoreSimulator device type.
- The newer runner image `20260912.0186.1` documents `iPhone 18 Pro Max` as an installed simulator.
- CI must not silently fall back to iPhone 17; an incompatible runner image is treated as an explicit infrastructure blocker.
- Full Gate remains blocked until a compatible Xcode-27 runner image is assigned and Visual/UI acceptance is aligned to the same device target.


This file distinguishes the **current test matrix** from an older successful gate so runtime wins cannot be overstated.

## Canonical current baseline

Source commit before runtime optimization: `f977078802b3518256543ccada37e343e66024d0`.

| Gate | Run | Result | Wall clock |
| --- | ---: | --- | ---: |
| Fast Gate | #16 / 35097789422 | success | 260.6 s (4m 20.6s) |
| Full Gate | #43 / 35097789404 | failure | 1678.6 s (27m 58.6s) to failure |

The current Full Gate cannot produce a green end-to-end baseline because its UI matrix contains a pre-existing orchestration defect: method-level `-skip-testing` selectors omit the test-class component, so the intended exclusions do not take effect. Accessibility-state tests and the iPad-only test therefore execute inside the standard iPhone shard. Five accessibility tests fail there and Xcode then spends roughly 600 seconds collecting failure diagnostics.

This failure is itself the canonical **BEFORE** state. The first optimization corrects sharding without removing any test: every state-specific test remains scheduled in its dedicated real simulator state, the iPad test remains scheduled on iPad, and the default accessibility render test remains on the standard iPhone shard.

## Current Full Gate step baseline (#43)

Measured from GitHub Actions log timestamps:

| Step | Seconds |
| --- | ---: |
| Checkout | ~1 |
| Go setup | ~2 |
| Environment/device discovery | ~5 |
| Portable security/backend | ~39 |
| Ensure XcodeGen | ~2 |
| Prepare WireGuard | ~3 |
| XcodeGen + WireGuard verification | <1 |
| Build-for-testing | ~51 |
| Packet tunnel + launch-screen verification | ~1 |
| Unit-test harness | ~238 |
| UI acceptance matrix until failure | ~1316 |
| Failure evidence upload | ~18 |

Within the failed standard iPhone XCUITest invocation:

- `testPrimaryProductScreensRenderLightAndDark`: 312.418 s
- `testIPadPortraitLandscapeCoreScreens` incorrectly ran on iPhone: 78.516 s
- five accessibility-state tests ran under the wrong/default state and failed
- post-failure simulator diagnostics timed out after 600 s

## Fast Gate details (#16)

- build-for-testing: 63.5 s
- unit-test harness: 181.1 s
- actual 19 XCTest methods: about 5.0 s total suite time, about 0.55 s measured test execution
- silent harness/startup gap before the first test process: about 153 s
- portable Linux job: 5.7 s

This makes simulator/Xcode test-harness startup, not Swift assertion execution, the primary Fast Gate target.

## Historical successful reference only

Full Gate #40 / 35094321720 completed in 914.2 s (15m 14.2s), but it predates the expanded accessibility/device matrix and is therefore **not** the canonical current baseline.

Its measured large blocks were:

- unit tests: 167.8 s
- product UI acceptance: 310.3 s
- HA card capture: 245.1 s
- animation acceptance: 68.3 s
- evidence upload: 15.0 s

The three visual/UI blocks alone consumed 623.7 s.

## Instrumentation

Commit `3045976a8085d22a958847b12d5abd7f306761b2` added measurement only:

- build/test durations
- simulator boot durations/counts
- app install durations/counts
- app launch/termination counts in shell-driven acceptance
- xcodebuild invocation counts
- machine-readable runtime artifacts

Historical logs cannot recover every internal counter, so later before/after comparisons use the closest instrumented predecessor plus the canonical current runs above.

## Optimization invariants

- No test is removed or skipped for speed.
- Accessibility settings are set on the real simulator, not simulated in assertions.
- iPhone and iPad coverage remain separate where device semantics matter.
- No product behavior, Home Assistant semantics, WireGuard behavior, owner/admin behavior, security model, or visual design is changed.
- Test-only instrumentation/routing may change only when assertions and evidence remain equivalent or stronger.
- Every runtime optimization is benchmarked against the immediately preceding comparable run.
