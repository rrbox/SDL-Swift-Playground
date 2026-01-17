# Scripts

This directory contains build scripts for the project.

## build-xcframework.sh

A script that builds SDL3 from source and generates an XCFramework.

### Features

- Builds SDL3 using the version tag specified in `dependencies.yml`
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

### Version Management

Library versions are managed in `dependencies.yml` at the project root:

```yaml
libraries:
  SDL3:
    tag: release-3.4.0
```

To change the SDL3 version, edit the `tag` value and re-run the build script.

### Build Flow

1. Read version tag from `dependencies.yml`
2. Clone SDL3 source code from GitHub (into `Vendor/SDL/`)
3. Checkout the specified tag
4. Build for each platform using CMake
5. Create universal binary for iOS Simulator using `lipo`
6. Generate XCFramework using `xcodebuild -create-xcframework`
7. Clean up build artifacts (`Vendor/`, `.build-sdl/`)

### Output

- `Dependencies/SDL3.xcframework` - XCFramework referenced by Swift Package Manager
