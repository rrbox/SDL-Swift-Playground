//
//  SDLWindow.swift
//  SDL-Swift-Playground
//
//  Created by rrbox on 2026/01/18.
//

import CSDL3

@MainActor
final class SDLWindow {
    struct Flags: OptionSet {
        let rawValue: UInt64

        // SDL_video.h の定義より
        static let fullscreen = Flags(rawValue: 0x00000001)  // SDL_WINDOW_FULLSCREEN
        static let opengl = Flags(rawValue: 0x00000002)  // SDL_WINDOW_OPENGL
        static let occluded = Flags(rawValue: 0x00000004)  // SDL_WINDOW_OCCLUDED
        static let hidden = Flags(rawValue: 0x00000008)  // SDL_WINDOW_HIDDEN
        static let borderless = Flags(rawValue: 0x00000010)  // SDL_WINDOW_BORDERLESS
        static let resizable = Flags(rawValue: 0x00000020)  // SDL_WINDOW_RESIZABLE
        static let minimized = Flags(rawValue: 0x00000040)  // SDL_WINDOW_MINIMIZED
        static let maximized = Flags(rawValue: 0x00000080)  // SDL_WINDOW_MAXIMIZED
        static let mouseGrabbed = Flags(rawValue: 0x00000100)  // SDL_WINDOW_MOUSE_GRABBED
        static let inputFocus = Flags(rawValue: 0x00000200)  // SDL_WINDOW_INPUT_FOCUS
        static let mouseFocus = Flags(rawValue: 0x00000400)  // SDL_WINDOW_MOUSE_FOCUS
        static let external = Flags(rawValue: 0x00000800)  // SDL_WINDOW_EXTERNAL
        static let modal = Flags(rawValue: 0x00001000)  // SDL_WINDOW_MODAL
        static let highPixelDensity = Flags(rawValue: 0x00002000)  // SDL_WINDOW_HIGH_PIXEL_DENSITY
        static let mouseCapture = Flags(rawValue: 0x00004000)  // SDL_WINDOW_MOUSE_CAPTURE
        static let alwaysOnTop = Flags(rawValue: 0x00010000)  // SDL_WINDOW_ALWAYS_ON_TOP
        static let utility = Flags(rawValue: 0x00020000)  // SDL_WINDOW_UTILITY
        static let tooltip = Flags(rawValue: 0x00040000)  // SDL_WINDOW_TOOLTIP
        static let popupMenu = Flags(rawValue: 0x00080000)  // SDL_WINDOW_POPUP_MENU
        static let keyboardGrabbed = Flags(rawValue: 0x00100000)  // SDL_WINDOW_KEYBOARD_GRABBED
        static let vulkan = Flags(rawValue: 0x10000000)  // SDL_WINDOW_VULKAN
        static let metal = Flags(rawValue: 0x20000000)  // SDL_WINDOW_METAL
        static let transparent = Flags(rawValue: 0x40000000)  // SDL_WINDOW_TRANSPARENT
        static let notFocusable = Flags(rawValue: 0x80000000)  // SDL_WINDOW_NOT_FOCUSABLE
    }

    let pointer: OpaquePointer

    init(_ pointer: OpaquePointer) {
        self.pointer = pointer
    }

    static func create(_ title: String, _ w: Int32, _ h: Int32, _ flags: Flags) -> SDLWindow {
        guard let pointer = SDL_CreateWindow(title, w, h, flags.rawValue) else {
            let error = String(cString: SDL_GetError())
            fatalError("SDL_CreateWindow failed: \(error)")
        }
        return SDLWindow(pointer)
    }

    func destroy() {
        SDL_DestroyWindow(pointer)
    }
}
