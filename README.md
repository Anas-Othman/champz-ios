# Champz iOS

Native SwiftUI customer app (iOS 17+, Swift 6). Architecture and conventions:
the **Champz iOS — Architecture & Engineering Guide** (Claude doc) and
`../champz-mobile/docs/SPEC_IOS_NATIVE.md`.

General rule: **clean, but humanized, clear and simple.** One view + one view model per
screen, one model struct per API type, repository protocols with fakes for tests, and no
infrastructure before a real need.

## First run

```sh
brew install just
just setup          # installs xcodegen/swiftlint/swiftformat, creates Config/Secrets.xcconfig, generates the .xcodeproj
open Champz.xcodeproj
```

Pick the **Staging** scheme. The `.xcodeproj` is generated from `project.yml` and git-ignored;
run `just project` after changing it.

## Everyday verbs

| Verb | Does |
| --- | --- |
| `just build` / `just run` | Build (and launch) on the simulator |
| `just test` | App + ChampzKit tests |
| `just lint` / `just fix` | SwiftLint (architecture rules as errors) + SwiftFormat |

## Layout

```
App/                    @main, AppConfig, AppContainer (wires everything), RootView, AppDestinations
ChampzKit/Sources/
  Core/                 AppError, Loadable, Log, Decoding/, Networking/, Session/
  Models/               one struct per API type: IDs, Money, Paging, Auth, PaymentPurpose
  Repositories/         per area: protocol + Live implementation + endpoints (AuthAPI, …)
  DesignSystem/         Palette (only hex values), ColorTokens, AppFont, Spacing, AppIcon, components
  Localization/         L10n.swift + Localizable.xcstrings (every user-facing string)
  Navigation/           AppRoute, AppRouter, DeepLink
  Features/<Name>/      views + view models for one area
ChampzKit/Tests/ChampzKitTests/   tests + JSON fixtures
Config/                 Local / Staging / Production .xcconfig; Secrets.xcconfig is git-ignored
```

Adding a screen = one view, one view model, an endpoint function in the area's `*API.swift`,
and a model struct if the response is new. The API contract to read from:
`../champz-mobile/contracts/openapi.yaml`.

## Rules the linter enforces

- Colors only via `Color.ds.<token>`; hex values live only in `Palette.swift`.
- User-facing strings only via `L10n.<Section>.<key>`; translations in `Localizable.xcstrings`.
- Fonts via `AppFont`, spacing via `Spacing`, radii via `Radius`, icons via `AppIcon`.
- Features depend on repository protocols; only `App` names the `Live…` implementations.
- Money is `Decimal`/`Money`, never `Double`.
