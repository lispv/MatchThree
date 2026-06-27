# Match Three

macOS-native match-3 puzzle game built with SwiftUI. Pure local, no backend.

An iOS baseline lives at [MatchThree-iOS](https://github.com/lispv/MatchThree-iOS).

## Features

- 8×8 grid, 8 gem types (4 initially, unlock as you score)
- Click-to-select, adjacent swap, chain reactions
- **3 themes**: Skynet (dark/red), Sakura (pink petals), Seaside (ocean bubbles)
- **2 modes**: Casual (unlimited), Ranked (5 failed swaps = loss, 10s countdown)
- **2 match effects**: Cruise missile, Block shatter
- Particles, screen shake, neon glow
- Deadlock detection + auto reshuffle

## Run

### Command line (no Xcode needed)

```bash
swiftc -parse-as-library -o build/MatchThree MatchThree.swift \
  -framework SwiftUI \
  -sdk $(xcrun --show-sdk-path --sdk macosx)

open build/MatchThree
```

### Xcode project (optional)

```bash
xcodegen generate     # requires XcodeGen
open MatchThree.xcodeproj
```

Requires macOS 14+ with Xcode Command Line Tools.

## Project structure

```
MatchThree.swift    — single-file game source (all logic + UI)
project.yml         — XcodeGen project spec (macOS target)
```

## License

MIT
