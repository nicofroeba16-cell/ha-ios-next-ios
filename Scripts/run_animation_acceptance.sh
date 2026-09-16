#!/bin/bash
set -euo pipefail

DEVICE_NAME="${DEVICE_NAME:-iPhone 17 Pro}"
APP_ID="de.nicofroeba16.iosnext"
OUT_DIR="${OUT_DIR:-AnimationAcceptance}"

device_id="$(DEVICE_NAME="$DEVICE_NAME" xcrun simctl list devices available -j | DEVICE_NAME="$DEVICE_NAME" python3 -c 'import json,os,sys; name=os.environ["DEVICE_NAME"]; data=json.load(sys.stdin); print(next(device["udid"] for devices in data["devices"].values() for device in devices if device.get("isAvailable", True) and device["name"] == name))')"
test -n "$device_id"
xcrun simctl boot "$device_id" 2>/dev/null || true
xcrun simctl bootstatus "$device_id" -b
xcrun simctl ui "$device_id" appearance light

app_path="$(find "$HOME/Library/Developer/Xcode/DerivedData" -type d -path '*/Build/Products/Debug-iphonesimulator/IOSNext.app' -print -quit)"
test -d "$app_path"
xcrun simctl install "$device_id" "$app_path"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/stages"

capture_stage() {
  local stage="$1"
  local destination="$OUT_DIR/stages/stage-$(printf '%02d' "$stage").png"
  local temp="$OUT_DIR/stages/.candidate-$stage.png"
  local attempt

  for attempt in 1 2 3 4; do
    rm -f "$temp"
    xcrun simctl terminate "$device_id" "$APP_ID" 2>/dev/null || true
    xcrun simctl launch "$device_id" "$APP_ID"       --animation-acceptance-mode "--animation-stage=$stage" >/tmp/iosnext-animation-launch.log
    sleep "$attempt"
    xcrun simctl io "$device_id" screenshot "$temp" >/dev/null

    if xcrun swift Scripts/validate_visual_capture.swift "$temp"; then
      mv "$temp" "$destination"
      return 0
    fi
  done

  echo "Unable to capture animation stage $stage" >&2
  return 1
}

for stage in 0 1 2 3 4 5 6 7; do
  capture_stage "$stage"
done

stage_count="$(find "$OUT_DIR/stages" -name 'stage-*.png' | wc -l | tr -d ' ')"
test "$stage_count" -eq 8
unique_stage_hashes="$(shasum -a 256 "$OUT_DIR"/stages/stage-*.png | awk '{print $1}' | sort -u | wc -l | tr -d ' ')"
test "$unique_stage_hashes" -eq 8

xcrun simctl terminate "$device_id" "$APP_ID" 2>/dev/null || true
video="$OUT_DIR/animation-acceptance.mp4"
xcrun simctl io "$device_id" recordVideo --codec=h264 "$video" >/tmp/iosnext-record.log 2>&1 &
rec_pid=$!
sleep 1
xcrun simctl launch "$device_id" "$APP_ID" --animation-acceptance-mode >/tmp/iosnext-animation-video-launch.log
sleep 16
kill -INT "$rec_pid" 2>/dev/null || true
wait "$rec_pid" 2>/dev/null || true

test -s "$video"
video_bytes="$(stat -f%z "$video")"
test "$video_bytes" -gt 200000

cat > "$OUT_DIR/summary.txt" <<EOF
Animation Acceptance
device=$DEVICE_NAME
stage_screenshots=$stage_count
unique_stage_hashes=$unique_stage_hashes
video_bytes=$video_bytes
sequence=app-start,navigation,light-toggle,conditional,media-play-pause,slider,chat,owner-area
capture_strategy=deterministic-stage-launch-plus-unblocked-video
EOF
