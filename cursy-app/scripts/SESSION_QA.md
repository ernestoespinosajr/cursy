# tsk003 — Session acceptance

Run the latest Cursy source from Xcode (not terminal xcodebuild). The Worker and
localization model do not need another deployment for this change. Use test data;
do not paste private messages, recordings, screenshots or credentials into QA logs.

## Repeatable offline check

From `cursy-app`: `bash scripts/test-session-core.sh`.

Compiles the actual session/replay sources and Swift Testing suites into a unique
temporary directory printed by the command. It does not launch the app, access
Keychain, record audio, capture displays, contact models or change TCC. Requires
the selected Xcode toolchain with Swift Testing. Artifacts remain in the temporary
directory for inspection; this is not a signed app or a full Xcode test run.

## Manual acceptance (user-run)

| Check | Action | Expected result |
|---|---|---|
| Two-turn continuity | Ask to locate an app and then a named control inside it. Open it yourself, move the pointer to its display and say “It is open now; show me.” | Remembers the requested control, captures current context automatically and points when verified. Does not ask for a manual screenshot or repeat the objective from scratch. |
| Interrupted answer | After the first reply starts, interrupt with another PTT request referring to the same goal. | Retains the original user request if its transcription arrived. Does not replay an incomplete assistant answer as completed. Only the new turn may update the cursor/state. |
| New conversation | In the menu choose New conversation after a few turns and an explicit objective. Ask what the previous objective was. | Old objective/history are unavailable locally; no claim to remember them. The new turn behaves as a new session. This does not delete provider-side records. |
| Reset while waiting | Choose New conversation during connecting/processing, then start a fresh request. | An old startup/result cannot restart recording, replace the new turn, restore the old indicator or reset the new turn to idle. |
| Short/cancelled turn | Release the shortcut before readiness, then start another normal turn. | No stuck state or old completion/error applied to the next turn. |
| Regression | Repeat with the user's normal AirPods, language and second-display setup; test sharing off. | Existing voice/cursor behavior preserved. No screen context is captured/shared while disabled. |

Record pass/fail per check and any content-free diagnostic reason. Do not assume
all rows passed from a single successful request. If transcription fails/expires,
the app must honestly warn that context could not be retained; it cannot reconstruct
speech it never transcribed. Tests of completed/failed/foreign transcription events
are automated; physical device/network failure simulation is not required here.

Scope: last ten requests/completed exchanges in memory; maximum 8,000 characters
per retained user/assistant text and 2,000 for the explicit objective. Realtime
replays user-only interrupted requests; legacy fallback still uses completed pairs.
This is not persistent history, automatic step advancement or a walkthrough engine.
