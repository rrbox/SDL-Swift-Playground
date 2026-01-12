# Scripts

This directory contains build scripts for the project.

## build-xcframework.sh

A script that builds SDL3 from source and generates an XCFramework.

### Features

- Builds SDL3 using the version tag specified in `sdl-version.txt`
- Builds static library for macOS (Universal: arm64 + x86_64)
- Builds static library for iOS Device (arm64)
- Builds static library for iOS Simulator (arm64 + x86_64)
- Generates `SDL3.xcframework` in the `Dependencies/` directory

### Prerequisites

- Xcode Command Line Tools
- CMake
- Git

### Usage

```bash
./scripts/build-xcframework.sh
```

### Build Flow

1. Read version tag from `sdl-version.txt`
2. Clone SDL3 source code from GitHub (into `Vendor/SDL/`)
3. Checkout the specified tag
4. Build for each platform using CMake
5. Create universal binary for iOS Simulator using `lipo`
6. Generate XCFramework using `xcodebuild -create-xcframework`
7. Clean up build artifacts (`Vendor/`, `.build-sdl/`)

### Output

- `Dependencies/SDL3.xcframework` - XCFramework referenced by Swift Package Manager
