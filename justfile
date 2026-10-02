# Champz iOS — task runner. Install just: brew install just

scheme := env_var_or_default("SCHEME", "Staging")
simulator := env_var_or_default("SIMULATOR", "iPhone 16")
destination := "platform=iOS Simulator,name=" + simulator

default:
    @just --list

# Install tools and generate the Xcode project.
setup:
    brew bundle --no-upgrade
    test -f Config/Secrets.xcconfig || cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
    just project

# Regenerate Champz.xcodeproj from project.yml (the .xcodeproj is git-ignored).
project:
    xcodegen generate

# Build the app for the simulator.
build: project
    xcodebuild -project Champz.xcodeproj -scheme {{scheme}} -destination '{{destination}}' build | xcbeautify || xcodebuild -project Champz.xcodeproj -scheme {{scheme}} -destination '{{destination}}' build

# Run every test: the app bundle and all ChampzKit test targets (they are in the scheme).
# Always go through the app project — running xcodebuild inside ChampzKit/ leaves a .swiftpm
# workspace behind that makes Xcode report "Missing package product".
test: project
    xcodebuild -project Champz.xcodeproj -scheme {{scheme}} -destination '{{destination}}' test

lint:
    swiftlint lint --strict
    swiftformat --lint .

fix:
    swiftformat .
    swiftlint lint --fix

# Fail if any endpoint the app uses changed in contracts/openapi.yaml.
contract-check:
    python3 scripts/contract_check.py

# Accept the current contract for the endpoints the app uses.
contract-accept:
    python3 scripts/contract_check.py --update

# Regenerate L10n.swift + Localizable.xcstrings from the Flutter strings (one-off seed; edit the catalog afterwards).
seed-strings:
    python3 scripts/seed_strings.py ../champz-mobile/lib/localization

# Build and launch on the simulator.
run: build
    xcrun simctl boot "{{simulator}}" 2>/dev/null || true
    open -a Simulator
