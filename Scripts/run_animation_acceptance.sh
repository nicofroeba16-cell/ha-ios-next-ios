#!/bin/bash
set -euo pipefail

DEVICE_NAME="${DEVICE_NAME:-iPhone 17 Pro}"
APP_ID="de.nicofroeba16.iosnext"
OUT_DIR="${OUT_DIR:-AnimationAcceptance}"

device_id="$(xcrun simctl list devices available | awk -F '[()]' -v name="$DEVICE_NAME" '$0 ~ name " \\(" {print $2; exit}')"
test -n "$device_id"
xcrun simctl boot "$device_id" 2>/dev/null || true
xcrun simctl bootstatus "$device_id" -b
xcrun simctl ui "$device_id" appearance light

app_path="$(find "$HOME/Library/Developer/Xcode/DerivedData" -type d -path '*/Build/Products/Debug-iphonesimulator/IOSNext.app' -print -quit)"
test -d "$app_path"
xcrun simctl install "$device_id" "$app_path"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/frames"

xcrun simctl terminate "$device_id" "$APP_ID" 2>/dev/null || true
video="$OUT_DIR/animation-acceptance.mp4"
xcrun simctl io "$device_id" recordVideo --codec=h264 "$video" >/tmp/iosnext-record.log 2>&1 &
rec_pid=$!
sleep 1
xcrun simctl launch "$device_id" "$APP_ID" --animation-acceptance-mode

for second in $(seq 1 16); do
  sleep 1
  xcrun simctl io "$device_id" screenshot "$OUT_DIR/frames/frame-$(printf '%02d' "$second").png" >/dev/null
done

kill -INT "$rec_pid" 2>/dev/null || true
wait "$rec_pid" 2>/dev/null || true

test -s "$video"
frame_count="$(find "$OUT_DIR/frames" -name '*.png' | wc -l | tr -d ' ')"
test "$frame_count" -ge 12
unique_hashes="$(shasum -a 256 "$OUT_DIR"/frames/*.png | awk '{print $1}' | sort -u | wc -l | tr -d ' ')"
test "$unique_hashes" -ge 7

cat > "$OUT_DIR/summary.txt" <<EOF
Animation Acceptance
device=$DEVICE_NAME
frames=$frame_count
unique_frame_hashes=$unique_hashes
sequence=app-start,navigation,light-toggle,conditional,media-play-pause,slider,chat,owner-area
EOF
