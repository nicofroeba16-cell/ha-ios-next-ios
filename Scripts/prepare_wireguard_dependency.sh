#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dependency_root="$project_root/.build-dependencies/wireguard-apple"
expected_commit="2fec12a6e1f6e3460b6ee483aa00ad29cddadab1"

if [[ ! -d "$dependency_root/.git" ]]; then
  mkdir -p "$(dirname "$dependency_root")"
  git clone --quiet --no-checkout https://git.zx2c4.com/wireguard-apple "$dependency_root"
  git -C "$dependency_root" fetch --quiet --depth 1 origin "$expected_commit"
  git -C "$dependency_root" checkout --quiet --detach "$expected_commit"
fi

actual_commit="$(git -C "$dependency_root" rev-parse HEAD)"
if [[ "$actual_commit" != "$expected_commit" ]]; then
  echo "Unexpected WireGuard source commit: $actual_commit" >&2
  exit 1
fi

if head -n 1 "$dependency_root/Package.swift" | grep -Eq 'swift-tools-version:5\.3'; then
  perl -pi -e 's#swift-tools-version:5\.3#swift-tools-version:5.5#' \
    "$dependency_root/Package.swift"
fi

if ! grep -Eq '^#include <sys/types\.h>$' \
  "$dependency_root/Sources/WireGuardKitC/WireGuardKitC.h"; then
  perl -0pi -e 's/#include "key\.h"/#include <sys\/types.h>\n\n#include "key.h"/' \
    "$dependency_root/Sources/WireGuardKitC/WireGuardKitC.h"
fi

status="$(git -C "$dependency_root" status --short)"
expected_status=$' M Package.swift\n M Sources/WireGuardKitC/WireGuardKitC.h'
if [[ "$status" != "$expected_status" ]] || \
   ! head -n 1 "$dependency_root/Package.swift" | grep -Eq 'swift-tools-version:5\.5'; then
  echo "WireGuard dependency differs from the two-file audited compatibility patch." >&2
  git -C "$dependency_root" status --short >&2
  exit 1
fi

echo "Prepared WireGuardKit $expected_commit with audited Xcode 27 compatibility."
