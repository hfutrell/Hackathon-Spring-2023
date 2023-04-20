//
//  GameWorld.swift
//  Hackathon
//
//  Created by Holmes Futrell on 4/19/23.
//

import Foundation

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
    static func cube() -> GameObject {
        let object = GameObject(kind: .cube)
        return object
    }
}

class GameWorld {
    private var grid: Grid = Grid()
    func insertCube(at location: Location) {
        grid.insert(object: GameObject.cube(), at: location)
    }
    var allObjects: [(location: Location, object: GameObject)] { return grid.allObjects }
}
