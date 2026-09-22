#!/bin/bash
set -euo pipefail
# Usage: bash scripts/evaluate-guide-verification.sh NATIVE_TEST_ARTIFACTS OUTPUT_DIRECTORY [--live-80-authorized] [--candidate-v2]
# Offline by default. The live flag requires explicit user approval for up to 80 paid calls.
app_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
artifacts="$1"
output_directory="$2"
test -f "$artifacts/libCursy.dylib"
test -d "$output_directory"
xcrun swiftc -swift-version 5 -enable-upcoming-feature MemberImportVisibility -parse-as-library \
  -module-cache-path "$artifacts/cache" -I "$artifacts" -L "$artifacts" -lCursy \
  -Xlinker -rpath -Xlinker "$artifacts" "$app_directory/scripts/EvaluateGuideVerification.swift" \
  -o "$artifacts/evaluate-guides"
"$artifacts/evaluate-guides" "$output_directory" "${3:-}" "${4:-}"
