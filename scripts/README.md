# Scripts

This directory contains build scripts for the project.

## build-xcframework.sh

A script that builds XCFrameworks for C libraries from source.

### Features

- Builds libraries defined in `dependencies.yml`
- Supports multiple libraries with dependency resolution
- Builds static library for macOS (Universal: arm64 + x86_64)
- Builds static library for iOS Device (arm64)
- Builds static library for iOS Simulator (arm64 + x86_64)
- Generates XCFrameworks in the `Dependencies/` directory

### Prerequisites

- Xcode Command Line Tools
- CMake
- Git

### Usage

```bash
# Build a specific library
./scripts/build-xcframework.sh SDL3

# Build multiple libraries
./scripts/build-xcframework.sh SDL3 SDL3_ttf

# Build all libraries defined in dependencies.yml
./scripts/build-xcframework.sh --all

# Force rebuild even if version matches
./scripts/build-xcframework.sh --force SDL3

# List available libraries
./scripts/build-xcframework.sh --list

# Show help
./scripts/build-xcframework.sh --help
```

### Version Tracking

The build script tracks which version was built by storing metadata in `.build-info` files within each XCFramework. When you run the script:

- If the library is already built at the same version, it will be **skipped**
- Use `--force` to rebuild even if the version matches
- Changing the `tag` in `dependencies.yml` will trigger a rebuild

### dependencies.yml Syntax

Library versions and metadata are managed in `dependencies.yml` at the project root.

#### Example

```yaml
libraries:
  SDL3:
    repo: https://github.com/libsdl-org/SDL.git
    tag: release-3.4.0

  SDL3_ttf:
    repo: https://github.com/libsdl-org/SDL_ttf.git
    tag: release-3.2.2
    depends_on: [SDL3]

  # Custom include path example
  # some_lib:
  #   repo: https://github.com/example/some_lib.git
  #   tag: v1.0.0
  #   include_path: src/headers
```

#### Field Reference

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `repo` | Yes | - | Git repository URL |
| `tag` | Yes | - | Git tag to checkout |
| `depends_on` | No | `[]` | List of dependent libraries (for build order) |
| `include_path` | No | `include` | Path to header files relative to repo root |
| `lib_name` | No | library name | Output file name (lib{name}.a) |
| `header` | No | auto-detect | Header path for C bindings (e.g., `SDL3/SDL.h`) |
| `cmake_options` | No | `[]` | List of CMake options (e.g., `-DSDL_SHARED=OFF`) |

#### CMake Options Example

```yaml
libraries:
  SDL3:
    repo: https://github.com/libsdl-org/SDL.git
    tag: release-3.4.0
    cmake_options:
      - -DSDL_SHARED=OFF
      - -DSDL_STATIC=ON
      - -DSDL_TEST=OFF

  SDL3_ttf:
    repo: https://github.com/libsdl-org/SDL_ttf.git
    tag: release-3.2.2
    depends_on: [SDL3]
    cmake_options:
      - -DBUILD_SHARED_LIBS=OFF
      - -DSDLTTF_VENDORED=ON
      - -DSDLTTF_HARFBUZZ=ON
```

#### Version Management

- Use **fixed versions** (Git tags) only
- Version ranges (e.g., `>= 3.2.0`) are not supported
- Version conflicts are detected by CMake's `find_package` at build time

#### Submodule Support

If a library repository contains `.gitmodules`, the build script automatically initializes submodules after checking out the tag. This is necessary for libraries like SDL3_ttf that use vendored dependencies (freetype, harfbuzz, etc.).

### Build Flow

1. Parse `dependencies.yml` for library metadata
2. Resolve build order based on `depends_on` dependencies
3. For each library:
   - Check if already built at the same version (skip if so, unless `--force`)
   - Clone source from Git repository
   - Checkout specified tag
   - Initialize submodules if `.gitmodules` exists
   - Build for each platform using CMake:
     - macOS (Universal: arm64 + x86_64)
     - iOS Device (arm64)
     - iOS Simulator (arm64)
     - iOS Simulator (x86_64)
   - Create universal binary for iOS Simulator using `lipo`
   - Generate XCFramework using `xcodebuild -create-xcframework`
   - Save build info (`.build-info`)
   - Clean up build artifacts
4. Clean up vendor and install directories

### Output

- `Dependencies/{LIB_NAME}.xcframework` - XCFramework referenced by Swift Package Manager

### Adding a New Library

1. Add entry to `dependencies.yml`:
   ```yaml
   libraries:
     NewLib:
       repo: https://github.com/example/newlib.git
       tag: v1.0.0
       depends_on: [SDL3]  # if it depends on SDL3
   ```

2. Add targets to `Package.swift`:
   ```swift
   .binaryTarget(name: "NewLib", path: "Dependencies/NewLib.xcframework"),
   .target(name: "CNewLib", dependencies: ["NewLib", "CSDL3"], ...)
   ```

3. Build:
   ```bash
   ./scripts/build-xcframework.sh NewLib
   ```

### C Bindings Auto-Generation

The build script automatically generates C bindings (`Sources/C{LibName}/`) when they don't exist. The generated files include:

- `include/shim.h` - Includes the library header
- `include/module.modulemap` - Module definition for Swift
- `shim.c` - Empty placeholder for SPM

#### Header Path Detection

For SDL libraries, the header path is automatically determined:

| Library | Header Path |
|---------|-------------|
| `SDL3` | `SDL3/SDL.h` |
| `SDL3_ttf` | `SDL3_ttf/SDL_ttf.h` |
| `SDL3_image` | `SDL3_image/SDL_image.h` |
| Other | `{LibName}/{LibName}.h` |

For non-standard header paths, use the `header` field in `dependencies.yml`:

```yaml
libraries:
  CustomLib:
    repo: https://github.com/example/custom.git
    tag: v1.0.0
    header: custom/main.h  # Custom header path
```
