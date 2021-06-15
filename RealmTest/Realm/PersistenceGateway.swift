//
//  PersistenceGateway.swift
//  RealmTest
//
//  Created by Vladislav Sedinkin on 28.05.2021.
//

import Combine
import Foundation
import RealmSwift

typealias GetResultBlock<T: PersistenceToDomainMapper> = (Results<T.PersistenceModel>) -> Results<T.PersistenceModel>
typealias SaveResultBlock<T: ObjectToPersistenceMapper> = (Results<T.PersistenceModel>) -> Results<T.PersistenceModel>

final class PersistenceGateway<S: Scheduler>: PersistenceGatewayProtocol {
    private let scheduler: S
    private let configuration: Realm.Configuration
    
    init(scheduler: S, configuration: Realm.Configuration = .init()) {
        self.scheduler = scheduler
        self.configuration = configuration
    }
    
    private func realm<S: Scheduler>(scheduler: S) -> AnyPublisher<Realm, Error> {
        // Создание рилма в определенном потоке
        return Just((configuration, nil))
            .receive(on: scheduler)
            .tryMap(Realm.init)
            .eraseToAnyPublisher()
    }
    
    // MARK: Get
    
    func get<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnySinglePublisher<M.DomainModel?, Error> {
        return realm(scheduler: scheduler)
            .map { $0.objects(M.PersistenceModel.self) }
            .map { filterBlock($0).last.map(mapper.convert) }
            .eraseToAnySinglePublisher()
    }
    
    func getArray<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnySinglePublisher<[M.DomainModel], Error> {
        return realm(scheduler: scheduler)
            .map { $0.objects(M.PersistenceModel.self) }
            .map { filterBlock($0) }
            .map { $0.map(mapper.convert) }
            .eraseToAnySinglePublisher()
    }
    
    // MARK: Listen
    
    func listen<M: PersistenceToDomainMapper>(mapper: M, filterBlock: @escaping GetResultBlock<M>) -> AnyPublisher<M.DomainModel, Error> {
        return realm(scheduler: RunLoop.main)
            .map { $0.objects(M.PersistenceModel.self) } // Получает список объектов для типа
            .map { filterBlock($0) } // Фильтрует список объектов для получения только интересующего объекта
            .flatMap(\.collectionPublisher) // Наблюдает за изменением фильтрованных объектов
            .compactMap { $0.last } // Результат может содержать массив объектов, если поиск осуществлялся не по primary key, либо, если primary key нет вовсе.
                                    // Для обработки ситуации, когда нет primary key берется `last`, а не `first`
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
                    // Если есть индексы удалённых или добавленных объектов, то нужно скорректировать индексы модификации, т.к. они сдвинуты
                    // Для этого отнимаем кол-во удаленых индексов, которые меньше либо равны каждому индексу модификации
                    // и прибавляем кол-во добавленных индексов, которые меньше либо равны каждому индексу модификации
                    if !deletions.isEmpty || !insertions.isEmpty {
                        for modIndex in modifications {
                            let deletesLessThenMod = deletions.filter { $0 <= modIndex }.count
                            let insertsGreaterThenMode = insertions.filter { $0 <= modIndex }.count
                            var newMod = max(0, modIndex - deletesLessThenMod)
                            newMod = min(objects.count - 1, newMod + insertsGreaterThenMode)
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
                // Если range существует - получаем слайс из коллекции, иначе берём коллекцию целиком
                let slice = range.map { $0.clamped(to: 0..<items.count) }.map { Array(items[$0]) }
                return slice ?? Array(items)
            }
            .map { $0.map(mapper.convert) }
            .eraseToAnyPublisher()
    }

    // MARK: Save
    
    func save<M: ObjectToPersistenceMapper>(object: M.Model, mapper: M, update: Realm.UpdatePolicy) -> AnySinglePublisher<Void, Error> {
        return realm(scheduler: scheduler)
            .tryMap { realm in
                try autoreleasepool {
                    let persistence = mapper.convert(model: object)
                    let hasPrimaryKey = M.PersistenceModel.primaryKey() != nil
                    
                    try realm.write {
                        hasPrimaryKey ? realm.add(persistence, update: update) : realm.add(persistence)
                    }
                    
                    return ()
                }
            }
            .eraseToAnySinglePublisher()
    }
    
    func save<M: ObjectToPersistenceMapper>(objects: [M.Model], mapper: M, update: Realm.UpdatePolicy) -> AnySinglePublisher<Void, Error> {
        return realm(scheduler: scheduler)
            .tryMap { realm in
                try autoreleasepool {
                    let persistenceObjects = objects.map(mapper.convert)
                    let hasPrimaryKey = M.PersistenceModel.primaryKey() != nil
                    
                    try realm.write {
                        hasPrimaryKey ? realm.add(persistenceObjects, update: update) : realm.add(persistenceObjects)
                    }
                    
                    return ()
                }
            }
            .eraseToAnySinglePublisher()
    }
    
    // MARK: Delete
    
    func delete<M: ObjectToPersistenceMapper>(_ type: M.Type, deleteHandler: @escaping SaveResultBlock<M>) -> AnySinglePublisher<Void, Error> {
        return realm(scheduler: scheduler)
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
        return realm(scheduler: scheduler)
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
        return realm(scheduler: scheduler)
            .map { $0.objects(T.PersistenceModel.self) }
            .compactMap { filterBlock($0).count }
            .eraseToAnySinglePublisher()
    }
}
