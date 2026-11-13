# Birimm

**Birimm** is a calculator-first multi-currency app for Windows and Android,
built with Flutter. It converts every amount through one USD reference and adds
the results in a single, independently selected output currency.

The interface is deliberately quiet: a near-black charcoal palette with a warm
cream accent by default, an optional light theme, a compact desktop rail, and a
bottom navigation bar on phones. The app has five destinations: **Calculate**,
**Markets**, **Favorites**, **History**, and **Settings**. English and Turkish
are supported.

Birimm never invents prices or rates. When a provider is unavailable it keeps
the last usable snapshot, labels it **Cached**, and shows the timestamp. When
there is no usable snapshot it shows an explicit **Unavailable** state instead
of a placeholder rate. Charts are drawn from real provider history points.

> The Dart package still uses the internal name `calc2`, and application IDs
> such as `com.example.calc2` are intentionally unchanged for compatibility. All
> user-facing branding is **Birimm**.

## Features

### Calculate

- Add any number of rows; each row has its own amount and currency.
- Search the fiat and crypto currency picker and select an independent output
  currency.
- Convert every row through USD before adding. Amounts in different currencies
  are never added directly.
- Accept `.` or `,` decimals, a leading `+` or `-`, and negative finite totals.
- Skip empty rows. Flag malformed amounts, amounts above `1e15`, missing rates,
  and arithmetic overflow without guessing a value.
- Show the total, its approximate USD value, per-row conversions, and live or
  cached rate status.
- Keep the output currency and current rows while navigating between
  destinations.
- Save a valid calculation to History with its inputs, output currency, result,
  rates, provider metadata, and timestamp.

A fresh install starts with `100 USD` and an output currency of `EUR`.

### Markets

- Browse the CoinGecko market overview without a fixed asset filter.
- Load 100 assets at a time, up to five pages (500 assets), with an explicit
  **Load more** action.
- Search the currently loaded assets and filter by **All**, **Popular** (ranks
  1–25), **Top 100** (ranks 1–100), **Gainers**, **Losers**, or **Favorites**.
- Sort by market cap, price, 24-hour change, or name, in either direction.
- Show prices in the selected output fiat currency when its rate is available;
  otherwise show a clearly labelled USD fallback.
- Open an asset sheet with live price, 24-hour change, market cap, volume, and
  real 24-hour, 7-day, and 30-day charts.
- Add any listed fiat or crypto asset to the calculator, set it as the output
  currency, or add it to Favorites.
- View a dedicated fiat market tab with an independently selectable reference
  currency.
- Keep the previous snapshot and show an error if a refresh fails. Charts also
  use a per-asset, per-range cache.

### Favorites

- Favorites contain only real fiat currencies and crypto assets, not saved
  calculations.
- Show current rates/prices, 24-hour crypto changes where available, and the
  selected output-currency view.
- Open the crypto asset detail and chart, add an asset to the calculator, set it
  as the output currency, or remove it from Favorites.
- Show a compact empty state with a route to Markets.

### History

- Save up to 100 calculations, newest first.
- Each entry stores its rows, output currency, result in both output currency
  and USD, relevant units-per-USD rates, timestamps, and provider metadata.
- Browse the stored summary, open a detail view, compare the **stored result**
  with a **current-rate recalculation**, and distinguish a live saved snapshot
  from one that used cached or unavailable rates.
- Restore an entry to the calculator, delete an individual entry from its detail
  view, or clear all history after confirmation. The stored result never changes
  when rates move.
- Invalid or empty calculations cannot be saved.

### Settings

- Choose **Dark** (default), **Light**, or **System** appearance.
- Switch the complete interface between **English** and **Turkish**.
- Change the output currency.
- Inspect fiat, crypto, and market provider status and refresh all data.
- See local storage usage, favorites/history counts, provider attribution links,
  and the app version.
- Theme, language, output currency, favorites, history, and caches persist across
  restarts.

## Conversion semantics

All rates are stored as **units of currency per 1 USD**. For a row:

```text
USD value       = row amount / unitsPerUsd[row currency]
Output value    = USD value × unitsPerUsd[output currency]
Total output    = sum of all USD values × unitsPerUsd[output currency]
```

This means mixed rows always pass through one shared reference:

```text
100 USD + 50 EUR + 250 TRY
```

is calculated as three separate USD conversions, added in USD, and then
converted once to the selected output currency. Raw amounts from different
currencies are never summed.

If a rate is missing, the affected row is flagged and the total is withheld
until the rate is available. Zero is a valid amount, and a finite negative
result is valid and can be saved. Empty rows are ignored.

Market quotes are fetched in USD. Display conversion uses the selected output
currency's fiat rate when possible. Chart prices remain USD and are labelled as
such.

History keeps stored results separate from any current-rate recalculation. A
stored history result is an intentional snapshot, not an invitation to silently
rewrite past data.

## Data sources, refresh, and failure behavior

### Fiat rates

- Endpoint: `https://open.er-api.com/v6/latest/USD`
- No API key is required.
- The app verifies a successful response, the USD base, numeric positive rates,
  and the provider timestamp.
- The provider updates roughly once per day. Birimm refreshes a stale snapshot
  on launch and refreshes rates hourly while running.

### Crypto rates used by the calculator

- Endpoint: `https://api.coingecko.com/api/v3/simple/price`
- The curated calculator catalog contains 18 crypto assets.
- Prices are converted to units-per-USD before they enter the shared converter.
- Market quotes supplement the calculator catalog for assets opened from
  Markets and Favorites.

### Crypto markets and charts

- Overview: `https://api.coingecko.com/api/v3/coins/markets`
- History: `https://api.coingecko.com/api/v3/coins/{id}/market_chart`
- The overview is paged and shows current USD price, 24-hour change, market cap,
  volume, and the provider update time.
- Chart ranges are 1 day, 7 days, and 30 days, rendered by a custom painter from
  provider points.
- Market data refreshes on launch when older than five minutes, every five
  minutes while running, and on manual refresh. Refreshing reloads every page
  already loaded by the user.

### CoinGecko API key

The keyless public API works but is IP rate-limited. A free CoinGecko Demo API
key can be supplied at build or run time:

```powershell
C:\flutter\bin\flutter.bat run -d windows --dart-define=COINGECKO_API_KEY=your_demo_key
```

When present, the key is sent as the `x-cg-demo-api-key` header for crypto rate,
market, and chart requests.

### Failure and cache policy

- Fiat, crypto, market, and chart caches are restored at startup.
- Fiat and crypto providers are fetched independently. One provider can fail
  while the other updates.
- A partial snapshot is never presented as fully live.
- A failed market refresh keeps the previous snapshot visible and reports the
  error.
- A failed chart request keeps a cached chart when one exists; otherwise the UI
  shows an unavailable state.
- Malformed local data is ignored safely. Errors are surfaced in the UI rather
  than silently discarded.
- No missing rate is replaced with a default or fabricated value.

Rates and market data are indicative, may be delayed by their providers, and are
not financial advice.

## Persistence

Storage is local and uses `shared_preferences` with versioned JSON records:

- `app_preferences_v1`: theme, language, and output currency.
- `favorites_v1`: favorite fiat and crypto assets.
- `calculation_history_v1`: up to 100 saved calculations.
- `rates_cache_v1`: last usable fiat/crypto rate snapshot.
- `market_cache_v2`: last usable paged market overview.
- `price_history_v1_{CODE}_{RANGE}`: cached chart points per asset and range.

The preferences reader also understands the old `targetCurrency` key so an
existing output-currency choice survives the redesign. There is no account and
no remote history sync.

## Project structure

```text
lib/
  app.dart                    MaterialApp, theme/locale selection, Provider wiring
  main.dart                   production dependency composition
  l10n/                       typed English/Turkish localization delegate
  logic/                      pure-Dart row conversion and validation
  models/                     currencies, rows, preferences, favorites, history,
                              rates, market data, and cache serialization
  providers/                  CalculatorController and MarketsController
  screens/                    shell, calculator, markets, favorites, history,
                              settings
  services/                   HTTP clients, rate repository, local storage
  theme/                      custom charcoal/cream light and dark themes
  utils/                      formatting, market pricing, errors, external links
  widgets/                    panels, picker, chart, asset sheet, status strips
test/
  l10n/                       locale coverage and formatting
  logic/                      conversion, validation, and overflow behavior
  models/                     cache/history serialization
  providers/                  state transitions, refresh policy, pagination
  services/                   HTTP parsing, fallback, and persistence
  widget_test.dart            end-to-end UI, responsive, and Windows pointer tests
```

The conversion logic is pure Dart and does not depend on Flutter widgets.

## Running and building

This project was developed with Flutter 3.47.7 / Dart 3.13.5. Flutter is
installed at `C:\flutter` in this environment and is not currently on `PATH`.

```powershell
$env:PATH = 'C:\flutter\bin;' + $env:PATH
flutter pub get
flutter run -d windows
```

Release Windows build:

```powershell
flutter build windows --release
# build\windows\x64\runner\Release\calc2.exe
```

Debug Windows build:

```powershell
flutter build windows --debug
# build\windows\x64\runner\Debug\calc2.exe
```

Android requires the Android SDK and accepted licenses:

```powershell
flutter build apk --debug
```

## Quality checks

Run the local checks with:

```powershell
C:\flutter\bin\dart.bat format --output=none --set-exit-if-changed lib test
C:\flutter\bin\flutter.bat analyze --no-pub
C:\flutter\bin\flutter.bat test --no-pub
```

The suite covers mixed-currency arithmetic through USD, decimal and sign
handling, invalid and oversized input, missing rates, overflow, history
snapshots and recalculations, cache serialization, provider failures, market
pagination and charts, localization, navigation, all five destinations, output
currency persistence, favorites, history clearing, dark/light themes, EN/TR,
narrow phones, short landscape phones, wide desktop toolbars, and the Windows
wheel/middle-button scrolling regression.

## Verification status

Verified locally on 2026-10-26:

- `dart format lib test` — 50 files checked, no changes.
- `flutter analyze --no-pub` — **No issues found!**
- `flutter test --no-pub` — **96 tests passed.**
- `flutter build windows --release` — **built successfully**, producing
  `build\windows\x64\runner\Release\calc2.exe`.
- The release app launched with the **Birimm** window title and current Birimm
  title-bar icon.
- All five destinations were opened in the running app. Live fiat rates and
  CoinGecko crypto/market data were observed during the run.
- Dark/light themes and English/Turkish were switched in the running app, and
  both choices survived a full app restart.
- Mouse-wheel scrolling and middle-button drag gestures were exercised on every
  destination without a crash. The automated Windows regression test covers the
  same dedicated-scroll-controller behavior.
- The app was resized to a narrow 640×1000 physical window on a 125% DPI display
  and checked visually; all destinations remain reachable through bottom
  navigation.
- Responsive widget tests pass at 1600×1000, 1280×900, 844×390, 360×760, and
  320×640 logical layouts.
- The Windows `.ico` and Android launcher PNGs were inspected and contain the
  Birimm mark. The Windows runner title and Android application label are
  **Birimm**.

Not verified here:

- No Android APK was built or run because the Android SDK is not installed in
  this environment. Android launcher assets and manifest branding were checked
  statically only.
- iOS, macOS, Linux, and web targets were not built or run in this environment.
- Windows installers, signing, and store packaging were not produced.
- Live API behavior was observed manually; provider availability, latency, and
  rate limits remain outside the app's control.

## Known limitations

- CoinGecko's keyless API is IP rate-limited and can reject requests; a Demo API
  key is recommended for heavier use.
- Fiat rates are provider-updated roughly daily and can lag live markets.
- The calculator catalog has 18 curated crypto assets for direct row entry.
  Markets can browse up to 500 assets through paging, but it is not a complete,
  unbounded exchange listing.
- Calculations use `double` arithmetic with display rounding. Birimm is an
  everyday calculator, not a ledger or settlement system.
- Price charts depend on the provider's available history points and network
  access. They are not generated or interpolated from fake data.

## Attribution

- Fiat rates: [ExchangeRate-API](https://www.exchangerate-api.com/)
- Crypto rates, market data, and charts:
  [CoinGecko](https://www.coingecko.com/)

ExchangeRate-API and CoinGecko are independent third-party services. Birimm is
not affiliated with either provider. Review their terms before redistributing or
commercializing their data.
