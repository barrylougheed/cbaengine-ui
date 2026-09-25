# cbaengine-ui

The Flutter frontend for [CBAEngine](../CBA) — connect your email, pick your council and Local Electoral
Area, draft a message, review who it'll reach, and send it through your own connected email account.
Targets web, Android, and iOS from one codebase.

## Current state

The full linear flow works end-to-end against the real backend:

```
Council picker → LEA picker → Compose → Review → Connect email (OAuth)
  → auto-chain: create draft → confirm → send → Result
```

- **Council picker, LEA picker, Compose, Review** are fully wired to the live backend (`GET /councils`,
  `GET /councils/{id}/leas`, `GET /topics`) via Riverpod — real council/LEA/topic data, real recipient
  names and parties on Review (never an email address — that stays server-side until a draft actually
  exists).
- **Connect** triggers real OAuth (Google/Microsoft) via `GET /email/authorize` +
  `GET /email/callback`, using `client_redirect_uri` and the URL **fragment** (never the query string —
  matches the backend's own design) on both web and mobile. Once connected, it auto-chains
  create → confirm → send with no extra tap, straight to **Result**.
- **API client, models, error handling, OAuth fragment parsing, draft/token storage, and the
  auth/message-flow notifiers are all unit-tested** (`flutter test` — 54 tests as of this writing).
- Router guards prevent skipping steps via a raw URL (e.g. visiting `/review` with no draft bounces back
  to `/compose` → `/council`), and any `401` from the backend routes to `/reconnect` from anywhere.
- **Not yet done:** real on-device testing on Android/iOS (see "Prerequisites").

## Decided against: session persistence across app restarts

Raised during the original design (as "should closing and reopening the app require reconnecting?") and
deliberately decided against, not deferred for lack of time. The payoff is small enough that it isn't
worth the added surface (secure storage wiring, boot-sequence restoration, another set of failure modes
to test):

- **Google/Microsoft OAuth access tokens expire in about an hour**, regardless of anything this app does.
  Persisting the token only helps within that same hour — reopen the app later than that and the restored
  token is dead on arrival, forcing a reconnect anyway. Persistence can't extend the useful window past
  what the provider already imposes.
- **The whole flow — pick council/LEA, compose, review, connect, send — takes a few minutes in one
  sitting.** With 99.9% backend availability, there's no legitimate "come back later mid-flow" case; the
  only scenario persistence helps is an *accidental* interruption (app killed, a call comes in) within
  that same short, already-narrow hour-long window.
- **The 1-send/day limit removes any reason to preserve continuity across a longer gap** — there's no
  "continue where I left off tomorrow," since tomorrow starts fresh regardless of what happened today.
- **Reconnecting is low-friction when it's needed** — the device/browser is almost always already logged
  into Google or Microsoft, so OAuth consent is typically one tap, not a real re-authentication burden.

So the actual value on offer is: save one OAuth tap, for someone accidentally interrupted, within a
one-hour window, occasionally. Worth revisiting for v2 if usage patterns turn out to disagree with this
(e.g. real users reporting the reconnect prompt as annoying) — `TokenStorageService` already exists and
is fully tested, so building the wiring later is cheap if it turns out to be warranted. What genuinely
*does* need to persist — the in-progress draft, surviving the OAuth redirect's page reload on web — is a
hard technical requirement (not a nice-to-have) and is already built (`DraftStorageService`).

## Known gap: only Google and Microsoft can connect

This isn't a coverage choice — Google and Microsoft are the only two mainstream providers with a public,
developer-registrable OAuth API for sending mail. Everyone else has no equivalent to plug into the same
pattern:

- **Apple iCloud Mail** — no OAuth send API at all ("Sign in with Apple" only authenticates, it can't
  send). Notable because iCloud Mail is the default mailbox on an un-configured iPhone.
- **Yahoo Mail** — has OAuth, but far less standardized/reliable for third-party developer registration
  than Google/Microsoft.
- **ProtonMail** — no general third-party OAuth send API (its architecture is built around end-to-end
  encryption).
- **Irish ISP webmail** (eircom.net, eir.ie, etc.) — essentially never OAuth-capable; plain IMAP/SMTP/POP.

The intent is to widen this to any email provider eventually. The realistic path is a **second connection
method** alongside OAuth: SMTP with an app-specific password, collected only at the moment of sending,
used for one SMTP session, and never persisted (not written to disk, not put in the session store, not
logged) — the same mechanism the backend already uses for its own manual testing
(`app/services/real_mailer.py` in the CBA repo). That covers iCloud and Yahoo, which both support
app-specific passwords for SMTP even without an OAuth API; it does not cover ProtonMail or most Irish ISP
webmail, which don't support app passwords either.

Worth going in with eyes open before building it: even never-persisted, an app-specific password is a
structurally different trust model than OAuth — it's a full-mailbox credential (send *and* read; there's
no equivalent to Gmail's `gmail.send`-only scope), it doesn't auto-expire the way an OAuth token does, and
it raises the UX cost (the resident has to leave the app to generate one). Not a reason to avoid it, just
not a drop-in replacement for what OAuth gives us today. Deliberately deferred — no work has started on
this.

## Prerequisites

- Flutter SDK (this project was built against 3.47.4, stable channel) — confirm with `flutter --version`.
- On Windows, only **web** is currently buildable/testable on this machine: there's no Android SDK
  installed yet (needs Android Studio), and iOS can never be built from Windows at all — it needs a Mac.
  The Android manifest and iOS `Info.plist` are already configured for the OAuth custom URL scheme
  (`cbaengine://oauth/callback`), but untested until there's a way to actually run on those platforms.

## Setup

```bash
flutter pub get
```

You'll also need the [CBA](../CBA) backend running locally — see its README. Two things it needs
configured for this app to talk to it:

```bash
# In the CBA repo, before starting uvicorn:
export CBA_CORS_ALLOWED_ORIGINS="http://localhost:5173"
export CBA_ALLOWED_CLIENT_REDIRECT_URIS="http://localhost:5173/connect,cbaengine://oauth/callback"
```

The first lets a browser call the API cross-origin at all; the second is required specifically to
complete a real OAuth connect (without it, `/connect` fails cleanly with "Could not connect" rather than
crashing — that's the backend correctly refusing an unrecognized redirect target, not a bug here).

## Running on web

```bash
flutter run -d chrome --web-port 5173
```

The port **must be pinned to 5173** (or whatever you configured above) and must match exactly what you
set in `CBA_ALLOWED_CLIENT_REDIRECT_URIS` — OAuth's `client_redirect_uri` allowlist is an exact-string
match, and Flutter's web dev server otherwise picks a random port each run.

This opens a real Chrome window with hot reload (`r`) and hot restart (`R`). If you'd rather run a plain
dev server and open it in your own browser:

```bash
flutter run -d web-server --web-port 5173
```

then open `http://localhost:5173` yourself.

These are debug builds: hundreds of separate script files, so a first load can take a while. Add
`--release` for a quick, optimised build to click through (no hot reload).

## Building for production

```bash
flutter build web --release --no-web-resources-cdn
```

`--no-web-resources-cdn` matters for privacy: without it, every visitor's browser loads Flutter's rendering
engine from Google's CDN (`www.gstatic.com`), sending their IP address to Google. With it, the engine and
its fallback font are served from `build/web` alongside the app. The Inter font is already bundled
(`assets/fonts/`, licence in `OFL.txt`), so a build made this way contacts no Google servers. Emoji or
scripts that Inter and Roboto don't cover would still make Flutter fetch a fallback font from Google. Setting
`fontFallbackBaseUrl` to self-hosted fonts would close that gap, and CBA's `TODO.md` tracks it.

## Manually testing a real send, through the UI

Same safety consideration as the backend: `BLOCK_REAL_COUNCILLOR_SENDS` is on by default, so a real
council/LEA will come back from `/connect` with a "failed" result explaining the block — expected, not a
bug. To see an actual "sent" result through the app itself, seed the backend's manual-test fixture first:

```bash
# In the CBA repo
python scripts/seed_manual_test_lea.py
```

The fixture (`manual-test-recipient`) is deliberately excluded from `GET /leas` and
`GET /councils/{id}/leas` (same as the backend's own listings), so the normal picker can never reach it —
but `POST /messages` accepts it directly, so the rest of the flow works identically to a real send. A
debug-only button on the Council picker screen, **"Use test recipient (dev)"**, skips straight to Compose
with this fixture selected — visible only in debug builds (`kDebugMode`), never in a release build. Use
it to exercise a real, delivery-confirmed send (and the 429/failure paths) entirely through the app.

## Tests

```bash
flutter test
flutter analyze
```

## Backend

The API this app talks to lives in the sibling [`CBA`](../CBA) repo — see its README for setup, the OAuth
app registration steps (Google Cloud Console / Microsoft Entra), and the full API contract.
