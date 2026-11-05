# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Mio Cartellino** (public name; the code package keeps `cartellino_unisa_mobile`). Flutter app (iOS + Android) companion of the desktop/TUI tool
[staffDiUnisa/CartellinoUniSA](https://github.com/staffDiUnisa/CartellinoUniSA)
(Python, GPL-3.0). It downloads the user's attendance record ("cartellino") from
`presenze.unisa.it`, shows a summary, and computes today's expected exit time.

Author: Andrea Bruno. Conventions: code, comments and this file in **English**; UI strings
in **Italian** (users are UniSA staff).

## Status

As of 2026-11-05 (Flutter 3.44.8): `ios/` and `android/` are generated (bundle id
`it.bruand81.cartellinoUnisaMobile`, Android `it.bruand81.cartellino_unisa_mobile`),
`flutter analyze` is clean and the unit tests pass. The debug APK builds but hasn't been
launched. On a real iPhone, SPID login and the download work, and the product owner confirmed
the dashboard numbers match the desktop app. Android, CIE and other users are still
untested: see the spike checklist. Only the demo flow has widget tests.

Deliberate edits to generated files, to redo if the platforms are ever regenerated:
- Android: `minSdk = 24` (webview_flutter 4.14) in `android/app/build.gradle.kts`, and
  `android.permission.INTERNET` in `android/app/src/main/AndroidManifest.xml` (flutter create
  only adds it to debug/profile).
- iOS: `IPHONEOS_DEPLOYMENT_TARGET = 15.0` in `ios/Runner.xcodeproj/project.pbxproj` (the
  template's 13.0 is rejected by Xcode).
- `flutter create` adds a `test/widget_test.dart` referencing a nonexistent `MyApp`: delete it.
- iOS is iPhone-only (`TARGETED_DEVICE_FAMILY = 1`) and declares `ITSAppUsesNonExemptEncryption = false`.
- Android signs releases with `android/key.properties` when present, otherwise with debug keys.

Store release: procedure in `docs/PUBBLICAZIONE.md`, texts and graphics in `store/`, icons from
`tool/generate_store_assets.py`. A debug build can't start from the iPhone home screen (it crashes in
`VSyncClient`): use `flutter run --release` to test a reopen. Screenshots must show only fictitious data.

## Commands

```sh
flutter pub get
flutter analyze
flutter test                                  # all unit tests
flutter test test/exit_time_test.dart         # one file
flutter test --plain-name 'currently out'     # by test or group name
flutter run                                   # needs a device or emulator
flutter build apk --debug
flutter build ios --simulator --debug
```

Use `flutter test`, not `dart test`: the `test` package isn't a direct dependency. Line length
is 100 (`.vscode/settings.json`), so format with `dart format -l 100`.

On a physical iPhone, keep the phone unlocked during `flutter run`: when it's locked the
developer disk image can't mount, and Flutter misreports this as "enable Developer Mode".
`xcrun devicectl device info ddiServices --device <udid>` shows the real error.

## Scope (MVP, chosen by the product owner)

From the desktop feature list, only:

| # | Feature | Where |
|---|---------|-------|
| 1 | Download cartellino (SPID/CIE login in WebView) | `lib/ui/update_screen.dart`, `assets/js/extract_cartellino.js` |
| 2 | Onboarding (min date for used riposi; the year is always the current one) | `lib/ui/settings_screen.dart` (first run opens it) |
| 3 | Eccezioni del mese (codes, default ERIT, SCN) | `lib/domain/dashboard.dart` |
| 4 | Saldo ore del mese (CRE, OE-DIU, SCN; SCN subtracted) | `lib/domain/ore.dart` |
| 5 | Riposi compensativi summary | `lib/domain/riposi.dart` |
| 6 | Ferie / festività soppresse / PMF counters | `lib/domain/dashboard.dart` |
| 8 | Ultimo aggiornamento | dashboard |
| 14 | Date escluse (full day or `HH:MM` subtraction) | `lib/domain/excluded_date.dart`, settings |
| new | **Uscita prevista** (mobile only) | `lib/domain/exit_time.dart`, `lib/ui/exit_time_screen.dart` |

Explicitly **out of scope** for now: ticket da ricevere, statistiche, credito ore,
ore giornaliere, exports (xlsx/csv), project timesheet, formal rendiconto, PDF request of
riposo compensativo (possible phase 2), configurable folders, app-update check.

## Architecture

```
lib/
  domain/     pure Dart, no Flutter imports, fully unit-tested
    clock.dart          minutes-since-midnight helpers, date formatting
    exit_time.dart      expected exit time (rules below)
    cartellino.dart     portal rows -> exploded entries (date parsing, code extraction)
    ore.dart            HH.MM extraction, signed balance (SUBTRACTIVE_CODES = {SCN})
    excluded_date.dart  date_escluse.txt format
    riposi.dart         OE-DIU, riposi grouping, SRC used dates, riposo state
    settings.dart       AppSettings (subset of desktop config.toml)
    dashboard.dart      per-section summary with per-section error capture
  data/
    stores.dart         JSON files in app documents dir (settings, cartellino cache, today's punches)
    presenze_portal.dart URLs/constants of presenze.unisa.it
  ui/                 home_shell (3 tabs), dashboard, exit_time, settings, update (WebView)
  theme/unisa_theme.dart colors taken from www.unisa.it
  services.dart       AppServices (stores + `revision` ValueNotifier for reloads)
assets/js/extract_cartellino.js  scraper injected in the WebView
```

Data flow (spans WebView, JS, storage and domain):
1. `UpdateScreen` waits for a logged-in URL, switches the WebView to a desktop user agent,
   loads the cartellino page, injects `extract_cartellino.js`, and runs
   `window.__cartellino.run()`.
2. The scraper waits for DataTables to be ready, draws all rows at once, then posts JSON over
   the `CartellinoChannel` JS channel: `page` (headers + rows), then `done`, or `error`.
   Columns `Stato`, `Data` and `Voci Base` are required.
3. Rows are validated with `explodeRows` *before* overwriting the cache, then stored **raw**
   in `cartellino_<year>.json`. A failed download therefore keeps the previous data.
4. Screens re-run `explodeRows` and `DashboardSummary.compute` on each load; no derived values
   are persisted. Each dashboard section has its own `guard`, so one failure lands in
   `errors` instead of breaking the whole screen.

Design choices:
- No state-management package; `AppServices` passed explicitly, screens listen to
  `services.revision`.
- Domain uses `int` minutes everywhere, not `Duration`/`DateTime`.
- No backend, no credentials stored, nothing leaves the device.
- Demo mode for store reviewers (`domain/demo_data.dart`): fictitious rows stored with `isDemo`, offered
  only when no cartellino is stored, so it can never replace real data.

## Authentication (decided)

- Username/password ("Credenziali UNISA") works only on the university wired network,
  never on Wi-Fi → **not supported on mobile**.
- **SPID** and **CIE level 2** (username + password + CieID app push/SMS OTP) inside the
  WebView. CIE level 3 (NFC) is not needed.
- With a mobile user agent the portal redirects `default.aspx` to a separate mobile site
  (`/static/mobile/`) that has no table `#1011`. Both URLs therefore count as logged in, and
  the app then switches to a desktop user agent to load the full-year cartellino URL. Keep the
  mobile user agent during login, so identity providers approve on the phone (no QR code).
- Cookies are never read: the scraper runs inside the page (same origin). If a native
  HTTP client is ever needed, `webview_flutter` cannot read HttpOnly cookies — evaluate
  then.

### Spike checklist (to verify on a real device)

1. **Done (iPhone, PosteID, 2026-11-05):** SPID login completes inside the WebView.
2. **Done (iPhone, 2026-11-05):** login with CieID works inside the WebView.
3. Session lifetime when reopening the app: a full login was needed after relaunching from
   `flutter run` (seen once); not checked on a normal reopen.
4. **Done:** `#1011` is client-side (`serverSide: false`, all rows in memory) but is created
   after the table element appears, so the scraper waits for the DataTables instance and uses
   `page.len(-1)` instead of paging. The portal's `/rpc/` endpoints weren't investigated.
5. Android: never launched; the whole flow is still to be checked there.
6. **Partly done:** `PresenzePortal.cartellinoUrl` passes no `iddip` (desktop `get.py` hard-codes
   one) and the author's cartellino still loads. Colleagues reportedly used the desktop app with its
   hard-coded id without problems, which suggests the session decides whose data is shown.
   Low risk, but to be confirmed with another employee's login on mobile (TestFlight).

## Exit time rules ("Uscita prevista") — agreed with the product owner

- Required daily presence **7:22**, already including a **10' lunch pause**.
- Presence counts from **07:50** at the earliest (earlier punches clamped; absences before
  07:50 ignored, absences straddling it count only after 07:50).
- Intermediate exit → re-entry intervals are **added in full** (they do NOT absorb the
  10' pause).
- Today's punches are entered **manually** (the portal shows them only with a delay);
  persisted per day in `today_punches.json`.
- Optional, always explicit: **use credit** (leave earlier) or **recover debt** (leave
  later). Over **29'/day** a permit is needed → **warning, never a block**. Also warn
  when credit used exceeds the current month balance.
- Credit slider: maximum **60'** (beyond that a permit is needed, so it's out of scope).
  Stops at the month's positive balance and at 29'.
- Debt slider: stops at the month's negative balance, at 29' and at the recovery that reaches
  19:50. A slider stop holds until forced 4' past it.
- Excess minutes after **19:50** are not counted → warning.
- If the last punch is an exit, result is provisional: re-entry assumed "now",
  refreshed every 30 s.

Reference cases (all in `test/exit_time_test.dart`): E 7:50 → 15:12; E 7:30 → 15:12;
E 8:15 → 15:37; E 7:50 U 13:00 E 13:30 → 15:42; E 8:15 credit 20' → 15:17;
E 8:15 debt 29' → 16:06; E 8:15 credit 40' → 14:57 + warning.

## Porting notes (desktop → mobile)

Desktop sources to compare against (the Python repo is cloned at `../CartellinoUniSA`):

| Mobile | Desktop |
|--------|---------|
| `domain/cartellino.dart` | `cartellino/cartellino.py` (`_from_raw`, `get_date_from_string`, `extract_codice`) |
| `domain/ore.dart` | `cartellino/ore_helpers.py` |
| `domain/riposi.dart` | `cartellino/ore_eccedenti.py`, `model/riposo_compensativo.py`, `_categorizza_riposo` in `cartellino/tui/screens/dashboard.py` |
| `domain/dashboard.dart` | `cartellino/tui/screens/dashboard.py` |
| `assets/js/extract_cartellino.js` | `get.py` (`ottieni_cartellino`) |
| `domain/settings.dart` | `cartellino/user_config.py`, `cartellino/config.py` |

Keep the riposi grouping **identical** to the desktop app so both show the same numbers,
including its quirks: a day that exactly completes a riposo adds a 0-minute entry to it
when the next day arrives; a single day larger than the remainder overfills the next
riposo (no multi-riposo split).

Known desktop bug, intentionally **not** replicated: partial exclusions in
`ore_eccedenti.py::_elabora` compare a datetime column with a `dd-mm-YYYY` string; pandas
parses it month-first, so for day ≤ 12 day and month are swapped (verified with pandas
3.0.5: `"03-04-2025"` matches 4 March). The mobile app matches by calendar day. Fix the
desktop app too, otherwise the two apps diverge on those dates.

Not ported: `riposi_usati.txt` fallback (mobile always uses SRC after the min date).

## UI / theme

Palette from www.unisa.it computed styles: primary `#2F577F`, primary light `#325D88`,
primary dark/link `#244363`, secondary link `#377193`, accent `#0D7FA4` (≈4.6:1 on white,
buttons/icons only), text `#212121`, surfaces `#FFFFFF`/`#F7F7F7`, footer `#333333`.
Font: Titillium Web (TODO: bundle it). The Department palette (`#94190a`) is NOT used:
the app is for all UniSA staff.

## Roadmap / TODO

- [ ] Finish the spike checklist above (session lifetime, Android, another employee).
- [ ] Local notification at exit time (e.g. `flutter_local_notifications`).
- [ ] Edit dashboard codes in settings.
- [ ] Bundle Titillium Web.
- [ ] Widget tests for the exit-time screen.
- [ ] Distribution: TestFlight (Apple Developer account already available) and signed
      APK on GitHub Releases / Play Store.
