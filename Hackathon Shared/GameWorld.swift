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

extension SIMD3<Float> {
    init(location: Location) {
        self = SIMD3(x: Float(location.x), y: Float(location.y), z: Float(location.z))
    }
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

struct GameObject: RayIntersectable {
    enum Kind {
        case cube
    }
    var kind: Kind
    var color: SIMD4<Float>
    var location: SIMD3<Float>
    static func cube(at location: Location, color: SIMD4<Float>) -> GameObject {
        let object = GameObject(kind: .cube, color: color, location: SIMD3<Float>(location: location))
        return object
    }
    func intersect(_ ray: Ray) -> Intersection? {
        switch kind {
        case .cube:
            return Cube(center: location, length: 1).intersect(ray)
        }
    }
}

class GameWorld {
    private var grid: Grid = Grid()
    func insertCube(at location: Location, color: UIColor) {
        
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let metalColor = SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
        
        grid.insert(object: GameObject.cube(at: location, color: metalColor), at: location)
    }
    var allObjects: [(location: Location, object: GameObject)] { return grid.allObjects }
}
