# Champz iOS

Native SwiftUI customer app (iOS 17+, Swift 6). Architecture, conventions and every
decision: the **Champz iOS — Architecture & Engineering Guide** (Claude doc) and
`../champz-mobile/docs/SPEC_IOS_NATIVE.md`.

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
| `just contract-check` | Fails if an endpoint in `contracts/used-endpoints.txt` changed in `openapi.yaml` |
| `just contract-accept` | Accept the current contract after updating DTOs and fixtures |

## Layout

```
App/            @main, AppContainer (composition root), RootView, AppDestinations
ChampzKit/      Core · Domain · Data · DesignSystem · Localization · Navigation · Payments (+ Tests)
Config/         Local / Staging / Production .xcconfig; Secrets.xcconfig is git-ignored
contracts/      openapi.yaml (reference copy) · used-endpoints.txt · lock file
scripts/        contract_check.py · seed_strings.py
```

## Rules the linter enforces

- Colors only via `Color.ds.<token>`; hex values live only in `Palette.swift`.
- User-facing strings only via `L10n.<Section>.<key>`; add translations in `Localizable.xcstrings`.
- Fonts only via `AppFont.<style>`; spacing via `Spacing`, radii via `Radius`, icons via `AppIcon`.
- Features never `import Data`; only `App` wires repository implementations.
- Money is `Decimal`/`Money`, never `Double`.
