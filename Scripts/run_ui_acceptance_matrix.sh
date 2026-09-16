#!/bin/bash
set -euo pipefail

PROJECT="IOSNext.xcodeproj"
SCHEME="IOSNext"
IPHONE_NAME="iPhone 17 Pro"
OUT_DIR="UIAcceptance"

rm -rf "$OUT_DIR" UITestResults-iPhone.xcresult UITestResults-iPad.xcresult
mkdir -p "$OUT_DIR"

devices_json="$(xcrun simctl list devices available -j)"
iphone_id="$(printf '%s' "$devices_json" | IPHONE_NAME="$IPHONE_NAME" python3 -c 'import json,os,sys; data=json.load(sys.stdin); name=os.environ["IPHONE_NAME"]; print(next(d["udid"] for ds in data["devices"].values() for d in ds if d.get("isAvailable", True) and d["name"] == name))')"
ipad_id="$(printf '%s' "$devices_json" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(next(d["udid"] for ds in data["devices"].values() for d in ds if d.get("isAvailable", True) and d["name"].startswith("iPad")))')"

test -n "$iphone_id"
test -n "$ipad_id"
printf 'iphone=%s\nipad=%s\n' "$iphone_id" "$ipad_id" | tee "$OUT_DIR/devices.txt"

xcrun simctl boot "$iphone_id" 2>/dev/null || true
xcrun simctl bootstatus "$iphone_id" -b
xcodebuild test-without-building \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$iphone_id" \
  -only-testing:IOSNextUITests \
  -resultBundlePath UITestResults-iPhone.xcresult \
  | tee -a xcodebuild.log

xcrun simctl boot "$ipad_id" 2>/dev/null || true
xcrun simctl bootstatus "$ipad_id" -b
xcodebuild test-without-building \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$ipad_id" \
  -only-testing:IOSNextUITests/testPrimaryProductScreensRenderLightAndDark \
  -only-testing:IOSNextUITests/testAccessibilityAppearanceMatrix \
  -only-testing:IOSNextUITests/testIPadPortraitLandscapeCoreScreens \
  -resultBundlePath UITestResults-iPad.xcresult \
  | tee -a xcodebuild.log
