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
if xcrun simctl boot "$device_id" 2>/dev/null; then
  runtime_count simulator_boots
fi
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
rm -f "$data_container"/tmp/iosnext-animation-stage-ready-*       "$data_container"/tmp/iosnext-animation-stage-captured-*       "$data_container"/tmp/iosnext-animation-stage-timeout-*       "$data_container"/tmp/iosnext-animation-sequence-complete

wait_for_file() {
  local path="$1"
  local description="$2"

  for _ in {1..400}; do
    if test -f "$path"; then
      return 0
    fi
    sleep 0.05
  done

  echo "Timed out waiting for $description: $path" >&2
  cat /tmp/iosnext-animation-launch.log >&2 || true
  return 1
}

video="$OUT_DIR/animation-acceptance.mp4"
xcrun simctl io "$device_id" recordVideo --codec=h264 "$video" >/tmp/iosnext-record.log 2>&1 &
rec_pid=$!

video_started=0
for _ in {1..100}; do
  if test -e "$video"; then
    video_started=1
    break
  fi
  if ! kill -0 "$rec_pid" 2>/dev/null; then
    echo "Simulator video recorder exited before creating output" >&2
    cat /tmp/iosnext-record.log >&2 || true
    exit 1
  fi
  sleep 0.05
done
test "$video_started" -eq 1

runtime_count app_terminations
xcrun simctl terminate "$device_id" "$APP_ID" 2>/dev/null || true
runtime_count app_launches
runtime_start app_launch
xcrun simctl launch "$device_id" "$APP_ID" --animation-acceptance-mode >/tmp/iosnext-animation-launch.log
runtime_end app_launch

for stage in 0 1 2 3 4 5 6 7; do
  ready="$data_container/tmp/iosnext-animation-stage-ready-$stage"
  captured="$data_container/tmp/iosnext-animation-stage-captured-$stage"
  timed_out="$data_container/tmp/iosnext-animation-stage-timeout-$stage"
  destination="$OUT_DIR/stages/stage-$(printf '%02d' "$stage").png"

  wait_for_file "$ready" "animation stage $stage"
  test ! -f "$timed_out"

  runtime_start screenshot
  xcrun simctl io "$device_id" screenshot "$destination" >/dev/null
  runtime_end screenshot

  printf 'captured' > "$captured"
done

complete="$data_container/tmp/iosnext-animation-sequence-complete"
wait_for_file "$complete" "animation sequence completion"

if ! kill -0 "$rec_pid" 2>/dev/null; then
  echo "Simulator video recorder exited before sequence completion" >&2
  cat /tmp/iosnext-record.log >&2 || true
  exit 1
fi

kill -INT "$rec_pid"
wait "$rec_pid" 2>/dev/null || true

for screenshot in "$OUT_DIR"/stages/stage-*.png; do
  xcrun swift Scripts/validate_visual_capture.swift "$screenshot"
done

stage_count="$(find "$OUT_DIR/stages" -name 'stage-*.png' | wc -l | tr -d ' ')"
test "$stage_count" -eq 8
unique_stage_hashes="$(shasum -a 256 "$OUT_DIR"/stages/stage-*.png | awk '{print $1}' | sort -u | wc -l | tr -d ' ')"
test "$unique_stage_hashes" -eq 8

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
capture_strategy=single-app-session-ready-ack-handshake-plus-single-video
EOF
