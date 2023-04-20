//
//  KeyboardControls.swift
//  Hackathon
//
//  Created by Holmes Futrell on 4/20/23.
//

import UIKit

class KeyboardControls {
    
    private enum KeyState {
        case down
        case up
        init() {
            self = .up
        }
    }
        
    private struct KeyMap {
        private var map: [UIKeyboardHIDUsage: KeyState] = [:]
        func state(for key: UIKeyboardHIDUsage) -> KeyState {
            return map[key] ?? .up
        }
        mutating func setState(_ state: KeyState, for key: UIKeyboardHIDUsage) {
            map[key] = state
        }
    }
    
    private var keyMap = KeyMap()
    
    func pressesBegan(_ presses: Set<UIPress>,
                      with event: UIPressesEvent?) {

        presses.forEach {
            guard let key = $0.key?.keyCode else { return }
            keyMap.setState(.down, for: key)
        }
        
    }

    func pressesEnded(_ presses: Set<UIPress>,
                      with event: UIPressesEvent?) {
        presses.forEach {
            guard let key = $0.key?.keyCode else { return }
            keyMap.setState(.up, for: key)
        }
    }
    
    func isKeyDown(_ key: UIKeyboardHIDUsage) -> Bool {
        return keyMap.state(for: key) == .down
    }
}
