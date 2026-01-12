import CSDL3

print("SDL3 Test")

// SDL初期化 (SDL3ではSDL_InitはBoolを返す)
if !SDL_Init(SDL_INIT_VIDEO) {
    let error = String(cString: SDL_GetError())
    print("SDL_Init failed: \(error)")
} else {
    print("SDL_Init succeeded!")

    // バージョン表示
    // SDL_VERSIONNUM_MAJOR/MINOR/MICROはCマクロなのでSwiftで直接計算
    let version = SDL_GetVersion()
    let major = version / 1000000
    let minor = (version / 1000) % 1000
    let micro = version % 1000
    print("SDL Version: \(major).\(minor).\(micro)")

    SDL_Quit()
    print("SDL_Quit called")
}
