#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

git diff --check

if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout Info.plist
  xmllint --noout Sources/Resources/PrivacyInfo.xcprivacy
else
  python3 -c 'import plistlib; plistlib.load(open("Info.plist", "rb"))'
  python3 -c 'import plistlib; plistlib.load(open("Sources/Resources/PrivacyInfo.xcprivacy", "rb"))'
fi

while IFS= read -r -d '' asset_json; do
  python3 -m json.tool "$asset_json" >/dev/null
done < <(find Assets.xcassets -name Contents.json -print0)

rg -q 'IPHONEOS_DEPLOYMENT_TARGET: 27\.0' project.yml

if rg -n --hidden -g '!**/.git/**' -g '!Scripts/validate_without_macos.sh' \
  '(Bearer[[:space:]]+[A-Za-z0-9._-]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9_-]{20,}\.)' .; then
  echo 'Potential credential material found.' >&2
  exit 1
fi

PYTHONPATH=Backend python3 -m unittest discover -s Backend/tests >/dev/null

echo 'Non-macOS validation passed.'
