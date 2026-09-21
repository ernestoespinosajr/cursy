#!/bin/bash
set -euo pipefail

# Pure in-memory tests only: no app launch, xcodebuild, microphone, Keychain or API.
app_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
developer_directory="$(xcode-select -p)"
testing_frameworks="$developer_directory/Platforms/MacOSX.platform/Developer/Library/Frameworks"
testing_macros="$developer_directory/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
test_directory="$(mktemp -d /private/tmp/cursy-session-core.XXXXXX)"
printf 'Session test artifacts: %s\n' "$test_directory"

xcrun swiftc -swift-version 5 -enable-testing -emit-library -emit-module \
  -module-name Cursy -module-cache-path "$test_directory/cache" \
  -emit-module-path "$test_directory/Cursy.swiftmodule" \
  "$app_directory/Cursy/ConversationSession.swift" \
  "$app_directory/Cursy/RealtimeConversationMemory.swift" \
  -o "$test_directory/libCursy.dylib"

xcrun swiftc -swift-version 5 -parse-as-library \
  -module-cache-path "$test_directory/cache" \
  -I "$test_directory" -L "$test_directory" -lCursy \
  -F "$testing_frameworks" -framework Testing \
  -load-plugin-library "$testing_macros" \
  -Xlinker -rpath -Xlinker "$test_directory" \
  -Xlinker -rpath -Xlinker "$testing_frameworks" \
  "$app_directory/CursyTests/ConversationSessionTests.swift" \
  "$app_directory/CursyTests/RealtimeConversationMemoryTests.swift" \
  "$app_directory/scripts/SessionTestRunner.swift" \
  -o "$test_directory/session-tests"

"$test_directory/session-tests"
