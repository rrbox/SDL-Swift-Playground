//
//  SDL.swift
//  SDL-Swift-Playground
//
//  Created by rrbox on 2026/01/18.
//

import CSDL3
import CSDL3_ttf

@MainActor
enum SDL {
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

    private static var externalInitFlags: ExternalInitFlags = []
    private static var isRunning: Bool = false

    static func sdlInit(_ flags: SDL.InitFlags, external: SDL.ExternalInitFlags = []) {
        guard !isRunning else { return }
        externalInitFlags = external

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

    static func quit() {
        guard isRunning else { return }

        // 外部ライブラリの終了（初期化の逆順）
        if externalInitFlags.contains(.ttf) {
            TTF_Quit()
        }
        externalInitFlags = []

        SDL_Quit()
    }
}
