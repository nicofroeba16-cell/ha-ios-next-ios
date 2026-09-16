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

xcrun simctl help ui | tee "$OUT_DIR/simctl-ui-help.txt"

reset_accessibility() {
  local device="$1"
  xcrun simctl ui "$device" appearance light
  xcrun simctl ui "$device" content_size large
  xcrun simctl ui "$device" increase_contrast disabled
  xcrun simctl ui "$device" reduce_motion disabled
  xcrun simctl ui "$device" reduce_transparency disabled
}

run_accessibility_variant() {
  local name="$1"
  shift
  reset_accessibility "$iphone_id"
  "$@"
  rm -rf "$OUT_DIR/$name.xcresult"
  xcodebuild test-without-building \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$iphone_id" \
    -only-testing:IOSNextUITests/testAccessibilityCoreScreenRenders \
    -resultBundlePath "$OUT_DIR/$name.xcresult" \
    | tee -a xcodebuild.log
}

xcrun simctl boot "$iphone_id" 2>/dev/null || true
xcrun simctl bootstatus "$iphone_id" -b
reset_accessibility "$iphone_id"

xcodebuild test-without-building \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$iphone_id" \
  -only-testing:IOSNextUITests \
  -skip-testing:IOSNextUITests/testIPadPortraitLandscapeCoreScreens \
  -skip-testing:IOSNextUITests/testAccessibilityCoreScreenRenders \
  -resultBundlePath UITestResults-iPhone.xcresult \
  | tee -a xcodebuild.log

run_accessibility_variant dynamic-type-xxxl \
  xcrun simctl ui "$iphone_id" content_size accessibility-extra-extra-extra-large
run_accessibility_variant reduce-motion \
  xcrun simctl ui "$iphone_id" reduce_motion enabled
run_accessibility_variant reduce-transparency \
  xcrun simctl ui "$iphone_id" reduce_transparency enabled
run_accessibility_variant increase-contrast \
  xcrun simctl ui "$iphone_id" increase_contrast enabled

reset_accessibility "$iphone_id"

xcrun simctl boot "$ipad_id" 2>/dev/null || true
xcrun simctl bootstatus "$ipad_id" -b
reset_accessibility "$ipad_id"

xcodebuild test-without-building \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$ipad_id" \
  -only-testing:IOSNextUITests/testPrimaryProductScreensRenderLightAndDark \
  -only-testing:IOSNextUITests/testIPadPortraitLandscapeCoreScreens \
  -resultBundlePath UITestResults-iPad.xcresult \
  | tee -a xcodebuild.log
