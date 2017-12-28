//
//  TeamsModel.swift
//  TheGreatGame
//
//  Created by Олег on 15.12.2017.
//  Copyright © 2017 The Great Game. All rights reserved.
//

import Foundation
import Shallows
import Alba

public final class LocalModel<Value> {
    
    private let storage: Storage<Void, Value>
    
    public init(storage: Storage<Void, Value>) {
        self.storage = storage
    }
    
    public var access: Retrieve<Value> {
        return storage.asReadOnlyStorage()
    }
    
    public var writeAccess: WriteOnlyStorage<Void, Value> {
        return storage
            .asWriteOnlyStorage()
            .onCompletingWrite({ (value, result) in
                if result.isSuccess {
                    self.didUpdate.publish(value)
                }
            })
    }
    
    public func prefetch() {
        access.retrieve(completion: { _ in print("Prefetched \(Value.self)") })
    }
    
    public func get() -> Value? {
        return try? access.makeSyncStorage().retrieve()
    }
    
    public func update(with newValue: Value) {
        writeAccess.set(newValue)
    }
    
    public let didUpdate = Publisher<Value>(label: "LocalModel<\(Value.self)>.didUpdate")
    
}

extension LocalModel {
    
    public static func inStorage<T : Mappable>(_ diskStorage: Storage<Filename, Data>, filename: Filename) -> LocalModel<T> {
        let storage = diskStorage
            .mapJSONDictionary()
            .mapMappable(of: T.self)
            .memoryCached()
            .singleKey(filename)
        return LocalModel<T>(storage: storage)
    }
    
    public static func inStorage<T>(_ diskStorage: Storage<Filename, Data>, filename: Filename) -> LocalModel<[T]> where T : MappableBoxable {
        let storage = diskStorage
            .mapJSONDictionary()
            .mapMappable(of: [T].self)
            .memoryCached()
            .singleKey(filename)
        return LocalModel<[T]>(storage: storage)
    }
    
}

extension StorageProtocol where Key : Hashable {
    
    func memoryCached() -> Storage<Key, Value> {
        let memCache = MemoryStorage<Key, Value>()
        return memCache.combined(with: self)
    }
    
}

extension WriteOnlyStorageProtocol {
    
    public func onCompletingWrite(_ handle: @escaping (Value, Result<Void>) -> ()) -> WriteOnlyStorage<Key, Value> {
        return WriteOnlyStorage<Key, Value>(storageName: self.storageName, set: { (value, key, completion) in
            self.set(value, forKey: key, completion: { (result) in
                completion(result)
                handle(value, result)
            })
        })
    }
    
}
