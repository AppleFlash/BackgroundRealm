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

struct ChangesetItem<T> {
    let index: Int
    let item: T
}

extension ChangesetItem: Equatable where T: Equatable {}

enum PersistenceChangeset<T, Failure: Error> {
    case initial(_ objects: [T])
    case update(deleted: [Int], inserted: [ChangesetItem<T>], modified: [ChangesetItem<T>])
    case error(Failure)
}

extension PersistenceChangeset: Equatable where T: Equatable {
    static func == (lhs: PersistenceChangeset<T, Failure>, rhs: PersistenceChangeset<T, Failure>) -> Bool {
        switch (lhs, rhs) {
        case (let .initial(lhsObj), let .initial(rhsObj)):
            return lhsObj == rhsObj
        case (let .update(lhsDeleted, lhsInserted, lhsModifier), let .update(rhsDeleted, rhsInserted, rhsModifier)):
            return lhsDeleted == rhsDeleted && lhsInserted == rhsInserted && lhsModifier == rhsModifier
        case (let .error(lhsError), let .error(rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

typealias GetResultBlock<T: PersistenceToDomainMapper> = (Results<T.PersistenceModel>) -> Results<T.PersistenceModel>
typealias SaveResultBlock<T: ObjectToPersistenceMapper> = (Results<T.PersistenceModel>) -> Results<T.PersistenceModel>

protocol PersistenceGatewayProtocol: AnyObject {
    func updateAction(_ action: @escaping (Realm) -> Void) -> AnySinglePublisher<Void, Error>
    
    func get<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnySinglePublisher<M.DomainModel?, Error>
    
    func getArray<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnySinglePublisher<[M.DomainModel], Error>
    
    func listen<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnyPublisher<M.DomainModel, Error>
    
    func listenArray<M: PersistenceToDomainMapper>(
        mapper: M,
        range: Range<Int>?,
        filterBlock: @escaping GetResultBlock<M>
    ) -> AnyPublisher<[M.DomainModel], Error>
    
    func listenArrayChangesSet<M: PersistenceToDomainMapper>(
        mapper: M,
        filterBlock: @escaping GetResultBlock<M>
    ) -> AnyPublisher<PersistenceChangeset<M.DomainModel, Error>, Error>
    
    func save<M: ObjectToPersistenceMapper>(object: M.Model, mapper: M) -> AnySinglePublisher<Void, Error>
    
    func save<M: ObjectToPersistenceMapper>(objects: [M.Model], mapper: M) -> AnySinglePublisher<Void, Error>
    
    func delete<M: ObjectToPersistenceMapper>(_ type: M.Type, deleteHandler: @escaping SaveResultBlock<M>) -> AnySinglePublisher<Void, Error>
    
    func count<T: ObjectToPersistenceMapper>(_ type: T.Type, filterBlock: @escaping SaveResultBlock<T>) -> AnySinglePublisher<Int, Error>
}

extension PersistenceGatewayProtocol {
    func get<M: PersistenceToDomainMapper>(mapper: M) -> AnySinglePublisher<M.DomainModel?, Error> {
        get(mapper: mapper) { $0 }
    }
    
    func getArray<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnySinglePublisher<[M.DomainModel], Error> {
        getArray(mapper: mapper) { $0 }
    }
    
    func listen<M: PersistenceToDomainMapper>(mapper: M) -> AnyPublisher<M.DomainModel, Error> {
        listen(mapper: mapper) { $0 }
    }
    
    func listenArray<M: PersistenceToDomainMapper>(mapper: M, range: Range<Int>? = nil) -> AnyPublisher<[M.DomainModel], Error> {
        listenArray(mapper: mapper, range: nil) { $0 }
    }
    
    func count<T: ObjectToPersistenceMapper>(_ type: T.Type) -> AnySinglePublisher<Int, Error> {
        count(type) { $0 }
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
        // async
//        return Realm.asyncOpen(configuration: configuration).eraseToAnyPublisher()
        
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
    
    func listenArrayChangesSet<M: PersistenceToDomainMapper>(
        mapper: M,
        filterBlock: @escaping GetResultBlock<M>
    ) -> AnyPublisher<PersistenceChangeset<M.DomainModel, Error>, Error> {
        return realm(scheduler: RunLoop.main)
            .map { $0.objects(M.PersistenceModel.self) }
            .flatMap { filterBlock($0).changesetPublisher }
            .map { changeset in
                switch changeset {
                case let .initial(objects):
                    return .initial(objects.map(mapper.convert))
                case let .update(objects, deletions, insertions, modifications):
                    var nModifications: [Int] = []
                    if !deletions.isEmpty {
                        for modIndex in modifications {
                            let deletesLessThenMod = deletions.filter { $0 <= modIndex }.count
                            let newMod = max(0, modIndex - deletesLessThenMod)
                            nModifications.append(newMod)
                        }
                    } else {
                        nModifications = modifications
                    }
                    
                    let inserted = insertions.map { ChangesetItem(index: $0, item: mapper.convert(persistence: objects[$0])) }
                    let modified = nModifications.map { ChangesetItem(index: $0, item: mapper.convert(persistence: objects[$0])) }

                    return .update(deleted: deletions, inserted: inserted, modified: modified)
                case let .error(error):
                    return .error(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func listenArray<M: PersistenceToDomainMapper>(
        mapper: M,
        range: Range<Int>?,
        filterBlock: @escaping GetResultBlock<M>
    ) -> AnyPublisher<[M.DomainModel], Error> {
        return realm(scheduler: RunLoop.main)
            .map { $0.objects(M.PersistenceModel.self) }
            .flatMap(\.collectionPublisher)
            .map { results -> [M.PersistenceModel] in
                let items = filterBlock(results)
                let slice = range.map { $0.clamped(to: 0..<items.count) }.map { Array(items[$0]) }
                return slice ?? Array(items)
            }
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
