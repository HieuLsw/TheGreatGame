//
//  TeamFull.swift
//  TheGreatGame
//
//  Created by Олег on 04.05.17.
//  Copyright © 2017 The Great Game. All rights reserved.
//

public struct TeamFull {
    
    public let id: TeamID
    public let name: String
    public let shortName: String
    public let rank: Int
    public let badgeURL: URL
    public let description: String
    
}

extension TeamFull : Mappable {
    
    public enum MappingKeys : String, IndexPathElement {
        case name
        case short_name
        case id
        case rank
        case badge_url
        case description
    }
    
    public init<Source : InMap>(mapper: InMapper<Source, MappingKeys>) throws {
        self.name = try mapper.map(from: .name)
        self.shortName = try mapper.map(from: .short_name)
        self.id = try mapper.map(from: .id)
        self.rank = try mapper.map(from: .rank)
        self.badgeURL = try mapper.map(from: .badge_url)
        self.description = try mapper.map(from: .description)
    }
    
    public func outMap<Destination : OutMap>(mapper: inout OutMapper<Destination, MappingKeys>) throws {
        try mapper.map(self.name, to: .name)
        try mapper.map(self.shortName, to: .short_name)
        try mapper.map(self.id, to: .id)
        try mapper.map(self.rank, to: .rank)
        try mapper.map(self.badgeURL, to: .badge_url)
        try mapper.map(self.description, to: .description)
    }
    
}