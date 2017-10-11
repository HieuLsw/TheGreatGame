//
//  WatchExtension.swift
//  TheGreatGame
//
//  Created by Олег on 26.05.17.
//  Copyright © 2017 The Great Game. All rights reserved.
//

import Foundation
import Alba
import TheGreatKit
import Shallows
import Avenues

final class WatchExtension {
    
    static let main = WatchExtension()
    
    let phone: Phone
    let images: Images
    let api: API
    let apiCache: APICache
    let favoriteTeams: FavoritesRegistry<Team.ID>
    let favoriteMatches: FavoritesRegistry<Match.ID>
    let complicationReloader: ComplicationReloader
    
    init() {
        Alba.InformBureau.isEnabled = true
        Alba.InformBureau.Logger.enable()
        ShallowsLog.isEnabled = true
        self.phone = Phone()
        self.images = Images.inLocalCachesDirectory(subpath: "dev-3-images")
        self.api = API.gitHub()
        self.apiCache = APICache.inLocalCachesDirectory()
        self.favoriteTeams = FavoritesRegistry.inLocalDocumentsDirectory()
        self.favoriteMatches = FavoritesRegistry.inLocalDocumentsDirectory()
        self.complicationReloader = ComplicationReloader()
        subscribe()
    }
    
    func subscribe() {
        phone.didReceiveUpdatedFavoriteTeams.subscribe(self.favoriteTeams, with: FavoritesRegistry.replace)
        phone.didReceiveUpdatedFavoriteMatches.subscribe(self.favoriteMatches, with: FavoritesRegistry.replace)
        complicationReloader.consume(didUpdateFavoriteTeams: self.favoriteTeams.didUpdateFavorite, didUpdateFavoriteMatches: self.favoriteMatches.didUpdateFavorite)
        complicationReloader.consume(complicationMatchUpdate: self.phone.didReceiveComplicationMatchUpdate,
                                     writingTo: apiCache.matches.allFull)
    }
    
    func isFavoriteMatch(_ match: Match.Full) -> Bool {
        return match.isFavorite(isFavoriteMatch: self.favoriteMatches.isFavorite,
                                isFavoriteTeam: self.favoriteTeams.isFavorite)
    }
    
    func chooseMatchToShow(_ lhs: Match.Full, _ rhs: Match.Full) -> Match.Full {
        switch (isFavoriteMatch(lhs),
                isFavoriteMatch(rhs)) {
        case (true, true), (false, false):
            return Match.endsLater(lhs, rhs)
        case (true, false):
            return lhs
        case (false, true):
            return rhs
        }
    }
    
}

extension Phone {
    
    var didReceiveComplicationMatchUpdate: Subscribe<Match.Full> {
        return didReceivePackage.proxy
            .filter({ $0.kind == .complication_match_update })
            .flatMap({ try? Match.Full.unpacked(from: $0) })
    }
    
    var didReceiveUpdatedFavoriteTeams: Subscribe<Set<Team.ID>> {
        return didReceivePackage.proxy
            .adapting(with: IDPackage.adapter)
    }
    
    var didReceiveUpdatedFavoriteMatches: Subscribe<Set<Match.ID>> {
        return didReceivePackage.proxy
            .adapting(with: IDPackage.adapter)
    }

}
