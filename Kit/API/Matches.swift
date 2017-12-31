//
//  Matches.swift
//  TheGreatGame
//
//  Created by Олег on 05.05.17.
//  Copyright © 2017 The Great Game. All rights reserved.
//

import Foundation
import Shallows

public struct MatchesEndpoint {
    
    public let path: APIPath
    
    init(path: APIPath) {
        self.path = "matches" + path
    }
    
    public static let all = MatchesEndpoint(path: "all.json")
    public static let allFull = MatchesEndpoint(path: "all-full.json")
    public static func fullMatch(withID id: Match.ID) -> MatchesEndpoint {
        return MatchesEndpoint(path: APIPath(rawValue: "\(id.rawID).json"))
    }
    public static let stages = MatchesEndpoint(path: "stages.json")
    
}

public final class MatchesAPI : APIPoint {
    
    public let provider: ReadOnlyStorage<MatchesEndpoint, [String : Any]>
    public let all: Retrieve<Editioned<Matches>>
    public let allFull: Retrieve<Editioned<FullMatches>>
    public let stages: Retrieve<Editioned<Stages>>
    public let fullMatch: ReadOnlyStorage<Match.ID, Editioned<Match.Full>>
    
    private let dataProvider: ReadOnlyStorage<APIPath, Data>
    
    public init(dataProvider: ReadOnlyStorage<APIPath, Data>) {
        self.dataProvider = dataProvider
        self.provider = dataProvider
            .mapJSONDictionary()
            .mapKeys({ $0.path })
        self.all = provider
            .singleKey(.all)
            .mapMappable(of: Editioned<Matches>.self)
        self.allFull = provider
            .singleKey(.allFull)
            .mapMappable()
        self.stages = provider
            .singleKey(.stages)
            .mapMappable()
        self.fullMatch = provider
            .mapMappable(of: Editioned<Match.Full>.self)
            .mapKeys({ .fullMatch(withID: $0) })
    }
        
}
