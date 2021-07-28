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
            .threadSafeReference()
            .receive(on: scheduler)
            .compactMap { $0.last } // Результат может содержать массив объектов, если поиск осуществлялся не по primary key, либо, если primary key нет вовсе.
                                    // Для обработки ситуации, когда нет primary key берется `last`, а не `first`
            .map(mapper.convert)
            .eraseToAnyPublisher()
    }
	
	func listenOrderedArrayChanges<Source: PersistenceToDomainMapper, Target: PersistenceToDomainMapper>(
		_ sourceType: Source.Type,
		mapper: Target,
		filterBlock: @escaping (Results<Source.PersistenceModel>) -> List<Target.PersistenceModel>?,
		comparator: @escaping (Target.DomainModel, Target.DomainModel) -> Bool
	) -> AnyPublisher<PersistenceChangeset<Target.DomainModel>, Error> {
		return realm(scheduler: RunLoop.main)
			.map { $0.objects(Source.PersistenceModel.self) }
			.flatMap {
				$0.collectionPublisher
					.filter { !$0.isEmpty }
					.prefix(1)
			}
			.compactMap { filterBlock($0) }
			.flatMap(\.collectionPublisher)
			.threadSafeReference()
			.receive(on: scheduler)
			.map { $0.map(mapper.convert) }
			.diff(comparator: comparator)
			.eraseToAnyPublisher()
	}
	
	func listenOrderedArrayChanges<Source: PersistenceToDomainMapper, Target: PersistenceToDomainMapper>(
		_ sourceType: Source.Type,
		mapper: Target,
		filterBlock: @escaping (Results<Source.PersistenceModel>) -> List<Target.PersistenceModel>?
	) -> AnyPublisher<PersistenceChangeset<Target.DomainModel>, Error> where Target.DomainModel: Equatable {
		listenOrderedArrayChanges(
			sourceType,
			mapper: mapper,
			filterBlock: filterBlock
		) { $0 == $1 }
	}
    
    func listenArray<M: PersistenceToDomainMapper>(
        mapper: M,
        range: Range<Int>?,
        filterBlock: @escaping GetResultBlock<M>
    ) -> AnyPublisher<[M.DomainModel], Error> {
        return realm(scheduler: RunLoop.main)
            .map { $0.objects(M.PersistenceModel.self) }
            .flatMap(\.collectionPublisher)
            .threadSafeReference()
            .receive(on: scheduler)
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
				let persistence = mapper.convert(model: object)
				let hasPrimaryKey = M.PersistenceModel.primaryKey() != nil
				
				try realm.safeWrite {
					hasPrimaryKey ? realm.add(persistence, update: update) : realm.add(persistence)
				}
				
				return ()
            }
            .eraseToAnySinglePublisher()
    }
    
    func save<M: ObjectToPersistenceMapper>(objects: [M.Model], mapper: M, update: Realm.UpdatePolicy) -> AnySinglePublisher<Void, Error> {
        return realm(scheduler: scheduler)
            .tryMap { realm in
				let persistenceObjects = objects.map(mapper.convert)
				let hasPrimaryKey = M.PersistenceModel.primaryKey() != nil
				
				try realm.safeWrite {
					hasPrimaryKey ? realm.add(persistenceObjects, update: update) : realm.add(persistenceObjects)
				}
				
				return ()
            }
            .eraseToAnySinglePublisher()
    }
    
    // MARK: Delete
    
    func delete<M: ObjectToPersistenceMapper>(_ type: M.Type, deleteHandler: @escaping SaveResultBlock<M>) -> AnySinglePublisher<Void, Error> {
        return realm(scheduler: scheduler)
            .tryMap { realm in
				let objects = realm.objects(M.PersistenceModel.self)
				let toDelete = deleteHandler(objects)
				
				try realm.safeWrite {
					realm.delete(toDelete)
				}
				
				return ()
            }
            .eraseToAnySinglePublisher()
    }
	
	func deleteAll() {
		let realm = try! Realm(configuration: configuration)
		try! realm.safeWrite {
			realm.deleteAll()
		}
	}
    
    // MARK: Action
    
    func updateAction(_ action: @escaping (Realm) throws -> Void) -> AnySinglePublisher<Void, Error> {
        return realm(scheduler: scheduler)
            .tryMap { realm in
				try realm.safeWrite {
					try action(realm)
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

extension Realm {
	func safeWrite(_ block: () throws -> Void) throws {
		if isInWriteTransaction {
			try block()
		} else {
			try write(block)
		}
	}
}
