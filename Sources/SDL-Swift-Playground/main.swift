import CSDL3
import CSDL3_ttf
import Foundation

print("SDL3 Demo - Bouncing Rectangles")

enum SDL {

}

extension SDL {
    struct InitFlags: OptionSet {
        let rawValue: UInt32

        // SDL_init.h の定義より
        static let audio = InitFlags(rawValue: 0x00000010)  // SDL_INIT_AUDIO
        static let video = InitFlags(rawValue: 0x00000020)  // SDL_INIT_VIDEO
        static let joystick = InitFlags(rawValue: 0x00000200)  // SDL_INIT_JOYSTICK
        static let haptic = InitFlags(rawValue: 0x00001000)  // SDL_INIT_HAPTIC
        static let gamepad = InitFlags(rawValue: 0x00002000)  // SDL_INIT_GAMEPAD
        static let events = InitFlags(rawValue: 0x00004000)  // SDL_INIT_EVENTS
        static let sensor = InitFlags(rawValue: 0x00008000)  // SDL_INIT_SENSOR
        static let camera = InitFlags(rawValue: 0x00010000)  // SDL_INIT_CAMERA
    }

    struct ExternalInitFlags: OptionSet {
        let rawValue: Uint8

        static let ttf = ExternalInitFlags(rawValue: 1 << 0)
    }

    struct WindowFlags: OptionSet {
        let rawValue: UInt64

        // SDL_video.h の定義より
        static let fullscreen = WindowFlags(rawValue: 0x00000001)  // SDL_WINDOW_FULLSCREEN
        static let opengl = WindowFlags(rawValue: 0x00000002)  // SDL_WINDOW_OPENGL
        static let occluded = WindowFlags(rawValue: 0x00000004)  // SDL_WINDOW_OCCLUDED
        static let hidden = WindowFlags(rawValue: 0x00000008)  // SDL_WINDOW_HIDDEN
        static let borderless = WindowFlags(rawValue: 0x00000010)  // SDL_WINDOW_BORDERLESS
        static let resizable = WindowFlags(rawValue: 0x00000020)  // SDL_WINDOW_RESIZABLE
        static let minimized = WindowFlags(rawValue: 0x00000040)  // SDL_WINDOW_MINIMIZED
        static let maximized = WindowFlags(rawValue: 0x00000080)  // SDL_WINDOW_MAXIMIZED
        static let mouseGrabbed = WindowFlags(rawValue: 0x00000100)  // SDL_WINDOW_MOUSE_GRABBED
        static let inputFocus = WindowFlags(rawValue: 0x00000200)  // SDL_WINDOW_INPUT_FOCUS
        static let mouseFocus = WindowFlags(rawValue: 0x00000400)  // SDL_WINDOW_MOUSE_FOCUS
        static let external = WindowFlags(rawValue: 0x00000800)  // SDL_WINDOW_EXTERNAL
        static let modal = WindowFlags(rawValue: 0x00001000)  // SDL_WINDOW_MODAL
        static let highPixelDensity = WindowFlags(rawValue: 0x00002000)  // SDL_WINDOW_HIGH_PIXEL_DENSITY
        static let mouseCapture = WindowFlags(rawValue: 0x00004000)  // SDL_WINDOW_MOUSE_CAPTURE
        static let alwaysOnTop = WindowFlags(rawValue: 0x00010000)  // SDL_WINDOW_ALWAYS_ON_TOP
        static let utility = WindowFlags(rawValue: 0x00020000)  // SDL_WINDOW_UTILITY
        static let tooltip = WindowFlags(rawValue: 0x00040000)  // SDL_WINDOW_TOOLTIP
        static let popupMenu = WindowFlags(rawValue: 0x00080000)  // SDL_WINDOW_POPUP_MENU
        static let keyboardGrabbed = WindowFlags(rawValue: 0x00100000)  // SDL_WINDOW_KEYBOARD_GRABBED
        static let vulkan = WindowFlags(rawValue: 0x10000000)  // SDL_WINDOW_VULKAN
        static let metal = WindowFlags(rawValue: 0x20000000)  // SDL_WINDOW_METAL
        static let transparent = WindowFlags(rawValue: 0x40000000)  // SDL_WINDOW_TRANSPARENT
        static let notFocusable = WindowFlags(rawValue: 0x80000000)  // SDL_WINDOW_NOT_FOCUSABLE
    }
}

extension SDL {
    static func sdlInit(_ flags: SDL.InitFlags, external: SDL.ExternalInitFlags = []) {
        if !SDL_Init(flags.rawValue) {
            let error = String(cString: SDL_GetError())
            fatalError("SDL_Init failed: \(error)")
        }

        // 外部ライブラリの初期化
        if external.contains(.ttf) {
            if !TTF_Init() {
                let error = String(cString: SDL_GetError())
                fatalError("TTF_Init failed: \(error)")
            }
        }
    }

    static func quit(external: SDL.ExternalInitFlags = []) {
        // 外部ライブラリの終了（初期化の逆順）
        if external.contains(.ttf) {
            TTF_Quit()
        }

        SDL_Quit()
    }
}

extension SDL {
    static func createWindow(_ title: String, _ w: Int32, _ h: Int32, _ flags: WindowFlags) -> OpaquePointer! {
        SDL_CreateWindow(title, w, h, flags.rawValue)
    }
}

// MARK: - Batch Rendering

extension SDL {
    /// 複数の矩形を一度にバッチ描画する（各矩形に異なる色を指定可能）
    /// SDL_RenderGeometryを使用して、各矩形を2つの三角形として描画
    static func renderFilledRectsBatch(
        renderer: OpaquePointer,
        rects: [(rect: SDL_FRect, r: UInt8, g: UInt8, b: UInt8, a: UInt8)]
    ) {
        guard !rects.isEmpty else { return }

        // 各矩形に4頂点、6インデックス（2三角形）
        var vertices: [SDL_Vertex] = []
        vertices.reserveCapacity(rects.count * 4)

        var indices: [Int32] = []
        indices.reserveCapacity(rects.count * 6)

        for (index, item) in rects.enumerated() {
            let rect = item.rect
            let color = SDL_FColor(
                r: Float(item.r) / 255.0,
                g: Float(item.g) / 255.0,
                b: Float(item.b) / 255.0,
                a: Float(item.a) / 255.0
            )

            // 4頂点: 左上、右上、右下、左下
            let topLeft = SDL_Vertex(
                position: SDL_FPoint(x: rect.x, y: rect.y),
                color: color,
                tex_coord: SDL_FPoint(x: 0, y: 0)
            )
            let topRight = SDL_Vertex(
                position: SDL_FPoint(x: rect.x + rect.w, y: rect.y),
                color: color,
                tex_coord: SDL_FPoint(x: 1, y: 0)
            )
            let bottomRight = SDL_Vertex(
                position: SDL_FPoint(x: rect.x + rect.w, y: rect.y + rect.h),
                color: color,
                tex_coord: SDL_FPoint(x: 1, y: 1)
            )
            let bottomLeft = SDL_Vertex(
                position: SDL_FPoint(x: rect.x, y: rect.y + rect.h),
                color: color,
                tex_coord: SDL_FPoint(x: 0, y: 1)
            )

            vertices.append(contentsOf: [topLeft, topRight, bottomRight, bottomLeft])

            // インデックス: 2つの三角形
            // 三角形1: 左上、右上、右下
            // 三角形2: 左上、右下、左下
            let baseIndex = Int32(index * 4)
            indices.append(contentsOf: [
                baseIndex + 0, baseIndex + 1, baseIndex + 2,  // 三角形1
                baseIndex + 0, baseIndex + 2, baseIndex + 3   // 三角形2
            ])
        }

        // バッチ描画
        _ = vertices.withUnsafeBufferPointer { vertexBuffer in
            indices.withUnsafeBufferPointer { indexBuffer in
                SDL_RenderGeometry(
                    renderer,
                    nil,  // テクスチャなし
                    vertexBuffer.baseAddress,
                    Int32(vertexBuffer.count),
                    indexBuffer.baseAddress,
                    Int32(indexBuffer.count)
                )
            }
        }
    }

    /// 同じ色の矩形を一度にバッチ描画する（シンプル版）
    static func renderFilledRectsBatchSameColor(
        renderer: OpaquePointer,
        rects: [SDL_FRect],
        r: UInt8, g: UInt8, b: UInt8, a: UInt8
    ) {
        guard !rects.isEmpty else { return }

        SDL_SetRenderDrawColor(renderer, r, g, b, a)
        var mutableRects = rects
        _ = mutableRects.withUnsafeMutableBufferPointer { buffer in
            SDL_RenderFillRects(renderer, buffer.baseAddress, Int32(buffer.count))
        }
    }
}

SDL.sdlInit([.video], external: [.ttf])
defer { SDL.quit(external: [.ttf]) }

// バージョン表示
let version = SDL_GetVersion()
let major = version / 1000000
let minor = (version / 1000) % 1000
let micro = version % 1000
print("SDL Version: \(major).\(minor).\(micro)")

// SDL_ttf バージョン表示
let ttfVersion = TTF_Version()
let ttfMajor = ttfVersion / 1000000
let ttfMinor = (ttfVersion / 1000) % 1000
let ttfMicro = ttfVersion % 1000
print("SDL_ttf Version: \(ttfMajor).\(ttfMinor).\(ttfMicro)")

// ウィンドウ作成（OptionSet を使用）
let windowWidth: Int32 = 800
let windowHeight: Int32 = 600

guard let window = SDL.createWindow(
    "SDL3 Swift Demo",
    windowWidth,
    windowHeight,
    [.resizable]
) else {
    let error = String(cString: SDL_GetError())
    fatalError("SDL_CreateWindow failed: \(error)")
}
defer { SDL_DestroyWindow(window) }

// レンダラー作成
guard let renderer = SDL_CreateRenderer(window, nil) else {
    let error = String(cString: SDL_GetError())
    fatalError("SDL_CreateRenderer failed: \(error)")
}
defer { SDL_DestroyRenderer(renderer) }

// ディスプレイ情報を取得
let displayID = SDL_GetPrimaryDisplay()
if let displayMode = SDL_GetCurrentDisplayMode(displayID) {
    print("Display: \(displayMode.pointee.w)x\(displayMode.pointee.h) @ \(displayMode.pointee.refresh_rate)Hz")
}

// VSync設定（ディスプレイ同期）
let vsyncResult = SDL_SetRenderVSync(renderer, 1)  // 1 = VSync有効
var actualVSync: Int32 = -1
SDL_GetRenderVSync(renderer, &actualVSync)
print("VSync初期設定: result=\(vsyncResult), actual=\(actualVSync)")

// バウンドする四角形の構造体
struct BouncingRect {
    var x: Float
    var y: Float
    var width: Float
    var height: Float
    var velocityX: Float
    var velocityY: Float
    var r: UInt8
    var g: UInt8
    var b: UInt8

    mutating func update(screenWidth: Float, screenHeight: Float) {
        x += velocityX
        y += velocityY

        // 壁でバウンド
        if x <= 0 || x + width >= screenWidth {
            velocityX = -velocityX
            x = max(0, min(x, screenWidth - width))
        }
        if y <= 0 || y + height >= screenHeight {
            velocityY = -velocityY
            y = max(0, min(y, screenHeight - height))
        }
    }

    func toSDLRect() -> SDL_FRect {
        return SDL_FRect(x: x, y: y, w: width, h: height)
    }
}

// ランダムな矩形を生成するヘルパー
func createRandomRect(screenWidth: Float, screenHeight: Float) -> BouncingRect {
    BouncingRect(
        x: Float.random(in: 50...(screenWidth - 100)),
        y: Float.random(in: 50...(screenHeight - 100)),
        width: Float.random(in: 20...60),
        height: Float.random(in: 20...60),
        velocityX: Float.random(in: -5...5),
        velocityY: Float.random(in: -5...5),
        r: UInt8.random(in: 50...255),
        g: UInt8.random(in: 50...255),
        b: UInt8.random(in: 50...255)
    )
}

// 複数のバウンドする四角形を作成
var rects: [BouncingRect] = (0..<100).map { _ in
    createRandomRect(screenWidth: 800, screenHeight: 600)
}

// ベンチマーク用設定
var useBatchRendering = true
var vsyncEnabled = true   // FPS制限
var drawGrid = true       // グリッド描画
var drawBorders = true    // 枠線描画

// メインループ
var running = true
var event = SDL_Event()
var frameCount: UInt64 = 0
var lastTime = SDL_GetTicks()
var currentWidth = windowWidth
var currentHeight = windowHeight

print("Press ESC or close the window to quit")
print("Press UP/DOWN to add/remove 100 rectangles")
print("Press SPACE to add 1000 rectangles")
print("Press B to toggle batch rendering")
print("Press V to toggle VSync/FPS limit")
print("Press G to toggle grid")
print("Press O to toggle borders")

while running {
    // イベント処理
    while SDL_PollEvent(&event) {
        switch SDL_EventType(event.type) {
        case SDL_EVENT_QUIT:
            running = false

        case SDL_EVENT_KEY_DOWN:
            let keyEvent = event.key
            switch keyEvent.key {
            case SDLK_ESCAPE:
                running = false
            case SDLK_UP:
                // 100個追加
                for _ in 0..<100 {
                    rects.append(createRandomRect(screenWidth: Float(currentWidth), screenHeight: Float(currentHeight)))
                }
                print("Added 100 rectangles - Total: \(rects.count)")
            case SDLK_DOWN:
                // 100個削除
                let removeCount = min(100, rects.count)
                rects.removeLast(removeCount)
                print("Removed \(removeCount) rectangles - Total: \(rects.count)")
            case SDLK_SPACE:
                // 1000個追加
                for _ in 0..<1000 {
                    rects.append(createRandomRect(screenWidth: Float(currentWidth), screenHeight: Float(currentHeight)))
                }
                print("Added 1000 rectangles - Total: \(rects.count)")
            case SDLK_B:
                // バッチ描画切り替え
                useBatchRendering.toggle()
                print("Batch rendering: \(useBatchRendering ? "ON" : "OFF")")
            case SDLK_V:
                // VSync切り替え
                vsyncEnabled.toggle()
                let result = SDL_SetRenderVSync(renderer, vsyncEnabled ? 1 : 0)
                var actualVSync: Int32 = -1
                SDL_GetRenderVSync(renderer, &actualVSync)
                print("VSync: \(vsyncEnabled ? "ON" : "OFF") | SetResult: \(result) | Actual: \(actualVSync)")
            case SDLK_G:
                // グリッド描画切り替え
                drawGrid.toggle()
                print("Grid: \(drawGrid ? "ON" : "OFF")")
            case SDLK_O:
                // 枠線描画切り替え
                drawBorders.toggle()
                print("Borders: \(drawBorders ? "ON" : "OFF")")
            default:
                break
            }

        case SDL_EVENT_WINDOW_RESIZED:
            // ウィンドウサイズ変更時
            _ = SDL_GetWindowSize(window, &currentWidth, &currentHeight)

        default:
            break
        }
    }

    // 四角形の更新
    for i in rects.indices {
        rects[i].update(screenWidth: Float(currentWidth), screenHeight: Float(currentHeight))
    }

    // 背景をクリア（暗いグレー）
    SDL_SetRenderDrawColor(renderer, 30, 30, 40, 255)
    SDL_RenderClear(renderer)

    // グリッドを描画（背景装飾）- Gキーで切り替え可能
    if drawGrid {
        SDL_SetRenderDrawColor(renderer, 50, 50, 60, 255)
        let gridSize: Int32 = 50
        for x in stride(from: Int32(0), to: currentWidth, by: Int(gridSize)) {
            SDL_RenderLine(renderer, Float(x), 0, Float(x), Float(currentHeight))
        }
        for y in stride(from: Int32(0), to: currentHeight, by: Int(gridSize)) {
            SDL_RenderLine(renderer, 0, Float(y), Float(currentWidth), Float(y))
        }
    }

    // 各四角形を描画
    if useBatchRendering {
        // バッチ描画: SDL_RenderGeometryで一括描画（異なる色対応）
        let fillData = rects.map { rect in
            (rect: rect.toSDLRect(), r: rect.r, g: rect.g, b: rect.b, a: UInt8(200))
        }
        SDL.renderFilledRectsBatch(renderer: renderer, rects: fillData)
    } else {
        // 個別描画: 従来の方法
        for rect in rects {
            var sdlRect = rect.toSDLRect()
            SDL_SetRenderDrawColor(renderer, rect.r, rect.g, rect.b, 200)
            SDL_RenderFillRect(renderer, &sdlRect)
        }
    }

    // 枠線: 個別描画（両モード共通）- Oキーで切り替え可能
    if drawBorders {
        for rect in rects {
            var sdlRect = rect.toSDLRect()
            SDL_SetRenderDrawColor(renderer,
                UInt8(min(Int(rect.r) + 50, 255)),
                UInt8(min(Int(rect.g) + 50, 255)),
                UInt8(min(Int(rect.b) + 50, 255)),
                255)
            SDL_RenderRect(renderer, &sdlRect)
        }
    }

    // 画面に表示
    SDL_RenderPresent(renderer)

    // フレームレート計算（1秒ごとに表示）
    frameCount += 1
    let currentTime = SDL_GetTicks()
    if currentTime - lastTime >= 1000 {
        let fps = Double(frameCount) * 1000.0 / Double(currentTime - lastTime)
        print("FPS: \(String(format: "%.1f", fps)) | Rectangles: \(rects.count)")
        frameCount = 0
        lastTime = currentTime
    }

    // VSync無効時のみ手動でフレームレート制限
    // （VSync有効時はSDL_RenderPresentがディスプレイ同期を行う）
    if !vsyncEnabled {
        // 制限なし - 最大FPSで動作
    }
}

print("Demo finished!")
