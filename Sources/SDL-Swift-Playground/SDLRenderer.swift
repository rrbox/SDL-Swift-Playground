//
//  SDLRenderer.swift
//  SDL-Swift-Playground
//
//  Created by rrbox on 2026/01/18.
//

import CSDL3

@MainActor
final class SDLRenderer {
    let pointer: OpaquePointer

    init(_ pointer: OpaquePointer) {
        self.pointer = pointer
    }

    static func create(window: SDLWindow) -> SDLRenderer {
        guard let pointer = SDL_CreateRenderer(window.pointer, nil) else {
            let error = String(cString: SDL_GetError())
            fatalError("SDL_CreateRenderer failed: \(error)")
        }
        return SDLRenderer(pointer)
    }

    func destroy() {
        SDL_DestroyRenderer(pointer)
    }
}

