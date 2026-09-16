# CI Runtime Baseline

Baseline source: successful GitHub Actions runs on `codex/ios27-owner-control`, captured before any runtime optimization.

## Wall clock

| Gate | Run | Wall clock |
| --- | ---: | ---: |
| Fast Gate | #16 / 35097789422 | 260.6 s (4m 20.6s) |
| Full Gate | #40 / 35094321720 | 914.2 s (15m 14.2s) |

The Fast Gate wall clock is governed by the macOS/Xcode job; its portable Linux job completed in 5.7 seconds in Run #16.

## Full Gate step baseline

Measured from GitHub Actions log timestamps for successful Run #40:

| Step | Seconds |
| --- | ---: |
| Checkout | 1.4 |
| Go setup | 2.5 |
| Environment/device discovery | 5.1 |
| Portable security/backend | 39.4 |
| Ensure XcodeGen | 1.7 |
| Prepare WireGuard | 2.6 |
| XcodeGen | 0.1 |
| WireGuard verification | 0.1 |
| Build-for-testing | 52.4 |
| Packet tunnel metadata | 0.5 |
| Launch-screen verification | 0.3 |
| Unit tests | 167.8 |
| Product UI acceptance | 310.3 |
| HA card capture | 245.1 |
| Animation acceptance | 68.3 |
| Evidence upload | 15.0 |

The three visual/UI acceptance blocks alone consumed 623.7 seconds (10m 23.7s) serially.

## Fast Gate step baseline

Latest green Run #16:

- build-for-testing: 63.5 s
- unit tests: 181.1 s
- total macOS job: 260.6 s

For comparison, green Run #13 measured 48.2 s build and 246.7 s unit-test time, demonstrating meaningful runner/test variance.

## Instrumentation gap and baseline rule

Historical workflow logs do not expose exact internal simulator boot, app install, app launch, app termination, screenshot, or per-XCUITest-process startup timings because the scripts did not record them. This commit adds measurement only; it does not optimize behavior.

The first green run of `codex/ci-runtime-optimization` is therefore the canonical instrumented baseline for those internal metrics. Optimization commits must compare against that run, not against theoretical estimates.

## Optimization invariants

- No test is removed or skipped for speed.
- No product behavior, Home Assistant semantics, WireGuard behavior, owner/admin behavior, security model, or visual design is changed.
- Test-only orchestration may be changed only if assertions and evidence coverage remain equivalent or stronger.
- Each optimization is benchmarked against this baseline and the immediately preceding green commit.
