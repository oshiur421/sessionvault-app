# SessionVault — Flutter app (Android)

On-device class / meeting recorder: record a class or meeting, save a
structured `.md` note on the phone, merge notes for any LLM. No server,
no upload — notes and audio never leave the device. Supabase is used for
login only.

## Run

```bash
# Demo mode (no real auth — any email/password works locally):
flutter run

# With real Supabase auth (same project as the web app):
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>

# Debug APK:
flutter build apk --debug
```

Keys are passed only via `--dart-define`. Never hardcode them, never
paste them in chat. See `.env.example`.

## What is implemented

- **Login (first screen only)** — Supabase Auth email/password (sign in,
  sign up, forgot password via email link). Session persists; next launch
  goes straight to the main page. Icon-only logout in the top bar clears
  only the session — models-ready state and theme are kept. Login events
  are recorded in the `login_logs` table when configured (failures silent).
- **AI Setup (first launch only, popup over Recorder)** — downloads the
  models from `assets/models.json` (Qwen3.5-4B GGUF + Whisper Small Bangla
  ONNX) with resume support into `models/qwen/` and `models/whisper/`
  under the app documents dir. The popup shows only "AI Setup", one
  overall progress bar with live %, a short status, "Download models" and
  "Continue" when done — no model names, sizes or details. Once done it
  never appears again; only a small quiet "AI ready" chip stays.
- **Recorder (screen-off background recording)** — Android foreground
  service (microphone type) + persistent notification with a Stop button
  + partial wake lock, so recording keeps going with the screen off /
  phone locked. Audio is saved in 10-minute WAV chunks (16 kHz, mono).
  Stop freezes the timer and **immediately** saves a real session (typed
  title or auto title, auto subject, actual duration, filename
  `YYYY-MM-DD_HH-MM_<subject>.md`) — the Sessions count goes up at once.
- **Sessions** — local-first storage as `.md` files
  (`sessions/index.json` + one `.md` per session); search, subject filter
  chips with counts, session detail (Formatted / Raw .md, Copy, Download
  / share .md, tickable action items), per-session delete with a confirm
  sheet naming the session and its `.md` file.
- **Merge for AI** — pick sessions, per-session + total token estimates,
  Copy / Download merged `.md` (first two sessions preselected).
- **Design** — Paper (warm cream) / Night (near-black), orange-red
  accent, serif headings, UI entirely English, icon-only tiny sun/moon
  theme toggle, three tabs only: Recorder / Sessions / Merge for AI.
  Calm paper-and-ink style, no gradients/glows/emoji icons.

## NOT done (next step, not faked)

On-device inference is **not wired**: Whisper ONNX transcription and
Qwen GGUF summarising via llama.cpp are not integrated yet. "Simulate AI
summary" fills a placeholder demo summary only, so the flow can be
tested end-to-end before inference lands.

## Toolchain (this VM)

Flutter 3.50.1 stable at `~/workspace/flutter-sdk/flutter`, JDK 17,
Android SDK at `~/Android/sdk` (SDK 36, build-tools 36.0.0).

**Building in this VM:** Java-as-a-TCP-client on loopback is broken here
(verified: a Java client connecting to a local socket gets
`Connection reset`, while Python clients work) — so the Gradle daemon
can never be reached and every build fails with "The first result from
the daemon was empty". The fix is to run Gradle fully in-process:
`android/gradle.properties` sets `org.gradle.daemon=false`, and the
build must be run with the launcher JVM matching the daemon JVM options
(including the instrumentation agent), otherwise Gradle forks a
single-use daemon anyway:

```bash
export GRADLE_OPTS="-Xmx2G -XX:MaxMetaspaceSize=512m -XX:ReservedCodeCacheSize=256m -javaagent:/root/.gradle/wrapper/dists/gradle-9.5.0-all/aca6g93cdtcf0oapcfka748qh/gradle-9.5.0/lib/agents/gradle-instrumentation-agent-9.5.0.jar"
flutter build apk --debug --no-android-gradle-daemon
```

On a normal machine (the user's PC) none of this is needed — plain
`flutter build apk --debug` works.
