import CSDL3
import Foundation

print("SDL3 Demo - Bouncing Rectangles")

// SDL初期化
guard SDL_Init(SDL_INIT_VIDEO) else {
    let error = String(cString: SDL_GetError())
    fatalError("SDL_Init failed: \(error)")
}
defer { SDL_Quit() }

// バージョン表示
let version = SDL_GetVersion()
let major = version / 1000000
let minor = (version / 1000) % 1000
let micro = version % 1000
print("SDL Version: \(major).\(minor).\(micro)")

// ウィンドウ作成
let windowWidth: Int32 = 800
let windowHeight: Int32 = 600

// SDL_WINDOW_RESIZABLE = 0x20 (CマクロがSwiftでサポートされないため直接指定)
let SDL_WINDOW_FLAGS_RESIZABLE: SDL_WindowFlags = 0x20

guard let window = SDL_CreateWindow(
    "SDL3 Swift Demo",
    windowWidth,
    windowHeight,
    SDL_WINDOW_FLAGS_RESIZABLE
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

// 複数のバウンドする四角形を作成
var rects: [BouncingRect] = [
    BouncingRect(x: 100, y: 100, width: 60, height: 60, velocityX: 4, velocityY: 3, r: 255, g: 100, b: 100),
    BouncingRect(x: 200, y: 150, width: 50, height: 50, velocityX: -3, velocityY: 4, r: 100, g: 255, b: 100),
    BouncingRect(x: 300, y: 200, width: 70, height: 40, velocityX: 5, velocityY: -2, r: 100, g: 100, b: 255),
    BouncingRect(x: 400, y: 250, width: 45, height: 55, velocityX: -4, velocityY: -3, r: 255, g: 255, b: 100),
    BouncingRect(x: 500, y: 300, width: 55, height: 55, velocityX: 3, velocityY: 5, r: 255, g: 100, b: 255),
]

// メインループ
var running = true
var event = SDL_Event()
var frameCount: UInt64 = 0
var lastTime = SDL_GetTicks()
var currentWidth = windowWidth
var currentHeight = windowHeight

print("Press ESC or close the window to quit")
print("Click to add a new rectangle")

while running {
    // イベント処理
    while SDL_PollEvent(&event) {
        switch SDL_EventType(event.type) {
        case SDL_EVENT_QUIT:
            running = false

        case SDL_EVENT_KEY_DOWN:
            let keyEvent = event.key
            if keyEvent.key == SDLK_ESCAPE {
                running = false
            }

        case SDL_EVENT_MOUSE_BUTTON_DOWN:
            // クリックで新しい四角形を追加
            let mouseEvent = event.button
            let newRect = BouncingRect(
                x: mouseEvent.x,
                y: mouseEvent.y,
                width: Float.random(in: 30...80),
                height: Float.random(in: 30...80),
                velocityX: Float.random(in: -5...5),
                velocityY: Float.random(in: -5...5),
                r: UInt8.random(in: 50...255),
                g: UInt8.random(in: 50...255),
                b: UInt8.random(in: 50...255)
            )
            rects.append(newRect)
            print("Added rectangle at (\(Int(mouseEvent.x)), \(Int(mouseEvent.y))) - Total: \(rects.count)")

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

    // グリッドを描画（背景装飾）
    SDL_SetRenderDrawColor(renderer, 50, 50, 60, 255)
    let gridSize: Int32 = 50
    for x in stride(from: Int32(0), to: currentWidth, by: Int(gridSize)) {
        SDL_RenderLine(renderer, Float(x), 0, Float(x), Float(currentHeight))
    }
    for y in stride(from: Int32(0), to: currentHeight, by: Int(gridSize)) {
        SDL_RenderLine(renderer, 0, Float(y), Float(currentWidth), Float(y))
    }

    // 各四角形を描画
    for rect in rects {
        var sdlRect = rect.toSDLRect()

        // 四角形の塗りつぶし
        SDL_SetRenderDrawColor(renderer, rect.r, rect.g, rect.b, 200)
        SDL_RenderFillRect(renderer, &sdlRect)

        // 四角形の枠線（より明るい色）
        SDL_SetRenderDrawColor(renderer,
            UInt8(min(Int(rect.r) + 50, 255)),
            UInt8(min(Int(rect.g) + 50, 255)),
            UInt8(min(Int(rect.b) + 50, 255)),
            255)
        SDL_RenderRect(renderer, &sdlRect)
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

    // 約60FPSに制限
    SDL_Delay(16)
}

print("Demo finished!")
