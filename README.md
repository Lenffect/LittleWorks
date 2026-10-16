# Little Works

Small, calm Mac apps for a solo freelancer, built in Swift and SwiftUI. A personal learning project, made for own use. Dutch-first (urencriterium, Dutch CSV), with an English interface as the default.

| App | What | Status |
|---|---|---|
| **tikk.** | Menu bar time tracker | In use |
| **moola.** | Money dashboard | Planned (waiting until the existing finance tool has been used for a few weeks) |

Brix was dropped as a separate app: projects now live inside tikk.

## tikk.

A menu bar app. One click on a client starts the timer, another stops it.

- Timer per client, never two at once, with switching without gaps. Entries are split at midnight.
- Recovers after a crash or restart, and asks what to do with time while the Mac slept.
- Overview of all entries (edit, delete, notes), report per period with Excel export, JSON backup and restore, automatic rolling backup.
- Urencriterium bar: progress towards 1,225 hours per year.
- Hourly rate per client, monthly fixed fee per client with the **effective hourly rate** that falls as you add hours.
- **Projects** (optional, off by default, toggle in Settings): per client, hourly or fixed price, estimated hours, progress and effective rate, project choice when starting a timer, per-project report and Excel, warnings at 80% and 100% of the estimate, project status in the overview.
- Reminders ("still working on X?"), launch at login, menu bar display style.
- English (default) and Dutch, switchable in Settings.
- Factory reset at the bottom of Settings.

## Repository

```
Apps/Tikk/                  The app (XcodeGen project.yml, Sources, Resources)
Packages/LittleWorksCore/   Swift package: models, timer engine, totals, project math (no UI, unit tested)
Design/                     Pixel-art mascots, icons and the scripts that generate them
Docs/                       Plan and briefs
```

The engine talks to an `EntryStore` protocol. The app supplies a SwiftData store; tests use an in-memory one.

## Build

Requirements: macOS 14+, Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
cd Apps/Tikk
xcodegen generate
xcodebuild -project Tikk.xcodeproj -scheme Tikk -derivedDataPath build build
open build/Build/Products/Debug/Tikk.app
```

The build is ad-hoc signed and not notarized, so it is for local use only.

## Test

```sh
cd Packages/LittleWorksCore
swift test
```

## Localization

Source strings in the code are Dutch and act as keys. `Apps/Tikk/Resources/en.lproj/Localizable.strings` holds the English translations. When adding a string, add it to both `en.lproj` and `nl.lproj`.

## Plan

See [`Docs/Little_Works_Plan.md`](Docs/Little_Works_Plan.md).
