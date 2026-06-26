# Match Three

macOS-native match-3 puzzle game built with SwiftUI. Pure local, no backend.

## Features

- 8×8 grid, 6 gem types (4 initially, unlock as you score)
- Click-to-select, adjacent swap, chain reactions
- **3 themes**: Skynet (dark/red), Sakura (pink petals), Seaside (ocean bubbles)
- **2 modes**: Casual (unlimited), Ranked (5 failed swaps = loss, 10s countdown)
- **2 match effects**: Cruise missile, Block shatter
- Particles, screen shake, neon glow
- Deadlock detection + auto reshuffle

## Run

```bash
swiftc -parse-as-library -o build/MatchThree MatchThree.swift \
  -framework SwiftUI \
  -sdk $(xcrun --show-sdk-path --sdk macosx)

open build/MatchThree
```

Or use the pre-built app bundle:

```bash
open MatchThree.app
```

Requires macOS with Xcode Command Line Tools. No full Xcode needed.

## Project structure

```
MatchThree.swift    — single-file game source
MatchThree.app/     — app bundle
project.yml         — XcodeGen project spec
```

## License

MIT
