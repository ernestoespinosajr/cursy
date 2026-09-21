# Validation and Release Scripts

## Native visual/session regressions (offline)

Run `bash scripts/test-native-regressions.sh` from `cursy-app`. It compiles native
sources except the Sparkle app entry, then runs isolated Swift Testing regression
files. It does not replace the full Xcode/UI suite or live provider QA. Temporary
build/test logs are printed by path; macros may require execution outside a tool
sandbox. No app launch, xcodebuild, credentials or external services.
App and test compilation enable `MemberImportVisibility`, matching the Xcode
project's import checks. This catches missing explicit framework imports that
the previous standalone compiler invocation allowed; other Xcode build settings
and signing/UI validation still require Xcode.
See [VISUAL_INTENT_QA.md](VISUAL_INTENT_QA.md) for the live tsk004 acceptance gate.
See [SPATIAL_CONTEXT_QA.md](SPATIAL_CONTEXT_QA.md) for the opt-in spatial-input beta,
its bounded multiscene Realtime input and remaining provider/manual acceptance gates (tsk006).
See [SETTINGS_QA.md](SETTINGS_QA.md) for the opt-in Home prototype and its design
gate before the remaining tsk007 settings/text-input work.
See [VOICE_LATENCY_QA.md](VOICE_LATENCY_QA.md) for early Realtime capture,
bounded buffering, numeric phase measurements and the tsk017 physical gate.

Static Home review (from `cursy-app`, using the runner's printed artifact path):

```bash
home_artifacts=/private/tmp/cursy-native-regression.REPLACE_WITH_ACTUAL
xcrun swiftc -swift-version 5 -parse-as-library -module-cache-path "$home_artifacts/cache" \
  -I "$home_artifacts" -L "$home_artifacts" -lCursy \
  -Xlinker -rpath -Xlinker "$home_artifacts" scripts/RenderHomePrototype.swift \
  -o "$home_artifacts/render-home"
"$home_artifacts/render-home" "$home_artifacts"
```

Renders light/dark PNGs of the production view using synthetic messages and an
unordered AppKit window (never foregrounded), no desktop screenshot or model call.
Does not validate physical window focus, keyboard traversal, capture or audio.

For synthetic message-preparation timing, run
`bash scripts/benchmark-spatial-preparation.sh <absolute-native-artifact-directory>`.
The directory comes from the regression runner above. Thirty samples each for
one/three scenes measure local raster/JSON preparation only, not capture, UI,
model quality, network latency or cost. No API calls or private inputs.

## Session core (offline)

Run `bash scripts/test-session-core.sh` from `cursy-app` to compile and execute
the in-memory session/replay tests without launching Cursy or using xcodebuild.
See [SESSION_QA.md](SESSION_QA.md) for the separate manual acceptance checklist.
No microphone, screenshots, credentials or provider calls are used by this command.

## `release.sh` — Ship a new version of Cursy

Automates the full release pipeline: build → sign → DMG → notarize → Sparkle appcast → GitHub Release.

### Quick start

```bash
# Auto-bumps version and build number from the latest GitHub Release
./scripts/release.sh
```

The script checks GitHub for the latest release (e.g. `v1.5`, build 6) and automatically bumps to `v1.6`, build 7. You'll see a confirmation prompt before anything runs.

### Override version or build

```bash
# Set a specific marketing version (auto-bumps build)
./scripts/release.sh 2.0

# Set both marketing version and build number
./scripts/release.sh 2.0 10
```

### Safety

- **Duplicate detection**: If the tag already exists on GitHub, the script exits with an error and suggests what to do.
- **Confirmation prompt**: Shows the version, build, and previous release before proceeding. Press `y` to continue.

### What it does

1. Fetches the latest release from GitHub to determine version + build
2. Archives the app via `xcodebuild`
3. Exports a signed `.app` with Developer ID
4. Creates a DMG with the drag-to-Applications background
5. Notarizes the DMG with Apple (Gatekeeper compliance)
6. Signs the DMG with the Sparkle EdDSA key
7. Generates `appcast.xml` for Sparkle auto-updates
8. Creates a GitHub Release with the DMG attached
9. Pushes the updated `cursy-app/appcast.xml` to the Cursy repository

### One-time setup (prerequisites)

1. **Xcode** with your Developer ID signing certificate
2. **Homebrew tools**:
   ```bash
   brew install create-dmg gh
   ```
3. **GitHub CLI auth**:
   ```bash
   gh auth login
   ```
4. **Apple notarization credentials** (stored in Keychain):
   ```bash
   xcrun notarytool store-credentials "AC_PASSWORD" \
       --apple-id YOUR_APPLE_ID \
       --team-id YOUR_TEAM_ID
   ```
   You'll be prompted for an app-specific password (generate one at [appleid.apple.com](https://appleid.apple.com)).
5. **Sparkle EdDSA key** — already generated and stored in Keychain (done during initial Sparkle setup)
6. **Build the project in Xcode at least once** so SPM downloads Sparkle and the Sparkle CLI tools are available
