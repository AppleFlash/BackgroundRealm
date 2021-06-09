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
    func updateAction(_ action: @escaping (Realm) -> Void) -> AnyPublisher<Void, Error>
    
    func get<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnyPublisher<M.DomainModel, Error> // Make Single
    func getArray<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnyPublisher<[M.DomainModel], Error>
    func listen<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnyPublisher<M.DomainModel, Error>
    
    func save<M: ObjectToPersistenceMapper>(object: M.Model, mapper: M) -> AnyPublisher<Void, Error>
    func save<M: ObjectToPersistenceMapper>(objects: [M.Model], mapper: M) -> AnyPublisher<Void, Error>
    
//    func delete<M: ObjectToPersistenceMapper>(object: M.Model, mapper: M) -> AnyPublisher<Void, Error>
    func delete<M: ObjectToPersistenceMapper>(_ type: M.Type, deleteHandler: @escaping SaveResultBlock<M>) -> AnyPublisher<Void, Error>
    
    func count<T: ObjectToPersistenceMapper>(type: T.Type, filterBlock: @escaping SaveResultBlock<T>) -> AnyPublisher<Int, Error>
}

extension PersistenceGatewayProtocol {
    func get<M: PersistenceToDomainMapper>(mapper: M) -> AnyPublisher<M.DomainModel, Error> {
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
        return Just((configuration, nil)) // чтобы создался в бг
            .receive(on: scheduler)
            .tryMap(Realm.init)
            .eraseToAnyPublisher()
    }
    
    // MARK: Get
    
    func get<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnyPublisher<M.DomainModel, Error> {
        return realm(scheduler: queue)
            .map { $0.objects(M.PersistenceModel.self) }
            .compactMap { filterBlock($0).last }
            .map(mapper.convert)
            .eraseToAnyPublisher()
    }
    
    func getArray<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnyPublisher<[M.DomainModel], Error> {
        return realm(scheduler: queue)
            .map { $0.objects(M.PersistenceModel.self) }
            .map { filterBlock($0) }
            .map { $0.map(mapper.convert) }
            .eraseToAnyPublisher()
    }
    
    // MARK: Listen
    
    func listen<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnyPublisher<M.DomainModel, Error> {
//        guard M.PersistenceModel.primaryKey() != nil else {
//            return Fail(error: PersistenceError.notPrimaryKeyObject).eraseToAnyPublisher()
//        }
        
        return realm(scheduler: RunLoop.main)
            .map { $0.objects(M.PersistenceModel.self) }
            .flatMap(\.collectionPublisher)
            .compactMap { filterBlock($0).last }
            .map(mapper.convert)
            .eraseToAnyPublisher()
    }

    // MARK: Save
    
    func save<M: ObjectToPersistenceMapper>(object: M.Model, mapper: M) -> AnyPublisher<Void, Error> {
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
            .eraseToAnyPublisher()
    }
    
    func save<M: ObjectToPersistenceMapper>(objects: [M.Model], mapper: M) -> AnyPublisher<Void, Error> {
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
            .eraseToAnyPublisher()
    }
    
    // MARK: Delete
    
//    func delete<M: ObjectToPersistenceMapper>(object: M.Model, mapper: M) -> AnyPublisher<Void, Error> {
//        return realm(scheduler: queue)
//            .tryMap { realm in
//                try autoreleasepool {
//                    let persistence = mapper.convert(model: object)
//
//                    try realm.write {
//                        realm.delete(persistence)
//                    }
//
//                    return ()
//                }
//            }
//            .eraseToAnyPublisher()
//    }
    
    func delete<M: ObjectToPersistenceMapper>(_ type: M.Type, deleteHandler: @escaping SaveResultBlock<M>) -> AnyPublisher<Void, Error> {
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
            .eraseToAnyPublisher()
    }
    
    // MARK: Action
    
    func updateAction(_ action: @escaping (Realm) -> Void) -> AnyPublisher<Void, Error> {
        return realm(scheduler: queue)
            .tryMap { realm in
                try autoreleasepool {
                    try realm.write {
                        action(realm)
                    }
                }
            }
            .eraseToAnyPublisher()
    }
    
    func count<T: ObjectToPersistenceMapper>(type: T.Type, filterBlock: @escaping SaveResultBlock<T>) -> AnyPublisher<Int, Error> {
        return realm(scheduler: queue)
            .map { $0.objects(T.PersistenceModel.self) }
            .compactMap { filterBlock($0).count }
            .eraseToAnyPublisher()
    }
}

/// Closure based

//protocol PersistenceClosureGatewayProtocol: AnyObject {
//    func get<M: PersistenceToDomainMapper>(
//        mapper: M,
//        filterBlock: @escaping GetResultBlock<M>,
//        completion: @escaping (Result<M.DomainModel, Error>) -> Void
//    )
//}
//
//final class PersistenceClosureGateway: PersistenceClosureGatewayProtocol {
//    private let queue: DispatchQueue
//    private let configuration: Realm.Configuration
//    
//    init(queue: DispatchQueue, configuration: Realm.Configuration = .init()) {
//        self.queue = queue
//        self.configuration = configuration
//    }
//    
//    private func realm(queue: DispatchQueue, completion: @escaping (Result<Realm, Error>) -> Void) {
//        let config = configuration
//        queue.async {
//            autoreleasepool {
//                do {
//                    completion(.success(try Realm(configuration: config)))
//                } catch {
//                    completion(.failure(error))
//                }
//            }
//        }
//    }
//    
//    // MARK: Get
//    
//    func get<M: PersistenceToDomainMapper>(
//        mapper: M,
//        filterBlock: @escaping GetResultBlock<M>,
//        completion: @escaping (Result<M.DomainModel, Error>) -> Void
//    ) {
//        realm(queue: queue) { result in
//            switch result {
//            case let .success(realm):
//                let objects = realm.objects(M.PersistenceModel.self)
//                guard let filtered = filterBlock(objects).first else { return }
//                let result = mapper.convert(persistence: filtered)
//                completion(.success(result))
//            case let .failure(error):
//                completion(.failure(error))
//            }
//        }
//    }
//}
//
//
//
