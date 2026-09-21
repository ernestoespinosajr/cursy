#!/bin/bash
set -euo pipefail

# Offline module/regression checks, not a signed Xcode build or live device test.
# Excludes only the Sparkle app entry; never launches Cursy or accesses credentials.
# Match Xcode's SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY for app and tests:
# otherwise transitive imports can hide missing per-file framework imports.
app_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
developer_directory="$(xcode-select -p)"
testing_frameworks="$developer_directory/Platforms/MacOSX.platform/Developer/Library/Frameworks"
testing_macros="$developer_directory/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
test_directory="$(mktemp -d /private/tmp/cursy-native-regression.XXXXXX)"
printf 'Native test artifacts: %s\n' "$test_directory"

sources=()
for source in "$app_directory"/Cursy/*.swift; do
  [[ "$(basename "$source")" == "CursyApp.swift" ]] || sources+=("$source")
done

if ! xcrun swiftc -swift-version 5 -enable-upcoming-feature MemberImportVisibility \
  -enable-testing -parse-as-library -emit-library -emit-module \
  -module-name Cursy -module-cache-path "$test_directory/cache" \
  -emit-module-path "$test_directory/Cursy.swiftmodule" \
  "${sources[@]}" -o "$test_directory/libCursy.dylib" > "$test_directory/build.log" 2>&1; then
  tail -100 "$test_directory/build.log"
  exit 1
fi

tests=()
for test_source in "$app_directory"/CursyTests/*.swift; do
  # The broad pre-existing app suite/UI target still run through Xcode separately.
  [[ "$(basename "$test_source")" == "CursyTests.swift" ]] || tests+=("$test_source")
done
if ! xcrun swiftc -swift-version 5 -enable-upcoming-feature MemberImportVisibility -parse-as-library \
  -module-cache-path "$test_directory/cache" \
  -I "$test_directory" -L "$test_directory" -lCursy \
  -F "$testing_frameworks" -framework Testing \
  -load-plugin-library "$testing_macros" \
  -Xlinker -rpath -Xlinker "$test_directory" \
  -Xlinker -rpath -Xlinker "$testing_frameworks" \
  "${tests[@]}" "$app_directory/scripts/SessionTestRunner.swift" \
  -o "$test_directory/regression-tests" > "$test_directory/tests-build.log" 2>&1; then
  tail -100 "$test_directory/tests-build.log"
  exit 1
fi
"$test_directory/regression-tests" 2>&1 | tee "$test_directory/tests-run.log"
