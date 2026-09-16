#!/bin/bash
set -euo pipefail

DEVICE_NAME="${DEVICE_NAME:-iPhone 17 Pro}"
APP_ID="de.nicofroeba16.iosnext"
OUT_DIR="${OUT_DIR:-DarkVisualAcceptance}"

device_id="$(DEVICE_NAME="$DEVICE_NAME" xcrun simctl list devices available -j | DEVICE_NAME="$DEVICE_NAME" python3 -c 'import json,os,sys; name=os.environ["DEVICE_NAME"]; data=json.load(sys.stdin); print(next(device["udid"] for devices in data["devices"].values() for device in devices if device.get("isAvailable", True) and device["name"] == name))')"
test -n "$device_id"

xcrun simctl boot "$device_id" 2>/dev/null || true
xcrun simctl bootstatus "$device_id" -b

# Standard accessibility state + system Dark appearance.
xcrun simctl ui "$device_id" appearance dark
xcrun simctl ui "$device_id" content_size large
xcrun simctl ui "$device_id" increase_contrast disabled
xcrun simctl spawn "$device_id" defaults write com.apple.Accessibility ReduceMotionEnabled -bool false
xcrun simctl spawn "$device_id" defaults write com.apple.Accessibility ReduceTransparencyEnabled -bool false
xcrun simctl spawn "$device_id" notifyutil -p com.apple.Accessibility.ReduceMotionStatusDidChange || true
xcrun simctl spawn "$device_id" notifyutil -p com.apple.Accessibility.ReduceTransparencyStatusDidChange || true

app_path="$(find "$HOME/Library/Developer/Xcode/DerivedData" -type d -path '*/Build/Products/Debug-iphonesimulator/IOSNext.app' -print -quit)"
test -d "$app_path"

xcrun simctl terminate "$device_id" "$APP_ID" 2>/dev/null || true
xcrun simctl uninstall "$device_id" "$APP_ID" 2>/dev/null || true
xcrun simctl install "$device_id" "$app_path"
data_container="$(xcrun simctl get_app_container "$device_id" "$APP_ID" data)"
test -d "$data_container"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/product-screens" "$OUT_DIR/logs"

capture_product_screen() {
  local screen="$1"
  local destination="$OUT_DIR/product-screens/$screen.png"
  local temp="$OUT_DIR/product-screens/.$screen-candidate.png"
  local marker="$data_container/tmp/iosnext-product-screen-ready-$screen"
  local attempt

  for attempt in 1 2 3 4; do
    rm -f "$temp" "$marker"
    xcrun simctl terminate "$device_id" "$APP_ID" 2>/dev/null || true
    if ! xcrun simctl launch "$device_id" "$APP_ID" \
      "--product-ui-test-screen=$screen" \
      --product-ui-test-dark \
      >"$OUT_DIR/logs/$screen-attempt-$attempt.log" 2>&1; then
      continue
    fi

    for _ in {1..60}; do
      test -f "$marker" && break
      sleep 0.1
    done
    test -f "$marker" || continue

    sleep 0.15
    xcrun simctl io "$device_id" screenshot "$temp" >/dev/null
    if xcrun swift Scripts/validate_visual_capture.swift "$temp"; then
      mv "$temp" "$destination"
      return 0
    fi
  done

  echo "Unable to capture stable Dark Mode screen: $screen" >&2
  return 1
}

for screen in home rooms chat media system light media-detail owner wireguard; do
  capture_product_screen "$screen"
done

# Record a real cold launch with no acceptance/test screen arguments.
xcrun simctl terminate "$device_id" "$APP_ID" 2>/dev/null || true
cold_video="$OUT_DIR/cold-launch-dark.mp4"
xcrun simctl io "$device_id" recordVideo --codec=h264 "$cold_video" >/tmp/iosnext-dark-cold-record.log 2>&1 &
record_pid=$!
sleep 0.75
xcrun simctl launch "$device_id" "$APP_ID" >/tmp/iosnext-dark-cold-launch.log
sleep 6
kill -INT "$record_pid" 2>/dev/null || true
wait "$record_pid" 2>/dev/null || true
test -s "$cold_video"

# Record the deterministic in-app interaction sequence in Dark Mode.
APPEARANCE=dark \
OUT_DIR="$OUT_DIR/animation" \
DEVICE_NAME="$DEVICE_NAME" \
bash Scripts/run_animation_acceptance.sh

screen_count="$(find "$OUT_DIR/product-screens" -name '*.png' | wc -l | tr -d ' ')"
test "$screen_count" -eq 9
cold_bytes="$(stat -f%z "$cold_video")"
animation_bytes="$(stat -f%z "$OUT_DIR/animation/animation-acceptance.mp4")"

cat > "$OUT_DIR/summary.txt" <<EOF
iOS Next Dark Visual Acceptance
device=$DEVICE_NAME
appearance=dark
content_size=large
increase_contrast=disabled
reduce_motion=false
reduce_transparency=false
product_screens=$screen_count
cold_launch_video_bytes=$cold_bytes
animation_video_bytes=$animation_bytes
normal_launch_has_test_arguments=false
product_capture_uses_deterministic_preview=true
animation_capture_uses_acceptance_mode=true
EOF
