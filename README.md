# SpeedCrunch for iOS (experimental port)

An experimental iPhone/iPad port of [SpeedCrunch](https://github.com/heldercorreia/speedcrunch).
The calculation engine is SpeedCrunch's own `math/` and `core/` code, unchanged in its logic;
the user interface is new and written in SwiftUI.

*Versión en español: [README.es.md](README.es.md).*

## Approach

```
SwiftUI app (ios/Sources)          ← new: touch UI, keypad, history, settings
        │  Swift ⇄ C, JSON strings
C bridge (engine/include/speedcrunch_bridge.h)
        │
SpeedCrunch math/ + core/ (upstream/) on Qt Core only
```

- **Engine.** `upstream/math` and `upstream/core` are copied from upstream (commit in
  `upstream/UPSTREAM_COMMIT`) and built as a static library against **Qt Core only** — no Widgets,
  no Qt Help, no Network. Qt Core runs fine on iOS.
- **One upstream change:** `core/settings.cpp` uses `QCoreApplication` instead of `QApplication` and
  skips the `QFont` default when `SPEEDCRUNCH_HEADLESS` is defined. Nothing else in math/core is touched.
- **Four GUI helpers reused:** `gui/resultlineformatutils.h`, `displayformatutils.*` and
  `simplifiedexpressionutils.h` only depend on Qt Core, so results are formatted exactly like the
  desktop (`√(2)`, `x²`, `10 [m] → [ft]`, …).
- **C bridge.** `speedcrunch_bridge.cpp` mirrors the desktop flow: Enter follows
  `MainWindow::evaluateEditorExpression`, live preview follows `Editor::autoCalc` (`evalNoAssign`,
  no `ans` update). History, variables and user functions are persisted with SpeedCrunch's own
  `Session::serialize` / `deSerialize`.
- **SwiftUI UI.** History list (tap to reuse, long-press to copy), live result line, a calculator
  keypad with a 2nd layer (or the system keyboard with a symbol bar), searchable built-in functions
  and CODATA constants, user variables/functions, and the Duskfox/Dawnfox colours and icon.

### Settings exposed on iOS

The engine uses the upstream `Settings` object as is. The iOS UI exposes the subset that makes sense
on a phone: angle unit, result format (general, fixed, scientific, engineering, rational,
sexagesimal, hex, octal, binary), precision, complex numbers, decimal separator and digit grouping.
Desktop-only settings (docks, fonts, colour-scheme editor, custom keypad, multiple result lines,
window behaviour) are not exposed yet.

## Build and run

Requirements: a Mac with Xcode and an Apple ID (a free account works; the app then has to be
re-installed from Xcode every 7 days).

```bash
scripts/setup-ios.sh            # installs Qt for iOS into .tools/ (~1 GB, first time), generates and opens the Xcode project
scripts/setup-ios.sh --check    # same, plus an unsigned build for iPhone as a sanity check
```

In Xcode: target **SpeedCrunch** → *Signing & Capabilities* → choose your team, change the bundle
identifier if needed (`BUNDLE_ID=... scripts/setup-ios.sh`), connect the iPhone and press Run.
The script's messages are in Spanish.

The Xcode project is generated in `~/Library/Developer/SpeedCrunch-iOS/build`, outside
Documents/Desktop: when those folders sync with iCloud, macOS adds extended attributes that make
`codesign` fail ("resource fork, Finder information, or similar detritus not allowed").

## Testing the engine without a device (Linux or macOS)

```bash
cmake -S engine -B build && cmake --build build
./build/sc-cli "sqrt(2)" "x = 5" "x^2"
python3 engine/tests/smoke_test.py build/sc-cli
```

Upstream's `testhmath` and `testevaluator` pass on the vendored commit.

## License

GNU General Public License v2 or later, like SpeedCrunch. See `LICENSE`.
