//
//  PushKitTokenUploader.swift
//  TheGreatGame
//
//  Created by Олег on 25.06.17.
//  Copyright © 2017 The Great Game. All rights reserved.
//

import Foundation
import Shallows
import Alba

public final class TokenUploader {
    
    let getDeviceIdentifier: () -> UUID?
    let pusher: WriteOnlyStorage<Void, TokenUpload>
    let consistencyKeeper: UploadConsistencyKeeper<PushToken>
    
    public init(pusher: WriteOnlyStorage<Void, TokenUpload>,
                getDeviceIdentifier: @escaping () -> UUID?,
                consistencyKeepersLastUpload: Storage<Void, PushToken>,
                getToken: Retrieve<PushToken>) {
        self.pusher = pusher
        self.getDeviceIdentifier = getDeviceIdentifier
        self.consistencyKeeper = UploadConsistencyKeeper<PushToken>(actual: getToken, lastUploaded: consistencyKeepersLastUpload, name: "token-uploader-consistency-keeper", reupload: { _ in })
        consistencyKeeper.reupload = self.upload(token:)
        consistencyKeeper.subscribeTo(didUploadFavorites: self.didUploadToken.proxy.map({ $0.token }))
    }
    
    public static func adapt(pusher: WriteOnlyStorage<Void, Data>) -> WriteOnlyStorage<Void, TokenUpload> {
        return pusher
            .mapJSONDictionary()
            .mapMappable()
    }
    
    public func subscribeTo(shouldCheckUploadConsistency: Subscribe<Void>) {
        consistencyKeeper.check(listeningTo: shouldCheckUploadConsistency)
    }
    
    let didUploadToken = Publisher<TokenUpload>(label: "TokenUploader.didUploadToken")
    
    func upload(token: PushToken) {
        guard let deviceID = getDeviceIdentifier() else {
            fault("No device UUID")
            return
        }
        let upload = TokenUpload(deviceIdentifier: deviceID, token: token)
        pusher.set(upload) { (result) in
            switch result {
            case .success:
                self.didUploadToken.publish(upload)
            case .failure(let error):
                printWithContext("Cannot upload token. Error: \(error)")
            }
        }
    }
    
}

public struct TokenUpload : Equatable {
    
    let deviceIdentifier: UUID
    let token: PushToken
    
    public init(deviceIdentifier: UUID, token: PushToken) {
        self.deviceIdentifier = deviceIdentifier
        self.token = token
    }
    
    public static func == (lhs: TokenUpload, rhs: TokenUpload) -> Bool {
        return lhs.deviceIdentifier == rhs.deviceIdentifier && lhs.token.rawToken == rhs.token.rawToken
    }
    
}

extension TokenUpload : Mappable {
    
    public enum MappingKeys : String, IndexPathElement {
        case device_identifier, token
    }
    
    public enum InMappingError : Error {
        case outMapOnly
    }
    
    public init<Source>(mapper: InMapper<Source, MappingKeys>) throws {
        throw InMappingError.outMapOnly
    }
    
    public func outMap<Destination>(mapper: inout OutMapper<Destination, MappingKeys>) throws {
        try mapper.map(self.deviceIdentifier.uuidString, to: .device_identifier)
        try mapper.map(self.token.string, to: .token)
    }
    
}

