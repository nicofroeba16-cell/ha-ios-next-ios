#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ci_runtime.sh"
CI_RUNTIME_SCOPE="${CI_RUNTIME_SCOPE:-full}"

DEVICE_NAME="${DEVICE_NAME:-iPhone 17 Pro}"
APP_ID="de.nicofroeba16.iosnext"
OUT_DIR="${OUT_DIR:-AnimationAcceptance}"

runtime_start device_discovery
device_id="$(DEVICE_NAME="$DEVICE_NAME" xcrun simctl list devices available -j | DEVICE_NAME="$DEVICE_NAME" python3 -c 'import json,os,sys; name=os.environ["DEVICE_NAME"]; data=json.load(sys.stdin); print(next(device["udid"] for devices in data["devices"].values() for device in devices if device.get("isAvailable", True) and device["name"] == name))')"
test -n "$device_id"
runtime_end device_discovery
runtime_start simulator_boot
if xcrun simctl boot "$device_id" 2>/dev/null; then runtime_count simulator_boots; fi
xcrun simctl bootstatus "$device_id" -b
runtime_end simulator_boot
xcrun simctl ui "$device_id" appearance light

app_path="$(find "$HOME/Library/Developer/Xcode/DerivedData" -type d -path '*/Build/Products/Debug-iphonesimulator/IOSNext.app' -print -quit)"
test -d "$app_path"
runtime_count app_installs
runtime_start app_install
xcrun simctl install "$device_id" "$app_path"
runtime_end app_install
data_container="$(xcrun simctl get_app_container "$device_id" "$APP_ID" data)"
test -d "$data_container"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/stages"

capture_stage() {
  local stage="$1"
  local destination="$OUT_DIR/stages/stage-$(printf '%02d' "$stage").png"
  local temp="$OUT_DIR/stages/.candidate-$stage.png"
  local attempt

  local marker="$data_container/tmp/iosnext-animation-stage-ready-$stage"

  for attempt in 1 2 3 4; do
    rm -f "$temp" "$marker"
    runtime_count app_terminations
    xcrun simctl terminate "$device_id" "$APP_ID" 2>/dev/null || true
    runtime_count app_launches
    runtime_start app_launch
    xcrun simctl launch "$device_id" "$APP_ID" \
      --animation-acceptance-mode "--animation-stage=$stage" >/tmp/iosnext-animation-launch.log
    runtime_end app_launch

    for _ in {1..50}; do
      test -f "$marker" && break
      sleep 0.1
    done
    test -f "$marker" || continue

    sleep 0.15
    runtime_start screenshot
    xcrun simctl io "$device_id" screenshot "$temp" >/dev/null
    runtime_end screenshot

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

runtime_count app_terminations
xcrun simctl terminate "$device_id" "$APP_ID" 2>/dev/null || true
video="$OUT_DIR/animation-acceptance.mp4"
xcrun simctl io "$device_id" recordVideo --codec=h264 "$video" >/tmp/iosnext-record.log 2>&1 &
rec_pid=$!
sleep 1
runtime_count app_launches
runtime_start app_launch
xcrun simctl launch "$device_id" "$APP_ID" --animation-acceptance-mode >/tmp/iosnext-animation-video-launch.log
runtime_end app_launch
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
capture_strategy=app-ready-marker-plus-deterministic-stage-launch-plus-unblocked-video
EOF
