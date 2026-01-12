# SDL-Swift-Playground

An experimental project exploring SDL3 integration with Swift.

## Overview

This is a sandbox for experimenting with SDL3 (Simple DirectMedia Layer 3) in Swift. The goal is to explore how SDL3 APIs can be used from Swift via Swift Package Manager, and to prototype various graphics and input handling techniques.

**Note:** This is an experimental project for learning and prototyping purposes.

## Requirements

- macOS 13.0+
- iOS 14.0+ (for iOS builds)
- Swift 6.0+
- Xcode Command Line Tools

## Project Structure

```
SDL-Swift-Playground/
├── Package.swift           # Swift Package Manager configuration
├── sdl-version.txt         # SDL3 build version specification
├── Sources/
│   ├── SDL-Swift-Playground/  # Main application
│   │   └── main.swift
│   └── CSDL3/                  # SDL3 C bindings
│       ├── include/
│       │   ├── module.modulemap
│       │   └── shim.h
│       └── shim.c
├── Dependencies/
│   └── SDL3.xcframework    # Pre-built SDL3 library
└── scripts/
    └── build-xcframework.sh  # SDL3 build script
```

## Build and Run

```bash
swift build
swift run
```

## Demo Application

The current demo implements the following features:

- SDL3 initialization and window creation
- GPU renderer-based drawing
- Multiple colorful bouncing rectangles animation
- Add new rectangles by mouse click
- Keyboard input handling (ESC to quit)
- Window resize support
- FPS display

### Controls

- **Click**: Add a new rectangle
- **ESC**: Quit application
- **Close window**: Quit application

## License

SDL3 is distributed under the zlib license.
