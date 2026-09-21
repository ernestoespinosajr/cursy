#!/bin/bash
set -euo pipefail

# Reuse the isolated module built by test-native-regressions.sh; never launches
# Cursy, reads credentials, captures a screen or calls a model.
artifact_directory="${1:?Pass the absolute Native test artifacts directory printed by test-native-regressions.sh}"
[[ "$artifact_directory" = /* && -f "$artifact_directory/Cursy.swiftmodule" && -f "$artifact_directory/libCursy.dylib" ]] || exit 2
script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
benchmark_directory="$(mktemp -d /private/tmp/cursy-spatial-benchmark.XXXXXX)"
xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path "$benchmark_directory/cache" \
  -I "$artifact_directory" -L "$artifact_directory" -lCursy \
  -Xlinker -rpath -Xlinker "$artifact_directory" \
  "$script_directory/SpatialPreparationBenchmark.swift" -o "$benchmark_directory/benchmark"
"$benchmark_directory/benchmark"
