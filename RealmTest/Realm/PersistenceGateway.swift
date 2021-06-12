//
//  PersistenceGateway.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 28.05.2021.
//

import Combine
import Foundation
import RealmSwift

enum PersistenceError: Error {
    case notPrimaryKeyObject
}

typealias GetResultBlock<T: PersistenceToDomainMapper> = (Results<T.PersistenceModel>) -> Results<T.PersistenceModel>
typealias SaveResultBlock<T: ObjectToPersistenceMapper> = (Results<T.PersistenceModel>) -> Results<T.PersistenceModel>

protocol PersistenceGatewayProtocol: AnyObject {
    func updateAction(_ action: @escaping (Realm) -> Void) -> AnySinglePublisher<Void, Error>
    
    func get<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnySinglePublisher<M.DomainModel?, Error>
    func getArray<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnySinglePublisher<[M.DomainModel], Error>
    func listen<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnyPublisher<M.DomainModel, Error>
    func listenArray<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnyPublisher<[M.DomainModel], Error>
    
    func save<M: ObjectToPersistenceMapper>(object: M.Model, mapper: M) -> AnySinglePublisher<Void, Error>
    func save<M: ObjectToPersistenceMapper>(objects: [M.Model], mapper: M) -> AnySinglePublisher<Void, Error>
    
    func delete<M: ObjectToPersistenceMapper>(_ type: M.Type, deleteHandler: @escaping SaveResultBlock<M>) -> AnySinglePublisher<Void, Error>
    
    func count<T: ObjectToPersistenceMapper>(_ type: T.Type, filterBlock: @escaping SaveResultBlock<T>) -> AnySinglePublisher<Int, Error>
}

extension PersistenceGatewayProtocol {
    func get<M: PersistenceToDomainMapper>(mapper: M) -> AnySinglePublisher<M.DomainModel?, Error> {
        get(mapper: mapper) { $0 }
    }
}

final class PersistenceGateway: PersistenceGatewayProtocol {
    private let queue: DispatchQueue
    private let configuration: Realm.Configuration
    
    init(queue: DispatchQueue, configuration: Realm.Configuration = .init()) {
        self.queue = queue
        self.configuration = configuration
    }
    
    private func realm<S: Scheduler>(scheduler: S) -> AnyPublisher<Realm, Error> {
        return Just((configuration, nil)) 
            .receive(on: scheduler)
            .tryMap(Realm.init)
            .eraseToAnyPublisher()
    }
    
    // MARK: Get
    
    func get<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnySinglePublisher<M.DomainModel?, Error> {
        return realm(scheduler: queue)
            .map { $0.objects(M.PersistenceModel.self) }
            .map { filterBlock($0).last.map(mapper.convert) }
            .eraseToAnySinglePublisher()
    }
    
    func getArray<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnySinglePublisher<[M.DomainModel], Error> {
        return realm(scheduler: queue)
            .map { $0.objects(M.PersistenceModel.self) }
            .map { filterBlock($0) }
            .map { $0.map(mapper.convert) }
            .eraseToAnySinglePublisher()
    }
    
    // MARK: Listen
    
    func listen<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnyPublisher<M.DomainModel, Error> {
        return realm(scheduler: RunLoop.main)
            .map { $0.objects(M.PersistenceModel.self) }
            .flatMap(\.collectionPublisher)
            .compactMap { filterBlock($0).last }
            .map(mapper.convert)
            .eraseToAnyPublisher()
    }
    
    func listenArray<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnyPublisher<[M.DomainModel], Error> {
        return realm(scheduler: RunLoop.main)
            .map { $0.objects(M.PersistenceModel.self) }
            .flatMap(\.collectionPublisher)
            .map { filterBlock($0) }
            .map { $0.map(mapper.convert) }
            .eraseToAnyPublisher()
    }

    // MARK: Save
    
    func save<M: ObjectToPersistenceMapper>(object: M.Model, mapper: M) -> AnySinglePublisher<Void, Error> {
        return realm(scheduler: queue)
            .tryMap { realm in
                try autoreleasepool {
                    let persistence = mapper.convert(model: object)
                    let hasPrimaryKey = M.PersistenceModel.primaryKey() != nil
                    
                    try realm.write {
                        hasPrimaryKey ? realm.add(persistence, update: .all) : realm.add(persistence)
                    }
                    
                    return ()
                }
            }
            .eraseToAnySinglePublisher()
    }
    
    func save<M: ObjectToPersistenceMapper>(objects: [M.Model], mapper: M) -> AnySinglePublisher<Void, Error> {
        return realm(scheduler: queue)
            .tryMap { realm in
                try autoreleasepool {
                    let persistenceObjects = objects.map(mapper.convert)
                    let hasPrimaryKey = M.PersistenceModel.primaryKey() != nil
                    
                    try realm.write {
                        hasPrimaryKey ? realm.add(persistenceObjects, update: .all) : realm.add(persistenceObjects)
                    }
                    
                    return ()
                }
            }
            .eraseToAnySinglePublisher()
    }
    
    // MARK: Delete
    
    func delete<M: ObjectToPersistenceMapper>(_ type: M.Type, deleteHandler: @escaping SaveResultBlock<M>) -> AnySinglePublisher<Void, Error> {
        return realm(scheduler: queue)
            .tryMap { realm in
                try autoreleasepool {
                    let objects = realm.objects(M.PersistenceModel.self)
                    let toDelete = deleteHandler(objects)
                    
                    try realm.write {
                        realm.delete(toDelete)
                    }
                    
                    return ()
                }
            }
            .eraseToAnySinglePublisher()
    }
    
    // MARK: Action
    
    func updateAction(_ action: @escaping (Realm) -> Void) -> AnySinglePublisher<Void, Error> {
        return realm(scheduler: queue)
            .tryMap { realm in
                try autoreleasepool {
                    try realm.write {
                        action(realm)
                    }
                }
            }
            .eraseToAnySinglePublisher()
    }
    
    func count<T: ObjectToPersistenceMapper>(_ type: T.Type, filterBlock: @escaping SaveResultBlock<T>) -> AnySinglePublisher<Int, Error> {
        return realm(scheduler: queue)
            .map { $0.objects(T.PersistenceModel.self) }
            .compactMap { filterBlock($0).count }
            .eraseToAnySinglePublisher()
    }
}
