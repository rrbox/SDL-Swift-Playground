#!/bin/bash
set -e

cd "$(dirname "$0")/.."
PROJECT_ROOT="$(pwd)"
DEPS_FILE="$PROJECT_ROOT/dependencies.yml"
VENDOR_DIR="$PROJECT_ROOT/Vendor"
OUTPUT_DIR="$PROJECT_ROOT/Dependencies"

# =============================================================================
# YAML パース関数
# =============================================================================

# ライブラリ一覧を取得
get_library_names() {
    grep -E "^  [A-Za-z0-9_]+:" "$DEPS_FILE" | sed 's/://g' | tr -d ' '
}

# ライブラリのフィールドを取得
get_field() {
    local lib_name=$1
    local field=$2
    local default=$3

    # ライブラリセクションを抽出してフィールドを検索
    # パターン: "  LibName:" から次の "  別LibName:" または EOF まで
    local value=$(sed -n "/^  ${lib_name}:\$/,/^  [A-Za-z0-9_]*:\$/p" "$DEPS_FILE" | grep "^    ${field}:" | head -1 | sed "s/^    ${field}: *//" | tr -d '[:space:]')

    # 配列形式 [item1, item2] の場合はそのまま返す
    if [[ "$value" == "["*"]" ]]; then
        echo "$value"
    elif [[ -n "$value" ]]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# 依存関係を配列として取得
get_depends_on() {
    local lib_name=$1
    local deps=$(get_field "$lib_name" "depends_on" "[]")
    # [SDL3, SDL3_image] -> SDL3 SDL3_image
    echo "$deps" | tr -d '[]' | tr ',' ' ' | tr -d ' '
}

# cmake_options を配列として取得
get_cmake_options() {
    local lib_name=$1
    # ライブラリセクションから cmake_options の行を抽出
    # 形式: "      - -DOPTION=VALUE"
    sed -n "/^  ${lib_name}:\$/,/^  [A-Za-z0-9_]*:\$/p" "$DEPS_FILE" | \
        grep "^      - " | \
        sed 's/^      - //' | \
        tr '\n' ' '
}

# =============================================================================
# バージョン管理関数
# =============================================================================

# ビルド情報を保存
save_build_info() {
    local lib_name=$1
    local tag=$2
    local info_file="$OUTPUT_DIR/${lib_name}.xcframework/.build-info"
    echo "tag=$tag" > "$info_file"
    echo "built_at=$(date -Iseconds)" >> "$info_file"
}

# ビルドが必要か判定（0=必要、1=スキップ可能）
needs_build() {
    local lib_name=$1
    local tag=$2
    local info_file="$OUTPUT_DIR/${lib_name}.xcframework/.build-info"

    # XCFramework が存在しない場合はビルド必要
    if [[ ! -d "$OUTPUT_DIR/${lib_name}.xcframework" ]]; then
        return 0
    fi

    # .build-info が存在しない場合はビルド必要
    if [[ ! -f "$info_file" ]]; then
        return 0
    fi

    # タグを比較
    local existing_tag=$(grep "^tag=" "$info_file" 2>/dev/null | cut -d= -f2)
    if [[ "$existing_tag" == "$tag" ]]; then
        return 1  # スキップ可能
    fi

    return 0  # ビルド必要
}

# =============================================================================
# C バインディング自動生成
# =============================================================================

# ヘッダーパスを取得（指定がなければライブラリ名から推測）
get_header_path() {
    local lib_name=$1
    local header=$(get_field "$lib_name" "header" "")

    if [[ -n "$header" ]]; then
        echo "$header"
    else
        # SDL ファミリーのパターンから推測
        # SDL3 -> SDL3/SDL.h
        # SDL3_ttf -> SDL3_ttf/SDL_ttf.h
        # SDL3_image -> SDL3_image/SDL_image.h
        case "$lib_name" in
            SDL3)
                echo "SDL3/SDL.h"
                ;;
            SDL3_*)
                local suffix="${lib_name#SDL3_}"
                echo "${lib_name}/SDL_${suffix}.h"
                ;;
            *)
                # デフォルト: LibName/LibName.h
                echo "${lib_name}/${lib_name}.h"
                ;;
        esac
    fi
}

# C バインディングを生成
generate_c_bindings() {
    local lib_name=$1
    local module_name="C${lib_name}"
    local bindings_dir="$PROJECT_ROOT/Sources/$module_name"
    local header_path=$(get_header_path "$lib_name")

    # 既に存在する場合はスキップ
    if [[ -d "$bindings_dir" ]]; then
        echo "C bindings already exist: $bindings_dir"
        return 0
    fi

    echo "Generating C bindings: $bindings_dir"

    # ディレクトリ作成
    mkdir -p "$bindings_dir/include"

    # shim.h
    cat > "$bindings_dir/include/shim.h" << EOF
#pragma once
#include <${header_path}>
EOF

    # module.modulemap
    cat > "$bindings_dir/include/module.modulemap" << EOF
module ${module_name} {
    header "shim.h"
    link "${lib_name}"
    export *
}
EOF

    # shim.c (空のプレースホルダー)
    cat > "$bindings_dir/shim.c" << EOF
// Empty placeholder for Swift Package Manager
EOF

    echo "Generated C bindings for $lib_name"
    echo "  Header: $header_path"
    echo "  Module: $module_name"
}

# =============================================================================
# CMake ヘルパー関数
# =============================================================================

# CMake configure をエラーハンドリング付きで実行
run_cmake_configure() {
    local source_dir=$1
    local build_dir=$2
    shift 2
    local cmake_args=("$@")

    if ! cmake -S "$source_dir" -B "$build_dir" "${cmake_args[@]}"; then
        echo ""
        echo "=========================================="
        echo "ERROR: CMake configure failed!"
        echo "=========================================="
        echo ""
        echo "Check your cmake_options in dependencies.yml."
        echo ""
        echo "Available CMake options for this library:"
        cmake -LH -S "$source_dir" -B /tmp/cmake-options-check 2>/dev/null | grep -E "^[A-Z_]+:" | head -40 || true
        rm -rf /tmp/cmake-options-check
        exit 1
    fi
}

# =============================================================================
# ビルド関数
# =============================================================================

build_library() {
    local LIB_NAME=$1

    # メタデータ取得（スキップ判定用に先に取得）
    local TAG=$(get_field "$LIB_NAME" "tag" "")

    # スキップ判定（--force でない場合のみ）
    if [[ "$FORCE_BUILD" != "true" ]] && ! needs_build "$LIB_NAME" "$TAG"; then
        echo ""
        echo "############################################################"
        echo "# Skipping: $LIB_NAME (already at $TAG)"
        echo "############################################################"
        return 0
    fi

    echo ""
    echo "############################################################"
    echo "# Building: $LIB_NAME"
    echo "############################################################"

    # Cバインディングを自動生成（存在しない場合のみ）
    generate_c_bindings "$LIB_NAME"

    # メタデータ取得
    local REPO=$(get_field "$LIB_NAME" "repo" "")
    local INCLUDE_PATH=$(get_field "$LIB_NAME" "include_path" "include")
    local LIB_FILE_NAME=$(get_field "$LIB_NAME" "lib_name" "$LIB_NAME")

    if [[ -z "$REPO" ]]; then
        echo "Error: repo not found for $LIB_NAME" >&2
        exit 1
    fi
    if [[ -z "$TAG" ]]; then
        echo "Error: tag not found for $LIB_NAME" >&2
        exit 1
    fi

    echo "  Repo: $REPO"
    echo "  Tag: $TAG"
    echo "  Include path: $INCLUDE_PATH"
    echo "  Library name: lib${LIB_FILE_NAME}.a"

    local SOURCE_DIR="$VENDOR_DIR/$LIB_NAME"
    local BUILD_DIR="$PROJECT_ROOT/.build-$LIB_NAME"

    # ソース取得
    if [[ ! -d "$SOURCE_DIR/.git" ]]; then
        echo ""
        echo "=========================================="
        echo "Cloning $LIB_NAME..."
        echo "=========================================="
        mkdir -p "$VENDOR_DIR"
        git clone "$REPO" "$SOURCE_DIR"
    fi

    # タグをチェックアウト
    echo ""
    echo "=========================================="
    echo "Checking out tag: $TAG"
    echo "=========================================="
    cd "$SOURCE_DIR"
    git fetch --tags
    git switch --detach "refs/tags/$TAG"

    # サブモジュールを初期化（存在する場合）
    if [[ -f ".gitmodules" ]]; then
        echo ""
        echo "=========================================="
        echo "Initializing submodules..."
        echo "=========================================="
        git submodule update --init --recursive
    fi
    cd "$PROJECT_ROOT"

    # ビルドディレクトリをクリア
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"

    # インストールディレクトリ
    local INSTALL_DIR="$PROJECT_ROOT/.install-$LIB_NAME"
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"

    # 依存ライブラリの確認（インストールディレクトリを参照）
    local DEPS=$(get_depends_on "$LIB_NAME")
    for dep in $DEPS; do
        if [[ -n "$dep" ]]; then
            local DEP_INSTALL="$PROJECT_ROOT/.install-${dep}/macos"
            if [[ ! -d "$DEP_INSTALL" ]]; then
                echo ""
                echo "Dependency $dep install directory not found. Building $dep first..."
                # 依存ライブラリを強制ビルド
                local OLD_FORCE="$FORCE_BUILD"
                FORCE_BUILD=true
                build_library "$dep"
                FORCE_BUILD="$OLD_FORCE"
            fi
        fi
    done

    # プラットフォーム別の CMAKE_PREFIX_PATH を生成
    local DEPS_ARRAY=($DEPS)
    build_prefix_paths() {
        local platform=$1
        local paths=""
        for dep in "${DEPS_ARRAY[@]}"; do
            if [[ -n "$dep" ]]; then
                local dep_path="$PROJECT_ROOT/.install-${dep}/${platform}"
                if [[ -n "$paths" ]]; then
                    paths="${paths};${dep_path};${dep_path}/lib/cmake"
                else
                    paths="${dep_path};${dep_path}/lib/cmake"
                fi
            fi
        done
        echo "$paths"
    }

    # 共通 CMake オプション
    local CMAKE_COMMON_OPTIONS=(
        -DCMAKE_BUILD_TYPE=Release
    )

    # dependencies.yml からライブラリ固有のオプションを読み込み
    local LIB_CMAKE_OPTIONS=$(get_cmake_options "$LIB_NAME")
    if [[ -n "$LIB_CMAKE_OPTIONS" ]]; then
        for opt in $LIB_CMAKE_OPTIONS; do
            CMAKE_COMMON_OPTIONS+=("$opt")
        done
    fi

    # --- macOS (Universal: arm64 + x86_64) ---
    echo ""
    echo "=========================================="
    echo "Building $LIB_NAME for macOS (Universal)..."
    echo "=========================================="
    local MACOS_PREFIX_PATHS=$(build_prefix_paths "macos")
    run_cmake_configure "$SOURCE_DIR" "$BUILD_DIR/macos" \
        "${CMAKE_COMMON_OPTIONS[@]}" \
        ${MACOS_PREFIX_PATHS:+-DCMAKE_PREFIX_PATH="$MACOS_PREFIX_PATHS"} \
        -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR/macos"

    cmake --build "$BUILD_DIR/macos" --config Release --parallel
    cmake --install "$BUILD_DIR/macos" --config Release

    # --- iOS Device (arm64) ---
    echo ""
    echo "=========================================="
    echo "Building $LIB_NAME for iOS Device (arm64)..."
    echo "=========================================="
    local IOS_DEVICE_PREFIX_PATHS=$(build_prefix_paths "ios-device")
    run_cmake_configure "$SOURCE_DIR" "$BUILD_DIR/ios-device" \
        "${CMAKE_COMMON_OPTIONS[@]}" \
        ${IOS_DEVICE_PREFIX_PATHS:+-DCMAKE_PREFIX_PATH="$IOS_DEVICE_PREFIX_PATHS"} \
        -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR/ios-device"

    cmake --build "$BUILD_DIR/ios-device" --config Release --parallel
    cmake --install "$BUILD_DIR/ios-device" --config Release

    # --- iOS Simulator (arm64) ---
    echo ""
    echo "=========================================="
    echo "Building $LIB_NAME for iOS Simulator (arm64)..."
    echo "=========================================="
    local IOS_SIM_ARM64_PREFIX_PATHS=$(build_prefix_paths "ios-sim-arm64")
    run_cmake_configure "$SOURCE_DIR" "$BUILD_DIR/ios-sim-arm64" \
        "${CMAKE_COMMON_OPTIONS[@]}" \
        ${IOS_SIM_ARM64_PREFIX_PATHS:+-DCMAKE_PREFIX_PATH="$IOS_SIM_ARM64_PREFIX_PATHS"} \
        -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_SYSROOT=iphonesimulator \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR/ios-sim-arm64"

    cmake --build "$BUILD_DIR/ios-sim-arm64" --config Release --parallel
    cmake --install "$BUILD_DIR/ios-sim-arm64" --config Release

    # --- iOS Simulator (x86_64) ---
    echo ""
    echo "=========================================="
    echo "Building $LIB_NAME for iOS Simulator (x86_64)..."
    echo "=========================================="
    local IOS_SIM_X86_PREFIX_PATHS=$(build_prefix_paths "ios-sim-x86_64")
    run_cmake_configure "$SOURCE_DIR" "$BUILD_DIR/ios-sim-x86_64" \
        "${CMAKE_COMMON_OPTIONS[@]}" \
        ${IOS_SIM_X86_PREFIX_PATHS:+-DCMAKE_PREFIX_PATH="$IOS_SIM_X86_PREFIX_PATHS"} \
        -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_SYSROOT=iphonesimulator \
        -DCMAKE_OSX_ARCHITECTURES=x86_64 \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR/ios-sim-x86_64"

    cmake --build "$BUILD_DIR/ios-sim-x86_64" --config Release --parallel
    cmake --install "$BUILD_DIR/ios-sim-x86_64" --config Release

    # --- 静的ライブラリ生成チェック ---
    if [[ ! -f "$INSTALL_DIR/macos/lib/lib${LIB_FILE_NAME}.a" ]]; then
        echo ""
        echo "=========================================="
        echo "ERROR: Static library not found!"
        echo "=========================================="
        echo "Expected: $INSTALL_DIR/macos/lib/lib${LIB_FILE_NAME}.a"
        echo ""
        echo "The library may have been built as a shared library instead."
        echo "Add appropriate cmake_options to dependencies.yml."
        echo ""
        echo "Available CMake options for $LIB_NAME:"
        cmake -LH -S "$SOURCE_DIR" -B /tmp/cmake-options-check 2>/dev/null | grep -E "^[A-Z_]+:" | head -30 || true
        rm -rf /tmp/cmake-options-check
        exit 1
    fi

    # --- iOS Simulator Universal (lipo) ---
    echo ""
    echo "=========================================="
    echo "Creating iOS Simulator universal library..."
    echo "=========================================="
    mkdir -p "$INSTALL_DIR/ios-sim-universal/lib"
    lipo -create \
        "$INSTALL_DIR/ios-sim-arm64/lib/lib${LIB_FILE_NAME}.a" \
        "$INSTALL_DIR/ios-sim-x86_64/lib/lib${LIB_FILE_NAME}.a" \
        -output "$INSTALL_DIR/ios-sim-universal/lib/lib${LIB_FILE_NAME}.a"

    echo "Verifying architectures..."
    lipo -info "$INSTALL_DIR/macos/lib/lib${LIB_FILE_NAME}.a"
    lipo -info "$INSTALL_DIR/ios-device/lib/lib${LIB_FILE_NAME}.a"
    lipo -info "$INSTALL_DIR/ios-sim-universal/lib/lib${LIB_FILE_NAME}.a"

    # --- XCFramework 作成 ---
    echo ""
    echo "=========================================="
    echo "Creating XCFramework..."
    echo "=========================================="
    rm -rf "$OUTPUT_DIR/${LIB_NAME}.xcframework"

    xcodebuild -create-xcframework \
        -library "$INSTALL_DIR/macos/lib/lib${LIB_FILE_NAME}.a" \
        -headers "$INSTALL_DIR/macos/include" \
        -library "$INSTALL_DIR/ios-device/lib/lib${LIB_FILE_NAME}.a" \
        -headers "$INSTALL_DIR/ios-device/include" \
        -library "$INSTALL_DIR/ios-sim-universal/lib/lib${LIB_FILE_NAME}.a" \
        -headers "$INSTALL_DIR/ios-sim-arm64/include" \
        -output "$OUTPUT_DIR/${LIB_NAME}.xcframework"

    # ビルド情報を保存
    save_build_info "$LIB_NAME" "$TAG"

    echo ""
    echo "=========================================="
    echo "$LIB_NAME build complete!"
    echo "=========================================="
    echo "XCFramework: $OUTPUT_DIR/${LIB_NAME}.xcframework"
    ls -la "$OUTPUT_DIR/${LIB_NAME}.xcframework"

    # ビルドディレクトリのみクリーンアップ（インストールディレクトリは依存ビルドで必要なため残す）
    echo ""
    echo "Cleaning up build artifacts..."
    rm -rf "$BUILD_DIR"
    rm -rf "$SOURCE_DIR"
}

# =============================================================================
# インストールディレクトリのクリーンアップ
# =============================================================================

cleanup_install_dirs() {
    echo ""
    echo "=========================================="
    echo "Cleaning up install directories..."
    echo "=========================================="
    rm -rf "$PROJECT_ROOT"/.install-*
    rm -rf "$VENDOR_DIR"
}

# =============================================================================
# 依存関係を解決してビルド順序を決定
# =============================================================================

resolve_build_order() {
    local libs_to_build=("$@")
    local resolved=()
    local unresolved=("${libs_to_build[@]}")

    while [[ ${#unresolved[@]} -gt 0 ]]; do
        local made_progress=false

        for i in "${!unresolved[@]}"; do
            local lib="${unresolved[$i]}"
            local deps=$(get_depends_on "$lib")
            local all_deps_resolved=true

            for dep in $deps; do
                if [[ -n "$dep" ]]; then
                    # 依存がビルド対象に含まれていて、まだ解決されていない場合
                    if [[ " ${libs_to_build[*]} " =~ " $dep " ]] && [[ ! " ${resolved[*]} " =~ " $dep " ]]; then
                        all_deps_resolved=false
                        break
                    fi
                fi
            done

            if $all_deps_resolved; then
                resolved+=("$lib")
                unset 'unresolved[$i]'
                made_progress=true
            fi
        done

        # 配列を再構築
        unresolved=("${unresolved[@]}")

        if ! $made_progress && [[ ${#unresolved[@]} -gt 0 ]]; then
            echo "Error: Circular dependency detected: ${unresolved[*]}" >&2
            exit 1
        fi
    done

    echo "${resolved[@]}"
}

# =============================================================================
# メイン処理
# =============================================================================

usage() {
    echo "Usage: $0 [OPTIONS] [LIBRARY_NAME...]"
    echo ""
    echo "Build XCFrameworks for SDL libraries."
    echo ""
    echo "Options:"
    echo "  --all       Build all libraries in dependencies.yml"
    echo "  --force     Force rebuild even if version matches"
    echo "  --list      List available libraries"
    echo "  --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 SDL3              # Build SDL3 only (skip if already built)"
    echo "  $0 --force SDL3      # Force rebuild SDL3"
    echo "  $0 SDL3 SDL3_ttf     # Build SDL3 and SDL3_ttf"
    echo "  $0 --all             # Build all libraries"
}

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

LIBS_TO_BUILD=()
FORCE_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            LIBS_TO_BUILD=($(get_library_names))
            shift
            ;;
        --force)
            FORCE_BUILD=true
            shift
            ;;
        --list)
            echo "Available libraries:"
            get_library_names | while read lib; do
                tag=$(get_field "$lib" "tag" "")
                echo "  - $lib ($tag)"
            done
            exit 0
            ;;
        --help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
        *)
            LIBS_TO_BUILD+=("$1")
            shift
            ;;
    esac
done

if [[ ${#LIBS_TO_BUILD[@]} -eq 0 ]]; then
    echo "Error: No libraries specified" >&2
    usage
    exit 1
fi

echo "Project root: $PROJECT_ROOT"
echo "Dependencies file: $DEPS_FILE"
echo "Libraries to build: ${LIBS_TO_BUILD[*]}"

# ビルド順序を解決
ORDERED_LIBS=($(resolve_build_order "${LIBS_TO_BUILD[@]}"))
echo "Build order: ${ORDERED_LIBS[*]}"

# 各ライブラリをビルド
for lib in "${ORDERED_LIBS[@]}"; do
    build_library "$lib"
done

# 最終クリーンアップ（インストールディレクトリと Vendor を削除）
cleanup_install_dirs

echo ""
echo "############################################################"
echo "# All builds complete!"
echo "############################################################"
