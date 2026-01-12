#!/bin/bash
set -e

cd "$(dirname "$0")/.."
PROJECT_ROOT="$(pwd)"

# バージョンファイルからタグを読み込む
VERSION_FILE="$PROJECT_ROOT/sdl-version.txt"
if [[ ! -f "$VERSION_FILE" ]]; then
    echo "Error: $VERSION_FILE not found"
    exit 1
fi

SDL_TAG=$(cat "$VERSION_FILE" | tr -d '[:space:]')
if [[ -z "$SDL_TAG" ]]; then
    echo "Error: SDL tag is empty in $VERSION_FILE"
    exit 1
fi

SDL_SOURCE="$PROJECT_ROOT/Vendor/SDL"
BUILD_DIR="$PROJECT_ROOT/.build-sdl"
OUTPUT_DIR="$PROJECT_ROOT/Dependencies"

echo "Project root: $PROJECT_ROOT"
echo "SDL source: $SDL_SOURCE"
echo "SDL version tag: $SDL_TAG"

# SDLソースが存在しない場合は自動取得
if [[ ! -d "$SDL_SOURCE/.git" ]]; then
    echo ""
    echo "=========================================="
    echo "SDL source not found. Cloning..."
    echo "=========================================="
    mkdir -p "$(dirname "$SDL_SOURCE")"
    git clone https://github.com/libsdl-org/SDL.git "$SDL_SOURCE"
fi

# 明示的にタグをチェックアウト
echo ""
echo "=========================================="
echo "Checking out tag: $SDL_TAG"
echo "=========================================="
cd "$SDL_SOURCE"
git fetch --tags
git switch --detach "refs/tags/$SDL_TAG"
cd "$PROJECT_ROOT"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 共通CMakeオプション
CMAKE_COMMON_OPTIONS=(
    -DSDL_SHARED=OFF
    -DSDL_STATIC=ON
    -DSDL_TEST=OFF
    -DCMAKE_BUILD_TYPE=Release
)

# --- macOS (Universal: arm64 + x86_64) ---
echo ""
echo "=========================================="
echo "Building for macOS (Universal)..."
echo "=========================================="
cmake -S "$SDL_SOURCE" -B "$BUILD_DIR/macos" \
    "${CMAKE_COMMON_OPTIONS[@]}" \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0

cmake --build "$BUILD_DIR/macos" --config Release --parallel

# --- iOS Device (arm64) ---
echo ""
echo "=========================================="
echo "Building for iOS Device (arm64)..."
echo "=========================================="
cmake -S "$SDL_SOURCE" -B "$BUILD_DIR/ios-device" \
    "${CMAKE_COMMON_OPTIONS[@]}" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0

cmake --build "$BUILD_DIR/ios-device" --config Release --parallel

# --- iOS Simulator (arm64) ---
echo ""
echo "=========================================="
echo "Building for iOS Simulator (arm64)..."
echo "=========================================="
cmake -S "$SDL_SOURCE" -B "$BUILD_DIR/ios-sim-arm64" \
    "${CMAKE_COMMON_OPTIONS[@]}" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0

cmake --build "$BUILD_DIR/ios-sim-arm64" --config Release --parallel

# --- iOS Simulator (x86_64) ---
echo ""
echo "=========================================="
echo "Building for iOS Simulator (x86_64)..."
echo "=========================================="
cmake -S "$SDL_SOURCE" -B "$BUILD_DIR/ios-sim-x86_64" \
    "${CMAKE_COMMON_OPTIONS[@]}" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES=x86_64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0

cmake --build "$BUILD_DIR/ios-sim-x86_64" --config Release --parallel

# --- iOS Simulator Universal (lipo) ---
echo ""
echo "=========================================="
echo "Creating iOS Simulator universal library..."
echo "=========================================="
mkdir -p "$BUILD_DIR/ios-sim-universal"
lipo -create \
    "$BUILD_DIR/ios-sim-arm64/libSDL3.a" \
    "$BUILD_DIR/ios-sim-x86_64/libSDL3.a" \
    -output "$BUILD_DIR/ios-sim-universal/libSDL3.a"

echo "Verifying architectures..."
lipo -info "$BUILD_DIR/macos/libSDL3.a"
lipo -info "$BUILD_DIR/ios-device/libSDL3.a"
lipo -info "$BUILD_DIR/ios-sim-universal/libSDL3.a"

# --- XCFramework作成 ---
echo ""
echo "=========================================="
echo "Creating XCFramework..."
echo "=========================================="
rm -rf "$OUTPUT_DIR/SDL3.xcframework"

xcodebuild -create-xcframework \
    -library "$BUILD_DIR/macos/libSDL3.a" \
    -headers "$SDL_SOURCE/include" \
    -library "$BUILD_DIR/ios-device/libSDL3.a" \
    -headers "$SDL_SOURCE/include" \
    -library "$BUILD_DIR/ios-sim-universal/libSDL3.a" \
    -headers "$SDL_SOURCE/include" \
    -output "$OUTPUT_DIR/SDL3.xcframework"

echo ""
echo "=========================================="
echo "Done!"
echo "=========================================="
echo "XCFramework created at: $OUTPUT_DIR/SDL3.xcframework"
ls -la "$OUTPUT_DIR/SDL3.xcframework"
