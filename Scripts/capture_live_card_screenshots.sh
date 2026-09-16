#!/bin/bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ci_runtime.sh"
CI_RUNTIME_SCOPE="${CI_RUNTIME_SCOPE:-full}"

DEVICE_NAME="${DEVICE_NAME:-iPhone 17 Pro}"
APP_ID="de.nicofroeba16.iosnext"
OUT_DIR="${OUT_DIR:-CardScreenshots}"

runtime_start device_discovery
device_id="$(DEVICE_NAME="$DEVICE_NAME" xcrun simctl list devices available -j | DEVICE_NAME="$DEVICE_NAME" python3 -c 'import json,os,sys; name=os.environ["DEVICE_NAME"]; data=json.load(sys.stdin); print(next(device["udid"] for devices in data["devices"].values() for device in devices if device.get("isAvailable", True) and device["name"] == name))')"
test -n "$device_id"
runtime_end device_discovery
runtime_start simulator_boot
if xcrun simctl boot "$device_id" 2>/dev/null; then runtime_count simulator_boots; fi
xcrun simctl bootstatus "$device_id" -b
runtime_end simulator_boot

app_path="$(find "$HOME/Library/Developer/Xcode/DerivedData" -type d -path '*/Build/Products/Debug-iphonesimulator/IOSNext.app' -print -quit)"
test -d "$app_path"
runtime_count app_installs
runtime_start app_install
xcrun simctl install "$device_id" "$app_path"
runtime_end app_install

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

capture_validated() {
  local destination="$1"
  shift
  local temp="${destination%.png}.candidate.png"
  local attempt

  for attempt in 1 2 3 4 5; do
    rm -f "$temp"
    runtime_count app_terminations
    xcrun simctl terminate "$device_id" "$APP_ID" 2>/dev/null || true
    runtime_count app_launches
    runtime_start app_launch
    xcrun simctl launch "$device_id" "$APP_ID" "$@" >/tmp/iosnext-visual-launch.log
    runtime_end app_launch
    sleep "$attempt"
    runtime_start screenshot
    xcrun simctl io "$device_id" screenshot "$temp" >/dev/null
    runtime_end screenshot

    if xcrun swift Scripts/validate_visual_capture.swift "$temp"; then
      mv "$temp" "$destination"
      return 0
    fi

    echo "Retrying visual capture: $destination (attempt $attempt)" >&2
  done

  echo "Unable to produce a valid visual capture: $destination" >&2
  cat /tmp/iosnext-visual-launch.log >&2 || true
  return 1
}

for appearance in light dark; do
  xcrun simctl ui "$device_id" appearance "$appearance"
  sleep 1
  for page in 0 1 2; do
    capture_validated       "$OUT_DIR/live-ha-card-$appearance-page-$page.png"       --live-card-test-mode "--live-card-page=$page"
  done
done

test "$(find "$OUT_DIR" -name '*.png' | wc -l | tr -d ' ')" -eq 6
