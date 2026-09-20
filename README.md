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
- **Not yet done:** session persistence across app restarts (Q3 from the design — the auth token
  currently only lives in memory for one session), and real on-device testing on Android/iOS (see
  "Prerequisites").

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

## Manually testing a real send

Same safety consideration as the backend: `BLOCK_REAL_COUNCILLOR_SENDS` is on by default, so a real
council/LEA will come back from `/connect` with a "failed" result explaining the block — expected, not a
bug. To see an actual "sent" result, seed the backend's manual-test fixture first:

```bash
# In the CBA repo
python scripts/seed_manual_test_lea.py
```

Then in the app, pick any council/LEA as normal for browsing — but note the manual-test fixture itself
(`manual-test-recipient`) isn't shown in the public picker (deliberately, same as the backend's own
`/leas` endpoint). Testing a real send currently means using the picker for a real council/LEA to see the
review flow, then using `scripts/send_real_test_email.py` or the backend's own documented curl flow (see
[CBA/README.md](../CBA/README.md#manually-testing-a-real-send)) for the actual delivery-confirmed test —
wiring the picker itself to the manual-test fixture isn't in scope for this app (it's excluded from every
public listing on purpose).

## Tests

```bash
flutter test
flutter analyze
```

## Backend

The API this app talks to lives in the sibling [`CBA`](../CBA) repo — see its README for setup, the OAuth
app registration steps (Google Cloud Console / Microsoft Entra), and the full API contract.
