//
//  GameWorld.swift
//  Hackathon
//
//  Created by Holmes Futrell on 4/19/23.
//

import UIKit

struct Location: Hashable {
    var x, y, z: Int
}

private class Grid {
    private var dictionary: [Location: GameObject] = [:]
    func insert(object: GameObject, at location: Location) {
        dictionary[location] = object
    }
    func object(at location: Location) -> GameObject? {
        return dictionary[location]
    }
    var allObjects: [(location: Location, object: GameObject)] { return dictionary.map { (location: $0.0, object: $0.1 ) } }
}

struct GameObject {
    enum Kind {
        case cube
    }
    var kind: Kind
    var color: SIMD4<Float>
    static func cube(color: SIMD4<Float>) -> GameObject {
        let object = GameObject(kind: .cube, color: color)
        return object
    }
}

class GameWorld {
    private var grid: Grid = Grid()
    func insertCube(at location: Location, color: UIColor) {
        
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let metalColor = SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
        
        grid.insert(object: GameObject.cube(color: metalColor), at: location)
    }
    var allObjects: [(location: Location, object: GameObject)] { return grid.allObjects }
}
