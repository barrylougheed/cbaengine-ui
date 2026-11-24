# cbaengine-ui

The Flutter frontend for [CBAEngine](../CBA) — write an email (choose the issues you
care about, write your own, or back a campaign), pick your council and Local Electoral Area, review who
it'll reach, and send it through your own connected email account.
Targets web, Android, and iOS from one codebase.

## Current state

The full linear flow works end-to-end against the real backend:

```
Home → Craft an email → Select issues / Write my own email   (or Campaigns → pick one)
  → Council picker → LEA picker → Review → Connect email and send (OAuth)
  → auto-chain: create draft → confirm → send → Result
```

The email comes first, and the area after it, because the text never names the area. There are three kinds
of email, one per email: about **issues**, in the resident's **own words**, or for a **campaign**.

- **Everything up to Review is wired to the live backend** (`GET /topics`, `POST /topics/compose`,
  `GET /campaigns`, `POST /campaigns/{id}/compose`, `GET /councils`, `GET /councils/{id}/leas`) via
  Riverpod — real issues, campaigns, councils and areas, and real recipient names and parties on
  Review (never an email address — that stays server-side until a draft actually exists).
- The **home screen** opens with a deep olive hero (the headline "Email your local councillors in minutes" and
  the tagline) holding three cards: **Craft an email**, **Campaigns**, and a disabled **Create a campaign
  link** marked "Coming soon" (Feature 3, not built yet). Under it, in large numerals, how many councillors,
  councils and local areas can be written to (left out if the councils cannot be loaded), then **How it
  works** in three numbered steps, a panel saying that you can send one email a day and that a Gmail,
  Outlook or Hotmail account is needed to send (so an iCloud or Yahoo user does not find out at the last
  step), and a footer saying this is an independent service, not affiliated with the Government of Ireland.
- **Craft an email** offers two choices: **Select issues** and **Write my own email**.
- **Select issues** is four screens, all step 1 of 5, shaped after letters.contactyourtd.ie:
  1. **Choose a category** (`/craft/issues`): a grid of tiles, one per category the server sends (only those
     with a finished issue, in the owner's order, reading across then down), three across where there is room and
     two on a phone, each with an icon and how many topics it has. The link "Want to say something different?
     Write your own email." is how someone covers a view the issues do not.
  2. **Choose a topic** (`/craft/issues/category/:id`): tick one or more topics. Ticking only records the choice
     (no request), the choice is kept when going back to add a topic from another category, and "You have chosen:
     ..." says what is picked.
  3. **Choose a letter style** (`/craft/issues/style`): six cards in ascending order (Communal, Concerned,
     Data-driven, Direct, Solution-based, Urgent), each with a one-line description, one chosen. The server
     sends the styles and their order. Continue asks the server to write the email in that style, for the topics
     chosen (an opening paragraph naming the topics, then one wording for each).
  4. **Write your message** (`/craft/issues/email`): the text, shown for editing, under a summary of the topics and
     style with "Change topics" and "Change style". The resident types **Your name**, which signs off the email.

  With no topic finished yet the first screen says so and offers "Write my own email". Changing the topics or the
  style after editing the text asks "This replaces your edits. Continue?" first; carrying on with the same
  choices goes straight to the editor and keeps the edits. Review also says which style the email is in.
- **Write my own email** (route `/craft/own`): the subject and message are the resident's own, plus their
  name. No footer is added.
- **Campaigns** (routes `/campaigns`, `/campaigns/email`): the list of campaigns the owner has set up, each
  with its summary and an optional "Learn more" link. Choosing one shows the email the server wrote for it
  (editable), then the name. Only campaigns that are finished are listed.
- On every one of these the server adds "Hi <name>," for each councillor and the sign-off
  around the text, and a read-only footer for issue and campaign emails (a campaign's footer names it);
  all of it is shown on Review.
- Text left in `[[double square brackets]]` is flagged and blocks Continue: it is a placeholder the
  author of the content still has to fill in, and the API refuses it.
- The **Council picker** lists all 31 councils with an always-visible scrollbar and a **search box** (it
  ignores case and fadas, and matches every word typed, so "dun lao" finds Dún Laoghaire-Rathdown). A list
  that merely scrolls gave no sign that there was more below the first ten. It shows the total ("31
  councils · 945 councillors", narrowing as you search) and, on each council, "7 areas · 40 councillors".
- **Find your area** (a card at the top of the council list, route `/find-area`): a resident who does not
  know their council or area types a town, village or suburb and picks the area it is in; choosing one sets the
  council and area and carries on to Review. A place split across two areas shows both ("Pick the area your
  address is in."); a name with many matches says "Showing 8 of 31 matches. Type more of the name to narrow it
  down."; no match offers the council list instead. It searches after a short pause in typing, sends the text in
  a POST body (never the URL), credits Tailte Éireann, and the privacy notice says the text is not stored or
  logged. Eircodes and full addresses are not supported.
- The **area picker** heads the list with the council's totals and shows, on each area, how many
  councillors it has and who they are, so a resident can tell they picked the right area.
- The **connect screen** says what connecting means before the resident is sent to Google or Microsoft:
  send-only permission (it cannot read mail or contacts), the message is sent as soon as they connect, they
  get a copy and replies come to their inbox, and which accounts work.
- A **429** ("already sent today") says when they can send again, in their own time zone ("after 14:32
  tomorrow"), using the `available_at` time the API returns.
- The **result screen**, for a sent message, says who it went to ("Sent to 6 councillors", each with their
  party; never an email address) and where the copy and any replies go ("A copy has been sent to
  you@example.com, and any replies will come to that inbox."). A message is only `sent` when every councillor
  received it, so the list is exactly who it reached. A failed or partly delivered send still shows the API's
  own explanation, with no list. It deliberately has no "share the app" prompt.
- **Connect** triggers real OAuth (Google/Microsoft) via `GET /email/authorize` +
  `GET /email/callback`, using `client_redirect_uri` and the URL **fragment** (never the query string —
  matches the backend's own design) on both web and mobile. Once connected, it auto-chains
  create → confirm → send with no extra tap, straight to **Result**.
- **API client, models, error handling, OAuth fragment parsing, draft storage, and the
  auth/message-flow notifiers are all unit-tested** (`flutter test`).
- Router guards prevent skipping steps via a raw URL: the council, area and Review screens need a finished
  email first (a raw `/review` with no email bounces back to Home, and with an email but no area to the
  council list), `/craft/own` and everything under `/craft/issues` need the matching choice (and the style screen
  needs a topic, and the editor needs the text written), and `/campaigns/email` needs a campaign chosen. Any `401` from the backend routes to `/reconnect` from anywhere.
- **Not yet done:** real on-device testing on Android/iOS (see "Prerequisites").

## Look and feel

One **light** theme, whatever the device is set to (`themeMode: ThemeMode.light`, no dark theme), built
around the logo's olive. All of it is in `lib/theme/app_theme.dart` (`AppColors`, `buildAppTheme()`), and
every text colour in it is held to WCAG AA contrast (4.5 : 1) by `test/theme/app_theme_test.dart`, so a
palette change that makes text hard to read fails a test.

| Colour | Hex | Used for |
|---|---|---|
| Brand green / cream | `#2C3F33` / `#F6F3E9` | the logos: green on white (the header), cream on deep olive (the footer). They are the brand's own colours, darker than the olive the theme is built on |
| Logo olive | `#748264` | the colour the placeholder logo had (`AppColors.logoOlive`). The real logo is the brand green above, so nothing draws this any more |
| Deep olive | `#3F4B37` | the hero, footer, buttons, the stepper |
| Link olive | `#5A6A4C` | links and small icons on white |
| Soft olive / mist | `#E7ECE0` / `#F4F6F0` | tinted discs, chips and panels |
| Clay | `#A8502F` | the one accent: a thin rule under the Home hero |
| Ink / muted | `#20261B` / `#5A6152` | text |

Layout: every screen's content sits in a centred column (720px for the steps, forms and the privacy
notice; 1040px for Home, the header and the footer) instead of stretching across a wide window, and shrinks to
the screen with a 16px margin on a phone. The pieces are in `lib/widgets/`:

- `AppHeader`: the white bar with the sloth icon (`LogoMark`) and the CBAEngine name (the way back to Home); on
  every screen. It has no links of its own: the privacy notice is linked from the footer (below), and from the
  consent panel on the Review screen.
- `ContentWidth` / `ContentList`: the centred column, for a block of content and for a scrolling page (the page
  spans the window, so its scrollbar sits at the window edge and the wheel scrolls anywhere; only its margins grow).
- `StepPage`: the frame of the steps that write or review: header, the five-stage stepper
  (`StepProgressIndicator`: Write, Council, Area, Review, Send), a scrolling column, and a button bar that
  stays on screen however long the message is.
- `ChoiceCard`: the big outlined cards on Home and "Craft an email".
- `AppFooter`: the olive foot of every screen, with the cream sloth wordmark (`BrandWordmark`), the independence
  statement and the link to the privacy notice (the privacy notice itself leaves the link out).
- `FooterScroll`: a scrolling page that ends with the footer. The footer follows the content, and when the
  content is short it sits at the foot of the window instead of floating half way up it; `centered: true` puts a
  short message (Result, Reconnect, a spinner) in the middle of the space above it. `ContentList` (so every
  `StepPage`, Craft, Campaigns and the privacy notice), Home, the council and area lists, Find your area, Result
  and Reconnect all use it. The buttons that move on are in a bar outside the scrolling, so Continue stays in
  reach. On the council and area lists the footer is at the end of the list, under a search box and heading that
  stay put; a screen that only shows a blank frame while the router sends the visitor elsewhere has none.

Review sets the email out as a letter, then who it goes to (each councillor's initial in an olive disc, with
their party), then the consent notice.

### Logo

The brand logos (the sloth icon, a sloth curled into a "C", and the sloth wordmark, "CBA" with the sloth as the
C) are in `assets/brand/`, in two colours each: `sloth_icon_green.png` and `sloth_wordmark_green.png` for white,
`sloth_icon_cream.png` and `sloth_wordmark_cream.png` for the deep olive. They are drawn in two places:

- `LogoMark` (`lib/widgets/logo_mark.dart`): the sloth icon in the header, 40px tall, beside the name.
- `BrandWordmark` (`lib/widgets/brand_wordmark.dart`): the wordmark in the footer, in cream.

Both take a `BrandTone` (`green` or `cream`) for the background they sit on.

The files in the brand folder (`CBA-docs/brandAssets`) are A4-sized canvases with a wide transparent margin, so
`assets/brand/` holds cropped, smaller copies (about 200 KB in all). If the artwork changes, rebuild them, and the
favicon and install icons, from the brand folder:

```bash
pip install pillow
python tool/make_brand_assets.py "C:\path\to\CBA_BrandAssets"
python tool/make_icons.py
```

`make_icons.py` writes `web/favicon.png` and `web/icons/*.png`: the green sloth on a cream tile, so it shows on a
dark browser tab and a dark home screen (a green logo on a transparent background would vanish there, and iOS
fills transparent icons with black). The brand folder also has black and white versions, the "CBA" wordmark
without the sloth and a hand icon; none is used yet.

The page title, description, theme colour and install name are in `web/index.html` and `web/manifest.json`
(the browser tab title is also set by `MaterialApp.title` in `lib/app.dart`, which wins once the app starts,
so keep the two the same).

## Decided against: session persistence across app restarts

Raised during the original design (as "should closing and reopening the app require reconnecting?") and
deliberately decided against, not deferred for lack of time. The payoff is small enough that it isn't
worth the added surface (secure storage wiring, boot-sequence restoration, another set of failure modes
to test):

- **Google/Microsoft OAuth access tokens expire in about an hour**, regardless of anything this app does.
  Persisting the token only helps within that same hour — reopen the app later than that and the restored
  token is dead on arrival, forcing a reconnect anyway. Persistence can't extend the useful window past
  what the provider already imposes.
- **The whole flow — write, pick council/LEA, review, connect, send — takes a few minutes in one
  sitting.** With 99.9% backend availability, there's no legitimate "come back later mid-flow" case; the
  only scenario persistence helps is an *accidental* interruption (app killed, a call comes in) within
  that same short, already-narrow hour-long window.
- **The 1-send/day limit removes any reason to preserve continuity across a longer gap** — there's no
  "continue where I left off tomorrow," since tomorrow starts fresh regardless of what happened today.
- **Reconnecting is low-friction when it's needed** — the device/browser is almost always already logged
  into Google or Microsoft, so OAuth consent is typically one tap, not a real re-authentication burden.

So the actual value on offer is: save one OAuth tap, for someone accidentally interrupted, within a
one-hour window, occasionally. Worth revisiting for v2 if usage patterns turn out to disagree with this
(e.g. real users reporting the reconnect prompt as annoying). An unused `TokenStorageService`, and the
`flutter_secure_storage` package behind it, were removed to cut dependencies; they're in git history as a
starting point if this is ever revisited. What genuinely
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
debug-only button on the Council picker screen, **"Use test recipient (dev)"**, skips straight to Review
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
