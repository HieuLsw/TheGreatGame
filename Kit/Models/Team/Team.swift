//
//  Team.swift
//  TheGreatGame
//
//  Created by Олег on 03.05.17.
//  Copyright © 2017 The Great Game. All rights reserved.
//

import Foundation
import Shallows

public protocol IDProtocol : Hashable, RawRepresentable {  }

public enum Team {
    
    public struct ID : RawRepresentable, Hashable, IDProtocol {
        
        public var rawID: Int
        
        public init?(rawValue: Int) {
            self.rawID = rawValue
        }
        
        public var rawValue: Int {
            return rawID
        }
        
        public var hashValue: Int {
            return rawValue
        }
        
        public func asString() -> String {
            return String(rawValue)
        }
        
    }
    
}

extension Team {

    public struct Compact {
        
        public let id: ID
        public let name: String
        public let shortName: String
        public let rank: Int
        public let badges: Badges
        
    }
    
}

extension Team.Compact : Mappable {
    
    public enum MappingKeys : String, IndexPathElement {
        case name
        case short_name
        case id
        case rank
        case badges
        case summary
    }
    
    public init<Source>(mapper: InMapper<Source, MappingKeys>) throws {
        self.name = try mapper.map(from: .name)
        self.shortName = try mapper.map(from: .short_name)
        self.id = try mapper.map(from: .id)
        self.rank = try mapper.map(from: .rank)
        self.badges = try mapper.map(from: .badges)
    }
    
    public func outMap<Destination>(mapper: inout OutMapper<Destination, MappingKeys>) throws {
        try mapper.map(self.name, to: .name)
        try mapper.map(self.shortName, to: .short_name)
        try mapper.map(self.id, to: .id)
        try mapper.map(self.rank, to: .rank)
        try mapper.map(self.badges, to: .badges)
    }
    
}

public struct Teams {
    
    public var teams: [Team.Compact]
    
}

extension Teams : Mappable {
    
    public enum MappingKeys : String, IndexPathElement {
        case teams
    }
    
    public init<Source>(mapper: InMapper<Source, MappingKeys>) throws {
        self.teams = try mapper.map(from: .teams)
    }
    
    public func outMap<Destination>(mapper: inout OutMapper<Destination, MappingKeys>) throws {
        try mapper.map(self.teams, to: .teams)
    }
    
}

public protocol ArrayMappableBox : Mappable {
    
    associatedtype Boxed
    
    init(_ values: [Boxed])
    
    var values: [Boxed] { get }
    
}

extension Teams : ArrayMappableBox {
    
    public init(_ values: [Boxed]) {
        self.teams = values
    }
    
    public var values: [Team.Compact] {
        return teams
    }
    
}

public protocol MappableBoxable {
    
    associatedtype Box : ArrayMappableBox where Box.Boxed == Self
    
}

extension Team.Compact : MappableBoxable {
    
    public typealias Box = Teams
    
}

extension Storage where Value == [String : Any] {
    
    public func mapMappable<T : MappableBoxable>(of: Array<T>.Type = Array<T>.self) -> Storage<Key, [T]> {
        return mapValues(transformIn: { (dict) -> [T] in
            let box = try T.Box.init(from: dict)
            return box.values
            }, transformOut: { (ar) -> [String : Any] in
                let box = T.Box(ar)
                return try box.map()
        })
    }
    
}
