Spall Native Community Edition
==============================

**Fast, portable native profiling.**

Spall Native Community Edition is the community-maintained continuation of the original **Spall Native** profiler created by Colin Davidson.

Originally released as a commercial product, Spall was later officially open-sourced so the community could continue maintaining and improving it.

* * *

Project Goals
-------------

*   Continued maintenance
*   Bug fixes
*   Toolchain compatibility updates
*   Platform support improvements
*   Performance refinements

Project Origins
---------------

Original project by **Colin Davidson**.

This repository preserves the original vision of Spall: fast, low-overhead, portable profiling for native applications.

Contact & Community
-------------------

### Original Project

*   [Website](https://gravitymoth.com/spall)
*   [Legacy Releases](https://gravitymoth.itch.io/spall)
*   [Issue Tracker](https://github.com/colrdavidson/spall-native-issues/issues)

### Original Community

*   [Handmade Network Discord](https://discord.gg/hmn)
*   [Spall Discord](https://discord.gg/MkAPHSWPZZ)

### Contact HyperSonic Games
*   [HyperSonic Games Discord Server](https://discord.gg/AFD9KwPCXk)


Profiling Modes
---------------

### Manual Tracing

`spall.h`

Add begin/end instrumentation to selected functions for highly precise profiling.

### Auto Tracing

`spall.h + examples/auto_tracing`

Profiles every function automatically using compiler instrumentation.

Auto-tracing officially supports Clang and GCC. MSVC auto-instrumentation remains unreliable.

### Native Auto Tracing

`spall_native_auto.h + examples/native_auto_tracing`

High-performance tracing with symbol extraction from binaries using PDB and DWARF debug information.

Runtime Dependencies
--------------------

### Ubuntu

sudo apt install libc++abi-14-dev

### macOS

brew install sdl2

Usage
-----

UI tutorial: [Spall Web Tutorial](https://gravitymoth.com/spall/spall-web.html)

### C / C++

See the `examples/` directory.

### Odin

import "core:prof/spall"

Attribution
-----------

*   [Odin](https://github.com/odin-lang/Odin)
*   [SDL2](https://github.com/libsdl-org/SDL)
*   [FontAwesome](https://fontawesome.com/)
*   [FiraCode](https://github.com/tonsky/FiraCode)

`demo_trace.json` courtesy of NeGate.

Acknowledgments
---------------

Thanks to all contributors, testers, maintainers, and community members who helped shape Spall.

License
-------

MIT License

Copyright © 2023 Colin Davidson  
Copyright © 2026 HyperSonic-Games & Community