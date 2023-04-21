//
//  GameViewController.swift
//  Hackathon iOS
//
//  Created by Holmes Futrell on 4/19/23.
//

import UIKit
import MetalKit

// Our iOS specific view controller
class GameViewController: UIViewController {
    
    var renderer: Renderer!
    var mtkView: MTKView!
    var keyboardControls: KeyboardControls!
    var mouseControls: MouseControls!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let mtkView = self.view as? MTKView else {
            print("View of Gameview controller is not an MTKView")
            return
        }
        
        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported")
            return
        }
        
        mtkView.device = defaultDevice
        mtkView.backgroundColor = UIColor.black
        
        guard let newRenderer = Renderer(metalKitView: mtkView) else {
            print("Renderer cannot be initialized")
            return
        }
        
        
        renderer = newRenderer
        
        keyboardControls = KeyboardControls()
        mouseControls = MouseControls(view: view)
        
        mouseControls.delegate = renderer
        renderer.keyboardControls = keyboardControls

        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        let hoverGesture = UIHoverGestureRecognizer(target: self, action: #selector(handleHover))
        self.view.addGestureRecognizer(hoverGesture)
        
        mtkView.delegate = renderer
    }
    
    @objc func handleHover(_ recognizer: UIHoverGestureRecognizer) {
        mouseControls.handleHover(recognizer)
    }
    
    override func pressesBegan(_ presses: Set<UIPress>,
                               with event: UIPressesEvent?) {
        keyboardControls.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>,
                               with event: UIPressesEvent?) {
        keyboardControls.pressesEnded(presses, with: event)
    }

    override func pressesCancelled(_ presses: Set<UIPress>,
                                   with event: UIPressesEvent?) {
        keyboardControls.pressesEnded(presses, with: event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        mouseControls.touchesEnded(touches, with: event)
    }
}
