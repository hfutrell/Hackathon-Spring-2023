//
//  MouseControls.swift
//  Hackathon
//
//  Created by Holmes Futrell on 4/20/23.
//

import UIKit

protocol MouseControlsDelegate: AnyObject {
    func mouseMoved(to viewPoint: CGPoint?, in view: UIView)
    // func mouseClicked(at viewPoint: CGPoint, isRightClick: Bool)
}

class MouseControls {
    
    private var view: UIView
    
    weak var delegate: MouseControlsDelegate?
    
    init(view: UIView) {
        self.view = view
    }
    
    func handleHover(_ recognizer: UIHoverGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            delegate?.mouseMoved(to: recognizer.location(in: view), in: view)
        case .possible, .cancelled, .failed, .ended:
            delegate?.mouseMoved(to: nil, in: view)
            break
        @unknown default:
            assertionFailure("unhandled hover state \(recognizer.state)")
            break
        }
    }
}
